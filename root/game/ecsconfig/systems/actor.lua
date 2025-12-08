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
        local attackable = ent.attackable
        local sprite = ent.sprite
        
        local move_vec_len = math.sqrt(actor.move_x * actor.move_x +
                                       actor.move_y * actor.move_y)
        if move_vec_len == 0.0 then
            move_vec_len = 1.0
        end

        if actor.rigid_velocity then
            vel.x = actor.move_x / move_vec_len * actor.move_speed
            vel.y = actor.move_y / move_vec_len * actor.move_speed
            vel.x = vel.x + actor.kb_vx
            vel.y = vel.y + actor.kb_vy
            actor.kb_vx = actor.kb_vx * 0.9
            actor.kb_vy = actor.kb_vy * 0.9
        else
            actor.kb_vx = 0.0
            actor.kb_vy = 0.0

            vel.x = vel.x + actor.move_x / move_vec_len * actor.move_speed
            vel.y = vel.y + actor.move_y / move_vec_len * actor.move_speed
            vel.x = vel.x * actor.velocity_damp
            vel.y = vel.y * actor.velocity_damp
        end

        if attackable and attackable.hit then
            local attack = attackable.hit --[[@as Game.Attack]]

            if actor.rigid_velocity then
                actor.kb_vx = attack.dx * attack.knockback
                actor.kb_vy = attack.dy * attack.knockback
            else
                vel.x = attack.dx * attack.knockback
                vel.y = attack.dy * attack.knockback
            end
        end

        -- if sprite then
        --     local ang = math.normalise_angle(actor.look_angle)
        --     if math.abs(ang) > math.pi / 2.0 then
        --         sprite.sx = -1.0
        --     else
        --         sprite.sx = 1.0
        --     end
        -- end
    end
end

return system