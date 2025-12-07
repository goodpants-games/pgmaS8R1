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
            control.run = false
            control.lock = false

            if input:down("player_lock") then
                control.lock = true
            elseif input:down("player_run") then
                control.run = true
            end

            if input:pressed("player_attack") then
                control.trigger_attack = true
            end
        end

        -- debug raycast function
        if Debug.enabled then
            local position = ent.position
            local rotation = ent.rotation
            if position and rotation then
                local ray_dx = math.cos(rotation.ang)
                local ray_dy = math.sin(rotation.ang)
                local dist = game:raycast(position.x, position.y, ray_dx * 100, ray_dy * 100)

                if dist then
                    local hit_x = position.x + ray_dx * dist
                    local hit_y = position.y + ray_dy * dist

                    Debug.draw:color(0.0, 1.0, 0.0)
                    Debug.draw:circle_lines(hit_x, hit_y, 4)
                end
            end
        end
    end
end

return system