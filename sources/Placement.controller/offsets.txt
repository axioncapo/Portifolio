local offsets = {
	Right = function(model: Model)
		return CFrame.new(model:GetExtentsSize().X/2,0,0)
	end,

	Left = function(model: Model)
		return CFrame.new(-(model:GetExtentsSize().X/2),0,0)
	end,

	Top = function(model: Model)
		return CFrame.new(0,(model:GetExtentsSize().Y/2),0)
	end,

	Bottom = function(model: Model)
		return CFrame.new(0,-(model:GetExtentsSize().Y/2),0)
	end,

	Front = function(model: Model)
		return CFrame.new(0,0,(model:GetExtentsSize().Z/2))
	end,

	Back = function(model: Model)
		return CFrame.new(0,0,-(model:GetExtentsSize().Z/2))
	end,
}

return offsets