local sceneman = require("sceneman")
local scene = sceneman.scene()

local Terminal = require("terminal")
local GameProgression = require("game.progression")

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

    local prog = GameProgression.progression
    assert(prog)

    local hearts_destroyed = 0
    for _, room in ipairs(prog.rooms) do
        if room.heart_destroyed then
            hearts_destroyed = hearts_destroyed + 1
        end
    end

    local grade

    if hearts_destroyed == 9 then
        grade = "s"
    elseif hearts_destroyed >= 7 then
        grade = "a"
    elseif hearts_destroyed >= 6 then
        grade = "b"
    elseif hearts_destroyed >= 5 then
        grade = "c"
    elseif hearts_destroyed >= 2 then
        grade = "d"
    else
        grade = "f"
    end

    local music
    do
        local music_grade = grade
        -- Bruh. You're on easy mode. you dont get to hear these sick tunes.
        if prog.difficulty == 1 and grade == "s" then
            music_grade = "a"
        end
        music = love.audio.newSource(("res/music/completion_%s.ogg"):format(music_grade), "stream")
        music:setVolume(0.5)
        music:play()
    end

    printf("MISSION END STATISTICS\n\n")
    coroutine.yield(1.0)

    local diff
    if prog.difficulty == 1 then
        diff = "Easy"
    elseif prog.difficulty == 2 then
        diff = "Normal"
    elseif prog.difficulty == 3 then
        diff = "Hard"
    elseif prog.difficulty == 4 then
        diff = "EVIL"
    end

    printf("Difficulty: %s\n", diff)
    coroutine.yield(1.0)
    printf("Hearts destroyed: %i/%i\n", hearts_destroyed, 9)
    coroutine.yield(1.0)

    -- local destroy_percentage = hearts_destroyed / 9
    local grade_display

    if grade == "s" then
        grade_display = "S !!!"
    elseif grade == "f" then
        grade_display = "F.\nUtter mission failure.\n"
    else
        grade_display = string.upper(grade)
    end

    printf("Grade: %s\n\n", grade_display)

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

    music:stop()
    music:release()

    self.terminal = Terminal()
    self.results = false
    require("game.progression").progression = nil
end

function scene.load()
    Lg.setBackgroundColor(0, 0, 0)
    love.keyboard.setTextInput(true)
    love.keyboard.setKeyRepeat(true)

    local results = false
    if GameProgression.progression then
        results = GameProgression.progression.player_color == 4
    end

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
        self.terminal:text_input(text)
    end
end

function scene.keypressed(key)
    assert(self)
    self.is_key_pressed = true
    if not self.results then
        self.terminal:key_pressed(key)
    end

    if key == "f3" then
        self.terminal:clear(true)
    end

    if key == "f2" then
        Lg.captureScreenshot("screenshot.png")
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