---@class game.HeartBehavior: game.Behavior
---@overload fun()
local Behavior = batteries.class {
    name = "game.HeartBehavior",
    extends = require("game.ecsconfig.behaviors.base")
}

function Behavior:new()
    self:super()

    self.home_x = 0.0
    self.home_y = 0.0
    self.beat_speed = 1.0
end

function Behavior:init(ent, game)
    self.__super.init(self, ent, game)

    local position = self.entity.position
    self.home_x = position.x
    self.home_y = position.y
end

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
    
    e.particle.vel_z = dz * particle_speed
    e.sprite.sx = 4
    e.sprite.sy = 4
    e.sprite.unshaded = true
    e.sprite.drop_shadow = false

    e.sprite.r = 0.6
    e.sprite.g = 0.0
    e.sprite.b = 0.0

    return e
end

local function rand()
    return love.math.random() * 2.0 - 1.0
end

function Behavior:tick()
    local ent = self.entity
    local model = ent.r3d_model
    local attackable = ent.attackable
    local velocity = ent.velocity
    local position = ent.position
    local health = ent.health

    if attackable.hit then
        self.beat_speed = 2.0
        local attack = attackable.hit --[[@as Game.Attack]]
        velocity.x = attack.dx * 4.0
        velocity.y = attack.dy * 4.0

        if health.value <= 0.0 then
            for i=1, 50 do
                self:_spawn_particle(love.math.random() * math.tau, 1.0 + rand() * 0.2)
            end

            self.game:destroy_entity(ent)
            return
        else
            local ang = math.atan2(attack.dy, attack.dx)
            for i=1, 10 do
                self:_spawn_particle(ang + rand() * 0.9, 1.0 + rand() * 0.2)
            end
        end
    end

    if health.value <= 0.0 then return end

    velocity.x = velocity.x + (self.home_x - position.x) * 0.004 - velocity.x * 0.05
    velocity.y = velocity.y + (self.home_y - position.y) * 0.004 - velocity.y * 0.05

    -- velocity.x = velocity.x * 0.9
    -- velocity.y = velocity.y * 0.9

    local x = self.game.frame / 60 % (1.0 / self.beat_speed) * 30.0

    -- local pulse = -((self.game.frame / 60) % 1.0) + 0.1
    -- pulse = math.clamp(pulse, 0.0, 1.0) / 0.1
    local pulse = 1.065 * (1.0 - math.cos(x)) / (1.3 ^ x)
    -- print(pulse)

    ent.rotation.ang = ent.rotation.ang + 0.05
    model.sx = 16 + pulse * 6.0
    -- model.sy = 16 + pulse * 4.0
    -- model.sz = 16 + pulse * 4.0

    model.r = math.lerp(0.1, 0.7, pulse)
end

return Behavior