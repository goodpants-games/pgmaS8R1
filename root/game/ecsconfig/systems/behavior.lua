local Concord = require("concord")

local system = Concord.system({
    pool = {"behavior"}
})

function system:tick()
    local game = self:getWorld().game

    for _, ent in ipairs(self.pool) do
        ---@type {inst: game.Behavior, _is_init:boolean?}
        local behavior = ent.behavior

        if not behavior._is_init then
            behavior._is_init = true
            behavior.inst:init(ent, game)
        end

        behavior.inst:tick()
    end
end

return system