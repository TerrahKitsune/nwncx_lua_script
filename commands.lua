local COMMANDS = {cmd={}, chat=nil, Print=nil};

function COMMANDS:AddCommand(cmd, func, desc)
	self.cmd[cmd] = {f=func, d=desc};
end

COMMANDS:AddCommand("lua", function(param)
	local ok, err = load(param);
	if not ok then 
		error(err);
	else 
		if COMMANDS.chat then
			COMMANDS.chat:NWNPrint("Executing: "..param);
		else 
			print("Executing: "..param);
		end
		ok, err = pcall(ok);
		if not ok then 
			COMMANDS.chat:NWNPrint(tostring(err));
		elseif ok and err then 
			COMMANDS.Print(err);
		end
	end 
end,
"runs provided lua script");

COMMANDS:AddCommand("reload", function() 
	dofile(FOLDER.."core.lua"); 
	Debug("Reloaded"); 
end,
"reloads the lua scripts");

COMMANDS:AddCommand("debug", function() 
	if DEBUG then 
		Debug("Disabled debugmode");
		DEBUG=false;
	else 
		Debug("Enabled debugmode");
		DEBUG=true;
	end
end,
"Toggle debugmode");

COMMANDS:AddCommand("help", function() 
	
	for k,v in pairs(COMMANDS.cmd)do 
		Debug("/"..k.." - "..tostring(v.d));
	end
end,
"this command");

function COMMANDS:DoCommand(str)

	local command = str:match("^/(.+)");
	
	if command then
	
		local c, param = str:match("^/(.-)%s(.+)");

		if c then 
			command = c;
		else 
			command = command:gsub("%s", "");
		end
		
		local cmd = self.cmd[command:lower()];	
		
		if cmd and cmd.f then
		
			param = param or "";
		
			print("Command: "..command .. " " .. param);
		
			local ok, err = pcall(cmd.f, param);
			if not ok then 
				if self.chat then
					self.chat:NWNPrint("Error: "..err);
				else 
					print("Error: "..err);
				end
			end
			
			return false;
		else
			return true;
		end
	else 
		return true;
	end
end

function COMMANDS:Start(chat, p)
	self.chat = chat;
	self.Print = assert(p);
end

return COMMANDS;