local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local GoodSignal = require("./GoodSignal")

local FreeCamera = {
	GlobalCamera = nil :: free_camera
}
FreeCamera.__index = FreeCamera

function FreeCamera.new()
	local self = setmetatable({}, FreeCamera)

	self.Enabled = false
	self.Camera = workspace.CurrentCamera
	self.Player = Players.LocalPlayer
	self.Humanoid = nil
	self.HumanoidRootPart = nil
	
	self.MoveVector = Vector3.zero
	self.Rotation = Vector2.new(0, 0)
	self.Connection = nil
	self.ChangeState = GoodSignal.new()
	
	self.Speed = 0.5
	self.Sensitivity = 0.002
	
	local state = false
	
	self.ChangeState:Connect(function(state: boolean, label: TextLabel)
		if state then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
			label.Text = `Mouse state: hidden`
		else
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
			
			label.Text = `Mouse state: free`
		end
	end)


	return self
end

function FreeCamera:Start(started_cframe)
	if self.Enabled then return end
	self.Enabled = true

	(Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()).PrimaryPart.Anchored = true
	
	self.Camera.CameraType = Enum.CameraType.Scriptable
	self.Camera.CFrame = started_cframe
	
	self.Connection = RunService.RenderStepped:Connect(function(dt)
		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		else
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		
		self:Update(dt)
	end)
end

function FreeCamera:Stop()
	if not self.Enabled then return end
	self.Enabled = false
	
	(Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()).PrimaryPart.Anchored = false

	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true

	self.Camera.CameraType = Enum.CameraType.Custom

	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
end

function FreeCamera:Update(dt)
	local move = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		move = move + Vector3.new(0, 0, -1)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		move = move + Vector3.new(0, 0, 1)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		move = move + Vector3.new(-1, 0, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		move = move + Vector3.new(1, 0, 0)
	end

	self.MoveVector = move.Unit.Magnitude > 0 and move.Unit or Vector3.zero
	
	local delta = UserInputService:GetMouseDelta()
	self.Rotation = self.Rotation + Vector2.new(-delta.Y, -delta.X) * self.Sensitivity
	self.Rotation = Vector2.new(math.clamp(self.Rotation.X, -math.rad(89), math.rad(89)), self.Rotation.Y)

	local cameraCFrame = CFrame.new(self.Camera.CFrame.Position) 
		* CFrame.Angles(0, self.Rotation.Y, 0) 
		* CFrame.Angles(self.Rotation.X, 0, 0)

	local moveWorld = cameraCFrame:VectorToWorldSpace(self.MoveVector) * self.Speed
	self.Camera.CFrame = cameraCFrame + moveWorld
end

FreeCamera.GlobalCamera = FreeCamera.new()

export type free_camera = typeof(FreeCamera.new())

return FreeCamera