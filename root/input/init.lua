local Input = {}
local baton = require("input.baton")

Input.players = {}
Input.players[1] = baton.new {
    controls = {
        left = {'key:left', 'key:a', 'axis:leftx-', 'button:dpleft'},
        right = {'key:right', 'key:d', 'axis:leftx+', 'button:dpright'},
        up = {'key:up', 'key:w', 'axis:lefty-', 'button:dpup'},
        down = {'key:down', 'key:s', 'axis:lefty+', 'button:dpdown'},

        player_attack = {'key:z', 'button:a'},
        player_lock = {'key:lshift', 'button:leftshoulder'},
        player_run = {'key:x', 'button:b'},
        player_switch_weapon = {'key:c', 'button:x'}
    },
    pairs = {
        move = {'left', 'right', 'up', 'down'}
    },
    joystick = love.joystick.getJoysticks()[1],
}

function Input.update()
    for _, p in pairs(Input.players) do
        p:update()
    end
end

return Input