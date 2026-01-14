--//libs

local region = require(script.Parent.region)
local typesCache = require(script.Parent.typesCache)
local world = require(script.Parent.Parent)

local CombatTool = {
    __class_name = "CombatTool",
    __type = "CombatTool"
}

function CombatTool:Attack()
    print("attacked", self)
end

return CombatTool