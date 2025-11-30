local Concord = require("concord")
local Input = require("input")

local system = Concord.system({
    pool = {"player_control"}
})

function system:tick()
    local ent = self.pool[1]
    if not ent then
        return
    end

    local game = self:getWorld().game --[[@as Game]]
    local position = ent.position

    if position then
        game.cam_x = position.x
        game.cam_y = position.y
    end
end

function system:update(dt)
    for _, ent in ipairs(self.pool) do
        local actor = ent.actor

        if actor then
            actor.move_x, actor.move_y = Input.players[1]:get("move")            
        end
    end
end

return system