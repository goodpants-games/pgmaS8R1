---@diagnostic disable undefined-global

local function display_help()
    puts
[[Usage: read [OPTION]... [FILE]
Read the FILE in a paginated
display.

  -h, --help    Show this help
                screen.
]]
end

if select("#", ...) == 0 then
    display_help()
    return
end

---@type string?
local file_path
local arg_errors = false

for i=1, select("#", ...) do
    local arg = select(i, ...)

    if arg == "-h" or arg == "--help" then
        display_help()
        return
    elseif arg:sub(1, 1) == "-" then
        print("error: unknown option " .. arg)
        arg_errors = true
    elseif file_path then
        print("error: can only specify one file")
        arg_errors = true
    else
        file_path = arg
    end
end

if arg_errors then
    return
end

local real_file_path = "res/terminal_fs/home/" .. file_path

if not love.filesystem.getInfo(real_file_path) then
    print(("error: file %s does not exist"):format(file_path))
    return
end

---@type string[]
local lines = {}
for line in love.filesystem.lines(real_file_path) do
    while true do
        if line:len() > term.cols then
            local break_pos

            for i=term.cols, 1, -1 do
                if string.byte(line, i) == 32 then
                    break_pos = i
                    break
                end    
            end

            if break_pos then
                table.insert(lines, line:sub(1, break_pos - 1))
                line = line:sub(break_pos + 1)
            else
                table.insert(lines, line:sub(1, term.cols - 1) .. "-")
                line = line:sub(term.cols)
            end
        else
            table.insert(lines, line)
            break
        end
    end
end

for i, v in ipairs(lines) do
    log(i,v)
end

local line_scroll = 1
local function display_text()
    term:clear(true)
    local line = 1
    for i=line_scroll, line_scroll + math.min(term.rows - 1, #lines) - 1 do
        line=line+1
        print(lines[i])
    end

    for i=line, term.rows-1 do
        puts("\n")
    end
    
    puts("Arrow Keys:Scroll          Q:Back")
end

local Input = require("input")
display_text()
while true do
    local ch = get_char()
    if ch == "down" then
        line_scroll = math.max(1, math.min(line_scroll + 1, #lines - term.rows + 2))
        display_text()
    elseif ch == "up" then
        line_scroll = math.max(1, line_scroll - 1)
        display_text()
    elseif ch == "q" then
        term:clear(true)
        break
    end
end