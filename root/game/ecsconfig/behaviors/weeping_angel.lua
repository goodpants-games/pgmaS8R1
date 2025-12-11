local game_consts = require("game.consts")
local bit = require("bit")

---@class game.WeepingAngelEnemyBehavior: game.EnemyBehaviorBase
local Behavior = batteries.class {
    extends = require("game.ecsconfig.behaviors.base_enemy")
}

function Behavior:new()
    self:super()

    self.aggro_buffer = 0
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

    self.__super.tick(self)

    if self:has_player_memory() then
        local known_player_dx = self.last_known_px - position.x
        local known_player_dy = self.last_known_py - position.y
        local known_player_dist = math.length(known_player_dx, known_player_dy)
        known_player_dx, known_player_dy = math.normalize_v2(known_player_dx, known_player_dy)
        actor.move_x = known_player_dx
        actor.move_y = known_player_dy
    
        actor.move_x, actor.move_y =
            self:calc_wall_redirect(actor.move_x, actor.move_y)
        
        local real_player_dx = player.position.x - position.x
        local real_player_dy = player.position.y - position.y

        local ang_to_player = math.atan2(real_player_dy, real_player_dx)
        local ang_diff = math.angle_difference(game.player.rotation.ang, ang_to_player + math.pi)

        local is_seen = math.abs(ang_diff) < math.rad(70) and known_player_dist > 2.0

        if is_seen then
            actor.move_x = 0.0
            actor.move_y = 0.0
            self.aggro_buffer = 10
        end

        if known_player_dist < 1.0 and not self.is_seeing_player then
            self.last_known_px = nil
            self.last_known_py = nil
        end

        if self.is_seeing_player and known_player_dist < 3.0 and not is_seen then
            if self.aggro_buffer > 0 then
                self.aggro_buffer = self.aggro_buffer - 1
            else
                game:add_attack({
                    x = position.x,
                    y = position.y,
                    radius = 5,
                    damage = 20,
                    dx = actor.move_x,
                    dy = actor.move_y,
                    mask = game_consts.COLGROUP_PLAYER,
                    -- mask = require("game.consts").COLGROUP_PLAYER,
                    owner = ent
                })
            end
        end
    else
        actor.move_x = 0.0
        actor.move_y = 0.0
    end
end

return Behavior