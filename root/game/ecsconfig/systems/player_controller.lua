local Concord = require("concord")
local Input = require("input")

local system = Concord.system({
    pool = {"player_control"}
})

function system:update(dt)
    ---@type Game
    local game = self:getWorld().game

    for _, ent in ipairs(self.pool) do
        local control = ent.player_control

        if control then
            local input = Input.players[1]
            local mx, my = input:get("move")
            local mlen = math.sqrt(mx*mx + my*my)
            if mlen > 0.0 then
                mx, my = mx / mlen, my / mlen
            end
            
            control.move_x, control.move_y = mx, my

            local aim_x = MOUSE_X - DISPLAY_WIDTH / 2.0
            local aim_y = MOUSE_Y - DISPLAY_HEIGHT / 2.0
            control.aim_x, control.aim_y = math.normalize_v2(aim_x, aim_y)

            control.run = false
            control.lock = false

            if input:down("player_lock") then
                control.lock = true
            elseif input:down("player_run") then
                control.run = true
            end

            if input:pressed("player_attack") then
                control.trigger_attack = 15
            end

            if input:pressed("player_switch_weapon") then
                control.trigger_weapon_switch = true
            end
        end
    end
end

return system