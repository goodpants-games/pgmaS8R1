require("postconf")

local Input = require("input")
local sceneman = require("sceneman")

local display_canvas = Lg.newCanvas(DISPLAY_WIDTH, DISPLAY_HEIGHT, { dpiscale = 1.0 })

local display_ox = 0.0
local display_oy = 0.0
local display_scale = 1.0

local font = Lg.newFont("res/fonts/ProggyClean.ttf", 16, "none", 1.0)

function love.load(args)
    for _, arg in ipairs(args) do
        if arg == "--debug" then
            Debug.enabled = true
            print("enable debug")
        end
    end

    sceneman.switchScene("voxel_map_view")
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

function love.keypressed(key)
    if key == "escape" then
        sceneman.switchScene("game")
    else
        sceneman.dispatch("keypressed", key)
    end
end

local function update_display_fit()
    display_scale = math.min(Lg.getHeight() / DISPLAY_HEIGHT, Lg.getWidth() / DISPLAY_WIDTH)
    display_scale = math.max(1, display_scale)
    -- display_scale = math.floor(display_scale)
    display_ox = (Lg.getWidth() - DISPLAY_WIDTH * display_scale) / 2
    display_oy = (Lg.getHeight() - DISPLAY_HEIGHT * display_scale) / 2
    display_ox = math.floor(display_ox)
    display_oy = math.floor(display_oy)
    -- print(display_ox, display_oy, display_scale)
end

function love.update(dt)
    batteries.manual_gc(3e-3)
    Debug.draw.enabled = Debug.enabled

    update_display_fit()
    MOUSE_X = (love.mouse.getX() - display_ox) / display_scale
    MOUSE_Y = (love.mouse.getY() - display_oy) / display_scale
    
    Input.update()
    sceneman.update(dt)
end

function love.draw()
    Lg.setCanvas({ display_canvas, depth = true })
    local bg_r, bg_g, bg_b, bg_a = Lg.getBackgroundColor()
    Lg.clear(bg_r, bg_g, bg_b, bg_a, false, 1.0)
    Lg.setFont(font)

    sceneman.draw()
    Debug.draw:flush()

    -- debug text
    Lg.setColor(1, 1, 1)
    Lg.print(("%.1f Kb"):format(collectgarbage("count")), 10, 10)

    -- draw display onto window
    Lg.setCanvas()
    Lg.clear(0, 0, 0, 1)
    Lg.origin()
    Lg.draw(display_canvas, display_ox, display_oy, 0, display_scale, display_scale)
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