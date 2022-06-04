
local color = {};

color.rgbtohsl = function(r, g, b)
  
	local R = r / 255;
	local G = g / 255;
	local B = b / 255;

	local Cmax = math.max(R,G,B);
	local Cmin = math.min(R,G,B);

	local delta = Cmax - Cmin;

	local h,s,l = 0,0,0;
  
	if delta == 0 then 
		h = 0;
	elseif Cmax == R then 
		h = ((G - B) / delta) % 6;
	elseif Cmax == G then 
		h = ((B - R) / delta) + 2;
	elseif Cmax == B then 
		h = ((R - G) / delta) + 4;
	end
	
	l = (Cmax + Cmin) / 2;
	
	if delta == 0 then
		s = 0;
	elseif l > 0.5 then 
		s = delta / (2 - Cmax - Cmin);
	else 
		s = delta / (Cmax + Cmin);
	end
	
	return h * 60,s,l;
end

color.hsltorgb = function(h, s, l)

	h = h / 360;

	local r,g,b = l,l,l;
	local v;
	if l<=0.5 then v=(l * (1.0 + s)); else v= (l + s - l * s); end 
	
	if v > 0 then 
	
		local m, sv, sextant, fract, vsf, mid1, mid2;
		m = l + l - v;
		sv = (v - m ) / v;
		h = h * 6.0;
		sextant = math.floor(h);
		fract = h - sextant;
		vsf = v * sv * fract;
		mid1 = m + vsf;
		mid2 = v - vsf;

		if sextant == 0 then 
			r = v;
			g = mid1;
			b = m; 
		elseif sextant == 1 then 
			r = mid2;
			g = v;
			b = m; 
		elseif sextant == 2 then 
			r = m;
			g = v;
			b = mid1; 
		elseif sextant == 3 then
			r = m;
			g = mid2;
			b = v; 
		elseif sextant == 4 then 
			r = mid1;
			g = m;
			b = v;
		elseif sextant == 5 then 
			r = v;
			g = m;
			b = mid2; 
		else 
			error("Hue invalid format");
		end	
	end
	
	return math.floor(r*255),math.floor(g*255),math.floor(b*255);
end 

return color;