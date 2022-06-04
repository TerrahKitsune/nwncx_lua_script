local COMMANDS = {cmd={}, chat=nil, Print=nil};

COMMANDS.cmd["lua"] = function(param)
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
end

COMMANDS.cmd["reload"] = function() 
	dofile(FOLDER.."core.lua"); 
	Debug("Reloaded"); 
end

function COMMANDS:AddCommand(cmd, func)
	COMMANDS.cmd[cmd] = func;
end

function COMMANDS:DoCommand(str)

	local command = str:match("^/(.+)");
	
	if command then
	
		local c, param = str:match("^/(.-)%s(.+)");

		if c then 
			command = c;
		else 
			command = command:gsub("%s", "");
		end
		
		local func = self.cmd[command:lower()];	
		
		if func then
		
			param = param or "";
		
			print("Command: "..command .. " " .. param);
		
			local ok, err = pcall(func, param);
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