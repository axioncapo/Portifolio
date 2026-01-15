local env_services = require("../../Environment/env.services")
local env_utils = require("../../Environment/env.utils")
local janitor = require(".././Others/Janitor")
local goodsignals = require(".././Others/GoodSignal")
local free_camera = require(".././Others/Camera")
local zone_plus = require("./ZonePlus")
local offsets = require("@self/offsets")

local function Vector3ToNormalId(normal: Vector3): Enum.NormalId?
	local axis = Vector3.new(
		math.abs(normal.X),
		math.abs(normal.Y),
		math.abs(normal.Z)
	)
	
	if axis.X > axis.Y and axis.X > axis.Z then
		return normal.X > 0 and Enum.NormalId.Right or Enum.NormalId.Left
	elseif axis.Y > axis.X and axis.Y > axis.Z then
		return normal.Y > 0 and Enum.NormalId.Top or Enum.NormalId.Bottom
	else
		return normal.Z > 0 and Enum.NormalId.Back or Enum.NormalId.Front
	end
end


local placement = {
	scope = janitor.new();
	placement_folders = nil :: any;
	collecteds = nil :: {Attachment}?;
	mode = "single",
	debug_mode = false,
	snaping_size = 3,
	
	data = {
		offset = 1,
	}
}

local local_player = env_services.Players.LocalPlayer
local mouse = local_player:GetMouse()
local placement_area = workspace:WaitForChild("PlayersAreas"):WaitForChild(local_player.Name):WaitForChild("PlacementArea")

local params = RaycastParams.new()
params.FilterDescendantsInstances = {placement_area}
params.FilterType =  Enum.RaycastFilterType.Include

local error_highlight = Instance.new("Highlight", local_player.PlayerGui)
error_highlight.OutlineTransparency = 1
error_highlight.FillTransparency = .2
error_highlight.Enabled = true

local function snapToGrid(pos: Vector3, gridSize: number): Vector3
	if not placement.owner.configs.snaping_angles then
		return pos
	end

	return Vector3.new(
		math.floor((pos.X / gridSize) + 0.5) * gridSize,
		math.floor((pos.Y / gridSize) + 0.5) * gridSize,
		math.floor((pos.Z / gridSize) + 0.5) * gridSize
	)
end

local function alignToSurface(position: Vector3, normal: Vector3, size: Vector3, gridSize: number, igY)
	if not placement.owner.configs.snaping_angles then
		return CFrame.new(position)
	end
	
	local snappedX = math.floor((position.X / gridSize) + 0.5) * gridSize
	local snappedZ = math.floor((position.Z / gridSize) + 0.5) * gridSize
	local snappedPos = Vector3.new(snappedX, position.Y, snappedZ)
	local offset = (size / 2) * normal
	
	return CFrame.new(snappedPos), snappedPos + offset
end

local function debug_hit(hitpos: Vector3)
	local attachment = Instance.new("Attachment", workspace.Terrain)
	attachment.Visible = true
	attachment.WorldCFrame = CFrame.new(hitpos)
	
	task.delay(2, attachment.Destroy, attachment)
end

function placement.assert_object(object: Model, changed_count: typeof(goodsignals.new()))
	assert(object, `object expected...`)
	assert(object:IsA("Model"), `Model expected, got {object.ClassName}`)
	
	placement.initialize_cameras:Fire(placement_area)
	
	placement.scope:Cleanup()

	local current = placement.scope:Add(object:Clone())
	current.Parent = workspace.Terrain
	current.PrimaryPart.Transparency = 0

	local last_attach
	local placing_angle = 0
	local finished_move = true

	local params = OverlapParams.new()
	params.BruteForceAllSlow = true
	params.FilterDescendantsInstances = {placement.placement_folders}
	params.FilterType = Enum.RaycastFilterType.Include

	local mocking = Instance.new("Part")
	mocking.Transparency = 1
	mocking.Size = Vector3.one
	mocking.Anchored = true
	mocking.CanCollide = false
	mocking.CanQuery = false
	mocking.CanTouch = false
	mocking.Parent = workspace.Terrain

	local connection = placement.scope:Add(env_services.UserInputService.InputChanged:Connect(function(input, process)
		if process or not finished_move then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

		local result = placement.get_mouse_hit()
		if result then
			--debug_hit(result.Position)
			
			local size = current:GetExtentsSize()

			local targetCFrame, finalPos = alignToSurface(result.Position, result.Normal, size, placement.owner.configs.gride_size)
			targetCFrame *= CFrame.Angles(0, math.rad(placing_angle), 0)
			mocking.CFrame = targetCFrame
			
			local have_object_placed = workspace:GetPartBoundsInBox(targetCFrame, size * .9, params)
			if next(have_object_placed) then	
				error_highlight.Adornee = current
			else
				error_highlight.Adornee = nil
			end
			
			if not placement.isTouching(mocking) then
				--env_services.ErrorsService:cached_error("touch", "Out of build limits...", 3, Color3.new(1,1,1))
				env_services.ErrorsService:billboard_error(result.Position, "Out of limits", 2)
				return
			end
			
			local lerp = env_services.TweenService:Create(current.PrimaryPart, TweenInfo.new(.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
				CFrame = targetCFrame * CFrame.new(0,size.Y/2,0)
			})

			last_attach = targetCFrame
			finished_move = false
			lerp:Play()
			lerp.Completed:Wait()
			lerp:Destroy()
			finished_move = true
		end
	end))

	placement.scope:Add(env_services.UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean) 
		if not gameProcessedEvent and input.UserInputType == Enum.UserInputType.MouseButton1 then
			if not finished_move then
				finished_move = true
				current:PivotTo(last_attach)
			end

			local result = placement.get_mouse_hit()
			if result then
				local have_object_placed = workspace:GetPartBoundsInBox(current:GetPivot(), current:GetExtentsSize() * .9, params)
				if next(have_object_placed) then					
					env_services.ErrorsService:display_error("Already have a object here", 3)
					return
				end

				local cloned = object:Clone()
				cloned.Parent = placement.placement_folders
				cloned:PivotTo(current:GetPivot() * CFrame.new(0,current:GetExtentsSize().Y/2, 0)* CFrame.Angles(0, math.rad(placing_angle), 0))
				--placement.initialize_cameras:Fire(cloned)

				if placement.owner.configs.placement_mode == "single" then
					placement.scope:Cleanup()
				end
			end
		end	
	end))

	-- Rotação com R
	placement.scope:Add(env_services.UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean) 
		if input.KeyCode == Enum.KeyCode.R then
			placing_angle = (placing_angle + 15) % 360
			current:PivotTo(current:GetPivot() * CFrame.Angles(0, math.rad(placing_angle), 0))
		end	
	end))

	return function()
		placement.scope:Cleanup()
	end
end

function placement.get_mouse_hit()	
	local loc = env_services.UserInputService:GetMouseLocation()
	local ray = workspace.CurrentCamera:ScreenPointToRay(loc.X, loc.Y)
	local result = workspace:Raycast(ray.Origin, ray.Direction * 600, placement.parameter_cast) :: RaycastResult
	
	return result
end

function placement.init<v>(self: placement, owner: v)
	warn("Initiliazed")
	
	self.placement_folders = Instance.new("Folder", workspace)
	self.placement_folders.Name = "placement_folder"
	
	self.walls_folders = Instance.new("Folder", self.placement_folders)
	self.walls_folders.Name = "walls"
	
	self.initialize_cameras = goodsignals.new()
	self.order = 1
	local offset = Vector3.new(0, 2, 16)
	
	local parameter_cast = RaycastParams.new()
	parameter_cast.FilterDescendantsInstances = {placement_area, placement.placement_folders}
	parameter_cast.FilterType = Enum.RaycastFilterType.Include
		
	local zone = zone_plus.fromRegion(placement_area:WaitForChild("Touching").CFrame, placement_area:WaitForChild("Touching").Size)
	placement_area:WaitForChild("Touching"):Destroy()
	
	self.parameter_cast = parameter_cast
	
	self.isTouching = function(item: BasePart)
		return zone:findPart(item)
	end
	
	self.initialize_cameras:Connect(function(target: Model)
		local targetPivot = target:GetPivot()
		local targetPos = targetPivot.Position

		local lookAtPos = targetPos
		local backPos = targetPivot.Position - targetPivot.LookVector * offset.Z + Vector3.new(0, offset.Y, 0)
		local camera_target = CFrame.lookAt(backPos, lookAtPos) * CFrame.Angles(0, math.rad(45), 0)
		
		free_camera.GlobalCamera:Start(camera_target)
	end)
	
	env_utils:foreach(placement_area:GetDescendants(), function(a0: number | string, a1: Instance) 
		if a1:IsA("Attachment") then
			a1.Visible = self.debug_mode
		end	
	end)
	
	placement_area.DescendantAdded:Connect(function(descendant: Instance) 
		if descendant:IsA("Attachment") then
			descendant.Visible = self.debug_mode
		end	
	end)
	
	placement.owner = owner
end

placement.walls = {}

function placement.walls.get_closest_attach(list: {Attachment}, position: Vector3)
	local closest: Attachment? = nil
	local closestDist = math.huge
		
	for _, attach in ipairs(list) do
		local dist = (attach.WorldPosition - position).Magnitude
		if dist < closestDist then
			closestDist = dist
			closest = attach
		end
	end

	return closest, closestDist
end


function placement.walls.init()
	local wall = placement.scope:Add(env_services.ReplicatedStorage.World["Placement.Assets"].Walls.Concrete:Clone())
	wall.Parent = workspace.Terrain
	local wall_preview = wall.Preview
	
	wall_preview.Transparency = .5
	wall_preview.Material = Enum.Material.Neon
	wall_preview.BrickColor = BrickColor.Blue()
	
	local state = 0
	local selected_position = nil
	local startPos = nil

	local mocking = Instance.new("Part")
	mocking.Transparency = 1
	mocking.Size = Vector3.one
	mocking.Anchored = true
	mocking.CanCollide = false
	mocking.CanQuery = false
	mocking.CanTouch = false
	mocking.Parent = workspace.Terrain
	
	local overlapParams = OverlapParams.new()
	overlapParams.BruteForceAllSlow = true
	overlapParams.FilterDescendantsInstances = {placement.placement_folders}
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	
	local function build_wall(origin: Vector3, direction: Vector3)
		local real_wall = env_services.ReplicatedStorage.World["Placement.Assets"].Walls.Concrete:Clone()
		
		real_wall.Parent = placement.placement_folders
		real_wall.Real.Size = wall_preview.Size
		real_wall:PivotTo(wall_preview:GetPivot())
		
		placement.scope:Cleanup()
	end
	
	local attachs = env_utils.collect(placement.walls_folders:GetDescendants(), "Attachment", placement.walls_folders)
	
	placement.scope:Add(env_services.UserInputService.InputChanged:Connect(function(input: InputObject, gameProcessedEvent: boolean) 
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local result = placement.get_mouse_hit()
			
			if not result then
				return
			end
			
			local get_relative_attachment = placement.walls.get_closest_attach(attachs, result.Position)
			
			warn(get_relative_attachment)
			
			if get_relative_attachment then
				result.Position = get_relative_attachment.WorldPosition
			end
			
			if state == 0 then				
				local position = alignToSurface(result.Position, result.Normal, wall.Preview.Size, placement.owner
					.configs.gride_size, true)
				mocking.CFrame = position
				
				if not placement.isTouching(mocking) then
					return
				end				
				
				--debug_hit(result.Position)
				
				wall_preview.CFrame = position * CFrame.new(0, wall_preview.Size.Y/2,0)
			elseif state == 1 then
				--local distance = (wall_preview.Position - result.Position).Magnitude
				--wall_preview.CFrame = CFrame.lookAt(
				--	wall_preview.Position, 
				--	Vector3.new(result.Position.X, wall_preview.Position.Y, result.Position.Z)) * CFrame.new(0,0,-distance/2)
				
				
				--wall_preview.Size = Vector3.new(wall_preview.Size.X, wall_preview.Size.Y, distance)

				local startSnap = snapToGrid(startPos, placement.owner.configs.gride_size)
				local endSnap = snapToGrid(result.Position, placement.owner.configs.gride_size)

				if next(workspace:GetPartBoundsInBox(wall_preview:GetPivot(), wall_preview.Size, overlapParams)) then
					env_services.ErrorsService:billboard_error(endSnap, "Cant build here", 4)
				end
				
				local dir = (endSnap - startSnap)
				local distance = dir.Magnitude

				local lookAt = CFrame.lookAt(
					startSnap,
					Vector3.new(endSnap.X, startSnap.Y, endSnap.Z)
				)

				wall_preview.Size = Vector3.new(wall_preview.Size.X, wall_preview.Size.Y, distance)
				wall_preview.CFrame = lookAt * CFrame.new(0, 0, -distance/2)
			end
		end	
	end))
	
	placement.scope:Add(env_services.UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean) 
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local result = placement.get_mouse_hit()
			
			if result and state == 0 then
				startPos = wall_preview.Position
				state = 1
				
			elseif result and state == 1 then
				state = 2
				build_wall(wall_preview.Position, result.Position)
			end
		end	
	end))
end

type placement = typeof(placement)

return placement