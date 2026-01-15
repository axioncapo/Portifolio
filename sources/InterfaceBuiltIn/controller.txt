--!strict
local env_services = require("../../Environment/env.services")
local env_utils = require("../../Environment/env.utils")
local fusion = require("../Interface.Libraries/Fusion")
local janitor = require(".././Others/Janitor")
local goodsignals = require(".././Others/GoodSignal")
local free_camera = require(".././Others/Camera")
local placement_controller = require("../Placement/Placement.controller")

local tween = env_services.TweenService
local replicated = env_services.ReplicatedStorage

local interfaces = replicated.World.Interfaces
local placement_gui = interfaces.Placement :: typeof(script.Parent.Parent.Parent.Interfaces.Placement)
local placement_objects = replicated.World["Placement.Assets"]

local templates = {
	category = placement_gui.Categorys.DownFrame.Background.ScrollingFrame.CategoryTemplate,
	object_template = placement_gui.Objects.DownFrame.Background.ScrollingFrame.ItemImage
}

local change_mode = goodsignals.new()

local local_player = env_services.Players.LocalPlayer
local mouse = local_player:GetMouse()

local placement = {
	initialized = false;
	storeds = janitor.new();
	under_display = nil :: any;
	
	placement_visuals_data = {
		velocity = 25
	}
}	

local tween_infos = {
	Transparency = TweenInfo.new(.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
	Hover = TweenInfo.new(.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Back = TweenInfo.new(.3, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
}

local under_hover = nil

function placement.init_configs()
	placement.configs = {
		snaping_angles = true,
		gride_size = 3 :: any,
		camera_follow_objects = false,
		placement_mode = "multiple"
	}
	
	local settings_gui = placement_gui.Settings.DownFrame.Background.ScrollingFrame
	
	local function easing_setting_button(button : typeof(settings_gui.Snaping))
		local original_color = button.Background.ImageColor3
		local scale = Instance.new("UIScale", button.Background.ViewButton)
		local hover, 
		unhover = tween:Create(scale, tween_infos.Hover, {Scale = .95}),tween:Create(scale, tween_infos.Hover, {Scale = 1})
		local state_enabled, state_disabled = tween:Create(button.Background, tween_infos.Hover, {
			ImageColor3 = original_color
		}),tween:Create(button.Background, tween_infos.Hover, {
			ImageColor3 = Color3.new(1, 0.670588, 0.670588)
		})
		
		button.Background.ViewButton.MouseEnter:Connect(function()
			hover:Play()
		end)	
		
		button.Background.ViewButton.MouseLeave:Connect(function()
			unhover:Play()
		end)
		
		return function(state)
			if state then
				button.Background.ViewButton.TextLabel.Text = "On"
				state_enabled:Play()
			else
				button.Background.ViewButton.TextLabel.Text = "Off"
				state_disabled:Play()
			end
		end
	end
	
	local camera_movement_ease = easing_setting_button(settings_gui.Camera)
	local snaping_ease = easing_setting_button(settings_gui.Snaping)
	
	easing_setting_button(settings_gui.Mode)
	camera_movement_ease(false)
	
	settings_gui.Camera.Background.ViewButton.Activated:Connect(function()
		placement.configs.camera_follow_objects = not placement.configs.camera_follow_objects
		camera_movement_ease(placement.configs.camera_follow_objects)
		
		if not placement.configs.camera_follow_objects then
			free_camera.GlobalCamera:Stop()
		end
	end)
	
	settings_gui.Snaping.Background.ViewButton.Activated:Connect(function()
		placement.configs.snaping_angles = not placement.configs.snaping_angles
		snaping_ease(placement.configs.snaping_angles)
		
		if placement.configs.snaping_angles then
			settings_gui.GridSize.Background.Increase.Active = true
			settings_gui.GridSize.Background.Descrease.Active = true

			tween:Create(settings_gui.GridSize, tween_infos.Hover, {GroupTransparency = 0}):Play()
		else
			settings_gui.GridSize.Background.Increase.Active = false
			settings_gui.GridSize.Background.Descrease.Active = false
			
			tween:Create(settings_gui.GridSize, tween_infos.Hover, {GroupTransparency = 0.55}):Play()
		end
	end)
	
	settings_gui.Mode.Background.ViewButton.Activated:Connect(function()
		if placement.configs.placement_mode == "single" then
			placement.configs.placement_mode = "multiple"
		else
			placement.configs.placement_mode = "single"
		end
		
		settings_gui.Mode.Background.ViewButton.TextLabel.Text = placement.configs.placement_mode
	end)
	
	local max_size = 10
	local min_size = .5
	local off = .5
	
	local function update_grid_size()
		settings_gui.GridSize.Background.Count.Text = ("X%s, Y%s,Z%s"):format(placement.configs.gride_size, placement.configs.gride_size, placement.configs.gride_size)
	end
	
	update_grid_size()
	
	settings_gui.GridSize.Background.Increase.Activated:Connect(function()
		placement.configs.gride_size = math.clamp(placement.configs.gride_size + off, min_size, max_size)
		update_grid_size()
	end)	
	
	settings_gui.GridSize.Background.Descrease.Activated:Connect(function()
		placement.configs.gride_size = math.clamp(placement.configs.gride_size - off, min_size, max_size)
		update_grid_size()
	end)
	
end

function placement.display_on(self: typeof(placement), folder)
	self.storeds:Cleanup()
	
	local camera_location: CFrame, object_location = folder:GetAttribute("CameraLocation"), folder:GetAttribute("ObjectLocation") 
	local camera = Instance.new("Camera")
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = camera_location
	
	placement_gui.Categorys.DownFrame.Background.Title.Text = folder.Name .. " Objects"
	
	self.storeds:Add(camera)
	self.order_to_focus = 1
	
	for _, model: Model in folder:GetChildren() do
		if not model:IsA("Model") then continue end	
		
		model = model:Clone()
		
		local primary_part = model.PrimaryPart :: BasePart
		local button = templates.object_template:Clone()
		
		button:WaitForChild("ViewportFrame")
		
		button.Parent = templates.object_template.Parent
		button.Visible = true
		
		model.Parent = button.ViewportFrame.WorldModel
		model:PivotTo(object_location)
		
		button.ViewportFrame.CurrentCamera = camera
				
		local original_pivot = model:GetPivot()
		local valid = false
		button.Title.Text = model.Name
		
		local object = {
			relative = button,

			deselect = function()				
				env_services.TweenService:Create(button.ViewportFrame, tween_infos.Hover, {Rotation = 0}):Play()
				env_services.TweenService:Create(button.InsertButton, tween_infos.Hover, {BackgroundColor3 = Color3.fromRGB(112, 188, 255)}):Play()
				env_services.TweenService:Create(button.InsertButton.UIScale, tween_infos.Hover, {Scale = 1.06}):Play()
				valid = false	
			end;

			select = function()
				
				env_services.TweenService:Create(button.ViewportFrame, tween_infos.Hover, {Rotation = 25}):Play()
				env_services.TweenService:Create(button.InsertButton, tween_infos.Hover, {BackgroundColor3 = Color3.fromRGB(121, 255, 148)}):Play()
				env_services.TweenService:Create(button.InsertButton.UIScale, tween_infos.Hover, {Scale = 1}):Play()
				valid = true	
			end,
		}
		
		button.MouseEnter:Connect(function()
			if under_hover and under_hover.relative == button and placement.configs.placement_mode == "multiple" then
				return
			end
			
			valid = true
			
			env_services.TweenService:Create(button.ViewportFrame, tween_infos.Hover, {Rotation = 25}):Play()
		end)
		
		button.MouseLeave:Connect(function()
			if under_hover and under_hover.relative == button and placement.configs.placement_mode == "multiple" then
				return
			end
			
			valid = false
			
			model:PivotTo(original_pivot)
			env_services.TweenService:Create(button.ViewportFrame, tween_infos.Hover, {Rotation = 0}):Play()
		end)
		
		button.InsertButton.Activated:Connect(function()
			
			if under_hover == object then
				pcall(under_hover.deselect)
				under_hover = nil
				return
			end
			
			if under_hover then
				pcall(under_hover.deselect)
				under_hover = nil
			end
			
			if self.under_display then self.under_display() end
			
			under_hover = object
			
			if placement.configs.placement_mode == "multiple" then
				object.select()
			else
				print("adsas", placement.configs.placement_mode)
			end
			
			self.under_display = placement_controller.assert_object(model)
		end)
		
		self.storeds:Add(env_services.RunService.RenderStepped:Connect(function(dt: number)
			if not valid then return end
			model:PivotTo(model:GetPivot() * CFrame.Angles(0,math.rad(dt * self.placement_visuals_data.velocity), 0))
		end))
		
		self.storeds:Add(button)
	end
end

function placement:init()
	assert(not self.initalized, `Init already called...`)
	
	local global_scope = fusion:scoped()
	
	env_utils:foreach(placement_objects:GetChildren(), function(_, value)
		if value:IsA("Folder") then
			
			local fusion_values = {
				Transparency = fusion.Value(global_scope, 0),
				Scale = fusion.Value(global_scope, .9)
			}
			
			local target = templates.category:Clone()
			target.Visible = true
			target.Name = value.Name
			target.Background.Title.Text = value.Name
			target.Parent = placement_gui.Categorys.DownFrame.Background.ScrollingFrame
			
			local scale = Instance.new("UIScale", target)
			
			fusion.Hydrate(global_scope, scale){
				Scale = fusion.Tween(
					global_scope,
					fusion_values.Scale, 
					tween_infos.Hover
				)
			}
			
			fusion.Hydrate(global_scope, target){
				[fusion.OnEvent("MouseEnter")] = function()
					fusion_values.Scale:set(1)
				end,
				[fusion.OnEvent("MouseLeave")] = function()
					fusion_values.Scale:set(.9)
				end,
			}
			
			fusion.Hydrate(global_scope, target.Background.ViewButton) {
				[fusion.OnEvent("Activated")] = function()	
					if value:HasTag("IgnorePage") then
						tween:Create(placement_gui.Objects, tween_infos.Back, {
							GroupTransparency = 0.6
						}):Play()
						return placement_controller[value.Name:lower()]
							:init()
					else
						tween:Create(placement_gui.Objects, tween_infos.Back, {
							GroupTransparency = 0
						}):Play()
						placement:display_on(value)
					end
				end,	
			}
						
			env_utils:add_trigger(target, target.Background.ViewButton)
		end
	end)
	
	placement_gui.Parent = env_services.Players.LocalPlayer:WaitForChild("PlayerGui")	
	--placement_controller.initialize_cameras:Fire(placement_controller.order)
	--placement_gui.States.Mode.Text = `Placement mode: Single`
	
	env_services.UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)  
		if input.KeyCode == Enum.KeyCode.M then
			if placement.configs.placement_mode == "single" then
				placement.configs.placement_mode = "multiple"
				--placement_gui.States.Mode.Text = `Placement mode: Multiple`
				
			else
				placement.configs.placement_mode = "single"
				--placement_gui.States.Mode.Text = `Placement mode: Single`
			end
		end
	end)
	
	local cam_state = false
	local easing;
	
	env_services.UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)  
		if input.KeyCode == Enum.KeyCode.H then
			cam_state = not cam_state
			
			if easing then task.cancel(easing) end
			
			easing = task.defer(function()
				local a1 = env_services.TweenService:Create(placement_gui.Mouse.UIScale, tween_infos.Back, {
					Scale = .9
				})
				
				a1:Play()
				a1.Completed:Wait()
				a1:Destroy()
				env_services.TweenService:Create(placement_gui.Mouse.UIScale, tween_infos.Back, {
					Scale = 1
				}):Play()
			end)
			
			free_camera.GlobalCamera.ChangeState:Fire(cam_state,placement_gui.Mouse.Mouse)
			
			if cam_state then
				placement_gui.KeyE.Visible = true
				placement_gui.KeyQ.Visible = true
			else
				placement_gui.KeyE.Visible = false
				placement_gui.KeyQ.Visible = false
			end
		end
	end)
	
	placement.init_configs()	
	env_utils:mouse_trigger(placement_gui)
	
	placement_controller:init(placement)
	free_camera.GlobalCamera:Start(CFrame.new(0.6, -0.5, -344.8))
end

placement.services = env_services

return placement