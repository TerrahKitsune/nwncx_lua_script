FOLDER = FOLDER or "";
local sqlite = SQLite.Open(FOLDER.."lua.sqlite", 1);
sqlite:Query([[CREATE TABLE "colors" (
	"Tag"	TEXT NOT NULL,
	"Color"	TEXT NOT NULL,
	PRIMARY KEY("Tag")
);]]);

math.randomseed(os.time());
math.random();math.random();math.random();

CONSOLE = dofile(FOLDER.."console.lua");
SINFAR = dofile(FOLDER.."sinfar.lua");
CHAT = dofile(FOLDER.."chat.lua");
COMMANDS = dofile(FOLDER.."commands.lua");

function PrintAll(tbl, depth, alreadyprinted)

	local pad = "";
	
	alreadyprinted = alreadyprinted or {};
	depth = depth or 0;
	
	if alreadyprinted[tostring(tbl)] then 
		return;
	else
		alreadyprinted[tostring(tbl)] = true;
	end 
	
	for n=1, depth do 
		pad = pad .. " ";
	end 

	for k,v in pairs(tbl) do
	
		if k ~= "_G" then
			print(pad..tostring(k)..": "..tostring(v));
			if type(v) == "table" then
				PrintAll(v, depth + 1, alreadyprinted);
			end
		end
	end
end

if not Hook then Debug=print; return; end;

function Debug(text)

	if type(text) == "table" then 
	
		for k,v in pairs(text) do 
			print(k,v);
			NWN.AppendTobuffer("<c"..string.char(254,1,254)..">"..tostring(k)..":</c><c"..string.char(127,254,254).."> "..tostring(v).."</c>", 32, "", 0, false);
			if type(v) == "table" then
				for kk, vv in pairs(v) do
					NWN.AppendTobuffer("<c"..string.char(254,1,254)..">- "..tostring(kk)..":</c><c"..string.char(127,254,254).."> "..tostring(vv).."</c>", 32, "", 0, false);
				end
			end
		end	
	else 
		NWN.AppendTobuffer("<c"..string.char(254,1,254)..">"..tostring(text).."</c>", 32, "", 0, false);
	end
end

Hook.HookAppendToBuffer(function(text, type, resref, playerId, isPlayer) 

	if type == 128 and SINFAR and SINFAR:WhoSpy(text) then 
		return false;
	end

	if CHAT then 
		return CHAT:DoPrint(text, type, resref, playerId, isPlayer);
	end
end);

Hook.HookParseChatString(function(text, type)

	if COMMANDS then 
		return COMMANDS:DoCommand(text);
	end

	return text;
end);

local menuCount = 0;

Hook.HookRadialMenu(function(count)

	if count == 1 and menuCount == 0 then 
		if DEBUG then
			Debug("Radial Menu: Open");
		end
	elseif count == 0 and menuCount > 0 then
		if DEBUG then
			Debug("Radial Menu: Close");
		end
	end

	menuCount = count;	
end);

Hook.HookSetTextBubbleText(function(text)

	if CHAT then 
		return CHAT:GetTextBubble(text);
	else 
		return text;
	end 
end);

local ev = {};

local function AddEvent(func, data)

	table.insert(ev, {f=func, d=data});
end 

local clearTimer=Timer.New();
clearTimer:Start()

local fpsTimer=Timer.New();
fpsTimer:Start()

local fpsbubble=nil;
local membubble=nil;
local cpububble=nil;
local luamembubble=nil;
local proc = Process.Open();
local spytime = 10;

Hook.HookMainLoop(function()

	if clearTimer:Elapsed() > 3600000 then
	
		ResetColors(false);
	
		clearTimer:Stop();
		clearTimer:Reset();
		clearTimer:Start();
		
		CT = ColorToken.Create();
	end
	
	if #ev > 0 then 
		
		local ok, err;
		
		for n=1, #ev do 

			ok, err = pcall(ev[n].f, ev[n].d);
			if not ok then 
				print(err);
			end 
		end 
	
		ev = {};
	end 
	
	if fpsTimer:Elapsed() > 1000 then
	
		local x,y = NWN.GetSceneSize();
		
		if fpsbubble then
				fpsbubble:Destroy();
			end
		
		if FPS then
			fpsbubble = TextBubble.Create("FPS: "..NWN.GetFps(), 0, y);
			fpsbubble:Activate();
		end
		
		if membubble then
			membubble:Destroy();
		end
		
		if MEM then		
			membubble = TextBubble.Create("MEMORY: "..tostring(math.ceil(proc:GetRAM()/1024)).." kb", 175, y);
			membubble:Activate();
		end
		
		if cpububble then
			cpububble:Destroy();
		end
		
		if CPU then	
			cpububble = TextBubble.Create("CPU: "..tostring(math.ceil(proc:GetCPU())).."%", 300, y);
			cpububble:Activate();		
		end
		
		if luamembubble then
			luamembubble:Destroy();
		end
		
		if LUAMEM then
			luamembubble = TextBubble.Create("LUA: "..tostring(math.ceil(collectgarbage("count"))).." kb", 425, y);
			luamembubble:Activate();		
		end
		
		if not WHOSPY then 
			whospybubble=nil;
		else
			spytime = spytime + 1;

			if spytime >= 5 then
				spytime = 0;
				if SINFAR then
					SINFAR:SendWhoSpy();
				end
			end
		end
		
		fpsTimer:Stop();
		fpsTimer:Reset();
		fpsTimer:Start();
	end
	
	if SINFAR then
		SINFAR:Tick();
	end
	
end);

function ToggleAll()

	if FPS then 
		FPS = false;
		MEM = false;
		CPU = false;
		WHOSPY = false;
		LUAMEM = false;
		Debug("Metrics: OFF");
	else 
		FPS = true;
		MEM = true;
		CPU = true;
		WHOSPY = true;
		LUAMEM = true;
		Debug("Metrics: ON");
	end
end

if COMMANDS then
	COMMANDS:AddCommand("metrics", ToggleAll);
end 

local function GameObjectArrayUpdate(data)
		
	local obj = NWN.GetGameObject(data.objid);

	if not obj then 
		if DEBUG then
			print(objid,add);
		end
		return;
	end 

	local msg;
	
	if data.add then 
		msg = "ADD ";
	else 
		msg = "REMOVE ";
	end

	msg = msg .. obj.Id.." ["..obj.Type.."]: "..obj.Name
	
	print(msg);
	if obj.Type == "creature" then
	
		local ply = NWN.GetPlayerByObjectId(obj.Id);
	
		if ply then
		
			if data.add then 
				if SINFAR then
					SINFAR:AddPlayer(ply);
					SINFAR:UpdateInGameData(obj.Id);
				end
				
				Debug("Add "..obj.Name.." ("..ply.Name..")");
			else 
				if SINFAR then
					SINFAR:RemovePlayer(ply);
				end
				Debug("Remove "..obj.Name.." ("..ply.Name..")");
			end
		end
	end
end

Hook.HookGameObjectArrayUpdate(function(objid, add)

	local data = {objid=objid, add=add};

	if add then
		AddEvent(GameObjectArrayUpdate, 
		data);
	else 
		GameObjectArrayUpdate(data);
	end
end);

Hook.HookSetPlayerCreature(function(objid)

	local obj = NWN.GetGameObject(objid);

	if SINFAR then 
		SINFAR:SetControl(obj);
	end 

	if not obj then 
		msg = "["..objid.."]: UNKNOWN";
	else
		msg = "["..objid.."]: "..obj.Name;
	end 

	print("Control: "..msg);
	Debug("Control: "..msg);
end);

t = function()
	local ids = NWN.GetAllGameObjectIds(); 
	local text = "";
	Debug("objs: "..tostring(#ids));
	for n=1, #ids do
		local obj = NWN.GetGameObject(ids[n]);
		if obj then
			text = text .. n..": "..ids[n].." "..obj.Type.." "..obj.Name.."\n";
		else 
			text = text .. n..": "..ids[n] .. "\n";
		end
	end
	
	Debug(text);
end 

p = function()
	local ply = NWN.GetAllPlayers(); 
	Debug("Players: "..tostring(#ply));
	for n=1, #ply do
		Debug(ply[n].Id.." "..ply[n].ObjectId.." "..ply[n].Name);
	end
end

a = function()
	
	Debug(NWN.GetPlayer());
end

b = function(str)
	
	if tk then 
		local info = tk:GetInfo();
		Debug(info);
		
		if info.Hidden then 
			tk:SetHidden(false);
		else
			tk:SetHidden(true);
		end
		
		return;
	end 
	
	local x,y = NWN.GetSceneSize();
	local bubble = TextBubble.Create(str, 200, y);
	
	local info = bubble:GetInfo();
	bubble:Activate();
	
	Debug(info);

	tk=bubble;
	
	return bubble;
end

if not HASPRINTED then 
	PrintAll(_G);
	HASPRINTED=true;
end 

if CHAT then 
	CHAT:Start(sqlite, SINFAR, CONSOLE);
end

if COMMANDS then 
	COMMANDS:Start(CHAT, function(str) Debug(str); print(str); end);
end

if SINFAR and CHAT then
	SINFAR:Start(function(str) Debug(str); print(str); end, sqlite, CHAT, COMMANDS);
end