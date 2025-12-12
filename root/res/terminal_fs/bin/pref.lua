---@diagnostic disable undefined-global
local arg_option, arg_value = ...

local function display_help()
    puts
[[Usage: pref OPTION [VALUE]
       pref -h|--help
Sets the OPTION setting to VALUE.
If VALUE is not given, it will
instead print the current setting.

Available options:
  
  fulscr [on|off]
    Enables/disables fullscreen.
  vol [<number>]
    Set game volume to a number
    from 0 to 10, inclusive.
]]
end

if not arg_option or arg_option == "-h" or arg_option == "--help" or arg_option == "/?" then
    display_help()
    return
end

local options = {
    fulscr = {
        set = function(v)
            if v == "on" then
                love.window.setFullscreen(true, "desktop")
            elseif v == "off" then
                love.window.setFullscreen(false)
            else
                return false, "invalid setting value"
            end

            return true
        end,
        get = function()
            local v = love.window.getFullscreen()
            if v then
                return "on"
            else
                return "off"
            end
        end
    },
    vol = {
        set = function(v)
            local n = tonumber(v)
            if not n then
                return false, "setting must be a number"
            end

            n = math.clamp(math.round(n), 0, 10)
            love.audio.setVolume(n / 10.0)
            return true
        end,
        get = function()
            local vol = love.audio.getVolume()
            return tostring(math.round(vol * 10.0))
        end
    }
}

local opt_data = options[arg_option]
if not opt_data then
    display_help()
    print("\nerror: unknown option " .. arg_option)
    return
end

if arg_value then
    local s, err = opt_data.set(arg_value)
    if not s then
        display_help()
        print("\nerror: " .. err)
    end
else
    print(opt_data.get())
end