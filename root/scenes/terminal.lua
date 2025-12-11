local sceneman = require("sceneman")
local scene = sceneman.scene()

local Terminal = require("terminal")

local self

function scene.load()
    Lg.setBackgroundColor(0, 0, 0)
    love.keyboard.setTextInput(true)
    love.keyboard.setKeyRepeat(true)

    self = {}
    self.terminal = Terminal()
end

function scene.unload()
    love.keyboard.setTextInput(false)
    love.keyboard.setKeyRepeat(false)

    self.terminal:release()
    self = nil
end

function scene.textinput(text)
    assert(self)
    self.terminal:text_input(text)
end

function scene.keypressed(key)
    assert(self)
    self.terminal:key_pressed(key)
end

function scene.update(dt)
    assert(self)
    self.terminal:update(dt)
end

function scene.draw()
    assert(self)
    self.terminal:draw()
end

return scene