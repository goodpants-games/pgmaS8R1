local game_consts = require("game.consts")
local bit = require("bit")

---@class game.FlyingEnemyBehavior: game.EnemyBehaviorBase
local Behavior = batteries.class {
    extends = require("game.ecsconfig.behaviors.base_enemy")
}

function Behavior:new()
    self:super()

    self.mode = "flying"
    self.comfort_dist = 16.0 * 4.0
    self.ready_to_dive = false
    self.dive_timer = 0
    self.home_height = 20.0

    self.dive_vx = 0.0
    self.dive_vy = 0.0
    self.dive_windup = 0.0
    self.dive_progress = 0.0
    self.dive_start_z = 0.0

    self.fly_speed = 0.2
    self.dive_speed = 3.0

    self.dive_length = 40.0
    self.dive_height = 10.0

    self.dead_vz = 0.0
end

function Behavior:init(ent, game)
    self.__super.init(self, ent, game)

    local actor = ent.actor
    local sprite = ent.sprite

    actor.move_speed = self.fly_speed
    actor.rigid_velocity = false
    actor.velocity_damping = 0.9
    
    if ent.health and ent.health.value <= 0.0 then
        self.mode = "dead"

        if sprite and sprite.anim ~= "dead" then
            sprite:play("dead")
        end
    else
        sprite:play("idle")
    end
end

function Behavior:_flying_mode_update()
    local ent = self.entity
    local actor = ent.actor
    local position = ent.position
    local sprite = ent.sprite
    local attackable = ent.attackable

    actor.rigid_velocity = false
    actor.move_speed = self.fly_speed
    attackable.aerial = true

    position.z = self.home_height + math.cos(self.game.frame / 10.0) * 5.0

    if self:has_player_memory() then
        local known_player_dx = self.last_known_px - position.x
        local known_player_dy = self.last_known_py - position.y
        local known_player_dist = math.length(known_player_dx, known_player_dy)
        known_player_dx, known_player_dy = math.normalize_v2(known_player_dx, known_player_dy)

        if not self.is_seeing_player or known_player_dist > self.comfort_dist then
            actor.move_x = known_player_dx
            actor.move_y = known_player_dy
        else
            actor.move_x = -known_player_dx
            actor.move_y = -known_player_dy
        end

        actor.move_x, actor.move_y =
            self:calc_wall_redirect(actor.move_x, actor.move_y)

        if known_player_dist < 1.0 and not self.is_seeing_player then
            self.last_known_px = nil
            self.last_known_py = nil
        end

        if math.abs(known_player_dist - self.comfort_dist) < 32.0 then
            if not self.ready_to_dive then
                self.dive_timer = math.random(80, 150)
            end

            self.ready_to_dive = true
        else
            self.ready_to_dive = false
        end

        if self.ready_to_dive then
            self.dive_timer = self.dive_timer - 1

            if known_player_dist < self.comfort_dist - 16 then
                print("Scary!")
                self.dive_timer = self.dive_timer - 1 
            end

            if self.dive_timer <= 0 then
                print("Dive please")
                self.dive_timer = 0
                self.dive_vx = known_player_dx
                self.dive_vy = known_player_dy
                actor.rigid_velocity = true
                self.dive_progress = 0.0
                self.dive_windup = 30.0
                self.dive_start_z = position.z
                self.mode = "diving"
            end
        end
    else
        actor.move_x = 0.0
        actor.move_y = 0.0
    end

    if not self.is_seeing_player then
        self.ready_to_dive = false
    end
end

---@param x number
---@param r number
---@param s number
---@param e number
local function calc_dive_height_offset(x, r, s, e)
    local fac = (2 * x * r) - r
    return -math.sqrt(r*r - fac * fac) + (e - s) * x + s
end

function Behavior:_diving_mode_update()
    local ent = self.entity

    local actor = ent.actor
    local sprite = ent.sprite
    local position = ent.position
    local attackable = ent.attackable

    actor.rigid_velocity = true

    if attackable.hit then
        self.mode = "flying"
        self.ready_to_dive = false
        actor.rigid_velocity = false
        ent.velocity.x = actor.kb_vx
        ent.velocity.y = actor.kb_vy

        return
    end

    if self.dive_windup > 0 then
        local backup_speed = self.dive_windup / 80.0
        actor.move_speed = self.dive_speed * backup_speed
        actor.move_x = -self.dive_vx
        actor.move_y = -self.dive_vy
        position.z = position.z + backup_speed
        self.dive_start_z = position.z

        self.dive_windup = self.dive_windup - 1
    else
        attackable.aerial = false
        actor.move_speed = self.dive_speed
        actor.move_x = self.dive_vx
        actor.move_y = self.dive_vy

        local dive_height_offset =
            calc_dive_height_offset(self.dive_progress,
                                    self.dive_height,
                                    self.dive_start_z - self.home_height,
                                    0.0)
        position.z = self.home_height + dive_height_offset
        
        self.dive_progress = self.dive_progress + (1.0 / self.dive_length)

        self.game:add_attack({
            x = position.x,
            y = position.y,
            radius = 4,
            damage = 10,
            dx = actor.move_x,
            dy = actor.move_y,
            mask = game_consts.COLGROUP_PLAYER,
            -- mask = require("game.consts").COLGROUP_PLAYER,
            owner = ent
        })

        if self.dive_progress > 1.0 then
            print("done diving")
            self.mode = "flying"
            self.ready_to_dive = false
        end
    end
end

function Behavior:tick()
    local ent = self.entity
    local game = self.game

    local player = game.player
    assert(player and player.position, "can't find player position")

    local actor = ent.actor
    local position = ent.position
    local health = ent.health
    local sprite = ent.sprite

    if ent.attackable.hit then
        if health.value <= 0.0 then
            if self.mode ~= "dead" then
                self.dead_vz = 2.0
                self.mode = "dead"

                if sprite.anim ~= "dead" then
                    sprite:play("dead")
                end
            end
        else
            sprite:play("hurt")
        end
    end

    if health.value <= 0.0 then
        actor.move_x = 0.0
        actor.move_y = 0.0

        self.dead_vz = self.dead_vz - 0.1
        position.z = position.z + self.dead_vz
        if position.z < 0.0 then
            position.z = 0.0
            self.dead_vz = self.dead_vz * -0.3
        end

        ent.attackable.aerial = false
        return
    end

    self.__super.tick(self)

    if not sprite.anim then
        sprite:play("idle")
    end

    if self.mode == "flying" then
        self:_flying_mode_update()
    elseif self.mode == "diving" then
        self:_diving_mode_update()
    else
        error("unknown control mode " .. self.mode)
    end
end

return Behavior