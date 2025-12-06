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
    local rotation = ent.rotation
    local light = ent.light
    local sprite = ent.sprite
    local health = ent.health
    local player = ent.player_control

    local battery_drain_scale = 0.01
    local battery_drain = 1.0

    if player.lock then
        actor.move_x = 0.0
        actor.move_y = 0.0
    else
        actor.move_x, actor.move_y = player.move_x, player.move_y
    end

    if player.lock then
        actor.move_speed = 0.0
    elseif player.run then
        actor.move_speed = 2.4
        battery_drain = battery_drain + 2.0
    else
        actor.move_speed = 1.4
    end

    local input_move_len =
        math.sqrt(player.move_x * player.move_x + player.move_y * player.move_y)
    local move_min = 0.1
    if rotation and input_move_len > move_min then
        local ang = math.atan2(player.move_y, player.move_x)
        local ang_diff = math.abs(math.angle_difference(rotation.ang, ang))

        -- snap angle when either close enough or turning 180 degrees
        -- if ang_diff < math.rad(0.5) or math.abs(ang_diff - math.pi) < math.rad(1) then
        --     rotation.ang = ang
        -- else
            rotation.ang = math.lerp_angle(rotation.ang, ang, 0.2)
        -- end
    end

    -- update animation lol
    local cur_move_speed =
          math.sqrt(actor.move_x * actor.move_x + actor.move_y * actor.move_y)
        * actor.move_speed
    
    if sprite then
        local anim = "idle"

        if cur_move_speed > 1.0 then
            anim = "walk"
        end

        if sprite.anim ~= anim then
            sprite:play(anim)
        end
    end

    -- update camera
    if position then
        local lookx, looky = 0.0, 0.0

        if rotation then
            lookx = math.cos(rotation.ang)
            looky = math.sin(rotation.ang)
        end

        game.cam_x = position.x + lookx * 20.0
        game.cam_y = position.y + looky * 20.0

        if Input.players[1]:pressed("player_attack") then
            game:add_attack({
                x = position.x + lookx * 16,
                y = position.y + looky * 16,
                radius = 16,
                damage = 1,
                dx = lookx,
                dy = looky,
                mask = require("game.consts").COLGROUP_ENEMY,
                owner = ent
            })

            -- health.value = health.value - 10
        end
    end

    if light and light.type == "spot" then
        -- local dx = MOUSE_X - DISPLAY_WIDTH / 2
        -- local dy = MOUSE_Y - DISPLAY_HEIGHT / 2
        -- local ang = math.atan2(dy, dx)

        light.spot_rz = rotation and rotation.ang or 0.0
    end

    if health then
        health.value = health.value - battery_drain * battery_drain_scale
    end
end

function system:update(dt)
    for _, ent in ipairs(self.pool) do
        local control = ent.player_control

        if control then
            local input = Input.players[1]
            local mx, my = input:get("move")
            local mlen = math.sqrt(mx*mx + my*my)
            if mlen > 0.0 then
                mx, my = mx / mlen, my / mlen
            end
            
            control.move_x, control.move_y = mx, my
            control.run = false
            control.lock = false

            if input:down("player_lock") then
                control.lock = true
            elseif input:down("player_run") then
                control.run = true
            end
        end
    end
end

return system