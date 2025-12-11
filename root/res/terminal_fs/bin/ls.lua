local args = {...}
local show_all = false

for _, arg in ipairs(args) do
    if arg == "-a" or arg == "-all" then
        show_all = true
    end
end

local files = love.filesystem.getDirectoryItems("res/terminal_fs/home")
table.sort(files)

for _, f in ipairs(files) do
    if show_all or f:sub(1, 1) ~= "." then
        print(f)
    end
end