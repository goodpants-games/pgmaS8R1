---@class r3d.Batch: r3d.Drawable
---@overload fun():r3d.Batch
local Batch = batteries.class({ name = "r3d.Batch", extends = require("r3d.drawable") })
local mat4 = require("r3d.mat4")
local mat3 = require("r3d.mat3")
local new_mesh = require("r3d.mesh").new

local function tappend(t, ...)
    local tinsert = table.insert
    for i=1, select("#", ...) do
        local v = select(i, ...)
        tinsert(t, v)
    end
end

function Batch:new()
    self:super() ---@diagnostic disable-line

    ---@type love.Mesh
    self.mesh = new_mesh(2048, "triangles", "stream")

    ---@private
    self._vtxi = 1

    ---@private
    ---@type integer[]
    self._vtx_map = {}
    ---@private
    self._draw_calls = {}
    ---@private
    ---@type love.Texture?
    self._last_tex = nil

    ---@private
    self._tmp_m4 = { mat4.new(), mat4.new() }
    ---@private
    self._tmp_m3 = mat3.new()

    ---@private
    self._color = { 1.0, 1.0, 1.0, 1.0 }

    ---@private
    self._dirty = false
end

function Batch:clear()
    self._draw_calls = {}
    self._vtxi = 1
    self._vtx_map = {}
    self._last_tex = nil
end

---@private
---@param transform mat4
---@param nx number
---@param ny number
---@param nz number
function Batch:_transform_normal(transform, nx, ny, nz)
    self._tmp_m4[1]:identity()
    self._tmp_m4[2]:identity()

    nx, ny, nz = transform:inverse(self._tmp_m4[1])
                          :transpose(self._tmp_m4[2])
                          :to_mat3(self._tmp_m3)
                          :mul_vec(nx, ny, nz)

    local nlen = math.sqrt(nx * nx + ny * ny + nz * nz)
    if nlen == 0.0 then nlen = 1.0 end

    return nx / nlen, ny / nlen, nz / nlen
end

---@private
function Batch:_flush()
    if self._dirty then
        table.insert(self._draw_calls, #self._vtx_map + 1)
        table.insert(self._draw_calls, self._last_tex)
        self._dirty = false
    end
end

---@param img love.Texture
---@param transform mat4
---@param u0 number
---@param v0 number
---@param u1 number
---@param v1 number
function Batch:_add_image_uv(img, transform, u0, v0, u1, v1)
    if self._last_tex ~= img then
        self:_flush()
    end

    self._last_tex = img
    local mesh = self.mesh
    local col = self._color

    local img_w = img:getWidth()
    local img_h = img:getHeight()

    local x0, y0, z0 = transform:mul_vec(0, img_h, 0)
    local x1, y1, z1 = transform:mul_vec(img_w, img_h, 0)
    local x2, y2, z2 = transform:mul_vec(img_w, 0, 0)
    local x3, y3, z3 = transform:mul_vec(0, 0, 0)

    local nx, ny, nz = self:_transform_normal(transform, 0.0, 0.0, 1.0)

    mesh:setVertex(
        self._vtxi + 0,
        x0, y0, z0,
        u0, v1,
        nx, ny, nz,
        col[1], col[2], col[3], col[4])
    mesh:setVertex(
        self._vtxi + 1,
        x1, y1, z1,
        u1, v1,
        nx, ny, nz,
        col[1], col[2], col[3], col[4])
    mesh:setVertex(
        self._vtxi + 2,
        x2, y2, z2,
        u1, v0,
        nx, ny, nz,
        col[1], col[2], col[3], col[4])
    mesh:setVertex(
        self._vtxi + 3,
        x3, y3, z3,
        u0, v0,
        nx, ny, nz,
        col[1], col[2], col[3], col[4])
    
    tappend(
        self._vtx_map,
        self._vtxi+0, self._vtxi+1, self._vtxi+2,
        self._vtxi+2, self._vtxi+3, self._vtxi+0
    )

    self._vtxi = self._vtxi + 4
    self._dirty = true
end

---@param img love.Texture
---@param quad love.Quad
---@param transform mat4
---@overload fun(self:r3d.Batch, img:love.Texture, transform:mat4)
function Batch:add_image(img, quad, transform)
    if transform == nil then
        transform = quad --[[@as mat4]]
        quad = nil ---@diagnostic disable-line
    end

    if quad then
        local x, y, w, h = quad:getViewport()
        local sx, sy = quad:getTextureDimensions()

        local u0 = x       / sx
        local u1 = (x + w) / sx
        local v0 = y       / sy
        local v1 = (y + h) / sy

        self:_add_image_uv(img, transform, u0, v0, u1, v1)
    else
        self:_add_image_uv(img, transform, 0.0, 0.0, 1.0, 1.0)
    end
end

function Batch:release()
    self.mesh:release()
    self.mesh = nil
end

function Batch:draw()
    self:_flush()

    local draw_calls = self._draw_calls
    local draw_start = 1
    
    self.mesh:setVertexMap(self._vtx_map)

    for i=1, #draw_calls, 2 do
        local idx_end, tex = draw_calls[i], draw_calls[i+1]
        
        self.mesh:setTexture(tex)
        self.mesh:setDrawRange(draw_start, idx_end - draw_start)
        Lg.draw(self.mesh)

        draw_start = idx_end
    end
end

return Batch