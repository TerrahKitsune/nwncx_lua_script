Players = Players or {};
local sinfar = {spytime=3, CO={}, Chat={}, Nil={}, Portraits={}, whospybubble=nil, Players=Players, chat=nil,CT = ColorToken.Create(), Control=nil, Sinfarian=false};

function sinfar:Start(printfunc, db, chat, COMMANDS)
	
	self.chat = chat;
	
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
	
	db:Query([[create view ChatLog as
	select Id,
	Timestamp,
	'[' || datetime(Timestamp, 'unixepoch', 'localtime') || '] [' ||
	COALESCE(json_extract(Data, "$.Channel"),'NULL') || "] " ||
	COALESCE(json_extract(Data, "$.Name"),'NULL') || ": " ||
	COALESCE(json_extract(Data, "$.Text"),'') as `Log` from chat;]]);
	
	db:Query([[CREATE UNIQUE INDEX "idx_players_name" ON "players" ("Name");]]);
	
	self.DB = db;
	self.Print = printfunc;
	
	if COMMANDS then
		COMMANDS:AddCommand("chatlog", function()
			self:PopChatlog();
		end);
		
		COMMANDS:AddCommand("whospy", function()
			
			if self.WHOSPY then 
				self.WHOSPY = false;
				self.Print("Whospy: OFF");
			else 
				self.WHOSPY = true;
				self.Print("Whospy: ON");
				self:SendWhoSpy();
			end
			
		end);
	end 
end 

function sinfar:PopChatlog()

	local co = self.CO["PopChatlog"];
	
	if not co or coroutine.status(co) == "dead" then 
	
		co = coroutine.create(function ()
			
			local ok, err = self.DB:Query("select count(*) as `cnt` from chat;");
		
			if not ok then 
				self.Print(err);
				return;
			elseif not self.DB:Fetch() then		
				self.Print("Failed to fetch count");
				return;
			end 
			
			local count = self.DB:GetRow(1);
			
			self.Print("Fetching "..tostring(count).." chatlogs");
		
			coroutine.yield();
		
			local j = Json.Create();
			local defaultToken = "<c"..string.char(0xfe, 0xfe, 0xfe)..">";
		
			coroutine.yield();
		
			ok, err = self.DB:Query("select Data, '[' || datetime(Timestamp, 'unixepoch', 'localtime') || ']' from chat order by Timestamp desc;");
		
			if not ok then
				self.Print(err);
				return;
			end
			
			local txt = "";
			local data;
			
			while self.DB:Fetch() do 
			
				data = j:Decode(self.DB:GetRow(1));
			
				if data then
				
					data.Name = tostring(data.Name);
					data.Text = tostring(data.Text);
					data.Channel = tostring(data.Channel);
					data.NameToken = data.NameToken or self.chat:GetNameColor(data.Name) or defaultToken;
					data.TextToken = data.TextToken or defaultToken;		
					
					txt = txt .. (self.DB:GetRow(2) or "[-]") .. " " .. data.NameToken ..data.Name..":</c>"..data.TextToken.." ["..data.Channel.."] "..data.TextToken..data.Text .."</c></c>\n\n";
				end
			end
			
			coroutine.yield();
		
			TextBox(txt);
		end);
		
		self.CO["PopChatlog"] = co;
	end
end

function sinfar:SendWhoSpy()
	if self:IsSinfar() then
		NWN.Chat("!whospy", 3);
	end
end

function sinfar:IsSinfar()

	local ply = NWN.GetPlayer();

	if not ply then 
		return Sinfarian;
	end 

	Sinfarian = (ply.Id ~= 0);

	return Sinfarian;
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

	if not self.WHOSPY then 
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

	local co = self.CO[playername]

	if co and coroutine.status(co) ~= "dead" then 
		return co;
	end 

	co = coroutine.create(function ()
	
		if not self:IsSinfar() then 
			self.Print("UpdatePlayerInfo: not sinfar");
			return;
		end
	
		self.Print("Fetching player info: "..playername);
	
		local r = Http.Start("GET","https://nwn.sinfar.net/search_characters.php?player_name="..Http.UrlEncode(playername));
		r:SetTimeout(60);
		
		local IsRunning, status, runtime, recv, send = r:GetStatus();
		while IsRunning do
			coroutine.yield();
			IsRunning, status, runtime, recv, send = r:GetStatus();
		end

		local code, ok, contents, header = r:GetResult()

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
				
					ok, err = self.DB:Query("insert or ignore into players (`PLID`,`Name`)VALUES(@id, @name);", {id=data[n].plid,name=data[n].playername});
					
					if not ok then 
						self.Print(err);
						return false;
					end
					
					ok, err = self.DB:Query("insert or ignore into characters (`PCID`,`PLID`,`Name`,`Portrait`,`LastSeen`)VALUES(@id, @plid, @name, @portrait, @lastseen);", {id=data[n].pcid, plid=data[n].plid, name=data[n].charname, portrait=data[n].portrait, lastseen=data[n].lastseen});
					
					if not ok then 
						self.Print(err);
						return false;
					end 
					
					if self:IsPortraitUnknown(data[n].portrait) then 
						ok, err = self.DB:Query("update characters set `Name`=@name, `LastSeen`=@lastseen WHERE `PCID`=@id", {name=data[n].charname, lastseen=data[n].lastseen, id=data[n].pcid});
					else			
						ok, err = self.DB:Query("update characters set `Name`=@name, `Portrait`=@portrait, `LastSeen`=@lastseen WHERE `PCID`=@id", {name=data[n].charname, portrait=data[n].portrait, lastseen=data[n].lastseen, id=data[n].pcid});
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
		
		while not save() do
			coroutine.yield();
		end
		
		self.Print("Fetched player info: "..playername.." "..tostring(#data).." records updated");
	end);

	self.CO[playername] = co;
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
		
		filename = "./portraits/"..filename;

		local f = io.open(filename, "wb");
		local buffer;
		
		repeat
		
			buffer = raw:read(1000);
			coroutine.yield();
			if buffer and buffer:len() > 0 then 
				f:write(buffer);
				f:flush();
			end
		
		until buffer == nil;
		
		coroutine.yield();
		f:close();
		raw:close();
		
		self.Print("Downloaded: " .. filename);
		
		coroutine.yield();
		
		local archive, err = Archive.OpenRead(filename);
		
		if not archive then 
			self.Debug(err);
		end 
		
		local entries = archive:Entries();
		local file, size, data;
		
		for n=1, #entries do 

			file, size = archive:SetEntry(n)
			entry = file:match(resref..".%.tga");
		
			if entry then 
				
				self.Print("Extracting ".."./portraits/"..file);
				
				data = archive:Read();
				
				if data then 
					f = assert(io.open("./portraits/"..file, "wb"));

					while data do 
						coroutine.yield();
						f:write(data);
						f:flush();
						data = archive:Read(1048576);
					end

					f:close();
					coroutine.yield();
				end			
			end 	
		end
		
		self.Print("Extracted: " .. filename);
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

	if not self:IsSinfar() then 
		self.Print("DownloadPortraitIfMissing: not sinfar");
		return;
	end

	local characterid = obj.Id.."_"..obj.ObjectId;

	local ok, err = self.DB:Query([[select Portrait, PCID, julianday('now')-julianday(characters.LastSeen) as `Julianday` from characters join players on characters.PLID=players.PLID where players.Name like @p and characters.Name like @c order by characters.LastSeen desc;]], {p=Wchar.FromAnsi(obj.Name), c=Wchar.FromAnsi(obj.CharacterName)});

	if ok and self.DB:Fetch() then
	
		local row = self.DB:GetRow();
	
		if row.Julianday < 2 and self:HasPortraitResources(row.Portrait) then

			if self:IsPortraitUnknown(ori) and not self:IsPortraitUnknown(row.Portrait) then
				NWN.SetPortrait(obj.ObjectId, row.Portrait);
				return row.Portrait;
			else 
				return ori;
			end
		end
	end
	
	if self.Portraits[characterid] then 
		return self.Portraits[characterid];
	elseif self.CO[characterid] then
		return ori;
	end 
	
	local co = coroutine.create(function ()
	
		if not self:IsPortraitUnknown(ori) and self:HasPortraitResources(ori) then 
			return;
		end 
	
		local obj = NWN.GetPlayer(playerid);
		
		if not obj then
			return;
		end 
	
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
	
		if self.DB:Fetch() then 
			portrait = self.DB:GetRow(1);
		end
	
		if not portrait then 
			self.Portraits[characterid] = ori;
			self.Print("Missing portrait "..obj.CharacterName);
			return;
		end
	
		if self:HasPortraitResources(portrait) then 
			NWN.SetPortrait(obj.ObjectId, portrait);
			self.CO[characterid] = portrait;
			return;
		end 
					
		update = self:DownloadPortraitByResRef(portrait);
		
		while coroutine.status(update) ~= "dead" do
			coroutine.yield();
		end

		if NWN.UpdatePortraitResourceDirectory() then
			NWN.SetPortrait(obj.ObjectId, portrait);
		else 
			self.Portraits[characterid] = ori;
		end
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

		print("Skip message with type "..type);
		return;
	elseif not self:IsSinfar() then 
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
					send.Text = parts[2].Text;
					send.NameToken = parts[1].Token
					send.TextToken = parts[2].Token
					send.Channel = send.Text:match("^%[(.-)%]%s");
					
					if not send.Channel then 
						send.Channel = "Talk";
					else 
						send.Text = send.Text:match("^%[.-%]%s(.+)");
						if send.Channel:match(".-(%s)") then 
							send.Channel = send.Channel:match("(.-)%s");
						end				
					end
					
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
									
									print(failsafe);
									
									while failsafe > Runtime() do 
										coroutine.yield();
										print(failsafe-Runtime());
									end 
									
									fails = fails + 1;
								
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
						self.Print(parts[1]);
						self.Print(parts[2]);
					end
					
					if not send.Channel or send.Channel == "" then 
						send.Channel = self.Nil;
						self.Print(parts[1]);
						self.Print(parts[2]);
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
		elseif not self:IsSinfar() then 
			self.Print("UpdateInGameData: not sinfar");
			return;
		end

		local ply = NWN.GetPlayerByObjectId(obj.Id);

		if not ply then 
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

		local data = {PC=obj, PLAYER=ply, Timestamp=os.time()};

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
	
	if self.WHOSPY then

		if self.spytime < 1 then 
			self.spytime = 1;
		end 

		if self.whoTimer:Elapsed() > (self.spytime * 1000) then

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