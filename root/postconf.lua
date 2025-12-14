LOVEJS = love.system.getOS() == "Web"
Lg = love.graphics

if LOVEJS then
    print("html5 canvas format check...")

    local supported_formats = Lg.getCanvasFormats()
    local format_check_list = {
        "rgba8",
        "srgba8",
        "rgba16",
        "rgba16f",
        "rgba32f",

        -- seems to unconditionally be supported, but as it is 16-bit color
        -- the game will look very off. i think.
        "rgba4",
    }

    local use_format
    for _, v in ipairs(format_check_list) do
        if supported_formats[v] then
            use_format = v
            break
        end
    end

    print("using: " .. use_format)

    if use_format == "rgba4" then
        love.window.showMessageBox(
            "Compatibility Warning",
            "The game must be rendered in 16-bit color mode. well, i think it's 16-bit color mode.",
            "warning")
    end

    local orig_newCanvas = love.graphics.newCanvas
    local default_settings = { format = use_format }

    local function fix_settings(s)
        if s == nil then
            s = default_settings
        elseif s.format == "normal" or s.format == nil then
            local old_s = s
            s = {}
            for k,v in pairs(old_s) do
                s[k] = v
            end
            s.format = use_format
        end

        return s
    end

    ---@diagnostic disable-next-line
    function love.graphics.newCanvas(w, h, l, s)
        if w == nil then
            w = love.graphics.getWidth()
        end

        if h == nil then
            h = love.graphics.getHeight()
        end

        if type(l) == "number" then
            return orig_newCanvas(w, h, l, fix_settings(s))
        else
            return orig_newCanvas(w, h, fix_settings(l))
        end
    end
end





require("batteries"):export()
Lg.setDefaultFilter("nearest")

local sceneman = require("sceneman")
sceneman.scenePrefix = "scenes."
sceneman.setCallbackMode("manual")

local tiled = require("tiled")
local tpath = require("tiled.path")
function tiled.mapPath(cwd, path)
    -- change extension from .tsx to .lua
    if tpath.getExtension(path) == ".tsx" then
        path = tpath.join(tpath.getDirName(path),
                          tpath.getNameWithoutExtension(path) .. ".lua")
    end

    return tpath.normalize(tpath.join(cwd, path))
end

---Return the sign of a number, counting zero as positive.
---@param v number
---@return integer sign 1 or -1
function math.binsign(v)
    if v >= 0.0 then
        return 1
    else
        return -1
    end
end

function math.normalize_v2(x, y)
    local len = math.sqrt(x*x + y*y)
    if len > 0 then
        x = x / len
        y = y / len
    end
    return x, y
end

MOUSE_X = 0
MOUSE_Y = 0

Debug = {
    enabled = false,
}

require("dbgdraw")

-- What the fuck.
-- Firefox does not allow LOVE vertex shaders to define varyings because it
-- expects varyings to be declared before the main function. or something.
-- That's fucking insane. well thankfully LOVE exposes the functions which
-- generates raw GLSL shaders to the Lua environment. Yay.......
-- it's actually Lua code, which I can copy and paste here, but I don't want to
-- have all that in this project. I'll just override the function and
-- patch the output.
-- Spent two fukcing hours figuring this out. The error message it gives is very
-- non-descriptive and obtuse.
if LOVEJS then
    local orig_shaderCodeToGLSL = love.graphics._shaderCodeToGLSL

    function love.graphics._shaderCodeToGLSL(gles, arg1, arg2)
        local orig_vertexcode, pixelcode = orig_shaderCodeToGLSL(gles, arg1, arg2)
        local vertexcode = orig_vertexcode
        if orig_vertexcode then
            local vlines = {}
            for line in string.gmatch(orig_vertexcode, "[^\r\n]+") do
                vlines[#vlines+1] = line
            end

            local insertion_index = nil
            local is_user_code = false

            for i=1, #vlines do
                local line = vlines[i]

                if string.match(line, "^%s*varying%s.+;%s*$") then
                    if is_user_code then
                        assert(insertion_index)
                        local l = table.remove(vlines, i)
                        table.insert(vlines, insertion_index, l)
                    elseif not insertion_index then
                        insertion_index = i
                    end
                end

                if not is_user_code and (line == "#line 0" or line == "#line 1") then
                    is_user_code = true
                end
            end

            vertexcode = table.concat(vlines, "\n")
        end
        
	    return vertexcode, pixelcode
    end
end