---@class Point
---@field x number
---@field y number
---@overload fun(x:number, y:number):Point
local Point = batteries.class({ name = "Point" })

function Point:new(x, y)
    self.x = x
    self.y = y
end

function Point:length()
    return math.sqrt(self.x * self.x + self.y * self.y)
end

return Point