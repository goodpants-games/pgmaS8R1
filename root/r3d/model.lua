---@class r3d.Model: r3d.Object
---@overload fun(mesh:love.Mesh):r3d.Model
local Model = batteries.class({ name = "r3d.Model", extends = require("r3d.object") })
local mat4 = require("r3d.mat4")

---@param mesh love.Mesh
function Model:new(mesh)
    self:super() ---@diagnostic disable-line
    self.mesh = mesh
    self.transform = mat4.new()
end

function Model:release()
    self.mesh:release()
    self.mesh = nil
end

return Model