LOVEJS = love.system.getOS() == "Web"

if LOVEJS then
    local orig_newCanvas = love.graphics.newCanvas
    local default_settings = { format = "srgba8" }

    local function fix_settings(s)
        if s == nil then
            s = default_settings
        elseif s.format == "normal" or s.format == nil then
            local old_s = s
            s = {}
            for k,v in pairs(old_s) do
                s[k] = v
            end
            s.format = "srgba8"
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