local object = require("r3d.object")

---@class r3d.Light: r3d.Object
---@overload fun():r3d.Light
local Light = batteries.class({ name = "r3d.Light", extends = object })

function Light:new()
    self:super() ---@diagnostic disable-line
    self.r = 1.0
    self.g = 1.0
    self.b = 1.0
    self.power = 1.0
    self.enabled = true

    self.constant = 1.0
    self.linear = 0.022
    self.quadratic = 0.0019
end

---@class r3d.SpotLight: r3d.Light
---@overload fun():r3d.SpotLight
local SpotLight = batteries.class({ name = "r3d.SpotLight", extends = object })

function SpotLight:new()
    self.angle = math.rad(60)
end

---@return number x, number y, number z
function SpotLight:get_light_direction()
    local t = self.transform
    local x, y, z = t:get(0, 0), t:get(1, 0), t:get(2, 0)
    local l = math.sqrt(x*x + y*y + z*z)
    if l > 0 then
        x, y, z = x/l, y/l, z/l
    end

    return x, y, z
end

return {
    light = Light,
    spotlight = SpotLight
}