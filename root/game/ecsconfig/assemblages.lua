local asm = {}
local consts = require("game.consts")
local bit = require("bit")

---@param e any
---@param x number
---@param y number
---@param w number
---@param h number
---@param spr love.Image|string
function asm.actor(e, x, y, w, h, spr)
    e:give("position", x, y)
     :give("rotation", 0)
     :give("velocity", 0, 0)
     :give("collision", w, h)
     :give("actor")
     :give("sprite", spr)
end

asm.entity = {}

function asm.entity.basic_enemy(e, x, y)
    e:assemble(
        asm.actor,
        x, y,
        13, 8,
        "res/robot.png")
    :give("behavior", "basic_enemy")
    :give("attackable")
    :give("health", 30)
    
    e.sprite.oy = 13
    e.collision.group = consts.COLGROUP_ENEMY
    e.actor.move_speed = 0.8
end

function asm.entity.flying_enemy(e, x, y)
    e:assemble(
        asm.actor,
        x, y,
        13, 8,
        "res/sprites/flying_enemy.json")
    :give("behavior", "flying_enemy")
    :give("attackable")
    :give("health", 30)
    
    e.sprite.oy = 13
    e.collision.group = consts.COLGROUP_ENEMY
    e.actor.move_speed = 0.8
    e.attackable.aerial = true
end

function asm.entity.weeping_angel(e, x, y)
    e:assemble(
        asm.actor,
        x, y,
        13, 8,
        "res/robot.png")
    :give("behavior", "weeping_angel")
    :give("attackable")
    :give("health", 300000000)
    
    e.sprite.oy = 13
    e.collision.group = consts.COLGROUP_ENEMY
    e.actor.move_speed = 0.8
end

function asm.entity.player(e, x, y)
    e:assemble(asm.actor,
               x, y,
               13, 8,
               "res/sprites/robot.json")
    e:give("light", "spot")
     :give("health", 150)
     :give("attackable")
     :give("player_control")
     :give("behavior", "player")

    e.sprite.oy = 14
    e.sprite.unshaded = true
    e.sprite:play("idle")
    e.attackable.iframe_length = 60
    
    e.collision.group = consts.COLGROUP_PLAYER
    e.light.power = 5.0
    e.light.linear = 0.007
    e.light.quadratic = 0.0002
end

function asm.entity.heart(e, x, y)
    e:give("position", x, y)
     :give("rotation", 0)
     :give("collision", 24, 24)
     :give("velocity")
     :give("attackable")
     :give("light", "point")
     :give("health", 30)
     :give("behavior", "heart")

    e.collision.group = consts.COLGROUP_ENEMY

    e.light.r = 1
    e.light.g = 0
    e.light.b = 0

    e.light.power = 2.0
    e.light.linear = 0.022
    e.light.quadratic = 0.0019
end

return asm