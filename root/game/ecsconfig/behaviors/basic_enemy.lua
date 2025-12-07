---@class game.BasicEnemyBehavior: game.Behavior
local Behavior = batteries.class {
    extends = require("game.ecsconfig.behaviors.base")
}

function Behavior:tick()
    local ent = self.entity
    local game = self.game

    local player = game.player
    assert(player and player.position, "can't find player position")

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

return Behavior