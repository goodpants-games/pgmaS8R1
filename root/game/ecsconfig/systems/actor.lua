local Concord = require("concord")

local system = Concord.system({
    pool = {"position", "actor"}
})

function system:tick()
    for _, ent in ipairs(self.pool) do
        local pos = ent.position
        local actor = ent.actor

        pos.x = pos.x + actor.move_x * actor.move_speed
        pos.y = pos.y + actor.move_y * actor.move_speed
    end
end

return system