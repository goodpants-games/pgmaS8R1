local game_consts = require("game.consts")
local bit = require("bit")

---@class game.BasicEnemyBehavior: game.EnemyBehaviorBase
local Behavior = batteries.class {
    extends = require("game.ecsconfig.behaviors.base_enemy")
}

function Behavior:new()
    self:super()
end

function Behavior:tick()
    local ent = self.entity
    local game = self.game

    local player = game.player
    assert(player and player.position, "can't find player position")

    local actor = ent.actor
    local position = ent.position
    local health = ent.health
    local sprite = ent.sprite

    if ent.attackable.hit then
        if health.value <= 0.0 then
            game:sound_quick_play("fleshblob_kill", ent)
        else
            game:sound_quick_play("fleshblob_hurt", ent)
        end
    end

    if health.value <= 0.0 then
        actor.move_x = 0.0
        actor.move_y = 0.0

        if sprite.anim ~= "dead" then
            sprite:play("dead")
        end

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
        
        if sprite.anim ~= "walk" then
            sprite:play("walk")
        end

        if known_player_dist < 1.0 and not self.is_seeing_player then
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

        if sprite.anim ~= "idle" then
            sprite:play("idle")
        end
    end
end

return Behavior