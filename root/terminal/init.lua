---@class Terminal
---@overload fun(process_env:table?, no_startup_msg:boolean?):Terminal
local Terminal = batteries.class {
    name = "Terminal"
}

---@param process_env table?
---@param no_startup_msg boolean?
function Terminal:new(process_env, no_startup_msg)
    self.lines = {""}
    self.font = Lg.newFont("res/fonts/DepartureMono-Regular.otf", 11, "none", 1.0)

    local char_width = self.font:getWidth("X")
    local char_height = self.font:getBaseline()

    self.cols = math.floor(DISPLAY_WIDTH / char_width)
    self.rows = math.floor(DISPLAY_HEIGHT / char_height)

    self.cursor_x = 1
    self.cursor_y = 1
    self.text_buffer = ""

    self.cur_process = nil
    self.cur_process_time_accum = nil
    self.cur_process_wait_length = nil
    self.cur_process_wait_for_char = false

    ---@type table
    self.process_env = nil

    if process_env then
        self.process_env = table.copy(process_env)
    else
        self.process_env = {}
    end

    for k,v in pairs(_G) do
        self.process_env[k] = v
    end
    
    self.process_env.puts = function(...) self:puts(...) end
    self.process_env.print = function(...) self:print(...) end
    self.process_env.get_char = function() return coroutine.yield("CHAR") end
    self.process_env.wait = function(sec) return coroutine.yield(sec) end
    self.process_env.log = print
    self.process_env.term = self

    if not no_startup_msg then
        local startup_msg =
[[
Unit ID: M016.52.%i
Loaded modules:
- Intelligence

]]
        self:puts(startup_msg:format(require("game.progression").progression.player_color + 18))
    end

    self:puts[[Type "help" to get a list of
commands.


]]
    self:puts(">")
end

function Terminal:release()
    if self.font then
        self.font:release()
        self.font = nil
    end
end

---@private
function Terminal:_newline()
    self.lines[#self.lines+1] = ""
    if #self.lines > self.rows then
        table.remove(self.lines, 1)
    end
end

---@param ... string
function Terminal:puts(...)
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
                self:_newline()
            end

            if text:sub(s,s) == "\n" then
                s=s+1
                self:_newline()
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
            self:_newline()
        end
    end
end

---@param ... any
function Terminal:print(...)
    for i=1, select("#", ...) do
        if i > 1 then
            self:puts("    ")
        end

        local str = tostring(select(i, ...))
        self:puts(str)
    end

    self:puts("\n")
end

function Terminal:backspace()
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

---@param no_prompt_string boolean?
function Terminal:clear(no_prompt_string)
    self.lines = {""}
    self.cursor_x = 1
    self.cursor_y = 1

    if not no_prompt_string then
        self:puts(">")
    end
end

---@private
---@param ... any
function Terminal:_resume_process(...)
    self.cur_process_time_accum = nil
    self.cur_process_wait_length = nil
    self.cur_process_wait_for_char = false

    local s, wait_time = coroutine.resume(self.cur_process, ...)
    if not s then
        local err = wait_time
        self:puts("PROGRAM ENCOUNTERED AN ERROR. THIS IS NOT SUPPOSED TO HAPPEN. REALLY. SEE GAME'S STDOUT.")
        print(("%s\n\ntraceback: %s"):format(err, debug.traceback(self.cur_process)))
    end

    if coroutine.status(self.cur_process) == "dead" then
        self.cur_process = nil
        self:puts(">")
        return
    end

    if wait_time == "CHAR" then
        self.cur_process_wait_for_char = true
    else
        self.cur_process_time_accum = 0.0
        self.cur_process_wait_length = wait_time or 0.0
    end
end

---@return boolean
function Terminal:is_process_running()
    return self.cur_process ~= nil
end

---@param proc function
---@param ... any
function Terminal:execute_process(proc, ...)
    self.cur_process = coroutine.create(proc)
    self:_resume_process(...)
end

---@param cmd string
function Terminal:execute_command(cmd)
    local args = {}
    for arg in string.gmatch(cmd, "[^%s]+") do
        table.insert(args, arg)
    end

    if not args[1] then
        self:puts(">")
        return
    end

    if args[1] == "clear" then
        self:clear()
        return
    end

    local exec_file_name = ("res/terminal_fs/bin/%s.lua"):format(args[1])
    if not love.filesystem.getInfo(exec_file_name) then
        self:puts(args[1], ": command not found\n")
        self:puts(">")
        return
    end

    local chunk, err = love.filesystem.load(exec_file_name)
    if not chunk then
        self:puts("ERROR LOADING ", args[1], ". THIS ERROR IS NOT SUPPOSED TO HAPPEN. REALLY.\n")
        self:puts(err, "\n")
        return
    end

    setfenv(chunk, self.process_env)

    self.cur_process = coroutine.create(chunk)
    self:_resume_process(unpack(args, 2))
end

---@param text string
function Terminal:text_input(text)
    if self.cur_process_wait_for_char then
        local ti = 1
        local strlen = text:len()
        while ti <= strlen and self.cur_process_wait_for_char do
            self:_resume_process(text:sub(ti, ti))
            ti=ti+1
        end
        return
    end

    local text_start = 1
    while true do
        if text_start > text:len() then
            break
        end

        local text_end = string.find(text, "\n", text_start, true)
        if not text_end then
            text_end = text:len() + 1
        elseif text_end == text_start then
            self:puts("\n")
            if self.cur_process == nil then
                self:execute_command(self.text_buffer)
                self.text_buffer = ""
            end
            
            text_start = text_end + 1
            goto continue
        end

        local slice = string.sub(text, text_start, text_end - 1)
        self.text_buffer = self.text_buffer .. slice
        self:puts(slice)

        text_start = text_end
        ::continue::
    end
end

---@param key love.KeyConstant
function Terminal:key_pressed(key)
    if key == "v" and love.keyboard.isDown("lctrl", "rctrl") then
        local txt = love.system.getClipboardText()
        if txt then
            self:text_input(txt)
        end
        return
    end

    if key == "enter" or key == "return" then
        if self.cur_process_wait_for_char then
            self:_resume_process("\n")
        else
            self:text_input("\n")
        end

        return
    end

    if key == "backspace" then
        if self.cur_process_wait_for_char then
            self:_resume_process("backspace")
        elseif self.text_buffer:len() > 0 then
            self:backspace()
            self.text_buffer = self.text_buffer:sub(1, -2)
        end

        return
    end

    if LOVEJS and key == "space" then
        self:text_input(" ")
        return
    end

    if self.cur_process_wait_for_char then
        if key == "left" or key == "right" or key == "up" or key == "down" then
            self:_resume_process(key)
        end
    end
end

---@param dt number
function Terminal:update(dt)
    if self.cur_process_time_accum then
        self.cur_process_time_accum = self.cur_process_time_accum + dt
        if self.cur_process_time_accum >= self.cur_process_wait_length then
            self:_resume_process(self.cur_process_time_accum)
        end
    end
end

---@param bg_opacity number?
function Terminal:draw(bg_opacity)
    Lg.push("all")

    Lg.setColor(0, 0, 0, bg_opacity or 1.0)
    Lg.rectangle("fill", 0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT)
    
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

return Terminal