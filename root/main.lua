require("envsetup")

local Point = require("game.testclass")
local p = Point(50, 50)

local music = love.audio.newSource("res/safety.xm", "stream")
music:play()

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

    p.x = love.mouse.getX()
    p.y = love.mouse.getY()
end

function love.draw()
    local t = {"foo", "bar", "baz", "world!"}
    local f = table.index_of(t, "world!")

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(("Hello, %s (%i)"):format(t[f], f), 10, 10)
    love.graphics.print(("%.1f Kb"):format(collectgarbage("count")), 10, 20)
    love.graphics.print(("%.3f"):format(p:length()), 10, 30)

    love.graphics.setColor(1, 0, 0)
    love.graphics.circle("fill", p.x, p.y, 4)
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