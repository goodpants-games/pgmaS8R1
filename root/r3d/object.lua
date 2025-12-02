local mat4 = require("r3d.mat4")

---@class r3d.Object
---@overload fun():r3d.Object
local Object = batteries.class({ name = "Object" })

function Object:new()
    self.transform = mat4.new()
end

function Object:get_position()
    return self.transform:get(0, 3),
           self.transform:get(1, 3),
           self.transform:get(2, 3)
end

---@param x number
---@param y number
---@param z number
function Object:set_position(x, y, z)
    self.transform:set(0, 3, x)
    self.transform:set(1, 3, y)
    self.transform:set(2, 3, z)
end

function Object:get_scale()
    return self.transform:get(0, 0),
           self.transform:get(1, 1),
           self.transform:get(2, 2)
end

---@param x number
---@param y number
---@param z number
function Object:set_scale(x, y, z)
    self.transform:set(0, 0, x)
    self.transform:set(1, 1, y)
    self.transform:set(2, 2, z)
end

return Object