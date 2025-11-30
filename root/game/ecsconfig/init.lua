local module_path = (...):gsub("%.init$", "")
local Concord = require("concord")

local ecsconfig = {}
ecsconfig.systems = {}

require(module_path .. ".components")
Concord.utils.loadNamespace("game/ecsconfig/systems", ecsconfig.systems)

return ecsconfig