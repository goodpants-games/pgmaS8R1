---@diagnostic disable undefined-global

for i=1, select("#", ...) do
    local file_name = select(i, ...)
    local text, err = love.filesystem.read("res/terminal_fs/home/" .. file_name)
    if not text then
        print("could not open file " .. file_name)
        goto continue
    end

    text = text:gsub("\r\n", "\n")
    puts(text)
    if text:sub(-1, -1) ~= "\n" then
        puts("\n")
    end
    
    ::continue::
end