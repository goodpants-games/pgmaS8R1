local Concord = require("concord")
local consts = require("game.consts")

Concord.component("position", function(cmp, x, y)
    cmp.x = x or 0
    cmp.y = y or 0
end)

Concord.component("rotation", function(cmp, ang)
    cmp.ang = ang or 0
end)

Concord.component("velocity", function(cmp, xv, yv)
    cmp.x = xv or 0
    cmp.y = yv or 0
end)

-- collision hitbox
Concord.component("collision", function(cmp, w, h)
    cmp.w = w
    cmp.h = h
    cmp.group = consts.COLGROUP_DEFAULT
end)

Concord.component("actor", function(cmp)
    cmp.move_x = 0
    cmp.move_y = 0
    cmp.look_angle = 0
    
    -- px/tick
    cmp.move_speed = 1.4

    cmp.kb_vx = 0.0
    cmp.kb_vy = 0.0
end)

Concord.component("player_control")

local function sprite_play(cmp, anim_name)
    local spr = cmp._spr --[[@as pklove.Sprite?]]
    if spr then
        spr:play(anim_name)
        cmp.anim = spr.curAnim
    else
        -- sprite does not exist yet; need to wait for render system to
        -- create it.
        cmp._cmd = "play"
        cmp._cmd_arg = anim_name
        cmp.anim = anim_name
    end
end

local function sprite_stop(cmp)
    local spr = cmp._spr --[[@as pklove.Sprite?]]
    if spr then
        spr:stop()
        cmp.anim = spr.curAnim
    else
        -- sprite does not exist yet; need to wait for render system to create
        -- it.
        cmp._cmd = "stop"
        cmp._cmd_arg = nil
        cmp.anim = nil
    end
end

Concord.component("sprite", function(cmp, img)
    cmp.img = img
    cmp.r = 1
    cmp.g = 1
    cmp.b = 1
    cmp.a = 1
    cmp.sx = 1
    cmp.sy = 1
    cmp.ox = 0
    cmp.oy = 0

    cmp.unshaded = false
    cmp.anim = nil

    cmp.play = sprite_play
    cmp.stop = sprite_stop
end)

Concord.component("light", function(cmp, type)
    cmp.r = 1.0
    cmp.g = 1.0
    cmp.b = 1.0
    cmp.power = 1.0
    cmp.enabled = true
    cmp.type = type

    cmp.constant = 1.0
    cmp.linear = 0.022
    cmp.quadratic = 0.0019

    cmp.spot_angle = math.rad(45)
    cmp.spot_rz = 0.0
    cmp.spot_rx = 0.0

    cmp.z_offset = 8.0
end)

Concord.component("ai")

Concord.component("attackable", function(cmp)
    cmp.hit = nil
    -- cmp.on_hit = hit_callback
end)