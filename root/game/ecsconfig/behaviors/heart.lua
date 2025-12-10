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
            self.game:destroy_entity(ent)
            return
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