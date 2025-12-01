---Row major 3x3 matrix
---@class mat3
local mat3 = {}
mat3.__index = mat3

function mat3.new()
    return setmetatable({
        1, 0, 0,
        0, 1, 0,
        0, 0, 1
    }, mat3)
end

---@param col integer
---@param row integer
---@return number
function mat3:get(col, row)
    return self[col*3+row+1]
end

---@param col integer
---@param row integer
---@param val number
---@return mat3
function mat3:set(col, row, val)
    self[col*3+row+1] = val
    return self
end

---@param x number
---@param y number
---@param z number
---@return number x, number y, number z
function mat3:mul_vec(x, y, z)
    return self[1] * x + self[2] * y + self[3] * z,
           self[4] * x + self[5] * y + self[6] * z,
           self[7] * x + self[8] * y + self[9] * z
end

return mat3