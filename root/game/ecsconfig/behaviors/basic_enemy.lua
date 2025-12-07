local game_consts = require("game.consts")
local bit = require("bit")

---@class game.BasicEnemyBehavior: game.Behavior
local Behavior = batteries.class {
    extends = require("game.ecsconfig.behaviors.base")
}

function Behavior:new()
    self:super()

    ---@type number?
    self.last_known_px = nil

    ---@type number?
    self.last_known_py = nil
end

function Behavior:tick()
    local ent = self.entity
    local game = self.game

    local player = game.player
    assert(player and player.position, "can't find player position")

    local actor = ent.actor
    local position = ent.position
    local health = ent.health

    if health.value <= 0.0 then
        actor.move_x = 0.0
        actor.move_y = 0.0
        return
    end

    local real_player_dx = player.position.x - position.x
    local real_player_dy = player.position.y - position.y
    -- local real_player_dist = math.length(real_player_dx, real_player_dy)
    real_player_dx, real_player_dy = math.normalize_v2(real_player_dx, real_player_dy)

    local _, _, _, raycast_ent =
        game:raycast(position.x, position.y,
                     real_player_dx * 160, real_player_dy * 160,
                     bit.bor(game_consts.COLGROUP_PLAYER, game_consts.COLGROUP_DEFAULT))

    local is_seeing_player = raycast_ent == player
    if is_seeing_player then
        self.last_known_px = player.position.x
        self.last_known_py = player.position.y
    end

    if self.last_known_px then
        local known_player_dx = self.last_known_px - position.x
        local known_player_dy = self.last_known_py - position.y
        local known_player_dist = math.length(known_player_dx, known_player_dy)
        known_player_dx, known_player_dy = math.normalize_v2(known_player_dx, known_player_dy)
        actor.move_x = known_player_dx
        actor.move_y = known_player_dy

        if known_player_dist < 1.0 and not is_seeing_player then
            self.last_known_px = nil
            self.last_known_py = nil
        end

        game:add_attack({
            x = position.x,
            y = position.y,
            radius = 4,
            damage = 10,
            dx = actor.move_x,
            dy = actor.move_y,
            mask = game_consts.COLGROUP_PLAYER,
            -- mask = require("game.consts").COLGROUP_PLAYER,
            owner = ent
        })
    else
        actor.move_x = 0.0
        actor.move_y = 0.0
    end
end

return Behavior