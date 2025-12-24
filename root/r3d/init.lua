local r3d = {}

---@class r3d.Object
---@field set_position fun(self:r3d.Object, x:number, y:number, z:number)
---@field get_position fun(self:r3d.Object):(number, number, number)

r3d.world = require("r3d.world")
r3d.model = require("r3d.model")
r3d.mesh = require("r3d.mesh")
r3d.batch = require("r3d.batch")
r3d.shader = require("r3d.shader")

return r3d