local scene = require("sceneman").scene()
local Game = require("game")

---@type {game:Game, music:love.Source}?
local scndat

function scene.load()
    scndat = {}
    scndat.game = Game()
    scndat.music = love.audio.newSource("res/cemetery.xm", "stream")
    scndat.music:setLooping(true)
    scndat.music:play()

    local ent = scndat.game:newEntity()
        :give("position", 100, 100)
        :give("rotation", 0)
        :give("velocity", 0, 0)
        :give("collision", 13, 8)
        :give("player_control")
        :give("actor")
        :give("sprite", Lg.newImage("res/robot.png"))

    ent.sprite.oy = 9
    scndat.game.cam_follow = ent

    -- playerEnt = ent

    Lg.setBackgroundColor(0.5, 0.5, 0.5)
end

function scene.unload()
    assert(scndat)

    scndat.game:release()
    scndat.music:stop()
    scndat.music:release()

    scndat = nil
end

function scene.update(dt)
    assert(scndat)

    scndat.game:update(dt)
end

function scene.draw()
    assert(scndat)

    scndat.game:draw()
end

return scene