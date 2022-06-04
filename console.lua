local CONSOLE = {};

CONSOLE.defaultb, CONSOLE.defaultf = Console.GetColor();
CONSOLE.colors = {
"#000000",
"#00008B",
"#006400",
"#008B8B",
"#8B0000",
"#8B008B",
"#8B8000",
"#808080",
"#A9A9A9",
"#0000FF",
"#008000",
"#00FFFF",
"#FF0000",
"#FF00FF",
"#FFFF00",
"#FFFFFF"};

function CONSOLE.hex2rgb(hex)
    hex = hex:gsub("#","")
    return {R = tonumber("0x"..hex:sub(1,2)), G = tonumber("0x"..hex:sub(3,4)), B = tonumber("0x"..hex:sub(5,6))};
end

math.pow = function(a,b)
	return a ^ b;
end 

function CONSOLE:ClosestConsoleColor(r,g,b)

	local ret = 1;
	local rr = r;
	local gg = g;
	local bb = b;
	local delta = 1.7976931348623157E+308;

	for k,v in ipairs(self.colors) do 
	
		local c = self.hex2rgb(v);
		local t = math.pow(c.R - rr, 2.0) + math.pow(c.G - gg, 2.0) + math.pow(c.B - bb, 2.0);

		if (t == 0.0) then
			ret = k;
			break;
		elseif t < delta then
			delta = t;
			ret = k;
		end
	end

	if ret <= 1 or ret > #self.colors then 
		ret = 8;
	end

	return ret;
end

function CONSOLE:SetColor(node)

	if node.Type ~= 1 then 
		Console.SetColor(self.defaultb, self.defaultf);
	else	
	
		local tag = node.Token;	
		local r,g,b = tag:match("<c(.)(.)(.)>");
		
		r = string.byte(r);
		g = string.byte(g);
		b = string.byte(b);
		
		Console.SetColor(self.defaultb, self:ClosestConsoleColor(r,g,b)-1);
	end 
end

function CONSOLE:ColorPrint(ct)

	local p = ct:GetAsParts();
	local colorStack = {};
	
	for n=1, #p do 

		self:SetColor(p[n]);
		Console.Write(p[n].Text);
	end
	
	Console.Write("\n");
	Console.SetColor(self.defaultb, self.defaultf);
end

function CONSOLE:Start()

end

return CONSOLE;