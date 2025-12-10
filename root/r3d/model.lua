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

    self.r = 1.0
    self.g = 1.0
    self.b = 1.0
    self.a = 1.0
end

function Model:release()
    if self.mesh then
        self.mesh:release()
        self.mesh = nil
    end
end

function Model:draw(draw_ctx)
    draw_ctx:activate_shader(self.shader)
    Lg.setColor(self.r, self.g, self.b, self.a)
    Lg.draw(self.mesh)
end

return Model