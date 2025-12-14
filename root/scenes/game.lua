local sceneman = require("sceneman")
local scene = sceneman.scene()

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
    scndat.was_player_dead = false
    scndat.game = Game(GameProgression.progression)
    scndat.terminal = Terminal({
        NO_START_COMMAND = true,
        func_shutdown = function()
            scndat.game:suicide()

            scndat.paused = false
            love.keyboard.setKeyRepeat(false)
            love.keyboard.setTextInput(false)
        end
    }, true)

    scndat.paused = false

    if scndat.game:get_difficulty() == 4 then
        scndat.music = love.audio.newSource("res/music/evildrone.ogg", "stream")
    else
        scndat.music = love.audio.newSource("res/music/drone.wav", "static")
    end

    scndat.music:setVolume(0.5)
    scndat.music:setLooping(true)
    scndat.music:play()

    scndat.img_sad_bot = Lg.newImage("res/img/sad_bot.png")

    scndat.canvas = Lg.newCanvas(DISPLAY_WIDTH, DISPLAY_HEIGHT, { dpiscale = 1.0 })
    scndat.death_timer = 0.0
    scndat.need_frame_capture = false

    ---@type love.ImageData?
    scndat.frame_capture = nil

    ---@type love.Image?
    scndat.frame_capture_tex = nil

    scndat.image_scramble_i = 0
    scndat.image_scramble_pasted = false

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
    scndat.canvas:release()
    scndat.img_sad_bot:release()

    if scndat.frame_capture then
        scndat.frame_capture:release()
    end

    if scndat.frame_capture_tex then
        scndat.frame_capture_tex:release()
    end

    scndat = nil
end

---@param t number
local function death_timer_stage(t)
    if t >= 7.0 then
        return "done"
    end

    if t >= 2.0 then
        return "screen_melt"
    end
end

local function update_screen_melt()
    local img = scndat.frame_capture
    assert(img)

    local rand = love.math.random

    local img_width = img:getWidth()
    local img_height = img:getHeight()
    local img_pset = img.setPixel
    local img_gset = img.getPixel

    local t = math.clamp01((scndat.death_timer - 2.0) / 2.0)
    local power = math.round(t * t * 7.0)

    local s = scndat.image_scramble_i
    for y=s+1, img_height-1, 14 do
        for x=1, img_width-1, 1 do
            local new_x = x + rand(-power, power)
            local new_y = y + rand(-power, power)
            if new_x < 0 then new_x = 0 end
            if new_y < 0 then new_y = 0 end
            if new_x >= img_width then new_x = img_width-1 end
            if new_y >= img_height then new_y = img_height-1 end
            
            local r, g, b, a = img_gset(img, new_x, new_y)
            r = r * 1.05
            g = g * 1.05
            b = b * 1.05

            img_pset(img, x, y, r, g, b, a)
        end
    end

    scndat.image_scramble_i = (s + 1) % 14
    -- for _=1, 20 do
    --     local x = rand(0, img:getWidth() - 1)
    --     for y=img:getHeight() - 1, 2, -1 do
    --         local src_x = rand(0, img:getWidth() - 1)
    --         local src_y = rand(0, img:getHeight() - 1)

    --         img:setPixel(x, y, img:getPixel(src_x, src_y))
    --     end
    -- end

    if not scndat.image_scramble_pasted and scndat.death_timer >= 3.9 then
        scndat.image_scramble_pasted = true

        local simg = love.image.newImageData("res/img/system_shutdown_imminent.png")
        local simg_width = simg:getWidth()
        local simg_height = simg:getHeight()
        assert(img_width >= simg_width and img_height >= simg_height)

        for y=1, img_height-1 do
            for x=1, img_width-1 do
                local r, g, b, a = img_gset(simg, x, y)
                if a > 0.0 then
                    img_pset(img, x, y, r, g, b, a)
                end
            end
        end

        simg:release()
    end

    if scndat.frame_capture_tex then
        scndat.frame_capture_tex:replacePixels(scndat.frame_capture)
    else
        scndat.frame_capture_tex = Lg.newImage(scndat.frame_capture)
    end
end

function scene.update(dt)
    assert(scndat)

    if scndat.game.player_is_dead then
        local old_stage = death_timer_stage(scndat.death_timer)
        scndat.death_timer = scndat.death_timer + dt

        local new_stage = death_timer_stage(scndat.death_timer)
        if new_stage ~= old_stage then
            if new_stage == "screen_melt" then
                scndat.need_frame_capture = true
            end

            if new_stage == "done" then
                GameProgression.progression = scndat.game:get_new_progression()
                love.audio.stop()
                sceneman.switchScene("terminal")
            end
        end

        if not scndat.was_player_dead then
            love.keyboard.setKeyRepeat(false)
            love.keyboard.setTextInput(false)
            scndat.paused = true
            scndat.death_timer = 0.0
        end
    end

    scndat.was_player_dead = scndat.game.player_is_dead

    if Input.players[1]:pressed("pause") and not scndat.game.player_is_dead then
        scndat.paused = not scndat.paused

        love.keyboard.setKeyRepeat(scndat.paused)
        love.keyboard.setTextInput(scndat.paused)
    end

    if not scndat.paused then
        scndat.game:update(dt)
    end

    if scndat.frame_capture then
        update_screen_melt()
    end
end

function scene.keypressed(k)
    if scndat.paused and not scndat.game.player_is_dead then
        scndat.terminal:key_pressed(k)
    end
end

function scene.textinput(txt)
    if scndat.paused and not scndat.game.player_is_dead then
        scndat.terminal:text_input(txt)
    end
end

function scene.draw()
    assert(scndat)

    if scndat.was_player_dead then
        if scndat.frame_capture_tex then
            Lg.setColor(1, 1, 1)
            Lg.draw(scndat.frame_capture_tex)
        else
            local old_canvas = Lg.getCanvas()
            Lg.setCanvas({ scndat.canvas, depth = true })
            Lg.clear(Lg.getBackgroundColor())
            scndat.game:draw()
            Lg.setColor(1, 1, 1)
            Lg.draw(scndat.img_sad_bot,
                    (DISPLAY_WIDTH - scndat.img_sad_bot:getWidth()) / 2,
                    (DISPLAY_HEIGHT - scndat.img_sad_bot:getHeight()) / 2)
            Lg.setCanvas(old_canvas)

            if scndat.need_frame_capture then
                print("captured frame")
                scndat.need_frame_capture = false
                scndat.frame_capture = scndat.canvas:newImageData()

                if scndat.canvas:getFormat() == "srgba8" then
                    local img = scndat.frame_capture --[[@as love.ImageData]]
                    local imgh = img:getHeight()
                    local imgw = img:getWidth()
                    local gp = img.getPixel
                    local sp = img.setPixel
                    local gtol = love.math.gammaToLinear

                    for y=0, imgh-1 do
                        for x=0, imgw-1 do
                            local r, g, b, a = gp(img, x, y)
                            local lr, lg, lb = gtol(r, g, b)
                            sp(img, x, y, lr, lg, lb, a)
                        end
                    end
                end
            end

            Lg.setColor(1, 1, 1)
            Lg.draw(scndat.canvas, 0, 0)
        end
    else
        scndat.game:draw()
    end

    if scndat.paused and not scndat.game.player_is_dead then
        scndat.terminal:draw(0.8)
    end
end

return scene