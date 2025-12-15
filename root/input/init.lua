local Input = {}
local baton = require("input.baton")

local base_controls = {
    pause = {'key:escape', 'button:start'},

    left = {'axis:leftx-', 'button:dpleft'},
    right = {'axis:leftx+', 'button:dpright'},
    up = {'axis:lefty-', 'button:dpup'},
    down = {'axis:lefty+', 'button:dpdown'},

    player_attack = {'button:a'},
    player_lock = {'button:leftshoulder'},
    player_run = {'button:b'},
    player_switch_weapon = {'button:x'},
}

---@param input_mode "arrow"|"wasd"
---@param mouse boolean
local function get_baton_config(input_mode, mouse)
    local controls = table.deep_copy(base_controls) --[[@as table]]
    local tinsert = table.insert

    tinsert(controls.left, "key:left")
    tinsert(controls.right, "key:right")
    tinsert(controls.up, "key:up")
    tinsert(controls.down, "key:down")

    if input_mode == "wasd" or mouse then
        tinsert(controls.left, "key:a")
        tinsert(controls.right, "key:d")
        tinsert(controls.up, "key:w")
        tinsert(controls.down, "key:s")

        if mouse then
            tinsert(controls.player_attack, "mouse:1")
            tinsert(controls.player_run, "key:lshift")
            tinsert(controls.player_switch_weapon, "key:e")
        else
            tinsert(controls.player_attack, "key:;")
            tinsert(controls.player_lock, "key:lshift")
            tinsert(controls.player_run, "key:'")
            tinsert(controls.player_switch_weapon, "key:l")
        end
    elseif input_mode == "arrow" then
        tinsert(controls.player_attack, "key:z")
        tinsert(controls.player_lock, "key:lshift")
        tinsert(controls.player_run, "key:x")
        tinsert(controls.player_switch_weapon, "key:c")
    else
        error("invalid input mode " .. input_mode)
    end

    batteries.pretty.print(controls)

    return controls
end

Input.players = {}
Input.players[1] = baton.new {
    controls = get_baton_config("arrow", false),
    pairs = {
        move = {'left', 'right', 'up', 'down'}
    },
    joystick = love.joystick.getJoysticks()[1],
}

---@param input_mode "arrow"|"wasd"
---@param mouse boolean
function Input.update_config(input_mode, mouse)
    local new_config = get_baton_config(input_mode, mouse)
    local active_config = Input.players[1].config.controls

    for k, sources in pairs(active_config) do
        table.clear(sources)
        for i,v in pairs(new_config[k]) do
            sources[i] = v
        end
    end
    -- .controls = 
end

function Input.update()
    for _, p in pairs(Input.players) do
        p:update()
    end
end

return Input