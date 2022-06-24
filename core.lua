FOLDER = FOLDER or "";
local sqlite = SQLite.Open(FOLDER.."lua.sqlite", 1);

math.randomseed(os.time());
math.random();math.random();math.random();

CONSOLE = dofile(FOLDER.."console.lua");
SINFAR = dofile(FOLDER.."sinfar.lua");
CHAT = dofile(FOLDER.."chat.lua");
COMMANDS = dofile(FOLDER.."commands.lua");
VARS = dofile(FOLDER.."globalvar.lua");

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

function Notification(text)

	local obj = NWN.GetGameObject();

	if not obj then 
		obj = {Portrait="po_hu_f_99_"};
	end

	NWN.AppendTobuffer("<c"..string.char(254,1,254)..">LUA: </c><c"..string.char(127,254,254)..">"..tostring(text).."</c>", 1024, obj.Portrait.."t", 0, true);
end

Hook.HookParseChatString(function(text, type)

	if NEEDSUPDATE then 
		
		Notification("Update available v"..NEEDSUPDATE..": https://github.com/TerrahKitsune/nwncx_lua_script/raw/main/nwnx_lua.zip");
		NEEDSUPDATE = nil;
	end 

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

local metricBubbles={};

local proc = Process.Open();

Hook.HookMainLoop(function()

	if clearTimer:Elapsed() > 3600000 then
	
		if CHAT then
			CHAT:ResetColors(false);
		end 
		
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
		
		if metricBubbles.fpsbubble then
			metricBubbles.fpsbubble:Destroy();
			metricBubbles.fpsbubble=nil;
		end
		
		if metricBubbles.membubble then
			metricBubbles.membubble:Destroy();
			metricBubbles.membubble=nil;
		end

		if metricBubbles.cpububble then
			metricBubbles.cpububble:Destroy();
			metricBubbles.cpububble=nil;
		end
		
		if metricBubbles.luamembubble then
			metricBubbles.luamembubble:Destroy();
			metricBubbles.luamembubble=nil;
		end
		
		if metricBubbles.posbubble then
			metricBubbles.posbubble:Destroy();
			metricBubbles.posbubble=nil;
		end
		
		if METRICS then
			metricBubbles.cpububble = TextBubble.Create("CPU: "..tostring(math.ceil(proc:GetCPU())).."%", 300, y);
			metricBubbles.luamembubble = TextBubble.Create("LUA: "..tostring(math.ceil(collectgarbage("count"))).." kb", 425, y);
			metricBubbles.membubble = TextBubble.Create("MEMORY: "..tostring(math.ceil(proc:GetRAM()/1024)).." kb", 175, y);
			metricBubbles.fpsbubble = TextBubble.Create("FPS: "..NWN.GetFps(), 0, y);
			
			metricBubbles.luamembubble:Activate();		
			metricBubbles.cpububble:Activate();			
			metricBubbles.membubble:Activate();		
			metricBubbles.fpsbubble:Activate();

			local obj = NWN.GetGameObject();
			
			if obj then 
				metricBubbles.posbubble = TextBubble.Create("x: "..tostring(math.floor(obj.Position.x+0.5)).." y: "..tostring(math.floor(obj.Position.y+0.5)).." f: "..NWN.Direction(math.floor((obj.Orientation or 0)+0.5)), 550, y);
				metricBubbles.posbubble:Activate();
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

	if METRICS then 
		METRICS = false;
		Debug("Metrics: OFF");
	else 
		METRICS = true;
		Debug("Metrics: ON");
	end
end

if COMMANDS then
	COMMANDS:AddCommand("metrics", ToggleAll, "Toggle metrics");
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

	obj.Name = obj.Name or "";

	msg = msg .. obj.Id.." ["..obj.Type.."]: "..obj.Name;
	
	print(msg);
	if obj.Type == "creature" then
	
		local ply = NWN.GetPlayerByObjectId(obj.Id);
	
		if ply then
		
			if data.add then 
				if SINFAR then
					SINFAR:AddPlayer(ply);
					SINFAR:UpdateInGameData(obj.Id);
				end
				
				if CHAT then 
					CHAT:LocalJoinLeave(ply, true);
				end
			else 
				if SINFAR then
					SINFAR:UpdateInGameData(obj.Id);
					SINFAR:RemovePlayer(ply);			
				end
				
				if CHAT then 
					CHAT:LocalJoinLeave(ply, false);
				end
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
end);

Hook.HookLoadArea(function(area)
	Debug(area);
end);

t = function()
	local ids = NWN.GetAllGameObjectIds(); 
	local text = "";
	Debug("objs: "..tostring(#ids));
	for n=1, #ids do
		local obj = NWN.GetGameObject(ids[n]);
		if obj then
			text = text .. n..": "..ids[n].." "..obj.Type.." "..(obj.Name or "").."\n";
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
	
	local obj = NWN.GetGameObject();
	
	Debug(obj);
	Debug(obj.Position.z);
	Debug(NWN.GetSurfaceHeight(obj.Position.x, obj.Position.y));
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

NWN.Direction = function(fAngle)

	if fAngle >= 0.0 and fAngle <= 45 then
        return "East";
	elseif fAngle > 45.0 and fAngle <= 90.0 then
        return "North East";
    elseif fAngle > 90.0 and fAngle <= 135.0 then
        return "North";
	elseif fAngle > 135.0 and fAngle <= 180.0 then
        return "North West";
    elseif fAngle > 180.0 and fAngle <= 225.0 then
        return "West";
	elseif fAngle > 225.0 and fAngle <= 270.0 then
        return "South West";
    elseif fAngle > 270.0 and fAngle <= 315.0 then
        return "South";
	elseif fAngle > 315.0 and fAngle <= 360.0 then
        return "South East";
	end 
	
    return "East";
end

if VARS then
	VARS:Start(sqlite);
end 

if CHAT then 
	CHAT:Start(sqlite, SINFAR, CONSOLE, COMMANDS);
end

if COMMANDS then 
	COMMANDS:Start(CHAT, function(str) Debug(str); print(str); end);
end

if SINFAR and CHAT then
	SINFAR:Start(function(str) Debug(str); print(str); end, sqlite, CHAT, COMMANDS);
end