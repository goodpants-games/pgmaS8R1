local Concord = require("concord")

local render_system = Concord.system({
    pool = {"position", "sprite"},
    dbgdraw_pool = {"position", "collision"}
})

function render_system:draw()
    for _, entity in ipairs(self.pool) do
        local pos = entity.position
        local rot = 0
        local sprite = entity.sprite

        if entity.rotation then
            rot = entity.rotation.ang
        end

        Lg.setColor(sprite.r, sprite.g, sprite.b)
        Lg.draw(sprite.img,
                math.floor(pos.x), math.floor(pos.y), rot,
                sprite.sx, sprite.sy,
                math.floor(sprite.img:getWidth() / 2 + sprite.ox), math.floor(sprite.img:getHeight() / 2 + sprite.oy))
    end

    for _, entity in ipairs(self.dbgdraw_pool) do
        local pos = entity.position
        local rect = entity.collision

        Lg.setColor(1, 0, 0)
        Lg.setLineWidth(1)
        Lg.rectangle("line",
                     math.floor(pos.x - rect.w / 2.0) + 0.5,
                     math.floor(pos.y - rect.h / 2.0) + 0.5,
                     rect.w,
                     rect.h)
    end
end

return render_system