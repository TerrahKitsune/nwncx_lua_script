local CHAT = {CT = ColorToken.Create(), savedColors={},ColorTagReplace={}, sinfar=nil, console=nil, TtsQueue={}, TTSDisabled=true, StripTokens=false};

CHAT.color = dofile(FOLDER.."color.lua");

function CHAT:ColorFunc(ct, node)

	local name = node.Text;
	
	if not name then 
		return;
	else 
		name = self:ToNameTag(name);
	end 
	
	if not name or name:len() == 0 then 
		return;
	end
	
	local color = self:GetNameColor(name);

	if color then
		
		local fix = node.Text:match("(.+)%s:%s$");
		if fix then 
			ct:SetText(node.Id, fix..": ");
		end

		ct:Replace(node.Id, color);
	end 
end

CHAT.ColorTagReplace[string.char(143,127,255)] = function(c, ct, node) return c:ColorFunc(ct, node); end
CHAT.ColorTagReplace[string.char(128,128,255)] = function(c, ct, node) return c:ColorFunc(ct, node); end

function CHAT:GetTextBubble(text, objid)

	local obj = NWN.GetGameObject(objid);

	if not obj then 
		return nil;
	end 
	
	local dist = nil;
	local s = NWN.GetGameObject();
	
	if s and s.Position and obj.Position then
		dist = math.floor(NWN.Distance(s.Position, obj.Position)*100)/100;
	end
	
	if obj.Type == "creature" and text:match("\n") then
	
		local name, injurdness;
		
		if obj.HP and obj.HP ~= "1/1" then 

			name, injurdness = text:match("(.+)\n(.-)</c>");
			
			if name and injurdness and injurdness:len() > 0 then		
				text = name .. "\n" .. injurdness .. " " .. obj.HP .. "</c>";
			end
		end
			
		if dist then
		
			local channel = nil;
			
			if s.Id == obj.Id then
				channel = nil;
			elseif dist <= 0.5 then 
				channel = self:ChatColor("silent") .. "Silent</c>";
			elseif dist <= 1.0 then 
				channel = self:ChatColor("quiet") .."Quiet</c>";
			elseif dist <= 3.0 then 
				channel = self:ChatColor("whisper") .."Whisper</c>";
			else 
				channel = nil;
			end
			
			if channel then 
			
				name, injurdness = text:match("(.+)\n(.-)$");
			
				if name and injurdness and injurdness:len() > 0 then		
					text = name .. "\n"..channel.."\n"..injurdness;
				end
			end		
		end
		
		self.CT:Parse(text); 
		self:ColorReplace(self.CT);
	else
		self.CT:Parse(text); 
	end

	if DEBUG then 
		
		local debugData = tostring(objid);
		local ply = NWN.GetPlayerByObjectId(objid);
	
		if dist then
			debugData = debugData .. " "..tostring(dist).." ft "..(obj.Gender or "").."\n";
			
			debugData = debugData .. "x: "..tostring(math.floor(obj.Position.x*100)/100);
			debugData = debugData .. " y: "..tostring(math.floor(obj.Position.y*100)/100);
			debugData = debugData .. " z: "..tostring(math.floor(obj.Position.z*100)/100);
			debugData = debugData .. " f: "..tostring(math.floor(obj.Orientation*100)/100)..string.char(0xB0);
		end
	
		if ply then 
			debugData = debugData .. "\n" .. ply.Id .." " .. ply.Name;
		end
	
		self.CT:AppendText("\n"..debugData, "<c"..string.char(200,200,200)..">");
		self.CT:AppendText(nil, "</c>");
	end

	return self.CT:ToString();
end

function CHAT:ColorReplace(ct)

	if self.ColorDisabled then
		return;
	end 

	local parsed = ct:GetAsParts(); 
	local color;
	
	for n=1, #parsed do 

		color = parsed[n].Token:match("<c(...)>");
		
		if self.ColorTagReplace[color] then
			
			if type(self.ColorTagReplace[color]) == "string" then			
				ct:Replace(parsed[n].Id, self.self.ColorTagReplace[color]);
			elseif type(self.ColorTagReplace[color]) == "function" then
				self.ColorTagReplace[color](self,ct, parsed[n]);
			end
		end	
	end
end

function CHAT:GetPlayerByName(name)

	local getplayerbyname = NWN.GetAllPlayers();
	
	for n = 1, #getplayerbyname do 
		if getplayerbyname[n].Name == name then
			return getplayerbyname[n];
		end 
	end

	return nil;
end

function CHAT:IsIdPlayer(objid)

	local numb = tonumber(objid, 16);
	if not numb then 
		return false;
	end 
	
	return (numb & 0xC0000000) == 0xC0000000;
end 

function CHAT:HandleJoinLeave(ct)

	local text = ct:Strip();

	local player, joinleave, client = text:match("(.-)%shas%s(.-)%sas%sa%s(.-)%.%.");

	if player and joinleave and client then 
	
		local ply = self:GetPlayerByName(player);
	
		if not ply then 
			print("Unable to find "..player);
			return false;
		end 
	
		local isReal = self:IsIdPlayer(ply.ObjectId);
		local color = "<c"..string.char(128,128,254)..">";
		local isWebclient = false;
		
		if not isReal then
		
			if ply.CharacterName == ply.Name then
				client = "a webclient";
				isWebclient=true;
			else 
				client = ply.CharacterName;
			end
			
			color = "<c"..string.char(195,195,195)..">";
			
		elseif client == "player" and ply.CharacterName then 
			client = self:GetNameColor(ply.CharacterName)..ply.CharacterName.."</c>";
		else 
			client = "<c"..string.char(237,28,36)..">a "..client.."</c>";
		end
	
		ct:Clear();
	
		if joinleave == "joined" then
			
			if isWebclient then 
			
				if self.WebNoteDisable then
					ct:Parse("");
				else
					ct:Parse(color..ply.Name.." joined webclient</c>");
				end
			else
				ct:Parse(color..ply.Name.." has joined as "..client.."</c>");
			end
			
		elseif joinleave == "left" then
		
			if isWebclient then 
				
				if self.WebNoteDisable then
					ct:Parse("");
				else
					ct:Parse(color..ply.Name.." left webclient</c>");
				end
			else
				ct:Parse(color..ply.Name.." has left as "..client.."</c>");
			end
		end
	end
end

function CHAT:SetNameColor(name, r,g,b, lock)
	
	name = self:ToNameTag(name);
	local ok, err;

	if type(r) == "boolean" then 
		ok, err = sqlite:Query("update `Colors` set `Lock`=@l where `Tag`=@tag;",{l=r, tag=name});
		if not ok then 
			error(err);
		end 
		return;
	end

	ok, err = self.sqlite:Query("delete from `Colors` where `Tag`=@tag;",{tag=name});
	if not ok then 
		error(err);
	end 
	
	if r == nil then
		self.savedColors[name] = nil;
		Debug(name.." cleared color");
		return;
	end
	
	if type(lock) ~= "boolean" then  
		lock = false;
	end 

	r=math.max(math.min(r, 255), 1);
	g=math.max(math.min(g, 255), 1);
	b=math.max(math.min(b, 255), 1);
	
	local j=Json.Create();
	local raw = j:Encode({R=r,G=g,B=b, Random=false});
	
	ok, err = self.sqlite:Query("insert into `Colors`(`Tag`,`Color`, `Lock`)VALUES(@tag,@color, @l);",{tag=name, color=raw, l=lock});
	if not ok then 
		error(err);
	end 
	
	self.savedColors = {};
	
	self.savedColors[name] = "<c"..string.char(r,g,b)..">";
	
	if DEBUG then
		Debug(name.." new color "..self.savedColors[name]..self:TagToReadable(self.savedColors[name]).."</c>");
	end 
	
	return self.savedColors[name];
end

function CHAT:LocalJoinLeave(ply, add)

	local color = "<c"..string.char(128,128,254)..">";

	if add then 
		self:DoPrint(self:GetNameColor(ply.CharacterName)..ply.CharacterName.."</c>"..color.." joined local</c>", 32, "", 0, false);
	else 
		self:DoPrint(self:GetNameColor(ply.CharacterName)..ply.CharacterName.."</c>"..color.." left local</c>", 32, "", 0, false);
	end 
end

function CHAT:GetNameColor(name, recurse)

	name = self:ToNameTag(name);

	if self.savedColors[name] then
		return self.savedColors[name];
	end

	local ok, err = self.sqlite:Query("select `Color` from `Colors` where `Tag`=@tag;",{tag=name});
	
	if not ok then 
		error(err);
		return nil;
	elseif self.sqlite:Fetch() then 
		local j=Json.Create();
		local color = j:Decode(self.sqlite:GetRow(1));
		
		if type(color.Link) == "string" and color.Link ~= "" then 
			
			recurse = recurse or {};
			
			if not recurse[color.Link] then 	
				recurse[color.Link] = color;
				self.savedColors[name] = self:GetNameColor(color.Link, recurse);
				return self.savedColors[name];
			end
		end
		
		self.savedColors[name] = self:RgbTableToTag(color);
		
		if DEBUG then
			Debug(name.." loaded color "..self.savedColors[name]..self:TagToReadable(self.savedColors[name]).."</c>");
		end
		
		return self.savedColors[name];
	end

	return self:SetNameColor(name, self:CreateColor(name));
end

function CHAT:SetLink(child, parent)

	if not child or child == "" then 
		self.savedColors={};
		return true;
	end

	child = self:ToNameTag(child);

	local ok, err = assert(self.sqlite:Query("select `Color` from `Colors` where `Tag`=@tag;",{tag=child}));

	if not self.sqlite:Fetch() then 
		return false;
	end 
	
	local j=Json.Create();
	local color = j:Decode(self.sqlite:GetRow(1));
	
	if parent then
		color.Link = self:ToNameTag(parent);
	else 
		color.Link = nil;
	end
	
	ok, err = assert(self.sqlite:Query("update `Colors` set `Color`=@c where `Tag`=@tag;",{c=j:Encode(color), tag=child}));
	
	if ok then
		self.savedColors={};
		return true;
	end 
	
	return false;
end

function CHAT:RgbTableToTag(color)

	if color.Random then 
	
		local r,g,b = self:CreateColor();	
		color.R = r;
		color.G = g;
		color.B = b;
	end

	return "<c"..string.char(math.max(math.min(color.R, 255), 1),math.max(math.min(color.G, 255), 1),math.max(math.min(color.B, 255), 1))..">";
end

function CHAT:TagToReadable(tag)
	
	if not tag then 
		return "<nil>";
	end 
	
	if tag == "</c>" then 
		return "<end>";
	end 
	
	local r,g,b = tag:match("<c(.)(.)(.)>");	
	
	if not r or not g or not b then 
		return "<none>";
	end 
	
	r = string.byte(r);
	g = string.byte(g);
	b = string.byte(b);
	
	return "<"..r.."|"..g.."|"..b..">";
end

function CHAT:GetColors(all)
	
	local result;
	
	if all then 
		result = {};
		local ok, err = self.sqlite:Query("select * from `Colors` order by `Tag`;");
		
		if not ok then 
			self.Print(err);
			return result;
		end 
		
		local j=Json.Create();
		local row;
		local color;
		
		while self.sqlite:Fetch() do 
			row = self.sqlite:GetRow();
			color = j:Decode(row.Color);	
			result[row.Tag]=self:RgbTableToTag(color);
		end
		
	else
		result = self.savedColors;
	end
	
	for k,v in pairs(result) do 
		self.Print(k.." "..v..self:TagToReadable(v).."</c>");
	end
	
	return result;
end


function CHAT:CreateColor()

	return self.color.hsltorgb(math.random(0, 360), math.random(50, 100) / 100, math.random(50, 75) / 100);
end

function CHAT:ToNameTag(name)

	name = name:gsub("%s", "");
	if name:sub(-1) == ":" then
		name = name:sub(1,name:len()-1);
	end
	
	return name:lower();
end

function CHAT:ResetColors(del)
	self.savedColors={};
	if del then
		sqlite:Query("delete from `Colors` where Lock=0;");
	end
end

CHAT.InvalidCharPattern = "["..string.char(13).."]";

function CHAT:StripInvalidCharacters(text)

	if not text then
		return "";
	end 

	return text:gsub(self.InvalidCharPattern, "");
end

function CHAT:IsLocalChannel(type)
	if 	type == 1 or
		type == 2 or
		type == 4 or
		type == 8 or
		type == 64 or 
		type == 1024 then
		return true;
	else
		return false;
	end
end

function CHAT:GetChannel(ct, type)

	if not self:IsLocalChannel(type) then
		return nil;
	elseif type == 1 then 
		return "talk";
	end 

	local channelNode = ct:GetNode(2);
	
	if not channelNode then
		return "talk";
	end 
	
	local channel = "";
	
	if channelNode.Token:match("<c...>") then
		channel = channelNode.Text:match("^%[(.-)%]");
	end

	if not channel then
		channelNode = ct:GetNode(3);
		if channelNode and channelNode.Token:match("<c...>") then
			channel = channelNode.Text:match("^%[(.-)%]");
		end
	end

	channel = channel or "talk";

	if channel:match("%(") then
		channel = channel:match("(.-)%s");
	end

	return channel:lower();
end

function CHAT:SetChannelColor(ct, type)

	local channel = self:GetChannel(ct, type);

	if not channel or channel == "talk" then
		return;
	end 

	local channelNode = ct:GetNode(2);

	if not channelNode then
		return;
	end 

	if channelNode.Token:match("<c...>") then
		ct:SetColor(channelNode.Id, self:ChatColor(channel, channelNode.Token));
	end
	
	if type ~= 1024 then return; end
	
	channelNode = ct:GetNode(3);
	
	if not channelNode then
		return;
	end 

	if channelNode.Token:match("<c...>") and self.Channels[channel] then
		ct:SetColor(channelNode.Id, self:ChatColor(channel, channelNode.Token));
	end
end

function CHAT:StripLocalChannelColorTokens(ct, specialChannel)

	if not self.StripTokens or ct:Highest() < 2 then
		return ct;
	end

	local node = ct:GetNode(1);
	
	if not node then 
		return ct;
	end
	
	local character = node.Text;
	local rest = "";
	local characterToken = node.Token;
	local restToken = nil;
	
	local offset = 2;
	
	if specialChannel and ct:Highest() > 2 and ct:GetNode(3).Text:match("^%[") then
		offset = offset + 1;
	end
	
	for n=offset, ct:Highest() do
		
		node = ct:GetNode(n);
		rest = rest .. node.Text;
		
		if not restToken then
			restToken = node.Token;
		end
	end

	ct:Clear();
	ct:Parse(characterToken..character.."</c>"..(restToken or "")..rest.."</c>");
	
	return ct;
end

function CHAT:DoPrint(text, type, resref, playerId, isPlayer, objectId)

	objectId = objectId or "7f000000";

	local obj = NWN.GetGameObject(objectId);

	self.CT:Clear();
	self.CT:Parse(text);
	self:SetChannelColor(self.CT, type);
	
	if DEBUG then
	
		local test = "";
		for n=1, self.CT:Highest() do		
			local node = self.CT:GetNode(n);	
			test = test .. self:TagToReadable(node.Token) .. node.Text;	
		end
		Debug(test);
	end
	
	for n=1, self.CT:Highest() do
		local node = self.CT:GetNode(n);
		if node.Type == 0 then
			self.CT:SetText(node.Id, self:StripInvalidCharacters(node.Text));
		end
	end
	
	if type == 32 then
		self:HandleJoinLeave(self.CT);
	end
	
	local p = nil;
	
	if isPlayer then
		p = NWN.GetPlayer(playerId);
		
		if self:IsLocalChannel(type) then
			self.CT = self:StripLocalChannelColorTokens(self.CT, type == 1024);
		end
	end
	
	self:ColorReplace(self.CT);
	
	local log = objectId;
	
	if obj then
		log = log .. " ("..obj.Name..")";
	end
	
	log = log .." "..resref.." "..type.." "..playerId.." "..tostring(isPlayer).." "..self.CT:Strip();
	
	Log(log);
	print(log);

	if isPlayer and self.sinfar then 
		local strippedresref = resref:sub(1, resref:len()-1);
		strippedresref = self.sinfar:DownloadPortraitIfMissing(playerId, strippedresref);
		self.sinfar:LogChat(self.CT, type, playerId, strippedresref);
		if strippedresref then
			resref = strippedresref .. "t";	
		end
	elseif self.sinfar then
		self.sinfar:LogChat(self.CT, type, nil, resref:sub(1, resref:len()-1));
	end

	local text = self.CT:ToString();
	
	if text and text ~= "" then
		
		NWN.AppendTobuffer(text, type, resref, playerId, isPlayer);
		
		if self:IsLocalChannel(type) and not self.TTSDisabled and TTS then 
			self:Speak(self.CT:Strip());
		end		

		if self.queue then
			
			local objects = {};
			local players = {};
			objects[objectId] = obj;
			
			if isPlayer then
				players[playerId] = NWN.GetPlayer(playerId);
			else
				playerId = nil;
			end
			
			local slf = NWN.GetPlayer();
			
			if slf then
				players[slf.Id] = slf;
				objects[slf.ObjectId] = NWN.GetGameObject(slf.ObjectId);
			else
				slf = {Id = nil, ObjectId="7f000000"};
			end
			
			local area = NWN.GetArea();
			
			if area then
				objects[area.Id] = area;
			else
				area = {Id="7f000000"};
			end
			
			self.queue:PostMessage(self.json:Encode({Type="Chat", Data = {Text=text, Type=type, ResRef=resref, AreaId = area.Id, ObjectId = objectId, PlayerId = playerId, SelfPlayerId = slf.Id, SelfObjectId = slf.ObjectId}, Objects = objects, Players = players}));
		end
	end 
	
	return false;
end

function CHAT:Speak(text)
	table.insert(self.TtsQueue, text);
end

CHAT.TTSCoroutine = coroutine.create(function ()
	
	while not TTS do
		coroutine.yield();
	end
	
	local tts = TTS.Create();
	local q = CHAT.TtsQueue;
	
	while true do
	
		if not tts:GetIsSpeaking() and #q > 0 then
			local text = table.remove(q, 1);
			if not CHAT.TTSDisabled then
				print(tostring(#q).." TTS: "..text);
				tts:Speak(text, 0);
			end
		end
		
		coroutine.yield();
	end
end);

function CHAT:Tick()
	coroutine.resume(self.TTSCoroutine);
end

function CHAT:NWNPrint(text)
	self:DoPrint("<c"..string.char(254,1,254)..">**Lua:** "..text.."</c>", 32, "", 0, false);
end

function CHAT:ChatColor(channel, existingToken)

	channel = channel:lower();

	if not self.Channels then
		local f = io.open("nwnplayer.ini", "r");
		if f then	
			local rawIni = f:read("*all");
			f:close();
			
			local section = rawIni:match("%[Chat Colors%](.-)%[");
			if not section or section == "" then
				section = rawIni:match("%[Chat Colors%](.-)$");
			end

			self.Channels = {};
			
			self.Channels["whisper"] = "<c"..string.char(128)..string.char(128)..string.char(128)..">";
			self.Channels["quiet"] = "<c"..string.char(64)..string.char(64)..string.char(64)..">";
			self.Channels["silent"] = "<c"..string.char(48)..string.char(48)..string.char(48)..">";
			self.Channels["talk"] = "<c"..string.char(249)..string.char(240)..string.char(240)..">";
			
			if section then	
				for k,v in section:gmatch("(%a-)Color=(.-)[\n\r]") do
				
					local r,g,b = v:match("^(.-),(.-),(.-)$");
					
					print(k, v, r,g,b);
					
					r = tonumber(r);
					g = tonumber(g);
					b = tonumber(b);
				
					if k and k ~= "" and r and g and b then
						self.Channels[k:lower()] = "<c"..string.char(r)..string.char(g)..string.char(b)..">";
					end
				end
			end
			
			--for k,v in pairs(self.Channels) do
			--	Debug(k..": "..v..self:TagToReadable(v).."</c>");
			--end
		end
	end
	
	existingToken = existingToken or self.Channels["talk"];
	
	return self.Channels[channel] or existingToken;
end

function CHAT:Start(db, sinfar, console, commands, vars, sharedqueue)

	self.console = console;
	self.sinfar = sinfar;
	self.sqlite = db;
	self.queue = sharedqueue;
	self.json = Json.Create();
	
	db:Query([[CREATE TABLE "colors" (
	"Tag"	TEXT NOT NULL,
	"Color"	TEXT NOT NULL,
	"Lock"	INTEGER NOT NULL,
	PRIMARY KEY("Tag")
)]]);

	self.WebNoteDisable = vars:Get("ColorDisabled", false);
	self.StripTokens = vars:Get("StripTokens", false);

	commands:AddCommand("resetcolor", function(param) 
		self:SetNameColor(param);
		Debug("Reset color for "..param);
	end, "Resets the color for a given name");
	
	commands:AddCommand("linkcolor", function(param) 
		
		local a, b = param:match("(.-)%s(.+)");
		
		if not a then 
			a = param or "";
		end 
		
		if a:len() == 0 then 
			Debug("Useage: /linkcolor nametolinkwithoutspace linktowithoutspace");
			return;
		end 
		
		if not b then 
			Debug("Unlinking "..a..": "..tostring(self:SetLink(a)));
		else 
			Debug("Linking "..a.." -> "..b..": "..tostring(self:SetLink(a, b)));
		end
			
	end, "Links a to b, names given without spaces or unlinks if b is not given");
	
	commands:AddCommand("skipweb", function(param) 
		if self.WebNoteDisable then 
			Debug("Enabled webclient join/leave messages");
			self.WebNoteDisable = false;
		else
			Debug("Disabled webclient join/leave messages");
			self.WebNoteDisable = true;
		end
	end, "Toggles webclient join/leave messages");
	
	commands:AddCommand("tts", function(param) 
		if self.TTSDisabled then 
			Debug("Enabled TTS");
			self.TTSDisabled = false;
		else
			Debug("Disabled TTS");
			self.TTSDisabled = true;
		end
	end, "Toggles TTS");

	commands:AddCommand("togglenamecolor", function(param) 

		self.ColorDisabled = not self.ColorDisabled;
		vars:Set("ColorDisabled", self.ColorDisabled);
		Debug("Disable Name Colors: "..tostring(self.ColorDisabled));
	end, "Resets the color for a given name");
	
	commands:AddCommand("togglecolortokens", function(param) 

		self.StripTokens = not self.StripTokens;
		vars:Set("StripTokens", self.StripTokens);
		Debug("Disable Webclient Colors: "..tostring(self.StripTokens));
	end, "Toggles disabling colortokens in the chat from players");
end

return CHAT;