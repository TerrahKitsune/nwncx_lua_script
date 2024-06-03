local CHAT = {CT = ColorToken.Create(), savedColors={},ColorTagReplace={}, sinfar=nil, console=nil};

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
				channel = "<c"..string.char(254,200,254)..">Silent</c>";
			elseif dist <= 1.0 then 
				channel = "<c"..string.char(254,100,254)..">Quiet</c>";
			elseif dist <= 3.0 then 
				channel = "<c"..string.char(254,50,254)..">Whisper</c>";
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
			debugData = debugData .. " "..tostring(dist).." ft\n";
			
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

function CHAT:DoPrint(text, type, resref, playerId, isPlayer)

	text = self:StripInvalidCharacters(text);

	self.CT:Clear();
	self.CT:Parse(text);
	
	if type == 32 then
		self:HandleJoinLeave(self.CT);
	end
	
	local p = nil;
	
	if isPlayer then
		p = NWN.GetPlayer(playerId);
	end
	
	Log(resref.."\t"..type.."\t"..self.CT:Strip().."\t"..playerId.."\t"..tostring(isPlayer));
	Console.Write(resref.."\t"..type.." "..playerId.." "..tostring(isPlayer).."\t");
	
	self:ColorReplace(self.CT);
	self.console:ColorPrint(self.CT);
	
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
	end 
	
	return false;
end

function CHAT:NWNPrint(text)
	self:DoPrint("<c"..string.char(254,1,254)..">**Lua:** "..text.."</c>", 32, "", 0, false);
end

function CHAT:Start(db, sinfar, console, commands)

	self.console = console;
	self.sinfar = sinfar;
	self.sqlite = db;
	
	db:Query([[CREATE TABLE "colors" (
	"Tag"	TEXT NOT NULL,
	"Color"	TEXT NOT NULL,
	"Lock"	INTEGER NOT NULL,
	PRIMARY KEY("Tag")
)]]);

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
	end, "Toggles webclietn join/leave messages");
end

return CHAT;