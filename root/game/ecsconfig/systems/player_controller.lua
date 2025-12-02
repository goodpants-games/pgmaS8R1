local Concord = require("concord")
local Input = require("input")

local system = Concord.system({
    pool = {"player_control"}
})

function system:tick()
    local ent = self.pool[1]
    if not ent then
        return
    end

    local game = self:getWorld().game --[[@as Game]]
    local position = ent.position
    local actor = ent.actor
    local light = ent.light

    if position then
        game.cam_x = position.x
        game.cam_y = position.y
    end

    local move_lsq = actor.move_x * actor.move_x + actor.move_y * actor.move_y
    if move_lsq > 0.0 then
        local ang = math.atan2(actor.move_y, actor.move_x)
        local ang_diff = math.abs(math.angle_difference(actor.look_angle, ang))

        -- snap angle when either close enough or turning 180 degrees
        if ang_diff < math.rad(0.5) or math.abs(ang_diff - math.pi) < math.rad(1) then
            actor.look_angle = ang
        else
            actor.look_angle = math.lerp_angle(actor.look_angle, ang, 0.2)
        end
    end

    if light and light.type == "spot" then
        local dx = MOUSE_X - DISPLAY_WIDTH / 2
        local dy = MOUSE_Y - DISPLAY_HEIGHT / 2
        local ang = math.atan2(dy, dx)

        light.spot_rz = ang
    end
end

function system:update(dt)
    for _, ent in ipairs(self.pool) do
        local actor = ent.actor

        if actor then
            local mx, my = Input.players[1]:get("move")
            local mlen = math.sqrt(mx*mx + my*my)
            if mlen > 0.0 then
                mx, my = mx / mlen, my / mlen
            end
            
            actor.move_x, actor.move_y = mx, my
        end
    end
end

return system