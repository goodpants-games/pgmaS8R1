---@diagnostic disable undefined-global
local arg_option, arg_value = ...
local UserPref = require("userpref")

local function update_baton()
    local Input = require("input")
    Input.update_config()
end

local options = {
    fulscr = {
        help =
[[  fulscr [on|off]
    Enables/disables fullscreen.]],
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
        help =
[[  vol [<number>]
    Set the game volume to a
    number from 0 to 10.]],
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
    },

    keymap = {
        help =
[[  keymap [arrow|wasd]
    Use arrow key- or WASD-based
    keyboard mappings.]],
        get = function()
            return UserPref.input_mode
        end,
        set = function(v)
            if v == "arrow" then
            elseif v == "wasd" then
            else
               return false, "invalid setting value" 
            end
            
            UserPref.input_mode = v
            update_baton()
            return true
        end
    },

    control = {
        help =
[[  control [std|tank|mouse]
    Set the game control scheme.]],
        get = function()
            local v = UserPref.control_mode
            if v == "standard" then
                return "std (standard)"
            elseif v == "dual" then
                return "mouse"
            end
            return v
        end,
        set = function(v)
            if     v == "std" then
                UserPref.control_mode = "standard"
            elseif v == "tank" then
                UserPref.control_mode = v
            elseif v == "mouse" then
                UserPref.control_mode = "dual"
            else
               return false, "invalid setting value" 
            end
            
            update_baton()
            return true
        end
    }
}

local function display_help()
    puts
[[Usage: pref SETTING [VALUE]
       pref [OPTIONS...]
Sets the SETTING setting to VALUE.
If VALUE is not given, it will
instead print the current setting.

  -h --help   Show this help
              screen.
  -l --list   Show list of
              available options.

Type "pref -l" to list options. 
]]
end

local function display_list()
    for _, k in ipairs({ "fulscr", "vol", "keymap", "control" }) do
        print(options[k].help)
    end
    print("\nType pref <option> <value> to\napply.")
end

if not arg_option or arg_option == "-h" or arg_option == "--help" or arg_option == "/?" then
    display_help()
    return
end

if arg_option == "-l" or arg_option == "--list" then
    display_list()
    return
end

local opt_data = options[arg_option]
if not opt_data then
    display_list()
    print("error: unknown option " .. arg_option)
    return
end

if arg_value then
    local s, err = opt_data.set(arg_value)
    if not s then
        display_help()
        print("error: " .. err)
    end
else
    print(opt_data.get())
end