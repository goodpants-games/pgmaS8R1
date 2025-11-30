local Concord = require("concord")

local system = Concord.system({
    pool = {"position", "velocity", "actor"}
})

local function vec_normalize(x, y)
    local d = math.sqrt(x*x + y*y)
    if d == 0 then
        return 0, 0
    end

    return x / d, y / d
end

function system:tick()
    local game = self:getWorld().game

    for _, ent in ipairs(self.pool) do
        local pos = ent.position
        local vel = ent.velocity
        local actor = ent.actor
        
        local move_vec_len = math.sqrt(actor.move_x * actor.move_x +
                                       actor.move_y * actor.move_y)
        if move_vec_len == 0.0 then
            move_vec_len = 1.0
        end

        vel.x = actor.move_x / move_vec_len * actor.move_speed
        vel.y = actor.move_y / move_vec_len * actor.move_speed
    end
end

return system