---@class game.Behavior
---@field entity any
---@field game Game
---@overload fun()
local Behavior = batteries.class { name = "game.Behavior" }

---@param ent any
---@param game Game
function Behavior:init(ent, game)
    self.entity = ent
    self.game = game
end

function Behavior:tick()
end

return Behavior