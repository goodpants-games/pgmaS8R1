local Concord = require("concord")

local system = Concord.system({
    pool = {"position", "particle"}
})

function system:tick()
    for _, ent in ipairs(self.pool) do
        local position = ent.position
        local particle = ent.particle
        local sprite = ent.sprite
        local velocity = ent.velocity

        particle.vel_z = particle.vel_z + particle.g
        position.z = position.z + particle.vel_z
        if position.z < 0.0 then
            position.z = 0.0
            particle.vel_z = particle.vel_z * -particle.vel_reflect

            velocity.x = velocity.x * particle.damping
            velocity.y = velocity.y * particle.damping
        end

        particle.life = particle.life - 1
        if sprite and particle.life < 60.0 then
            sprite.a = particle.life / 60.0
        end

        if particle.life <= 0 then
            ent:destroy()
        end
    end
end

return system