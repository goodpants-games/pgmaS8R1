local map_loader = require("game.map_loader")

local scene = require("sceneman").scene()
local self

function scene.load()
    self = {}
    self.tex = map_loader.create_edge_atlas({ "metal", "flesh" })

    Lg.setBackgroundColor(0.5, 0.5, 0.5)
end

function scene.unload()
    self.tex:release()

    self = nil
end

function scene.draw()
    Lg.push()
    Lg.translate(math.round(-MOUSE_X * 3), math.round(-MOUSE_Y * 3))

    for y=0, 31 do
        for x=0, 31 do
            if (x + y) % 2 == 0 then
                Lg.setColor(1, 1, 1)
            else
                Lg.setColor(0.5, 0.5, 0.5)
            end

            Lg.rectangle("fill", x*16, y*16, 16, 16)
        end
    end

    Lg.setColor(1, 1, 1)
    Lg.draw(self.tex)

    Lg.pop()
end

return scene