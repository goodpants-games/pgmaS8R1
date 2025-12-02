local Concord = require("concord")
local mat4 = require("r3d.mat4")

local render_system = Concord.system({
    pool = {"position", "sprite"},
    dbgdraw_pool = {"position", "collision"}
})

function render_system:draw()
    ---@type r3d.Batch
    local draw_batch = self:getWorld().game.r3d_draw_batch

    local transform0 = mat4.new()
    local rot_matrix = mat4.new()
    local transform1 = mat4.new()

    rot_matrix:rotation_x(math.pi / 2)

    for _, entity in ipairs(self.pool) do
        local pos = entity.position
        local rot = 0
        local sprite = entity.sprite

        if entity.rotation then
            rot = entity.rotation.ang
        end

        local px, py = math.floor(pos.x), math.floor(pos.y)
        local sx, sy = sprite.sx, sprite.sy
        local ox = math.floor(sprite.img:getWidth() / 2 + sprite.ox)
        local oy = math.floor(sprite.img:getHeight() / 2 + sprite.oy)

        transform0:identity()
        transform0:set(0, 3, -ox)
        transform0:set(2, 3, -oy)
        transform0:set(0, 0, sx)
        transform0:set(1, 1, sy)

        rot_matrix:mul(transform0, transform1)

        transform1:set(0, 3, px - ox)
        transform1:set(1, 3, py)
        transform1:set(2, 3, sprite.img:getHeight())

        draw_batch:set_color(sprite.r, sprite.g, sprite.b)
        draw_batch:add_image(sprite.img, transform1)
    end

    if Debug.enabled then
        for _, entity in ipairs(self.dbgdraw_pool) do
            local pos = entity.position
            local rect = entity.collision
            local actor = entity.actor

            Lg.setColor(1, 0, 0, 0.2)
            Lg.setLineWidth(1)
            Lg.setLineStyle("rough")
            Lg.rectangle("line",
                         math.floor(pos.x - rect.w / 2.0) + 0.5,
                         math.floor(pos.y - rect.h / 2.0) + 0.5,
                         rect.w,
                         rect.h)
            
            if actor then
                local lookx = math.cos(actor.look_angle)
                local looky = math.sin(actor.look_angle)

                Lg.setColor(1, 0, 0, 0.8)
                Lg.line(
                    math.floor(pos.x) + 0.5, math.floor(pos.y) + 0.5,
                    math.floor(pos.x + lookx * 10) + 0.5, math.floor(pos.y + looky * 10) + 0.5)
            end
        end
    end
end

return render_system