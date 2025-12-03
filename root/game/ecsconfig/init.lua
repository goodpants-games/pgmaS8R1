local module_path = (...):gsub("%.init$", "")
local Concord = require("concord")
require(module_path .. ".components")

local ecsconfig = {}
ecsconfig.systems = {}
ecsconfig.asm = require(module_path .. ".assemblages")

Concord.utils.loadNamespace("game/ecsconfig/systems", ecsconfig.systems)

return ecsconfig