---@class game.HeartParticleFlashBehavior: game.Behavior
---@overload fun(color:number[], time_offset:number):game.HeartParticleFlashBehavior
local Behavior = batteries.class {
    name = "game.HeartParticleFlashBehavior",
    extends = require("game.ecsconfig.behaviors.base")
}

---@param color number[]
---@param time_offset number
function Behavior:new(color, time_offset)
    self:super()
    self.color = color
    self.time_offset = time_offset
end

function Behavior:tick()
    local sprite = self.entity.sprite

    local t = (math.sin(self.game.frame * 0.3 + self.time_offset) + 1.0) / 2.0
    t = math.lerp(0.3, 1.0, t)

    local r, g, b = table.unpack3(self.color)
    sprite.r = math.lerp(0.0, r, t)
    sprite.g = math.lerp(0.0, g, t)
    sprite.b = math.lerp(0.0, b, t)
end

return Behavior