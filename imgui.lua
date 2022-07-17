local Imgui ={};

Imgui.DoStart=true;

Imgui.Disabled = false;
Imgui.RenderFuncs = {};
Imgui.MainMenuSettingsFuncs = {};
Imgui.Fails = 0;
Imgui.SampleTime = 250;
Imgui.MaxFpses = 120;
Imgui.LastFps = Runtime();

function Imgui:AddMainMenuSettingsFunction(func)
	
	table.insert(Imgui.MainMenuSettingsFuncs, func);
end

function Imgui:AddRenderFunction(func)
	
	table.insert(Imgui.RenderFuncs, func);
end

local vec0 = {x=0,y=0};
local partyportraitsize = 77;

function Imgui:SaveStyle()

	local j = Json.Create(true);	
	local raw = j:Encode(Gui.GetStyle());
	
	local f = io.open(FOLDER.."style.json", "wb");
	
	if not f then 
		error("Unable to open "..FOLDER.."style.json for writing");
	end 
	
	f:write(raw);
	f:flush();
	f:close();
	Debug("Saved style");
end

function Imgui:RestoreStyle()

	local f = io.open(FOLDER.."style.json", "rb");
	if not f then 
		return;
	end 
	
	local raw = f:read("*all");
	f:close();
	
	local j = Json.Create();
	Gui.SetStyle(j:Decode(raw));
end

function Imgui:PlotFPS(ui, fps)

	local r = Runtime();

	if r - self.LastFps >= self.SampleTime then

		self.LastFps = r;
		self.Fpses = self.Fpses or self.Vars:CreateLinkedList()

		if self.Fpses:Len() < self.MaxFpses then 
			self.Fpses:AddFirst(fps);
		else 
			self.Fpses:LastToFirst();
			self.Fpses.First.Value = fps;
		end
		
		local total = 0;
		local c = self.Fpses.First;
		while c do
			total = total + c.Value;
			c = c.Next;
		end

		Gui.SetValue("avgfps", 5, math.floor(total / #self.Fpses) .. " Avg");
	end 
	
	if ui:IsItemHovered() and #self.Fpses > 0 then
	
		ui:BeginTooltip();
		ui:PlotLines("##fpsplot", self.Fpses, "avgfps");
		ui:EndTooltip();
	end
end

function Imgui:Start(COMMANDS, VARS)

	self.Vars = VARS;

	if self.Fails >= 5 then
		return;
	end 

	local ok, ver = Hook.HookImguiRender(function(ui)
	
		if self.Disabled or not self.Enabled then 
			return;
		end
	
		for n=1, #Imgui.RenderFuncs do
			Imgui.RenderFuncs[n](ui);
		end	
		
		if ui:GetValue("showdemowindow", 1) then
			ui:ShowDemoWindow("showdemowindow");
		end
		
		if ui:GetValue("showstyleeditor", 1) then
			ui:ShowStyleEditor("showstyleeditor");
		end
		
		local info = ui:Info();
		local xoffset = info.DisplaySizeX;
		
		if NWN.GetGameObject() then 
			xoffset = xoffset - partyportraitsize;
		end
		
		ui:PushStyleVar(3, 1.0);
		ui:PushStyleVar(5, vec0);		
		ui:SetNextWindowPos(vec0);

		if ui:GetValue("showmainbar", 1) then

			ui:SetNextWindowSize({x=xoffset,y=1});

			if ui:Begin("##mainmenubar", "showmainbar", 1295) and ui:BeginMenuBar() then 

				ui:PopStyleVar(2);

				if ui:Button("<") then
					Gui.SetValue("showmainbar", 1, false);
				end

				if ui:BeginMenu("Settings##settingsmenu") then 
	
					if ui:BeginMenu("Style##stylemenu") then 
					
						ui:MenuItem("Style Editor", "showstyleeditor");
						
						if ui:MenuItem("Save Style") then
							
							local ok, err = pcall(self.SaveStyle, self);
							
							if not ok then 
								Debug(err);
							end					
						end 
						
						ui:EndMenu();
					end 
					
					if ui:MenuItem("VSync", "vsync") then
						Gui.VSync(ui:GetValue("vsync", 1));
					end

					for n=1, #Imgui.MainMenuSettingsFuncs do
						Imgui.MainMenuSettingsFuncs[n](ui);
					end	
					
					ui:EndMenu();
				end

				framerate = info.Framerate;

				local fps = math.floor(framerate).." fps";
				local size = ui:GetWindowSize();
				local textSize = ui:CalcTextSize(fps);
				local cursor = ui:GetCursorPos();

				ui:SameLine(xoffset - cursor.x - textSize.x);

				ui:Text(fps);
				self:PlotFPS(ui, framerate);
				
				ui:EndMenuBar();
				
			else 
				ui:PopStyleVar(2);
			end

			ui:End();
		else 
			ui:PushStyleVar(3, 1.0);
			ui:PushStyleVar(5, vec0);
			
			ui:SetNextWindowSize({x=23,y=1});
			
			if ui:Begin("##mainmenubar", "showmainbar", 1295) and ui:BeginMenuBar() then
				ui:PopStyleVar(2);
				if ui:Button(">") then
					Gui.SetValue("showmainbar", 1, true);
				end
				ui:EndMenuBar();
			else
				ui:PopStyleVar(2);	
			end
					
			ui:End();
			ui:PopStyleVar(2);
		end
	end);
	
	if ok then
	
		self.Enabled = (ver == "0.0.1");	
		print("Imgui: "..tostring(self.Enabled).." v"..ver);

		if self.Enabled then 
			self:RestoreStyle();
		end 

		self.DoStart = false;
	else
		self.Enabled = false;
		print("Imgui: "..tostring(self.Enabled));
		
		self.Fails = self.Fails + 1;
		
		if self.Fails >= 5 then
			print("Disabling imgui");
		end 
	end
	
	Gui.SetValue("showstyleeditor", 5, "avgfps");
	Gui.SetValue("showstyleeditor", 1, false);
	Gui.SetValue("showdemowindow", 1, false);
	Gui.SetValue("showmainbar", 1, true);
	Gui.SetValue("vsync", 1, Gui.VSync());
	
	COMMANDS:AddCommand("imgui", function() 
		
		if self.Disabled then 
			self.Disabled = false;
			Debug("Enabled Dear ImGui");
		else 
			self.Disabled = true;
			Debug("Disabled Dear ImGui");
		end		
	end,
	"Toggle all Dear ImGui rendering");
	
	COMMANDS:AddCommand("demowindow", function() 
		
		if self.Enabled then 
			Gui.SetValue("showdemowindow", 1, true);
			Debug("Showing imgui demowindow");
		else 
			Debug("Imgui not enabled");
		end		
	end,
	"Show the imgui debug window");
end

return Imgui;