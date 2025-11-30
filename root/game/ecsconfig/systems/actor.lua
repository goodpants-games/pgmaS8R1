local Concord = require("concord")

local system = Concord.system({
    pool = {"position", "velocity", "actor"}
})

function system:tick()
    local game = self:getWorld().game

    for _, ent in ipairs(self.pool) do
        local pos = ent.position
        local vel = ent.velocity
        local actor = ent.actor

        vel.x = actor.move_x * actor.move_speed
        vel.y = actor.move_y * actor.move_speed
    end
end

return system