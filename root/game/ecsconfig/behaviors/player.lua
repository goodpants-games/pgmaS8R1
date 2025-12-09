---@class game.PlayerBehavior: game.Behavior
local PlayerBehavior = batteries.class {
    name = "PlayerBehavior",
    extends = require("game.ecsconfig.behaviors.base")
}

function PlayerBehavior:new()
    self:super() ---@diagnostic disable-line
    self.selected_weapon = 1
end

function PlayerBehavior:_fire_shoot_scanline()
    local gun_sight = self.entity.gun_sight
    if not gun_sight then return end

    local position = self.entity.position

    local dx, dy = math.normalize_v2(gun_sight.cur_dx, gun_sight.cur_dy)

    print("fire!")
    self.game:add_attack({
        x = position.x + gun_sight.cur_dx,
        y = position.y + gun_sight.cur_dy,
        radius = 1,
        damage = 16,
        dx = dx,
        dy = dy,
        mask = require("game.consts").COLGROUP_ENEMY,
        knockback = 2.0,
        ground_only = false,
        owner = self.entity
    })
end

function PlayerBehavior:tick()
    local ent = self.entity
    local game = self.game
    
    local position = ent.position
    local actor = ent.actor
    local rotation = ent.rotation
    local light = ent.light
    local sprite = ent.sprite
    local health = ent.health
    local player = ent.player_control
    local attackable = ent.attackable

    local battery_drain_scale = 0.003
    local battery_drain = 1.0

    local prev_state = player.state

    if attackable and attackable.hit then
        player.state = "hurt"
    end

    local was_attack_triggered = false
    if player.trigger_attack > 0 then
        if player.state == "move" then
            if self.selected_weapon == 1 then
                player.state = "melee_attack"
            else
                player.state = "shoot"
            end

            was_attack_triggered = true
        end
    end

    if was_attack_triggered then
        player.trigger_attack = 0.0
    elseif player.trigger_attack > 0 then
        player.trigger_attack = player.trigger_attack - 1
    end

    if player.trigger_weapon_switch then
        local last_selected_weapon = self.selected_weapon

        self.selected_weapon = self.selected_weapon % 2 + 1
        print(self.selected_weapon)
        player.trigger_weapon_switch = false

        if self.selected_weapon == 2 and last_selected_weapon ~= 2 then
            ent:give("gun_sight", 1, 0, 0)
            ent.gun_sight.auto_aim = true
        elseif self.selected_weapon ~= 2 and last_selected_weapon == 2 then
            ent:remove("gun_sight")
        end
    end

    local movement_lock = player.state ~= "move"
    if player.lock or movement_lock then
        actor.move_x = 0.0
        actor.move_y = 0.0
    else
        actor.move_x, actor.move_y = player.move_x, player.move_y
    end

    if player.lock or movement_lock then
        actor.move_speed = 0.0
    elseif player.run then
        actor.move_speed = 2.4
        battery_drain = battery_drain + 2.0
    else
        actor.move_speed = 1.4
    end

    -- room transport behavior override
    do
        local is_transport, transport_dx, transport_dy
            = game:room_transport_info()
        
        if is_transport then
            actor.move_x = transport_dx
            actor.move_y = transport_dy
            player.move_x = transport_dx
            player.move_y = transport_dy
            actor.move_speed = 0.5
            player.state = "move"
            movement_lock = false
            was_attack_triggered = false
            battery_drain_scale = 0.0
        end
    end

    local input_move_len =
        math.sqrt(player.move_x * player.move_x + player.move_y * player.move_y)
    local move_min = 0.1
    if rotation and input_move_len > move_min and not movement_lock then
        local ang = math.atan2(player.move_y, player.move_x)
        local ang_diff = math.abs(math.angle_difference(rotation.ang, ang))

        -- snap angle when either close enough or turning 180 degrees
        -- if ang_diff < math.rad(0.5) or math.abs(ang_diff - math.pi) < math.rad(1) then
        --     rotation.ang = ang
        -- else
            rotation.ang = math.lerp_angle(rotation.ang, ang, 0.2)
        -- end
    end

    local lookx, looky = 0.0, 0.0

    if rotation then
        lookx = math.cos(rotation.ang)
        looky = math.sin(rotation.ang)
    end

    -- update animation lol
    local cur_move_speed =
          math.sqrt(actor.move_x * actor.move_x + actor.move_y * actor.move_y)
        * actor.move_speed
    
    if sprite then
        local sprite_anim_frame = sprite._spr:getAnimFrame()
        local anim_frame_changed = sprite_anim_frame ~= self._sprite_last_anim_frame

        if player.state == "melee_attack" then
            if prev_state ~= "melee_attack" then
                sprite:play("melee_attack")
            elseif not sprite.anim then
                player.state = "move"
                sprite:play("idle")
            elseif sprite._spr:getAnimFrame() == 10 then
                game:add_attack({
                    x = position.x + lookx * 14,
                    y = position.y + looky * 14,
                    radius = 12,
                    damage = 10,
                    dx = lookx,
                    dy = looky,
                    mask = require("game.consts").COLGROUP_ENEMY,
                    ground_only = true,
                    knockback = 4.0,
                    owner = ent
                })
            end

        elseif player.state == "shoot" then
            if prev_state ~= "shoot" then
                sprite:play("shoot")
            elseif not sprite.anim then
                player.state = "move"
                sprite:play("idle")
            elseif anim_frame_changed and sprite_anim_frame == 5 then
                battery_drain = battery_drain + 300.0
                self:_fire_shoot_scanline()

                if ent.gun_sight then
                    ent.gun_sight.visible = false
                end
            end
        
        elseif player.state == "hurt" then
            if prev_state ~= "hurt" then
                sprite:play("hurt")
            elseif not sprite.anim then
                player.state = "move"
                sprite:play("idle")
            end
        else
            local anim = "idle"

            if cur_move_speed > 0.2 then
                anim = "walk"
            end

            if sprite.anim ~= anim then
                sprite:play(anim)
            end
        end

        self._sprite_last_anim_frame = sprite._spr:getAnimFrame()
    end

    -- update camera
    if position then
        -- local lookx, looky = 0.0, 0.0

        -- if rotation then
        --     lookx = math.cos(rotation.ang)
        --     looky = math.sin(rotation.ang)
        -- end

        game.room.cam.follow = ent
        game.room.cam.offset_target_x = lookx * 25.0
        game.room.cam.offset_target_y = looky * 25.0
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

    if ent.gun_sight and player.state == "move" then
        ent.gun_sight.visible = true
    end
end

return PlayerBehavior