local game_consts = require("game.consts")
local bit = require("bit")

---@class game.EnemyBehaviorBase: game.Behavior
local Behavior = batteries.class {
    extends = require("game.ecsconfig.behaviors.base")
}

function Behavior:new()
    self:super()

    ---@type number?
    self.last_known_px = nil

    ---@type number?
    self.last_known_py = nil

    self.is_seeing_player = false
end

function Behavior:has_player_memory()
    return self.last_known_px ~= nil
end

function Behavior:tick()
    local ent = self.entity
    local game = self.game

    local player = game.player
    assert(player and player.position, "can't find player position")

    local actor = ent.actor
    local position = ent.position

    local real_player_dx = player.position.x - position.x
    local real_player_dy = player.position.y - position.y
    -- local real_player_dist = math.length(real_player_dx, real_player_dy)
    real_player_dx, real_player_dy = math.normalize_v2(real_player_dx, real_player_dy)

    local _, _, _, raycast_ent =
        game.room:raycast(position.x, position.y,
                          real_player_dx * 160, real_player_dy * 160,
                          bit.bor(game_consts.COLGROUP_PLAYER, game_consts.COLGROUP_DEFAULT))

    self.is_seeing_player = raycast_ent == player
    if self.is_seeing_player then
        self.last_known_px = player.position.x
        self.last_known_py = player.position.y
    end
end

return Behavior