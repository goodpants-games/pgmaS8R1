local game_consts = require("game.consts")

---@class game.HeartBehavior: game.Behavior
---@overload fun()
local Behavior = batteries.class {
    name = "game.HeartBehavior",
    extends = require("game.ecsconfig.behaviors.base")
}

local HEART_COLORS = {
    { batteries.colour.unpack_rgb(0xb20000) },
    { batteries.colour.unpack_rgb(0x04d423) },
    { batteries.colour.unpack_rgb(0x0415cf) },
}

function Behavior:new()
    self:super()

    self.home_x = 0.0
    self.home_y = 0.0
    self.beat_speed = 1.0
    self.last_visible = false
    self.last_pulse_t = 1.0
end

function Behavior:init(ent, game)
    self.__super.init(self, ent, game)

    local position = self.entity.position
    self.home_x = position.x
    self.home_y = position.y

    ent.light.r, ent.light.g, ent.light.b =
        table.unpack3(HEART_COLORS[ent.heart.color])

    self.last_visible = ent.heart.visible
    self:_update_visibility()

    self.heartbeat_sound = self.game:new_sound("heartbeat")
    self.heartbeat_sound.src:setVolume(0.5)
    self.heartbeat_sound:attach_to(self.entity)
end

---@private
---@param ang number
---@param dz number
function Behavior:_spawn_particle(ang, dz)
    local game = self.game
    local position = self.entity.position

    local particle_speed = 1.8

    local dx = math.cos(ang)
    local dy = math.sin(ang)

    -- local dlen = math.sqrt(dx*dx + dy*dy + dz*dz)
    -- dx, dy, dz = dx/dlen, dy/dlen, dz/dlen

    local e = game:new_entity()
        :give("position", position.x, position.y, position.z)
        :give("velocity", particle_speed * dx, particle_speed * dy)
        :give("particle", 180)
        :give("collision", 5, 5)
        :give("sprite", "res/img/white1x1.png")
        :give("behavior", "heart_particle_flash",
              HEART_COLORS[self.entity.heart.color], love.math.random() * 50.0)
    
    e.particle.vel_z = dz * particle_speed
    e.sprite.sx = 4
    e.sprite.sy = 4
    -- e.sprite.unshaded = true
    e.sprite.drop_shadow = false

    e.sprite.r = 1.0
    e.sprite.g = 0.0
    e.sprite.b = 0.0

    return e
end

---@private
function Behavior:_update_visibility()
    local ent = self.entity
    local visible = ent.heart.visible

    ent.light.enabled = visible
    ent.r3d_model.visible = visible

    if visible then
        ent.collision.group = game_consts.COLGROUP_ENEMY

        if not ent:has("attackable") then
            ent:give("attackable")
        end
    else
        ent.collision.group = 0

        if ent:has("attackable") then
            ent:remove("attackable")
        end
    end
end

local function rand()
    return love.math.random() * 2.0 - 1.0
end

function Behavior:tick()
    local ent = self.entity
    local game = self.game

    local model = ent.r3d_model
    local attackable = ent.attackable
    local velocity = ent.velocity
    local position = ent.position
    local health = ent.health

    if ent.heart.visible ~= self.last_visible then
        self:_update_visibility()
        self.last_visible = ent.heart.visible 
    end

    if attackable and attackable.hit then
        local attack = attackable.hit --[[@as Game.Attack]]
        velocity.x = attack.dx * 4.0
        velocity.y = attack.dy * 4.0

        if self.game.player_color ~= ent.heart.color then
            health.value = health.max
            self.game:sound_quick_play("fleshblob_hurt", self.entity)
        else
            self.beat_speed = self.beat_speed * 2.0

            if health.value <= 0.0 then
                for i=1, 50 do
                    self:_spawn_particle(love.math.random() * math.tau, 1.0 + rand() * 0.2)
                end

                -- self.game.room.has_heart = false
                self.game:heart_destroyed()
                self.game:destroy_entity(ent)
                self.game:sound_quick_play("heart_kill", self.entity)
                game.cam_shake = game.cam_shake + 9
                return
            else
                self.game:sound_quick_play("heart_hurt", self.entity)
                game.cam_shake = game.cam_shake + 3
                local ang = math.atan2(attack.dy, attack.dx)
                for i=1, 10 do
                    self:_spawn_particle(ang + rand() * 0.9, 1.0 + rand() * 0.2)
                end
            end
        end
    end

    if health.value <= 0.0 then return end

    velocity.x = velocity.x + (self.home_x - position.x) * 0.004 - velocity.x * 0.05
    velocity.y = velocity.y + (self.home_y - position.y) * 0.004 - velocity.y * 0.05

    -- velocity.x = velocity.x * 0.9
    -- velocity.y = velocity.y * 0.9

    local pulse_t = self.game.frame / 60 % (1.0 / self.beat_speed) * 30.0
    if pulse_t < self.last_pulse_t then
        if ent.heart.visible then
            self.heartbeat_sound.src:seek(0)
            self.heartbeat_sound.src:play()
        end
    end
    self.last_pulse_t = pulse_t

    -- local pulse = -((self.game.frame / 60) % 1.0) + 0.1
    -- pulse = math.clamp(pulse, 0.0, 1.0) / 0.1
    local pulse = 1.065 * (1.0 - math.cos(pulse_t)) / (1.3 ^ pulse_t)
    -- print(pulse)

    ent.rotation.ang = ent.rotation.ang + 0.05
    model.sx = 16 + pulse * 6.0
    -- model.sy = 16 + pulse * 4.0
    -- model.sz = 16 + pulse * 4.0

    local color = HEART_COLORS[ent.heart.color]
    model.r = math.lerp(0.0, color[1], pulse)
    model.g = math.lerp(0.0, color[2], pulse)
    model.b = math.lerp(0.0, color[3], pulse)
end

return Behavior