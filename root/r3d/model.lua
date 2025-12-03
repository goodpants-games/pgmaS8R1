---@class r3d.Model: r3d.Drawable
---@overload fun(mesh:love.Mesh):r3d.Model
local Model = batteries.class({ name = "r3d.Model", extends = require("r3d.drawable") })
local mat4 = require("r3d.mat4")

---@param mesh love.Mesh
function Model:new(mesh)
    self:super() ---@diagnostic disable-line
    self.shader = "shaded"
    self.mesh = mesh
    self.transform = mat4.new()
end

function Model:release()
    if self.mesh then
        self.mesh:release()
        self.mesh = nil
    end
end

function Model:draw(draw_ctx)
    draw_ctx:activate_shader(self.shader)
    Lg.draw(self.mesh)
end

return Model