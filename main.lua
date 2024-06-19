local allowUpdate = true;
FOLDER = "./lua/";
Console.Create();
Console.SetTitle("Neverwinter Nights")
FileSystem.CreateDirectory(FOLDER);

print = function(...)

	local result = "";

	for k,v in ipairs{...} do
		result = result .. tostring(v).."\t";
	end
	
	if result:sub(-1) == "\t" then
		result = result:sub(1, result:len()-1);
	end
	
	Console.Write(result.."\n");
	if Log then 
		Log(result);
	end
end

local function Download(url, file)

	local r = Http.Start("GET", url);
	r:SetTimeout(5);
	
	local code, ok, contents, header = r:GetResult();
	
	if code == 200 then 
		local f = io.open(file, "wb");
		if not f then 
			print("Unable to write to file "..tostring(file));
			return;
		end 
		
		f:write(contents);
		f:flush();
		f:close();
		
		print("Downloaded: "..file);
	else
		print("Query failed "..tostring(url).." "..tostring(code).." "..tostring(ok));
	end
end

local function GetRemoteVersion()

	local r = Http.Start("GET", "https://raw.githubusercontent.com/TerrahKitsune/nwncx_lua_script/main/ver.txt");
	r:SetTimeout(5);
	
	local code, ok, contents, header = r:GetResult();
	
	if code == 200 then 
		return contents;
	end 
	
	return nil;
end

local function DoUpdateCheck()

	local remVer = GetRemoteVersion();

	if remVer == nil then 
		print("Unable to get remote version");
		return;
	end

	if GetVersion() == remVer then
		Download("https://raw.githubusercontent.com/TerrahKitsune/nwncx_lua_script/main/core.lua", FOLDER.."core.lua");
		Download("https://raw.githubusercontent.com/TerrahKitsune/nwncx_lua_script/main/chat.lua", FOLDER.."chat.lua");
		Download("https://raw.githubusercontent.com/TerrahKitsune/nwncx_lua_script/main/color.lua", FOLDER.."color.lua");
		Download("https://raw.githubusercontent.com/TerrahKitsune/nwncx_lua_script/main/commands.lua", FOLDER.."commands.lua");
		Download("https://raw.githubusercontent.com/TerrahKitsune/nwncx_lua_script/main/console.lua", FOLDER.."console.lua");
		Download("https://raw.githubusercontent.com/TerrahKitsune/nwncx_lua_script/main/sinfar.lua", FOLDER.."sinfar.lua");
		Download("https://raw.githubusercontent.com/TerrahKitsune/nwncx_lua_script/main/globalvar.lua", FOLDER.."globalvar.lua");
		Download("https://raw.githubusercontent.com/TerrahKitsune/nwncx_lua_script/main/imgui.lua", FOLDER.."imgui.lua");
		Download("https://raw.githubusercontent.com/TerrahKitsune/nwncx_lua_script/main/sharedmemoryqueue.lua", FOLDER.."sharedmemoryqueue.lua");
		Download("https://raw.githubusercontent.com/TerrahKitsune/nwncx_lua_script/main/main.lua", "main.lua");

		print("Plugin is up to date v"..remVer);
	else
		NEEDSUPDATE=remVer;
		print("New version v"..remVer.." available");
	end
end

if allowUpdate then
	DoUpdateCheck();
end 

dofile(FOLDER.."core.lua");
