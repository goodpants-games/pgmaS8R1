local sceneman = require("sceneman")
local scene = sceneman.scene()

local self

local function newline()
    self.lines[#self.lines+1] = ""
    if #self.lines > self.rows then
        table.remove(self.lines, 1)
    end
end

---@param ... string
local function puts(...)
    assert(self)

    for i=1, select("#", ...) do
        local text = select(i, ...)

        local s = 1
        local full_len = text:len()
        while s <= full_len do
            local li = #self.lines
            local free = self.cols - self.lines[li]:len()

            local e
            local nl = string.find(text, "\n", s, true)
            if nl then
                e = nl - 1
            else
                e = full_len
            end

            if free >= e - s + 1 then
                self.lines[li] = self.lines[li] .. text:sub(s, e)
                s = e + 1
            else
                self.lines[li] = self.lines[li] .. text:sub(s, s + free - 1)
                s = s + free
                newline()
            end

            if text:sub(s,s) == "\n" then
                s=s+1
                newline()
            end
        end
    end

    self.cursor_y = #self.lines
    self.cursor_x = self.lines[self.cursor_y]:len() + 1
    -- print(self.cursor_x, self.cols)
    if self.cursor_x > self.cols then
        -- newline()
        self.cursor_x = 1
        self.cursor_y = self.cursor_y + 1
        if self.cursor_y > self.rows then
            self.cursor_y = self.rows
            newline()
        end
    end
end

local function backspace()
    if not self.lines[1] then return end

    if self.cursor_x == 1 then
        if self.cursor_y == 1 then
            return
        end

        assert(self.cursor_y == #self.lines)
        table.remove(self.lines)
        self.cursor_y = self.cursor_y - 1
        self.cursor_x = #self.lines[self.cursor_y] + 1
    end

    if self.lines[self.cursor_y]:len() > 0 then
        self.lines[self.cursor_y] = self.lines[self.cursor_y]:sub(1, -2)
        self.cursor_x = self.cursor_x - 1
    end
    -- if self.cursor_x < 1 then
    --     self.cursor_y = self.cursor_y - 1
    --     self.cursor_x = #self.lines[self.cursor_y]
    -- end
end

local function resume_process(...)
    self.cur_process_time_accum = nil
    self.cur_process_wait_length = nil

    local s, wait_time = coroutine.resume(self.cur_process, ...)
    if not s then
        local err = wait_time
        error(("%s\n\ntraceback: %s"):format(err, debug.traceback(self.cur_process)))
    end

    if coroutine.status(self.cur_process) == "dead" then
        self.cur_process = nil
        puts(">")
        return
    end

    self.cur_process_time_accum = 0.0
    self.cur_process_wait_length = wait_time or 0.0
end

local function start_process()
    -- TODO: make these process names cooler/less obvious
    puts("Starting kinematics process.")
    for i=1, math.random(4, 8) do
        coroutine.yield(0.5)
        puts(".")
    end
    puts("\n")
    
    puts("Starting auditory process.")
    for i=1, math.random(4, 8) do
        coroutine.yield(0.5)
        puts(".")
    end
    puts("\n")

    puts("Starting optical process.")
    for i=1, math.random(4, 8) do
        coroutine.yield(0.5)
        puts(".")
    end
    puts("\n")

    coroutine.yield()
    puts("Start-up completed successfully!")
    coroutine.yield()

    sceneman.switchScene("game")
end

local function execute_command(cmd)
    local args = {}
    for arg in string.gmatch(cmd, "[^%s]+") do
        table.insert(args, arg)
    end

    if not args[1] then
        return
    end

    if args[1] == "help" then
        puts(
[[
help        Show this help screen.
ls          List contents of the
            directory.
cat <file>  Print a given file to
            the terminal.
start       Start up remaining
            components.
]]
        )
        return
    end

    if args[1] == "start" then
        self.cur_process = coroutine.create(start_process)
        resume_process(self.cur_process)
        return
    end

    if args[1] == "ls" then
        if args[2] == "-a" then
            puts(".ditto        mission.txt\n")
            puts("controls.txt\n")
        else
            puts("mission.txt  controls.txt\n")
        end
        return
    end

    if args[1] == "cat" then
        for i=2, #args do
            local f = args[i]
            if f == "mission.txt" then
                puts("your mission is to destroy all the Things.\n")
            elseif f == "controls.txt" then
                puts("WASD/arrow keys to move, etc.\n")
            elseif f == ".ditto" then
                puts(":3\n")
            end
        end
        return
    end

    puts(args[1], ": command not found\n")
end

function scene.load()
    Lg.setBackgroundColor(0, 0, 0)
    love.keyboard.setTextInput(true)
    love.keyboard.setKeyRepeat(true)

    self = {}
    self.lines = {""}
    self.font = Lg.newFont("res/fonts/DepartureMono-Regular.otf", 11, "none", 1.0)

    local char_width = self.font:getWidth("X")
    local char_height = self.font:getBaseline()

    self.cols = math.floor(DISPLAY_WIDTH / char_width)
    self.rows = math.floor(DISPLAY_HEIGHT / char_height)

    print(self.cols)

    self.cursor_x = 1
    self.cursor_y = 1
    self.text_buffer = ""

    self.cur_process = nil
    self.cur_process_time_accum = nil
    self.cur_process_wait_length = nil

    puts(
[[
Embedded OS for robot guy v43.13.9
Loaded modules:
- Intelligence
- Sentience

Type "help" to get a list of
commands. You may also want to
list the directory.


]])

    puts(">")
end

function scene.unload()
    love.keyboard.setTextInput(false)
    love.keyboard.setKeyRepeat(false)

    self.font:release()
    self = nil
end

function scene.textinput(text)
    local text_start = 1
    while true do
        if text_start > text:len() then
            break
        end

        local text_end = string.find(text, "\n", text_start, true)
        if not text_end then
            text_end = text:len() + 1
        elseif text_end == text_start then
            puts("\n")
            if self.cur_process == nil then
                execute_command(self.text_buffer)
                self.text_buffer = ""
                text_start = text_end + 1

                if not self.cur_process then
                    puts(">")
                end
            end

            goto continue
        end

        local slice = string.sub(text, text_start, text_end - 1)
        self.text_buffer = self.text_buffer .. slice
        puts(slice)

        text_start = text_end
        ::continue::
    end
end

function scene.keypressed(key)
    if key == "v" and love.keyboard.isDown("lctrl", "rctrl") then
        local txt = love.system.getClipboardText()
        if txt then
            scene.textinput(txt)
        end
    end

    if key == "enter" or key == "return" then
        scene.textinput("\n")
    end

    if key == "backspace" then
        if self.text_buffer:len() > 0 then
            backspace()
            self.text_buffer = self.text_buffer:sub(1, -2)
        end
    end
end

function scene.update(dt)
    if self.cur_process_time_accum then
        self.cur_process_time_accum = self.cur_process_time_accum + dt
        if self.cur_process_time_accum >= self.cur_process_wait_length then
            resume_process(self.cur_process_time_accum)
        end
    end
end

function scene.draw()
    Lg.push("all")
    Lg.setFont(self.font)
    Lg.setColor(1, 1, 1)

    local line_height = self.font:getBaseline()
    local char_w = self.font:getWidth("X")
    for i, line in ipairs(self.lines) do
        Lg.print(line, 1, line_height * (i - 1))
    end

    Lg.rectangle("fill", (self.cursor_x - 1) * char_w + 1, (self.cursor_y - 1) * line_height + 1, 1, line_height)

    Lg.pop()
end

return scene