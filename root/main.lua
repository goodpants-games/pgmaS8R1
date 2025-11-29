require("envsetup")
Lg.setDefaultFilter("nearest")

local Game = require("game")
local Input = require("input")

DISPLAY_WIDTH = 240
DISPLAY_HEIGHT = 180
MOUSE_X = 0
MOUSE_Y = 0
local display_canvas = Lg.newCanvas(DISPLAY_WIDTH, DISPLAY_HEIGHT)

local font = Lg.newFont("res/fonts/ProggyClean.ttf", 16)

love.audio.newSource("res/safety.xm", "stream"):play()
local game = Game()
local playerEnt

function love.load()
    local ent = game:newEntity()
        :give("position", 100, 100)
        :give("rotation", 0)
        :give("sprite", Lg.newImage("res/swatPixelart.png"))

    ent.sprite.sx = 1
    ent.sprite.sy = 1

    playerEnt = ent

    Lg.setBackgroundColor(0.5, 0.5, 0.5)
end

local _paused_sources
function love.visible(visible)
    if visible then
        if _paused_sources then
            love.audio.play(_paused_sources)
        end
    else
        _paused_sources = love.audio.pause()
    end
end

function love.update(dt)
    batteries.manual_gc(3e-3)
    Input.update()

    MOUSE_X = love.mouse.getX() / Lg.getWidth() * DISPLAY_WIDTH
    MOUSE_Y = love.mouse.getY() / Lg.getHeight() * DISPLAY_HEIGHT

    game:update(dt)

    playerEnt.position.x = MOUSE_X
    playerEnt.position.y = MOUSE_Y
end

function love.draw()
    Lg.setCanvas(display_canvas)
    Lg.clear()
    Lg.setFont(font)

    game:draw()
    Lg.setColor(1, 1, 1)
    Lg.print(("%.1f Kb"):format(collectgarbage("count")), 10, 10)

    Lg.setCanvas()

    Lg.origin()
    Lg.draw(display_canvas, 0, 0, 0,
            Lg.getWidth() / display_canvas:getWidth(),
            Lg.getHeight() / display_canvas:getHeight())
end

function love.run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local dt = 0

	-- Main loop time.
	return function()
        assert(love.event)
        assert(love.window)

		-- Process events.
		if love.event then
			love.event.pump()
			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a or 0
					end
				end
				love.handlers[name](a,b,c,d,e,f)
			end
		end

		-- Update dt, as we'll be passing it to update
		if love.timer then dt = love.timer.step() end

        if not LOVEJS or love.window.isVisible() then
            -- Call update and draw
            if love.update then love.update(dt) end -- will pass 0 if love.timer is disabled

            if love.graphics and love.graphics.isActive() then
                love.graphics.origin()
                love.graphics.clear(love.graphics.getBackgroundColor())

                if love.draw then love.draw() end

                love.graphics.present()
            end
        end

		if not LOVEJS and love.timer then love.timer.sleep(0.001) end
	end
end