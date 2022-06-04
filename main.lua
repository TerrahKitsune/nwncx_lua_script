FOLDER = "./lua/";

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

--Download("https://raw.githubusercontent.com/TerrahKitsune/nwncx_lua/main/core.lua?token=GHSAT0AAAAAABUJZAVF2PJZTG5TLQ7UGZTMYUYSXGQ", FOLDER.."core.lua");
--Download("https://raw.githubusercontent.com/TerrahKitsune/nwncx_lua/main/chat.lua?token=GHSAT0AAAAAABUJZAVEGJBVNPZQ5472PYRAYUYSXYA", FOLDER.."chat.lua");
--Download("https://raw.githubusercontent.com/TerrahKitsune/nwncx_lua/main/color.lua?token=GHSAT0AAAAAABUJZAVFAJ65ULA6VO7U6GOIYUYSYDQ", FOLDER.."color.lua");
--Download("https://raw.githubusercontent.com/TerrahKitsune/nwncx_lua/main/commands.lua?token=GHSAT0AAAAAABUJZAVFMSVSPLJCXEA3UZWAYUYSYOQ", FOLDER.."commands.lua");
--Download("https://raw.githubusercontent.com/TerrahKitsune/nwncx_lua/main/console.lua?token=GHSAT0AAAAAABUJZAVEKL6UAO37DND2FYQUYUYSYZQ", FOLDER.."console.lua");
--Download("https://raw.githubusercontent.com/TerrahKitsune/nwncx_lua/main/sinfar.lua?token=GHSAT0AAAAAABUJZAVFIMMOYVLCC6LQCSAOYUYSZXQ", FOLDER.."sinfar.lua");
--Download("https://raw.githubusercontent.com/TerrahKitsune/nwncx_lua/main/main.lua?token=GHSAT0AAAAAABUJZAVFDF6I2O3JDUUBYAFWYUYSZGQ", "main.lua");

dofile(FOLDER.."core.lua");