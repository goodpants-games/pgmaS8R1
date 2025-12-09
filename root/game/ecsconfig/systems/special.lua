local Concord = require("concord")

local system = Concord.system({
    transport_pool = {"room_transport"}
})

function system:tick()
    ---@type Game
    local game = self:getWorld().game

    -- if game:room_transport_info() then
    --     return
    -- end

    local candidates = {}

    for _, transport in ipairs(self.transport_pool) do
        assert(transport.position, "room_transport does not have a position!")
        assert(transport.collision, "room_transport does not have a collider!")
        local transport_dir = transport.room_transport.dir

        table.clear(candidates)
        for _, ent in ipairs(game:get_entities_touching(transport, candidates)) do
            if ent == game.player then
                game:initiate_room_transport(transport_dir)
                break
            end
        end
    end
end

return system