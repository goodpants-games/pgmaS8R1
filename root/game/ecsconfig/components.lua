local Concord = require("concord")
local consts = require("game.consts")
local r3d = require("r3d")

Concord.component("position", function(cmp, x, y, z)
    cmp.x = x or 0
    cmp.y = y or 0
    cmp.z = z or 0
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

    -- collision response info
    cmp.wall_hit_count = 0

    -- collision information for the last handled collision reponse
    cmp.wall_dx = 0
    cmp.wall_dy = 0

    -- well this information only exists for actors to be able to move
    -- perpendicularly to a wall when running towards it, since im too lazy to
    -- make enemy pathfinding. so it's not particularly useful for when there's
    -- multiple collisions happening simultaneously because that would mean that
    -- they are in a corner.
end)

Concord.component("actor", function(cmp)
    cmp.move_x = 0
    cmp.move_y = 0
    
    -- px/tick
    cmp.move_speed = 1.4
    cmp.rigid_velocity = true
    cmp.velocity_damp = 0.9

    cmp.kb_vx = 0.0
    cmp.kb_vy = 0.0
end)

Concord.component("particle", function(cmp, life)
    cmp.life = life or 60
    cmp.vel_reflect = 0.5
    cmp.vel_z = 0.0
    cmp.damping = 0.94
    cmp.g = -0.1
end)

Concord.component("player_control", function(cmp)
    cmp.move_x = 0.0
    cmp.move_y = 0.0
    cmp.aim_x = 1.0
    cmp.aim_y = 0.0
    cmp.run = false
    cmp.lock = false

    cmp.trigger_attack = 0
    cmp.trigger_weapon_switch = false

    cmp.state = "move"
end)

Concord.component("health", function(cmp, max, init)
    cmp.value = max
    cmp.max = init or max
end)

local function sprite_play(cmp, anim_name)
    local spr = cmp._spr --[[@as pklove.Sprite?]]
    if spr then
        spr:play(anim_name)
        cmp.anim = spr.curAnim
        cmp.anim_frame = spr:getAnimFrame()
    else
        -- sprite does not exist yet; need to wait for render system to
        -- create it.
        cmp._cmd = "play"
        cmp._cmd_arg = anim_name
        cmp.anim = anim_name
        cmp.anim_frame = 1
    end
end

local function sprite_stop(cmp)
    local spr = cmp._spr --[[@as pklove.Sprite?]]
    if spr then
        spr:stop()
        cmp.anim = spr.curAnim
        cmp.anim_frame = spr:getAnimFrame()
    else
        -- sprite does not exist yet; need to wait for render system to create
        -- it.
        cmp._cmd = "stop"
        cmp._cmd_arg = nil
        cmp.anim = nil
        cmp.anim_frame = 0
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
    cmp.oz = 0
    
    cmp.unshaded = false
    cmp.anim = nil
    cmp.anim_frame = 0
    cmp.drop_shadow = true
    cmp.visible = true
    cmp.on_floor = false

    cmp.play = sprite_play
    cmp.stop = sprite_stop
end)

Concord.component("r3d_model", function(cmp, model)
    assert(model and model.is and model:is(r3d.model), "must be given an r3d.Model")
    cmp.model = model
    
    cmp.r = 1.0
    cmp.g = 1.0
    cmp.b = 1.0
    cmp.sx = 1.0
    cmp.sy = 1.0
    cmp.sz = 1.0
    cmp.ox = 0.0
    cmp.oy = 0.0
    cmp.oz = 0.0
    cmp.visible = true
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

Concord.component("gun_sight", function(cmp, r, g, b)
    cmp.r = r or 1.0
    cmp.g = g or 0.0
    cmp.b = b or 0.0
    cmp.max_dist = 1000.0
    cmp.visible = true
    cmp.auto_aim = false

    cmp.cur_dx = 0.0
    cmp.cur_dy = 0.0
    cmp.target_zoff = 0.0
end)

Concord.component("behavior", function(cmp, behav_name, ...)
    local behav = require("game.ecsconfig.behaviors." .. behav_name)
    cmp.inst = behav(...)
end)

Concord.component("attackable", function(cmp)
    cmp.hit = nil
    cmp.iframe_length = 20
    cmp.iframes = 0
    cmp.aerial = false
    -- cmp.on_hit = hit_callback
end)

Concord.component("room_transport", function(cmp, dir)
    cmp.dir = dir
end)

Concord.component("heart", function(cmp, color, visible)
    cmp.color = color
    cmp.visible = visible
end)