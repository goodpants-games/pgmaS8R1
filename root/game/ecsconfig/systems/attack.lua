local Concord = require("concord")
local collision = require("game.collision")
local bit = require("bit")

local system = Concord.system({
    pool = {"position", "collision", "attackable"}
})

function system:init(world)
    ---@type Game.Attack[]
    self.attacks = {}
end

function system:tick()
    for _, ent in ipairs(self.pool) do
        local attackable = ent.attackable
        attackable.hit = nil

        if attackable.iframes > 0 then
            attackable.iframes = attackable.iframes - 1
        end
    end

    for _, attack in ipairs(self.attacks) do
        -- Debug.draw:color(1, 0, 0)
        -- Debug.draw:circle_lines(attack.x, attack.y, attack.radius)

        -- TODO: maybe i could do some basic spatial partitioning (like maybe
        --       sweep and prune) but i doubt i'd need it.
        for _, ent in ipairs(self.pool) do
            if attack.owner == ent then
                goto continue
            end

            local ent_col = ent.collision
            if bit.band(ent_col.group, attack.mask) == 0 then
                goto continue
            end

            local ent_pos = ent.position
            local ent_attackable = ent.attackable

            local col = collision.circle_rect_intersection(
                attack.x, attack.y, attack.radius,
                ent_pos.x, ent_pos.y, ent_col.w, ent_col.h)
            
            if col and ent_attackable.iframes == 0 then
                print("attack hit something")
                ent_attackable.hit = attack
                ent_attackable.iframes = ent_attackable.iframe_length

                local ent_health = ent.health
                if ent_health then
                    ent_health.value = math.max(0, ent_health.value - attack.damage)
                end
            end

            ::continue::
        end
    end
    
    self.attacks = {}
end

return system