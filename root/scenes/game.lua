local scene = require("sceneman").scene()
local Game = require("game")
local GameProgression = require("game.progression")
local Terminal = require("terminal")
local Input = require("input")

local scndat

local function create_actor(x, y)
    local ent = scndat.game:new_entity()
        :give("position", x, y)
        :give("rotation", 0)
        :give("velocity", 0, 0)
        :give("collision", 13, 8)
        :give("actor")
        :give("sprite", "res/robot.png")
        :give("light", "spot")
    
    -- ent.sprite.oy = 9
    ent.sprite.unshaded = true
    ent.light.power = 5.0
    ent.light.linear = 0.007
    ent.light.quadratic = 0.0002
    
    return ent
end

function scene.load()
    scndat = {}
    scndat.game = Game(GameProgression.progression)
    scndat.terminal = Terminal({
        NO_START_COMMAND = true
    })

    scndat.paused = false

    if Debug.enabled then
        -- so i dont go insane lol
        -- i think once i add sounds the droning will be less annoying
        scndat.music = love.audio.newSource("res/cemetery.xm", "stream")
    else
        scndat.music = love.audio.newSource("res/music/drone.wav", "static")
    end

    scndat.music:setVolume(0.2)
    scndat.music:setLooping(true)
    scndat.music:play()

    -- local player = create_actor(100, 100)
    -- player:give("player_control")
    -- scndat.game.cam_follow = player

    -- for i=1, 100 do
    --     create_actor(148 + i, 116 + i)
        
    -- end

    -- playerEnt = ent

    Lg.setBackgroundColor(0, 0, 0)
end

function scene.unload()
    assert(scndat)

    scndat.game:release()
    scndat.music:stop()
    scndat.music:release()
    scndat.terminal:release()

    scndat = nil
end

function scene.update(dt)
    assert(scndat)

    if Input.players[1]:pressed("pause") then
        scndat.paused = not scndat.paused

        love.keyboard.setKeyRepeat(scndat.paused)
        love.keyboard.setTextInput(scndat.paused)
    end

    if not scndat.paused then
        scndat.game:update(dt)
    end
end

function scene.keypressed(k)
    if scndat.paused then
        scndat.terminal:key_pressed(k)
    end
end

function scene.textinput(txt)
    if scndat.paused then
        scndat.terminal:text_input(txt)
    end
end

function scene.draw()
    assert(scndat)

    scndat.game:draw()

    if scndat.paused then
        scndat.terminal:draw(0.8)
    end
end

return scene