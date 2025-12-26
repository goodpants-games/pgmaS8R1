---@class r3d.Drawable: r3d.Object
---@overload fun():r3d.Drawable
local Drawable = batteries.class({ name = "r3d.Drawable", extends = require("r3d.object") })

function Drawable:new()
    self:super()

    --- True if fully opaque, false if not.
    self.opaque = true
    self.double_sided = false
    self.visible = true
    self.cast_shadow = true
    self.receive_shadow = true
end

---@param draw_ctx r3d.DrawContext
function Drawable:draw(draw_ctx)
    error(self:type() .. " draw not implemented")
end

return Drawable