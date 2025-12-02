---@class r3d.Drawable: r3d.Object
---@overload fun():r3d.Drawable
local Drawable = batteries.class({ name = "r3d.Drawable", extends = require("r3d.object") })

function Drawable:new()
    self:super()

    --- True if fully opaque, false if not.
    self.opaque = true
    self.use_shading = true
    self.double_sided = false
end

function Drawable:draw()
    error(self:type() .. " draw not implemented")
end

return Drawable