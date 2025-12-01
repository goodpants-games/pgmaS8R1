---Row-major 4x4 matrix.
---@class mat4
local mat4 = {}
mat4.__index = mat4

function mat4.new()
    return setmetatable({
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }, mat4)
end

---@param col integer
---@param row integer
function mat4:get(col, row)
    return self[col*4+row + 1]
end

---@param col integer
---@param row integer
---@param val number
function mat4:set(col, row, val)
    self[col*4+row + 1] = val
    return self
end

---@param a mat4
---@param b mat4
---@param res mat4
function mat4.mul(a, b, res)
    if res == nil then
        res = mat4.new()
    end

    for row=0, 3 do
        for col=0, 3 do
            res[col*4+row + 1] =
                a[0*4+row + 1] * b[col*4+0 + 1] +
                a[1*4+row + 1] * b[col*4+1 + 1] +
                a[2*4+row + 1] * b[col*4+2 + 1] +
                a[3*4+row + 1] * b[col*4+3 + 1]
        end
    end

    return res
end

mat4.__mul = mat4.mul

---@param dst mat4?
function mat4:clone(dst)
    if dst == nil then
        dst = mat4.new()
    end

    for i=1, 16 do
        dst[i] = self[i]
    end

    return dst
end

---@param mat any
function mat4.is_mat4(mat)
    return getmetatable(mat) == mat4
end

---@param ang number
---@param res mat4?
---@return mat4
function mat4.rotation_x(ang, res)
    if res == nil then
        res = mat4.new()
    end

    local c = math.cos(ang)
    local s = math.sin(ang)

    res:set(1, 1, c)
    res:set(2, 1, -s)
    res:set(1, 2, s)
    res:set(2, 2, c)

    return res
end

---@param ang number
---@param res mat4?
---@return mat4
function mat4.rotation_y(ang, res)
    if res == nil then
        res = mat4.new()
    end

    local c = math.cos(ang)
    local s = math.sin(ang)

    res:set(0, 0, c)
    res:set(2, 0, s)
    res:set(0, 2, -s)
    res:set(2, 2, c)

    return res
end

---@param ang number
---@param res mat4?
---@return mat4
function mat4.rotation_z(ang, res)
    if res == nil then
        res = mat4.new()
    end

    local c = math.cos(ang)
    local s = math.sin(ang)

    res:set(0, 0, c)
    res:set(0, 1, -s)
    res:set(1, 0, s)
    res:set(1, 1, c)

    return res
end

---@param x number
---@param y number
---@param z number
---@param res mat4?
---@return mat4
function mat4.translation(x, y, z, res)
    if res == nil then
        res = mat4.new()
    end

    res:set(0, 3, x)
    res:set(1, 3, y)
    res:set(2, 3, z)

    return res
end

---Create an oblique projection matrix. Z is the up axis.
---@param left number
---@param right number
---@param top number
---@param bottom number
---@param zmin number
---@param zmax number
---@return mat4
function mat4.oblique(left, right, top, bottom, zmin, zmax)
    local res = mat4.new()

    local sx = (right - left) / 2.0
    local sy = (bottom - top) / 2.0

    local cza = -1 - (2.0 * zmin) / (top - bottom)
    local czb = -1 + (2.0 * zmax) / (bottom - top)
    local czm = (czb - 1.0) / (1.0 - cza)

    local zf = czm * 2.0 / (bottom - top)
    local zc = czm * ((-2.0 * top) / (bottom - top) - cza - 1.0) + 1.0

    -- print("b", f_top, f_bottom)
    -- print("m", zf, zc)

    -- assert(math.abs((f_top * zf + zc) - (1.0)) < 1e-5)
    -- assert(math.abs((f_bottom * zf + zc) - (-1.0)) < 1e-5)

        res[ 1], res[ 2], res[ 3], res[ 4],
        res[ 5], res[ 6], res[ 7], res[ 8],
        res[ 9], res[10], res[11], res[12],
        res[13], res[14], res[15], res[16]
    = 
        1 / sx, 0,      0,       -1 - left / sx,
        0,      1 / sy, -1 / sy, -1 - top / sy,
        0,      zf,     0,       zc,
        0,      0,      0,       1
    
    return res
end

return mat4