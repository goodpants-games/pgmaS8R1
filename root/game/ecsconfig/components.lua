local Concord = require("concord")

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
end)

Concord.component("actor", function(cmp)
    cmp.move_x = 0
    cmp.move_y = 0
    cmp.look_angle = 0
    
    -- px/tick
    cmp.move_speed = 2
end)

Concord.component("player_control")

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