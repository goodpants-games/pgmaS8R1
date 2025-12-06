local Concord = require("concord")

local system = Concord.system({
    pool = {"position", "actor", "ai"}
})

function system:tick()
    ---@type Game
    local game = self:getWorld().game
    local player = game.player
    assert(player and player.position, "can't find player position")

    for _, ent in ipairs(self.pool) do
        local actor = ent.actor
        local position = ent.position

        local dx = player.position.x - position.x
        local dy = player.position.y - position.y
        dx, dy = math.normalize_v2(dx, dy)

        actor.move_x = dx
        actor.move_y = dy

        game:add_attack({
            x = position.x,
            y = position.y,
            radius = 4,
            damage = 10,
            dx = dx,
            dy = dy,
            -- mask = require("game.consts").COLGROUP_PLAYER,
            owner = ent
        })
    end
end

return system