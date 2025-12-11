local Concord = require("concord")
local Input = require("input")

local system = Concord.system({
    pool = {"player_control"}
})

function system:init()
    self.ping_hold_len = 0
    self.ping_held = false
    self.did_ping = false
end

function system:tick()
    ---@type Game
    local game = self:getWorld().game

    local do_ping = false

    if self.ping_held then
        self.ping_hold_len = self.ping_hold_len + 1
        if self.ping_hold_len >= 60 then
            self.ping_hold_len = -999999
            self.did_ping = true
            do_ping = true
        end
    else
        self.ping_hold_len = 0
        self.did_ping = false
    end

    if do_ping then
        game:player_ping()
    end

    -- for _, ent in ipairs(self.pool) do
    --     local control = ent.player_control
    --     control.ping = do_ping
    -- end
end

function system:update(dt)
    local input = Input.players[1]

    local ping_action = "player_switch_weapon"

    self.ping_held = input:down(ping_action)

    for _, ent in ipairs(self.pool) do
        local control = ent.player_control

        if control then
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

            if input:released("player_switch_weapon") and not self.did_ping then
                control.trigger_weapon_switch = true
            end
        end
    end
end

return system