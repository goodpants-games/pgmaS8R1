local sceneman = require("sceneman")
local scene = sceneman.scene()

local Terminal = require("terminal")

local self

---@param term Terminal
local function results_proc(term)
    local function printf(fmt, ...)
        local str = string.format(fmt, ...)
        for i=1, string.len(str) do
            local ch = str:sub(i, i)
            term:puts(ch)
            coroutine.yield(0.04)
        end
    end

    printf("MISSION END STATISTICS\n\n")
    coroutine.yield(1.0)

    local prog = require("game.progression").progression
    assert(prog)

    local hearts_destroyed = 0
    for _, room in ipairs(prog.rooms) do
        if room.heart_destroyed then
            hearts_destroyed = hearts_destroyed + 1
        end
    end

    printf("Hearts destroyed: %i/%i\n", hearts_destroyed, 9)
    coroutine.yield(1.0)

    -- local destroy_percentage = hearts_destroyed / 9
    local grade

    if hearts_destroyed == 9 then
        grade = "S !!!"
    elseif hearts_destroyed >= 7 then
        grade = "A"
    elseif hearts_destroyed >= 5 then
        grade = "B"
    elseif hearts_destroyed >= 4 then
        grade = "C"
    elseif hearts_destroyed >= 2 then
        grade = "D"
    else
        grade = "F.\nUtter mission failure.\n"
    end

    printf("Grade: %s\n\n", grade)

    coroutine.yield(1.0)

    if hearts_destroyed == 0 then
        printf("\n\nUtter...")
        coroutine.yield(4.0)
        printf("Moo...")
        coroutine.yield(5.0)
    end
    printf("\n\nmade by pkhead\n")
    coroutine.yield(1.0)
    printf("thanks for playing my game!\n")
    coroutine.yield(2.0)

    term:puts("\n\nPress any key to continue...")
    self.is_key_pressed = false
    while not self.is_key_pressed do
        coroutine.yield(0.1)
    end

    print("Key is pressed")

    self.terminal = Terminal()
    self.results = false
    require("game.progression").reset_progression()
end

function scene.load()
    Lg.setBackgroundColor(0, 0, 0)
    love.keyboard.setTextInput(true)
    love.keyboard.setKeyRepeat(true)

    local results = require("game.progression").progression.player_color == 4

    self = {}
    self.terminal = Terminal()
    self.results = results

    if self.results then
        self.terminal:clear(true)
        self.terminal:execute_process(results_proc, self.terminal)
    end
end

function scene.unload()
    love.keyboard.setTextInput(false)
    love.keyboard.setKeyRepeat(false)

    self.terminal:release()
    self = nil
end

function scene.textinput(text)
    assert(self)
    if not self.results then
        print("send text input")
        self.terminal:text_input(text)
    end
end

function scene.keypressed(key)
    assert(self)
    self.is_key_pressed = true
    if not self.results then
        print("send key press")
        self.terminal:key_pressed(key)
    end
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