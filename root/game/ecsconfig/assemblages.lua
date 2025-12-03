local asm = {}

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

function asm.entity_player(e, x, y)
    e:assemble(asm.actor,
               x, y,
               13, 8,
               "res/robot.png")
    e:give("light", "spot")

    e.light.power = 5.0
    e.light.linear = 0.007
    e.light.quadratic = 0.0002
end

return asm