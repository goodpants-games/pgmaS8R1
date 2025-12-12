local mat3 = require("r3d.mat3")

---Row-major 4x4 matrix.
---@class mat4
---@operator mul(mat4):mat4
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
---@return number
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
---@param res mat4?
---@return mat4
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

---@param x number
---@param y number
---@param z number
---@param w number?
---@return number x, number y, number w, number z
function mat4:mul_vec(x, y, z, w)
    w = w or 1.0

    return
        self[ 1] * x + self[ 2] * y + self[ 3] * z + self[ 4] * w,
        self[ 5] * x + self[ 6] * y + self[ 7] * z + self[ 8] * w,
        self[ 9] * x + self[10] * y + self[11] * z + self[12] * w,
        self[13] * x + self[14] * y + self[15] * z + self[16] * w
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

-- Oh my lord
-- Refactored into lua from some stackoverflow page
-- \.v\[(\d+)\]\[(\d+)\]
-- [$2*4+$1+1]
---@param res mat4?
---@return mat4
function mat4:inverse(res)
    local A2323 = self[2*4+2+1] * self[3*4+3+1] - self[3*4+2+1] * self[2*4+3+1]
    local A1323 = self[1*4+2+1] * self[3*4+3+1] - self[3*4+2+1] * self[1*4+3+1]
    local A1223 = self[1*4+2+1] * self[2*4+3+1] - self[2*4+2+1] * self[1*4+3+1]
    local A0323 = self[0*4+2+1] * self[3*4+3+1] - self[3*4+2+1] * self[0*4+3+1]
    local A0223 = self[0*4+2+1] * self[2*4+3+1] - self[2*4+2+1] * self[0*4+3+1]
    local A0123 = self[0*4+2+1] * self[1*4+3+1] - self[1*4+2+1] * self[0*4+3+1]
    local A2313 = self[2*4+1+1] * self[3*4+3+1] - self[3*4+1+1] * self[2*4+3+1]
    local A1313 = self[1*4+1+1] * self[3*4+3+1] - self[3*4+1+1] * self[1*4+3+1]
    local A1213 = self[1*4+1+1] * self[2*4+3+1] - self[2*4+1+1] * self[1*4+3+1]
    local A2312 = self[2*4+1+1] * self[3*4+2+1] - self[3*4+1+1] * self[2*4+2+1]
    local A1312 = self[1*4+1+1] * self[3*4+2+1] - self[3*4+1+1] * self[1*4+2+1]
    local A1212 = self[1*4+1+1] * self[2*4+2+1] - self[2*4+1+1] * self[1*4+2+1]
    local A0313 = self[0*4+1+1] * self[3*4+3+1] - self[3*4+1+1] * self[0*4+3+1]
    local A0213 = self[0*4+1+1] * self[2*4+3+1] - self[2*4+1+1] * self[0*4+3+1]
    local A0312 = self[0*4+1+1] * self[3*4+2+1] - self[3*4+1+1] * self[0*4+2+1]
    local A0212 = self[0*4+1+1] * self[2*4+2+1] - self[2*4+1+1] * self[0*4+2+1]
    local A0113 = self[0*4+1+1] * self[1*4+3+1] - self[1*4+1+1] * self[0*4+3+1]
    local A0112 = self[0*4+1+1] * self[1*4+2+1] - self[1*4+1+1] * self[0*4+2+1]

    local det = self[0*4+0+1] * ( self[1*4+1+1] * A2323 - self[2*4+1+1] * A1323 + self[3*4+1+1] * A1223 )
        - self[1*4+0+1] * ( self[0*4+1+1] * A2323 - self[2*4+1+1] * A0323 + self[3*4+1+1] * A0223 )
        + self[2*4+0+1] * ( self[0*4+1+1] * A1323 - self[1*4+1+1] * A0323 + self[3*4+1+1] * A0123 )
        - self[3*4+0+1] * ( self[0*4+1+1] * A1223 - self[1*4+1+1] * A0223 + self[2*4+1+1] * A0123 )
    det = 1 / det
    
    res = res or mat4.new()

    res[0*4+0+1] = det *   ( self[1*4+1+1] * A2323 - self[2*4+1+1] * A1323 + self[3*4+1+1] * A1223 )
    res[1*4+0+1] = det * - ( self[1*4+0+1] * A2323 - self[2*4+0+1] * A1323 + self[3*4+0+1] * A1223 )
    res[2*4+0+1] = det *   ( self[1*4+0+1] * A2313 - self[2*4+0+1] * A1313 + self[3*4+0+1] * A1213 )
    res[3*4+0+1] = det * - ( self[1*4+0+1] * A2312 - self[2*4+0+1] * A1312 + self[3*4+0+1] * A1212 )
    res[0*4+1+1] = det * - ( self[0*4+1+1] * A2323 - self[2*4+1+1] * A0323 + self[3*4+1+1] * A0223 )
    res[1*4+1+1] = det *   ( self[0*4+0+1] * A2323 - self[2*4+0+1] * A0323 + self[3*4+0+1] * A0223 )
    res[2*4+1+1] = det * - ( self[0*4+0+1] * A2313 - self[2*4+0+1] * A0313 + self[3*4+0+1] * A0213 )
    res[3*4+1+1] = det *   ( self[0*4+0+1] * A2312 - self[2*4+0+1] * A0312 + self[3*4+0+1] * A0212 )
    res[0*4+2+1] = det *   ( self[0*4+1+1] * A1323 - self[1*4+1+1] * A0323 + self[3*4+1+1] * A0123 )
    res[1*4+2+1] = det * - ( self[0*4+0+1] * A1323 - self[1*4+0+1] * A0323 + self[3*4+0+1] * A0123 )
    res[2*4+2+1] = det *   ( self[0*4+0+1] * A1313 - self[1*4+0+1] * A0313 + self[3*4+0+1] * A0113 )
    res[3*4+2+1] = det * - ( self[0*4+0+1] * A1312 - self[1*4+0+1] * A0312 + self[3*4+0+1] * A0112 )
    res[0*4+3+1] = det * - ( self[0*4+1+1] * A1223 - self[1*4+1+1] * A0223 + self[2*4+1+1] * A0123 )
    res[1*4+3+1] = det *   ( self[0*4+0+1] * A1223 - self[1*4+0+1] * A0223 + self[2*4+0+1] * A0123 )
    res[2*4+3+1] = det * - ( self[0*4+0+1] * A1213 - self[1*4+0+1] * A0213 + self[2*4+0+1] * A0113 )
    res[3*4+3+1] = det *   ( self[0*4+0+1] * A1212 - self[1*4+0+1] * A0212 + self[2*4+0+1] * A0112 )

    return res
end

---@param res mat4?
function mat4:transpose(res)
    res = res or mat4.new()

    for r=0, 3 do
        for c=0, 3 do
            res[r*4+c+1] = self[c*4+r+1]
        end
    end

    return res
end

---@param out mat3?
---@return mat3
function mat4:to_mat3(out)
    out = out or mat3.new()

    out[1], out[2], out[3],
    out[4], out[5], out[6],
    out[7], out[8], out[9]
    =
    self[ 1], self[ 2], self[ 3],
    self[ 5], self[ 6], self[ 7],
    self[ 9], self[10], self[11]

    return out
end

---@param mat any
function mat4.is_mat4(mat)
    return getmetatable(mat) == mat4
end

---@param mat mat4?
---@return mat4
function mat4.identity(mat)
    mat = mat or mat4.new()

    mat[ 1], mat[ 2], mat[ 3], mat[ 4],
    mat[ 5], mat[ 6], mat[ 7], mat[ 8],
    mat[ 9], mat[10], mat[11], mat[12],
    mat[13], mat[14], mat[15], mat[16]
        =
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1

    return mat
end

---@param mat mat4?
---@param ang number
---@return mat4
function mat4.rotation_x(mat, ang)
    mat = mat or mat4.new()

    local c = math.cos(ang)
    local s = math.sin(ang)

    mat:set(1, 1, c)
    mat:set(2, 1, -s)
    mat:set(1, 2, s)
    mat:set(2, 2, c)

    return mat
end

---@param mat mat4?
---@param ang number
---@return mat4
function mat4.rotation_y(mat, ang)
    mat = mat or mat4.new()

    local c = math.cos(ang)
    local s = math.sin(ang)

    mat:set(0, 0, c)
    mat:set(2, 0, s)
    mat:set(0, 2, -s)
    mat:set(2, 2, c)

    return mat
end

---@param mat mat4?
---@param ang number
---@return mat4
function mat4.rotation_z(mat, ang)
    mat = mat or mat4.new()

    local c = math.cos(ang)
    local s = math.sin(ang)

    mat:set(0, 0, c)
    mat:set(0, 1, -s)
    mat:set(1, 0, s)
    mat:set(1, 1, c)

    return mat
end

---@param mat mat4?
---@param x number
---@param y number
---@param z number
---@return mat4
function mat4.translation(mat, x, y, z)
    mat = mat or mat4.new()

    mat:set(0, 3, x)
    mat:set(1, 3, y)
    mat:set(2, 3, z)

    return mat
end

---@param mat mat4?
---@param x number
---@param y number
---@param z number?
---@param w number?
---@return mat4
function mat4.scale(mat, x, y, z, w)
    mat = mat or mat4.new()

    mat:set(0, 0, x)
    mat:set(1, 1, y)
    mat:set(2, 2, z or 1.0)
    mat:set(3, 3, w or 1.0)

    return mat
end

---Create an oblique projection matrix. Z is the up axis.
---@param mat mat4?
---@param left number
---@param right number
---@param top number
---@param bottom number
---@param near number Near plane offset.
---@param far number Far plane offset.
---@return mat4
function mat4.oblique(mat, left, right, top, bottom, near, far)
    mat = mat or mat4.new()

    local sx = (right - left) / 2.0
    local sy = (bottom - top) / 2.0
    
    local bn = -1 + 2.0 * far / (top - bottom)
    local bf = 1 - 2.0 * near / (bottom - top)
    local zf = -2.0 / (bf - bn)

    local zyc = zf * (2.0 / (bottom - top))
    local zwc = zf * (-2.0 * top / (bottom - top) - 1.0 - bn) + 1.0

        mat[ 1], mat[ 2], mat[ 3], mat[ 4],
        mat[ 5], mat[ 6], mat[ 7], mat[ 8],
        mat[ 9], mat[10], mat[11], mat[12],
        mat[13], mat[14], mat[15], mat[16]
    = 
        1 / sx, 0,      0,       -1 - left / sx,
        0,      1 / sy, -1 / sy, -1 - top / sy,
        0,      zyc,    0,       zwc,
        0,      0,      0,       1
    
    return mat
end

return mat4