local scene = require("sceneman").scene()
local Game = require("game")

---@type {game:Game, music:love.Source}?
local scndat

local function create_actor(x, y)
    local ent = scndat.game:new_entity()
        :give("position", x, y)
        :give("rotation", 0)
        :give("velocity", 0, 0)
        :give("collision", 13, 8)
        :give("actor")
        :give("sprite", Lg.newImage("res/robot.png"))
    ent.sprite.oy = 9
    
    return ent
end

function scene.load()
    scndat = {}
    scndat.game = Game()
    scndat.music = love.audio.newSource("res/cemetery.xm", "stream")
    scndat.music:setLooping(true)
    scndat.music:play()

    local player = create_actor(100, 100)
    player:give("player_control")
    scndat.game.cam_follow = player

    -- for i=1, 100 do
    --     create_actor(148 + i, 116 + i)
        
    -- end

    -- playerEnt = ent

    Lg.setBackgroundColor(0.5, 0.5, 0.5)
end

function scene.keypressed(key)
    assert(scndat)

    if Debug.enabled then
        if key == "h" then
            local actor = scndat.game.cam_follow
            local e = create_actor(actor.position.x, actor.position.y)
            e.actor.move_x = math.random(-1, 1)
            e.actor.move_y = math.random(-1, 1)
        elseif key == "j" then
            for i=1, 3 do
                local entities = scndat.game.ecs_world:getEntities()
                if #entities > 1 then
                    while true do
                        local ent = entities[math.random(1, #entities)]
                        if ent ~= scndat.game.cam_follow then
                            ent:destroy()
                            break
                        end
                    end
                end
            end
        end
    end
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