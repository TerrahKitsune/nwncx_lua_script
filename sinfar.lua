Players = Players or {};
local sinfar = {spytime=3, CO={}, InfosUpdated={}, Chat={}, Nil={}, Portraits={}, whospybubble=nil, Players=Players, chat=nil,CT = ColorToken.Create(), Control=nil, Sinfarian=false};

function sinfar:Start(printfunc, db, chat, COMMANDS, IMGUI)
	
	self.chat = chat;
	self.imgui = IMGUI;	
	self.LastWhospy = {};
	self.ChatLog = {};

	Gui.SetValue("whospyinterval", 4, 3);
	Gui.SetValue("maxchatlogs", 4, 1000);
	Gui.SetValue("cc_filter_name", 5, "");
	Gui.SetValue("cc_filter_msg", 5, "");
	self.imgui:AddRenderFunction(function(ui) self:RenderImguiUI(ui); end);
	self.imgui:AddMainMenuSettingsFunction(function(ui)

		if ui:MenuItem("Whospy", "whospywindow") then
		end
		
		if ui:MenuItem("Chatlog", "chatlog") then
		end
	end);
	
	db:Query([[CREATE TABLE "characters" (
	"PCID"	INTEGER NOT NULL,
	"PLID"	INTEGER NOT NULL,
	"Name"	TEXT NOT NULL,
	"Portrait"	TEXT NOT NULL,
	"LastSeen"	DATE NOT NULL,
	"IngameData"	JSON,
	PRIMARY KEY("PCID"))]]);
	
	db:Query([[CREATE TABLE "players" (
	"PLID"	INTEGER NOT NULL,
	"Name"	INTEGER NOT NULL,
	PRIMARY KEY("PLID"));]]);
	
	db:Query([[CREATE TABLE "chat" (
	"Id"	INTEGER NOT NULL,
	"PCID"	INTEGER,
	"PLID"	INTEGER,
	"ChannelId"	INTEGER NOT NULL,
	"Timestamp"	INTEGER NOT NULL,
	"Data"	JSON NOT NULL,
	PRIMARY KEY("Id" AUTOINCREMENT));]]);
	
	db:Query([[CREATE INDEX "idx_chat_timestamp" ON "chat" ("Timestamp"	DESC);]]);
	db:Query([[CREATE UNIQUE INDEX "idx_players_name" ON "players" ("Name");]]);
	
	self.DB = db;
	self.Print = printfunc;
	
	if COMMANDS then
		COMMANDS:AddCommand("chatlog", function(param)
			self:PopChatlog(param, false);
		end, "Pops open a chatlog, param is the number of records default 100. 0 = all.");
		
		COMMANDS:AddCommand("exportchatlog", function(param)
			self:PopChatlog(param, true);
		end, "Exports the chatlog, param is the number of records default 100. 0 = all.");
		
		COMMANDS:AddCommand("whospy", function()
			
			if  Gui.GetValue("whospywindow", 1) then 
				Gui.SetValue("whospywindow", 1, false);
				self.Print("Whospy: OFF");
			else 
				Gui.SetValue("whospywindow", 1, true);
				self.Print("Whospy: ON");
				self:SendWhoSpy();
			end			
		end, "Toggles auto whospy");
	end
	
	self.Channels = {};
	
	table.insert(self.Channels, "Shout");
	table.insert(self.Channels, "DM");
	table.insert(self.Channels, "Event");
	table.insert(self.Channels, "Action");
	table.insert(self.Channels, "OOC");
	table.insert(self.Channels, "PVP");
	table.insert(self.Channels, "Sex");
	table.insert(self.Channels, "Build");
	table.insert(self.Channels, "FFA");
	table.insert(self.Channels, "Talk");
	table.insert(self.Channels, "Whisper");
	table.insert(self.Channels, "Quiet");
	table.insert(self.Channels, "Silent");
	table.insert(self.Channels, "Yell");
	table.insert(self.Channels, "Party");
	table.insert(self.Channels, "Tell");
	table.insert(self.Channels, "ALL");
	
	for n=1, #self.Channels do 
		Gui.SetValue("c_chan_"..tostring(n), 1, false);
	end
	
	Gui.SetValue("c_chan_"..tostring(#self.Channels), 1, true);
	self:RebuildFilter(#self.Channels);
	
	self:PopulateChatlogData(Gui.GetValue("maxchatlogs", 4));
	self.selectedName = "";
end 

function sinfar:GetPortraitFolder()

	if self.PortraitFolder then
		return self.PortraitFolder;
	end

	self.PortraitFolder = "./portraits/";

	local f = io.open("nwn.ini", "r");
	if f then	
		local rawIni = f:read("*all");
		f:close();
		
		local folder = rawIni:match("PORTRAITS=(.-)[\r,\n]");
		if folder then
			folder = folder:gsub("\\", "/");
			
			if not folder:match("/$") then
				folder = folder .. "/";
			end
			
			self.PortraitFolder = folder;
		end
	end

	self.Print("Using portrait folder: "..self.PortraitFolder);

	return self.PortraitFolder;
end

function sinfar:PopulateChatlogData(limit)

	self.ChatLog = {};
	assert(self.DB:Query("select datetime(`Timestamp`, 'unixepoch', 'localtime') as `Timestamp`, `Data` from Chat order by `Timestamp` desc limit "..tostring(tonumber(limit))..";"));

	local j=Json.Create();
	local rows = {};
	local row;
	local data;
	while self.DB:Fetch() do
		row = self.DB:GetRow();
		data = j:Decode(row.Data);
		table.insert(rows, {
			Timestamp = row.Timestamp,
			Text = data.Text,
			Name = data.Name,
			Channel = data.Channel,
			NameToken = data.NameToken,
			TextToken = data.TextToken
		});
	end
	
	for n=#rows, 1, -1 do 
		self:AddChat(rows[n]);
	end
end

function sinfar:AddChat(chat)

	local maxChats = Gui.GetValue("maxchatlogs", 4);
	local temp;
	
	chat.Timestamp = chat.Timestamp or "";
	chat.Channel = chat.Channel or "";
	chat.Name = NWN.Utf8(chat.Name or "") or "";
	chat.Text = NWN.Utf8(chat.Text or "") or "";

	local r,g,b = chat.NameToken:match("<c(.)(.)(.)>");	
	chat.NameColor = Gui.RGBToVec4(string.byte(r),string.byte(g),string.byte(b));
	
	r,g,b = chat.TextToken:match("<c(.)(.)(.)>");	
	chat.ChannelColor = Gui.RGBToVec4(string.byte(r or ""),string.byte(g or ""),string.byte(b or ""));
	
	for n=#self.ChatLog, 1, -1 do 
	
		if n <= maxChats then 
			self.ChatLog[n+1] = self.ChatLog[n];
		end
	end
	
	self.ChatLog[1] = chat;
end

function sinfar:RebuildFilter(n)

	local k,v;
	
	if n == #self.Channels then
	
		v = Gui.GetValue("c_chan_"..tostring(#self.Channels), 1);
	
		for n=1, #self.Channels-1 do 	
			k = "c_chan_"..tostring(n);
			Gui.SetValue(k, 1, v);
		end
	else
		local trues = 0;
		
		for n=1, #self.Channels-1 do
			k = "c_chan_"..tostring(n);
			if Gui.GetValue(k, 1) then 
				trues = trues + 1;
			end
		end

		Gui.SetValue("c_chan_"..tostring(#self.Channels), 1, trues == (#self.Channels-1));
	end

	v = Gui.GetValue("c_chan_"..tostring(#self.Channels), 1);

	if v then 
		self.ChannelFilter = nil;
	else 
	
		self.ChannelFilter = {};
		
		for n=1, #self.Channels-1 do
			k = "c_chan_"..tostring(n);
			if Gui.GetValue(k, 1) then 
				self.ChannelFilter[self.Channels[n]]=true;
			end
		end
	end
end

function sinfar:CheckFilter(entry)

	if self.ChannelFilter and not self.ChannelFilter[entry.Channel] then
		return false;
	end
	
	local namefilter = Gui.GetValue("cc_filter_name", 5);
	
	if namefilter and namefilter ~= "" then
		
		local ok, result = pcall(string.match, entry.Name, namefilter);
	
		if not ok or not result then 
			return false;
		end 
	end 
	
	local msgfilter = Gui.GetValue("cc_filter_msg", 5);
	
	if msgfilter and msgfilter ~= "" then
		
		local ok, result = pcall(string.match, entry.Text, msgfilter);
	
		if not ok or not result then 
			return false;
		end 
	end 
	
	return true;
end

function sinfar:RenderChatLog(ui)

	ui:PushStyleVar(2, {x=0, y=0});

	ui:SetNextWindowSize({x=500, y=400}, ui.GetEnums().ImGuiCond.FirstUseEver);
	if not ui:Begin("Chatlog", "chatlog") then
		ui:End();
		ui:PopStyleVar();
		return;
	end
	
	if ui:BeginPopup("Channels") then

		for n=1, #self.Channels do
			ui:PushId(n);
			if ui:Checkbox(self.Channels[n], "c_chan_"..tostring(n)) then
				self:RebuildFilter(n);
			end
			ui:PopId();
		end
	
		ui:EndPopup();
	end

	if ui:BeginPopup("Filter Name") then
		if ui:Button("Clear") then 
			Gui.SetValue("cc_filter_name", 5, "");
		end
		ui:SameLine();
		ui:InputText("Filter", "cc_filter_name", "match pattern");
		ui:EndPopup();
	end
	
	if ui:BeginPopup("Filter Message") then
		if ui:Button("Clear") then 
			Gui.SetValue("cc_filter_msg", 5, "");
		end
		ui:SameLine();
		ui:InputText("Filter", "cc_filter_msg", "match pattern");
		ui:EndPopup();
	end

	if ui:Button("Channels") then 
		ui:OpenPopup("Channels");
	end
	
	ui:SameLine();
	
	if ui:Button("Filter Name") then 
		ui:OpenPopup("Filter Name");
	end
	
	ui:SameLine();
	
	if ui:Button("Filter Message") then 
		ui:OpenPopup("Filter Message");
	end
	
	ui:PushStyleVar(14, {x=0, y=0});

	local tmSize = 0;
	local chanSize = 0;
	local nameSize = 0;
	
	local size;
	for n=1, #self.ChatLog do
	
		size = ui:CalcTextSize(self.ChatLog[n].Timestamp);
	
		if size.x > tmSize then 
			tmSize = size.x;
		end
	
		size = ui:CalcTextSize(self.ChatLog[n].Channel);
	
		if size.x > chanSize then 
			chanSize = size.x;
		end
		
		size = ui:CalcTextSize(self.ChatLog[n].Name);
	
		if size.x > nameSize then 
			nameSize = size.x;
		end
	end

	if not ui:BeginChild("chatlogchild") then 
		ui:PopStyleVar();
		ui:PopStyleVar();
		ui:EndChild();
		return;
	end

	ui:PushId("ChatLogWindow");
	if ui:BeginTable("Chat", 2, 1920 | 1 | 64) then
	
		ui:TableSetupColumn("Name", 16, math.max(tmSize, chanSize, nameSize, 1));

		for n=#self.ChatLog, 1, -1 do
		
			if self:CheckFilter(self.ChatLog[n]) then
			
				ui:TableNextRow();
			
				if ui:TableNextColumn() then 
				
					ui:Text(self.ChatLog[n].Timestamp);

					ui:PushId(n);
					ui:PushStyleColor(0, self.ChatLog[n].NameColor);

					if ui:Selectable(self.ChatLog[n].Name, self.ChatLog[n].Name == self.selectedName) then 
						
						if self.selectedName == self.ChatLog[n].Name then 
							self.selectedName = "";
						else				
							self.selectedName = self.ChatLog[n].Name;
						end
					end
					
					ui:PopStyleColor();
					ui:PopId();

					ui:PushStyleColor(0, self.ChatLog[n].ChannelColor);
					ui:Text(self.ChatLog[n].Channel);
					ui:PopStyleColor();
				end
				
				if ui:TableNextColumn() then 
					ui:TextWrapped(self.ChatLog[n].Text);
				end
			end
		end

		ui:EndTable();
	end
	ui:PopId();
	
	ui:PopStyleVar();
	ui:PopStyleVar();
	
	if ui:GetScrollY() >= ui:GetScrollMaxY() then 
		ui:SetScrollHereY(1);
	end
	
	ui:EndChild();
	ui:End();
end

function sinfar:RenderImguiUI(ui)

	if Gui.GetValue("chatlog", 1) then 
		self:RenderChatLog(ui);
	end

	if Gui.GetValue("whospywindow", 1) then 
	
		local obj = NWN.GetGameObject();
	
		if not obj then 
			return;
		end 
	
		local interval = Gui.GetValue("whospyinterval", 4) * 1000;
		local progress = self.whoTimer:Elapsed() / interval;
	
		local symbol;
	
		if progress <= 0.25 then
			symbol = "";
		elseif progress <= 0.50 then
			symbol = ".";
		elseif progress <= 0.75 then
			symbol = ". .";
		else
			symbol = ". . .";
		end
	
		ui:SetNextWindowSize({x=25,y=25},8);
		if ui:Begin("Whospy "..symbol.."###Whospy", "whospywindow", 64) then
			local v, r,g,b;

			if DEBUG then
		
				ui:SliderInt("Whospy Interval", "whospyinterval", 1, 10)
				ui:Separator();
			end
			
			if #self.LastWhospy <= 0 then 
				table.insert(self.LastWhospy, {T="Just You", Who=obj.Name});
			end 
			
			for n=1, #self.LastWhospy do
			
				v = self.LastWhospy[n];
				
				r,g,b = self.chat:GetNameColor(v.Who):match("<c(.)(.)(.)>");

				ui:TextColored(ui.RGBToVec4(string.byte(r),string.byte(g),string.byte(b)), v.Who);
				ui:SameLine();
				
				if v.T == "unheard" then
					ui:TextColored(ui.RGBToVec4(149,139,154), v.T);
				elseif v.T == "talk" then 
					ui:TextColored(ui.RGBToVec4(230,230,230), v.T);
				else
					ui:TextColored(ui.RGBToVec4(200,1,1), v.T);
				end
					
				if n < #self.LastWhospy then
					ui:Separator();
				end
			end
			
			--[[
			local interval = Gui.GetValue("whospyinterval", 4);
			
			if interval == nil then 
				interval = 3;
			end
		
			Gui.SetValue("whospyprogresstext", 5, tostring(math.floor(self.whoTimer:Elapsed())));
		
			interval = interval * 1000;
			interval = self.whoTimer:Elapsed() / interval;
		
			if interval < 0.0 then 
				interval = 0.0;
			elseif interval > 1.0 then 
				interval = 1.0;
			end
		
			ui:ProgressBar(interval, nil, "whospyprogresstext");]]
		end 
		
		ui:End();
	end
end

function sinfar:PopChatlog(param, tofile)

	param = tonumber(param);
	
	if type(param) ~= "number" then 
		param = 100;
	end
	
	local co = self.CO["PopChatlog"];
	
	if not co or coroutine.status(co) == "dead" then 
	
		co = coroutine.create(function ()
			
			local db = tostring(self.DB):match(".-File: (.-)$");
			
			db = assert(SQLite.Open(db, 1));
			
			local ok, err = db:Query("select count(*) as `cnt` from chat;");
		
			if not ok then 
				self.Print(err);
				return;
			elseif not db:Fetch() then		
				self.Print("Failed to fetch count");
				return;
			end 
			
			local count = db:GetRow(1);
			
			if type(param) == "number" then 
				param = math.floor(param);
			else 
				param = 0;
			end 
			
			if param > 0 and param < count then 
				count = param;
			end
			
			local f = nil;
			
			if tofile then
				self.Print("Exporting "..tostring(count).." chatlogs to "..FOLDER.."chatlog.txt");
				
				f = assert(io.open(FOLDER.."chatlog.txt", "w"));		
			else 
				self.Print("Fetching "..tostring(count).." chatlogs");
			end 
			
			coroutine.yield();
		
			local j = Json.Create();
			local defaultToken = "<c"..string.char(0xfe, 0xfe, 0xfe)..">";
		
			coroutine.yield();
		
			ok, err = db:Query("select Data, '[' || datetime(Timestamp, 'unixepoch', 'localtime') || ']' from chat order by Timestamp desc limit "..tostring(count)..";");
		
			if not ok then
				self.Print(err);
				return;
			end
			
			local txt = "";
			local data;
			local nth = 0;
			
			while db:Fetch() do 
			
				data = j:Decode(db:GetRow(1));
			
				if data then
				
					data.Name = tostring(data.Name);
					data.Text = tostring(data.Text);
					data.Channel = tostring(data.Channel);
					data.NameToken = data.NameToken or self.chat:GetNameColor(data.Name) or defaultToken;
					data.TextToken = data.TextToken or defaultToken;		
					
					if f then
					
						data.Area = data.Area or "Unknown Area";
					
						f:write((db:GetRow(2) or "[-]") .. " [".. data.Area .."] " ..data.Name..": ["..data.Channel.."] "..data.Text .."\n\n");
					else
						txt = txt .. (db:GetRow(2) or "[-]") .. " " .. data.NameToken ..data.Name..":</c>"..data.TextToken.." ["..data.Channel.."] "..data.TextToken..data.Text .."</c></c>\n\n";
					end
					
					nth = nth + 1;
				
					if nth >= 100 then		
						if f then
							f:flush();
						end
						nth = 0;
						coroutine.yield();
					end
				end
			end
			
			coroutine.yield();
		
			db:Close();
		
			if f then 
				f:flush();
				f:close();
				Debug("Chatlog export finished");
			else		
				NWN.TextBox(txt);
			end
		end);
		
		self.CO["PopChatlog"] = co;
	end
end

function sinfar:SendWhoSpy()
	if self:IsSinfar() then
		NWN.Chat("!whospy", 3);
	end
end

function sinfar:IsSinfar(player)

	local ply = player or NWN.GetPlayer();

	if not ply then 
		return self.Sinfarian;
	end 

	self.Sinfarian = (ply.Id ~= 0);

	return self.Sinfarian;
end

function sinfar:IsIdPlayer(objid)

	local numb = tonumber(objid, 16);
	if not numb then 
		return false;
	end 
	
	return (numb & 0xC0000000) == 0xC0000000;
end

function sinfar:SetControl(obj)

	if not obj or not sinfar:IsIdPlayer(obj.Id) then
		return;
	end 

	self.Control = obj.Id;
end

function sinfar:HearListHasPlayer(hear, name)

	for k,v in pairs(hear) do
		if v.Player == name then 
			return true;
		end 
	end
	
	return false;
end

function sinfar:AddPlayer(ply)
	self.Players[ply.Id] = ply;
end

function sinfar:RemovePlayer(ply)
	self.Players[ply.Id] = nil;
end

function sinfar:WhoSpy(text)

	if not Gui.GetValue("whospywindow", 1) then 
		return false;
	end 

	self.CT:Parse(text);

	local txt = self.CT:Strip();

	if txt:match("^===") and self:IsSinfar() then

		txt = txt:match([[=== PCs able to hear you ===(.+)========================]]);
		
		if not txt then 
			return false;
		end
		
		if txt:sub(1,1) == "\n" then
			txt = txt:sub(2);
		else
			return false;
		end 

		local hears={};
		local c,p,t;
		for row in txt:gmatch("(.-)\n") do 
			c,p,t = row:match("(.+)%s%((.-)%)%s%((.-)%)");
			if c == nil then 
				c,p = row:match("(.+)%s%((.-)%)");
				t = "talk";
			end
			table.insert(hears, {Who=c, Player=p, T=t});
		end
		
		local selfc = self.Control; 
		
		if not selfc and NWN.GetPlayer() then 
			selfc = NWN.GetPlayer().ObjectId;
			self.Control = selfc;
		end
		
		for k,v in pairs(self.Players) do
		
			if v.ObjectId ~= selfc and not self:HearListHasPlayer(hears, v.Name) then
				c = NWN.GetCreatureByPlayerId(k);

				if c then
					table.insert(hears, {Who=c.Name, Player=v.Name, T="unheard"});
				end
			end	
		end

		if self.imgui and self.imgui.Enabled then
		
			self.LastWhospy = hears;
			return true;
		end

		local msg = "<c"..string.char(151,202,100)..">==== PCs near you ====</c>\n";
		local unheard = "<c"..string.char(149,139,154)..">";
		local talk = "<c"..string.char(230,230,230)..">";
		local whisp = "<c"..string.char(200,1,1)..">";
		local token;
		
		for k,v in pairs(hears) do
		
			if v.T == "unheard" then
				token = unheard;
			elseif v.T == "talk" then 
				token = talk;
			else
				token = whisp;
			end
		
			msg = msg .. self.chat:GetNameColor(v.Who)..v.Who.."</c> ("..v.Player..") "..token.."("..v.T..")</c>\n";	
		end

		msg = msg .. "<c"..string.char(151,202,100)..">====================</c>";

		local x,y = NWN.GetSceneSize();
		
		if self.whospybubble then 
			self.whospybubble:Destroy();
		end 
		
		if #hears > 0 then
			if METRICS then 
				y = y-20;
			end
			self.whospybubble = TextBubble.Create(msg, 0, y);
			self.whospybubble:Activate();
		end
		
		return true;
	else 
		return false;
	end
end

function sinfar:IsPortraitUnknown(portrait)
	
	if type(portrait) == "userdata" then 
		portrait = portrait:ToAnsi();
	end
	
	portrait = portrait or "";
	portrait = portrait:lower();
	
	return (portrait == "po_hu_f_99_" or portrait == "po_hu_m_99_" or portrait == "");
end

function sinfar:HasPortraitResources(resref)

	return 	NWN.GetResourceExists(resref.."h", 3) and
			NWN.GetResourceExists(resref.."l", 3) and
			NWN.GetResourceExists(resref.."m", 3) and
			NWN.GetResourceExists(resref.."s", 3) and
			NWN.GetResourceExists(resref.."t", 3);
end

function sinfar:UpdatePlayerInfo(playername)

	local co = self.CO["info_"..playername];

	if co and coroutine.status(co) ~= "dead" then 
		return co;
	end 

	co = coroutine.create(function ()
	
		if not self:IsSinfar() then 
			self.Print("UpdatePlayerInfo: not sinfar");
			return;
		elseif self.InfosUpdated[playername] and self.InfosUpdated[playername].Success then
			return;
		end
		
		self.InfosUpdated[playername] = {Last=Runtime(), Success=false};
	
		print("Fetching player info: "..playername);
	
		local r = Http.Start("GET","https://nwn.sinfar.net/search_characters.php?player_name="..Http.UrlEncode(playername));
		r:SetTimeout(60);
		
		local IsRunning, status, runtime, recv, send = r:GetStatus();
		while IsRunning do
			coroutine.yield();
			IsRunning, status, runtime, recv, send = r:GetStatus();
		end

		local code, ok, contents, header = r:GetResult();

		if code ~= 200 then
			self.Print("Unable to update player "..playername..": "..tostring(code).." "..tostring(ok));
			return;
		end 

		local tbody = contents:match([[<tbody>(.+)</tbody>]]);
		
		if not tbody then 
			self.Print("Unexpected query contents: "..tostring(contents));
			return;
		end 
		
		local data={};

		for row in tbody:gmatch("<tr>(.-)</tr>")do 
			local plid, pcid, playername, charname, world, portrait, lastseen = row:match([[<td>(.-)</td>.-<td>(.-)</td>.-<td>(.-)</td>.-<td>(.-)</td>.-<td>(.-)</td>.-<td>(.-)</td>.-<td>.-</td>.-<td>(.-)</td>]]);
			
			charname = charname:match([[<a href="character.php%?pc_id=.-">(.-)</a>]]);
			portrait = portrait:match([[href="/.+/(.-)h.jpg"]]);
			
			plid = tonumber(plid);
			pcid = tonumber(pcid);		
			
			if plid and pcid and playername and charname and world and portrait and lastseen and world == "SF" then 
				table.insert(data, {plid=plid,pcid=pcid, playername=playername,charname=charname,world=world,portrait=portrait, lastseen=lastseen});
			end
		end 

		local save;

		if #data > 0 then

			save = function()
			
				for	n=1, #data do 
				
					ok, err = self.DB:Query("select Name from players where PLID = @id;",{id=data[n].plid});
				
					if not ok then 
						self.Print(err);
						return false;
					end
				
					if ok and self.DB:Fetch() then 
					
						if self.DB:GetRow(1) ~= data[n].playername then 
						
							self.Print("Updating PLID "..tostring(data[n].plid).." from "..self.DB:GetRow(1).." to "..data[n].playername);
							ok, err = self.DB:Query("update players set Name = @name where PLID = @id;", {id=data[n].plid,name=data[n].playername});
						end				
					else
						self.Print("First seen player: "..data[n].playername);
						ok, err = self.DB:Query("insert into players (`PLID`,`Name`)VALUES(@id, @name);", {id=data[n].plid,name=data[n].playername});
					end
					
					if not ok then 
						self.Print(err);
						return false;
					end
					
					ok, err = self.DB:Query("select PCID from characters where PCID = @id;",{id=data[n].pcid});
					
					if not ok then 
						self.Print(err);
						return false;
					end
					
					if not self.DB:Fetch() or self.DB:GetRow(1) ~= data[n].pcid then 
						self.Print("First seen character: "..data[n].charname);
						ok, err = self.DB:Query("insert into characters (`PCID`,`PLID`,`Name`,`Portrait`,`LastSeen`)VALUES(@id, @plid, @name, @portrait, @lastseen);", {id=data[n].pcid, plid=data[n].plid, name=data[n].charname, portrait=data[n].portrait, lastseen=data[n].lastseen});
					end 
					
					if not ok then 
						self.Print(err);
						return false;
					end 

					if self:IsPortraitUnknown(data[n].portrait) then 
						ok, err = self.DB:Query("update characters set `Name`=@name, `LastSeen`=@lastseen, `PLID`=@plid WHERE `PCID`=@id", {name=data[n].charname, lastseen=data[n].lastseen, plid=data[n].plid, id=data[n].pcid});
					else			
						ok, err = self.DB:Query("update characters set `Name`=@name, `Portrait`=@portrait, `LastSeen`=@lastseen, `PLID`=@plid WHERE `PCID`=@id", {name=data[n].charname, portrait=data[n].portrait, lastseen=data[n].lastseen, plid=data[n].plid, id=data[n].pcid});
					end 
					
					if not ok then 
						self.Print(err);
						return false;
					end
				end
				
				return true;
			end
		else 
			save = function() return true; end
		end
		
		local tries = 0;
		
		while not save() do
			coroutine.yield();
			tries = tries + 1;
			if tries > 3 then 
				self.Print("Failed to update records for "..playername);
				return;
			end 
		end
		
		self.InfosUpdated[playername].Success = true;
		print("Fetched player info: "..playername.." "..tostring(#data).." records updated");
	end);

	self.CO["info_"..playername] = co;
	return co;
end

function sinfar:DownloadPortraitByResRef(resref)

	local co = self.CO["d_"..resref];

	if co and coroutine.status(co) ~= "dead" then 
		return co;
	end 

	co = coroutine.create(function ()

		local query = "https://nwn.sinfar.net/portraits_download_one.php?resref="..Http.UrlEncode(resref);
					
		self.Print("Downloading: "..query);

		local r = Http.Start("GET",query);
		r:SetTimeout(300);

		local IsRunning, status, runtime, recv, send = r:GetStatus();
		while IsRunning do
			coroutine.yield();
			IsRunning, status, runtime, recv, send = r:GetStatus();
		end	

		local raw = r:GetRaw();

		if not raw then 
			self.Print("Failed to download: "..query);
			return;
		end

		local headers = "";
		local r;
		local l;
		while not headers:match("\r\n\r\n$") do
		
			r = raw:read(1);	
			l = headers:len();
			
			if not r or l > 1048576 then
				headers = nil;
				break;
			elseif l % 1000 == 0 then
				coroutine.yield();
			end
			
			headers = headers .. r;
		end
			
		local code, status, rest = headers:match("HTTP/.-%s(.-)%s(.-)\n(.+)\r\n");
		
		local headers = {};

		for k,v in rest:gmatch("(.-):%s(.-)\r\n") do
			headers[k] = v;
		end
		
		local filename = nil;
		
		if headers["Content-Disposition"] then 
			filename = headers["Content-Disposition"]:match([[.-filename="(.-)"]]);
		end 
		
		if not filename then 
			filename = resref..".7z";
		end
		
		filename = self:GetPortraitFolder()..filename;

		local f = io.open(filename, "wb");
		
		if not f then 
			self.Print("Unable to open file for write: " .. filename);
			return;
		end 
		
		local buffer;
		local written = 0;
		repeat
		
			buffer = raw:read(1048576);
			coroutine.yield();
			if buffer and buffer:len() > 0 then 
				f:write(buffer);
				f:flush();
				written = written + buffer:len();
			end
		
		until buffer == nil;
		
		coroutine.yield();
		f:close();
		raw:close();
		
		self.Print("Downloaded: " .. filename.. " "..tostring(written) .. " bytes");
		
		coroutine.yield();
		
		local archive, err = Archive.OpenRead(filename);
		
		if not archive then 
			self.Print(err);
			return;
		end 
		
		local entries = archive:Entries();
		local file, size, data;
		local extracted = 0;
		for n=1, #entries do 

			file, size = archive:SetEntry(n)

			if file:match(".+[hHlLmMsStT]%.[tT][gG][aA]$") then 
				
				self.Print("Extracting "..self:GetPortraitFolder()..file);
				
				data = archive:Read();
				
				if data then 
					f = assert(io.open(self:GetPortraitFolder()..file, "wb"));

					while data do 
						coroutine.yield();
						f:write(data);
						f:flush();
						data = archive:Read(1048576);
					end

					f:close();
					coroutine.yield();
					extracted = extracted + 1;
				end			
			end 	
		end
		
		if extracted ~= 5 then
			self.Print("Failed to extract all files: " .. filename);
		end

		archive:Close();
		FileSystem.Delete(filename);
		
	end);

	self.CO["d_"..resref] = co;
	
	return co;
end

function sinfar:DownloadPortraitIfMissing(playerid, ori)

	ori = ori or "po_hu_f_99_";

	local obj = NWN.GetPlayer(playerid);
		
	if not obj then 
		return ori;
	end 

	local characterid = obj.Id.."_"..obj.ObjectId;

	if self.Portraits[characterid] then	
		return self.Portraits[characterid];
	elseif self.CO[characterid] then
		return ori;
	end 

	if not self:IsSinfar() then
		self.Portraits[characterid] = ori;
		self.Print("DownloadPortraitIfMissing: not sinfar");
		return ori;
	end

	local ok, err = self.DB:Query([[select Portrait from characters join players on characters.PLID=players.PLID where players.Name like @p and characters.Name like @c order by characters.LastSeen desc;]], {p=Wchar.FromAnsi(obj.Name), c=Wchar.FromAnsi(obj.CharacterName)});

	if ok and self.DB:Fetch() then
	
		local row = self.DB:GetRow();
	
		if self:HasPortraitResources(row.Portrait) then
			ori = row.Portrait;
		end
	end
	
	self.Portraits[characterid] = ori;
	
	local co = coroutine.create(function ()
	
		local characterid = obj.Id.."_"..obj.ObjectId;
	
		local update = self:UpdatePlayerInfo(obj.Name); 
	
		while coroutine.status(update) ~= "dead" do
			coroutine.yield();
		end
	
		local ok, err = self.DB:Query([[select Portrait, PCID from characters join players on characters.PLID=players.PLID where players.Name like @p and characters.Name like @c order by characters.LastSeen desc;]], {p=Wchar.FromAnsi(obj.Name), c=Wchar.FromAnsi(obj.CharacterName)});
	
		if not ok then 
			self.Print(err);
			return;
		end 
	
		local portrait = nil;
		local pcid = nil;
		
		if self.DB:Fetch() then 
			portrait = self.DB:GetRow(1);
			pcid =  self.DB:GetRow(2);
		end
	
		if not portrait then 
			self.Portraits[characterid] = ori;
			self.Print("Missing portrait "..obj.CharacterName);
			return;
		end
	
		local gameObject = NWN.GetGameObject(obj.ObjectId);
	
		if not gameObject then
			return;
		end
	
		if self:HasPortraitResources(portrait) then

			if gameObject.Portrait ~= portrait then	
				NWN.SetPortrait(obj.ObjectId, portrait);
			end
			
			self.Portraits[characterid] = portrait;
			return;
		end 

		update = self:DownloadPortraitByResRef(portrait);
		
		while coroutine.status(update) ~= "dead" do
			coroutine.yield();
		end

		if NWN.UpdatePortraitResourceDirectory() and self:HasPortraitResources(portrait) then
			if gameObject.Portrait ~= portrait then	
				NWN.SetPortrait(obj.ObjectId, portrait);
			end
			self.Portraits[characterid] = portrait;
			return;
		end
		
		self.Print("Fallback download and convert jpg");
		
		local query = "https://nwn.sinfar.net/getcharportrait.php?pc_id="..pcid.."&res=h";
					
		self.Print("Downloading: "..query);

		local r = Http.Start("GET",query);
		r:SetTimeout(300);

		local IsRunning, status, runtime, recv, send = r:GetStatus();
		while IsRunning do
			coroutine.yield();
			IsRunning, status, runtime, recv, send = r:GetStatus();
		end	
		
		local code, ok, contents, header = r:GetResult()
		
		if code ~= 200 then 
			self.Print("Failed: "..query.." "..tostring(code).." "..tostring(ok));
			self.Portraits[characterid] = ori;
			return;
		end
		
		coroutine.yield();
		
		local f = io.open(self:GetPortraitFolder()..portrait..".jpg", "wb");
		if not f then 
			self.Print("Failed to open file for write "..self:GetPortraitFolder()..portrait..".jpg");
			self.Portraits[characterid] = ori;
			return;
		end
		
		f:write(contents);
		f:flush();
		f:close();
	
		coroutine.yield();
	
		if NWN.PortraitConvert(portrait) and self:HasPortraitResources(portrait) then 
			if gameObject.Portrait ~= portrait then	
				NWN.SetPortrait(obj.ObjectId, portrait);
			end
			self.Portraits[characterid] = portrait;
			self.Print("Portrait converted: "..portrait);
		else 	
			self.Portraits[characterid] = ori;
			self.Print("Failed to convert portrait "..portrait);
		end
		
		FileSystem.Delete(self:GetPortraitFolder()..portrait..".jpg");
	end);
	
	
	self.CO[characterid] = co;
	
	return ori, co;
end

function sinfar:LogChat(chat, type, playerId, resref)

	if 	type ~= 1 and
		type ~= 2 and
		type ~= 8 and
		type ~= 64 and 
		type ~= 1024 then 

		return;
	end 
	
	if not self:IsSinfar() then 
		self.Print("LogChat: not sinfar");
		return;
	end 

	table.insert(self.Chat, {C=chat:ToString(), T=type, P=playerId, R=resref});
	local co = self.CO["Chat"];
	
	if not co or coroutine.status(co) == "dead" then 
	
		co = coroutine.create(function ()
		
			local msgs;
			local msg;
			local send;
			local parts;
			local ok, err;
			local j = Json.Create();
			local pl, pc;
			
			j:SetNullValue(self.Nil);
			
			while self.Chat and #self.Chat > 0 do 
			
				msgs = self.Chat;
				self.Chat={};
				
				for idx=1, #msgs do 
					
					pl = nil; 
					pc = nil;
					
					msg = msgs[idx];
					send = {Portrait=msg.R};
					local ct = ColorToken.Create();
					ct:Parse(msg.C);
					parts = ct:GetAsParts();
					
					send.Name = parts[1].Text:match("(.+):");
					send.NameToken = parts[1].Token;
					send.Text = parts[2].Text;
					
					if send.Text == "" and #parts > 2 then
						send.Text = parts[3].Text;
						send.TextToken = parts[3].Token;
					else
						send.TextToken = parts[2].Token;
					end

					send.Channel = send.Text:match("^%[(.-)%]%s");
					
					if not send.Channel then 
						send.Channel = "Talk";
					else 
						send.Text = send.Text:match("^%[.-%]%s(.+)");
						if send.Channel:match(".-(%s)") then 
							send.Channel = send.Channel:match("(.-)%s");
						end				
					end
					
					local chatlogmsg = {
						Name = send.Name,
						Text =send.Text,
						Channel = send.Channel,
						Timestamp = os.time(),
						TextToken = send.TextToken,
						NameToken = send.NameToken
					};
					
					assert(self.DB:Query("select datetime("..tostring(tonumber(chatlogmsg.Timestamp))..", 'unixepoch', 'localtime');"));
	
					if self.DB:Fetch() then
						chatlogmsg.Timestamp = self.DB:GetRow(1);
					end
					
					self:AddChat(chatlogmsg);

					if msg.P then 

						local ply = NWN.GetPlayer(msg.P);

						if ply then	
							send.Player = ply.Name;
							local failsafe = Runtime();
							local fails = 0;
							while not pl do
							
								ok, err = self.DB:Query([[select PLID from players where Name like @p;]], {p=Wchar.FromAnsi(send.Player)});
								
								if not ok then
									self.Print(err);
								elseif self.DB:Fetch() then
									pl = self.DB:GetRow(1);
								else 
								
									failsafe = Runtime() + (60000*fails);
									
									--print(failsafe);
									
									while failsafe > Runtime() do 
										coroutine.yield();
										--print(failsafe-Runtime());
									end 
									
									fails = fails + 1;
								
									if fails >= 3 then
										Debug("Record "..send.Player.." not found after 3 retries");
										return;
									end 
								
									local co = self:UpdatePlayerInfo(send.Player);
									while coroutine.status(co) ~= "dead" do
										coroutine.yield();
									end
								end 
							end
							
							ok, err = self.DB:Query([[select PCID from characters join players on characters.PLID=players.PLID where players.Name like @p and characters.Name like @c order by characters.LastSeen desc;]], {p=Wchar.FromAnsi(send.Player), c=Wchar.FromAnsi(send.Name)});
						
							if not ok then 
								self.Print(err);
							end 
						else 
							ok = nil;
						end
					
						if ok and self.DB:Fetch() then 
							pc = self.DB:GetRow(1);
						else 
							pc = nil;
						end			
					end
					
					if not send.Name or send.Name == "" then 
						send.Name = self.Nil;
						--self.Print(parts[1]);
						--self.Print(parts[2]);
						send.Text="";
					end
					
					if not send.Channel or send.Channel == "" then 
						send.Channel = self.Nil;
						--self.Print(parts[1]);
						--self.Print(parts[2]);
						send.Text="";
					end
					
					if not send.Player then 
						send.Player = self.Nil;
					end
					
					if not send.Portrait then 
						send.Portrait = self.Nil;
					end
					
					if not send.Text or send.Text == "" then 
						
						return;
					end
					
					local area = NWN.GetArea();
					
					if area then 
						ct:Parse(area.Name);
						send.Area = ct:Strip();
					end 
					
					local params = {};
					params.pcid = pc;
					params.plid = pl;
					params.chan = msg.T;					
					params.data = j:Encode(send);
					
					repeat
					ok, err = self.DB:Query([[INSERT INTO chat(PCID,PLID,ChannelId,Timestamp,Data) VALUES (@pcid,@plid,@chan,strftime('%s', 'now'),@data);]], params);
					
					if not ok then 
						self.Print(err);
						coroutine.yield();
					end
					until ok;
					
					coroutine.yield();
				end
			end	
		end);
	
		self.CO["Chat"] = co;
	end
	
	return co;
end

function sinfar:GetPCID(objid)

	local obj = NWN.GetGameObject(objid);
		
	if not obj then 
		return nil;
	end 

	local ply = NWN.GetPlayerByObjectId(obj.Id);

	if not ply then 
		return nil;
	end

	local ok, err = self.DB:Query([[select PCID from characters join players on characters.PLID=players.PLID where players.Name like @p and characters.Name like @c order by characters.LastSeen desc;]], {p=Wchar.FromAnsi(ply.Name), c=Wchar.FromAnsi(obj.Name)});

	if ok and self.DB:Fetch() then 
		return self.DB:GetRow(1);
	else 
		return nil;
	end
end

function sinfar:UpdateInGameData(objid)

	local co = coroutine.create(function ()

		local obj = NWN.GetGameObject(objid);
		
		if not obj then 
			return;
		end

		local ply = NWN.GetPlayerByObjectId(obj.Id);

		if not ply then 
			return;
		elseif not self:IsSinfar(ply) then 
			return;
		end
		
		local resref, subroutine = self:DownloadPortraitIfMissing(ply.Id, obj.Portrait);
		
		if subroutine then 
			while coroutine.status(subroutine) ~= "dead" do
				coroutine.yield();
			end
		end 

		local id = self:GetPCID(obj.Id);

		if id == nil then 
			return;
		end

		obj = NWN.GetGameObject(obj.Id);

		if not obj then 
			return;
		end 
		
		ply = NWN.GetPlayerByObjectId(obj.Id);
		
		if not ply then 
			return;
		end

		local data = {PC=obj, PLAYER=ply, Timestamp=os.time(), AREA=NWN.GetArea()};

		local ok, err = self.DB:Query("update characters set `IngameData`=@data WHERE `PCID`=@id", {data=Json.Create():Encode(data), id=id});

		if not ok then 
			self.Print(err);
		end

	end);

	self.CO[tostring(co)] = co;
	return co;
end

sinfar.whoTimer=Timer.New();
sinfar.whoTimer:Start()

function sinfar:Tick()

	local dead = nil;
	local count = 0;
	local ok, err;
	
	for k,v in pairs(self.CO) do
		
		if coroutine.status(v) == "dead" then 
			dead = dead or {};
			table.insert(dead, k);
		else 

			ok, err = coroutine.resume(v);
			
			if not ok then 
				self.Print(err);
			end
			
			count = count + 1;
		end		
	end

	if dead then 
		for n=1, #dead do 
			self.CO[dead[n]] = nil;
		end
	end
	
	if Gui.GetValue("whospywindow", 1) then

		if self.spytime < 1 then 
			self.spytime = 1;
		end 

		local interval = Gui.GetValue("whospyinterval", 4);
		
		if interval == nil then 
			interval = 3;
			Gui.SetValue("whospyinterval", 4, interval);
		end

		if self.whoTimer:Elapsed() > (interval * 1000) then

			self:SendWhoSpy();
			
			self.whoTimer:Stop();
			self.whoTimer:Reset();
			self.whoTimer:Start();
		end
	elseif self.whospybubble then 
		self.whospybubble:Destroy();
		self.whospybubble=nil;
	end
	
	return count;
end

return sinfar;