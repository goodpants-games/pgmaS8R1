---@class r3d.Batch: r3d.Drawable
---@overload fun(vertex_count:integer?):r3d.Batch
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

---@param x0 number
---@param y0 number
---@param z0 number
---@param x1 number
---@param y1 number
---@param z1 number
---@return number x, number y, number z
local function v3_cross(x0,y0,z0, x1,y1,z1)
    return y0 * z1 - z0 * y1,
           z0 * x1 - x0 * z1,
           x0 * y1 - y0 * x1
end

---@param x number
---@param y number
---@param z number
---@return number x, number y, number z
local function v3_normalize(x, y, z)
    local dist = math.sqrt(x * x + y * y + z * z)
    if dist > 0 then
        x = x / dist
        y = y / dist
        z = z / dist
    end
    return x, y, z
end

---@param vertex_count integer?
function Batch:new(vertex_count)
    self:super() ---@diagnostic disable-line
    vertex_count = vertex_count or 2048

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
    self._last_shader = nil

    ---@private
    self._tmp_m4 = { mat4.new(), mat4.new() }
    ---@private
    self._tmp_m3 = mat3.new()

    ---@private
    self._color = { 1.0, 1.0, 1.0, 1.0 }

    ---@private
    self._shader = "shaded"

    ---@private
    self._dirty = false

    local white_img = love.image.newImageData(1, 1, "rgba8")
    white_img:setPixel(0, 0, 1, 1, 1, 1)
    ---@private
    self._white_tex = Lg.newImage(white_img)
    white_img:release()
end

function Batch:release()
    if self.mesh then
        self.mesh:release()
        self.mesh = nil
    end

    if self._white_tex then
        self._white_tex:release()
        self._white_tex = nil
    end
end

function Batch:clear()
    self._draw_calls = {}
    self._vtxi = 1
    self._vtx_map = {}
    self._last_tex = nil
    self._shader = nil
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
        table.insert(self._draw_calls, self._last_shader)
        self._dirty = false
    end
end

---@param tex love.Texture
---@param shader string?
function Batch:_begin_draw(tex, shader)
    if shader == nil then
        shader = self._shader
    end

    if self._last_tex ~= tex or self._last_shader ~= shader then
        self:_flush()
    end

    self._last_tex = tex
    self._last_shader = shader
    self._dirty = true
end

---@param r number
---@param g number
---@param b number
---@param a number?
---@overload fun(color:number[])
function Batch:set_color(r, g, b, a)
    if type(r) == "table" then
        r, g, b, a = r[1], r[2], r[3], r[4]
    end
    a = a or 1.0

    local t = self._color
    t[1], t[2], t[3], t[4] = r, g, b, a
end

---@param shader_name string
function Batch:set_shader(shader_name)
    self._shader = shader_name
end

function Batch:get_shader()
    return self._shader
end

---Adds a quad to the batch (but does not call _begin_draw)
---@param x0 number
---@param y0 number
---@param z0 number
---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@param x3 number
---@param y3 number
---@param z3 number
---@param nx number
---@param ny number
---@param nz number
---@param u0 number
---@param v0 number
---@param u1 number
---@param v1 number
function Batch:_add_quad(x0,y0,z0, x1,y1,z1, x2,y2,z2, x3,y3,z3, nx,ny,nz, u0,v0,u1,v1)
    local mesh = self.mesh
    local col = self._color

    mesh:setVertex(
        self._vtxi + 0,
        x0, y0, z0,
        u0, v0,
        nx, ny, nz,
        col[1], col[2], col[3], col[4])
    mesh:setVertex(
        self._vtxi + 1,
        x1, y1, z1,
        u0, v1,
        nx, ny, nz,
        col[1], col[2], col[3], col[4])
    mesh:setVertex(
        self._vtxi + 2,
        x2, y2, z2,
        u1, v1,
        nx, ny, nz,
        col[1], col[2], col[3], col[4])
    mesh:setVertex(
        self._vtxi + 3,
        x3, y3, z3,
        u1, v0,
        nx, ny, nz,
        col[1], col[2], col[3], col[4])
    
    tappend(
        self._vtx_map,
        self._vtxi+0, self._vtxi+1, self._vtxi+2,
        self._vtxi+2, self._vtxi+3, self._vtxi+0
    )

    self._vtxi = self._vtxi + 4
end

function Batch:add_line(x0, y0, z0, x1, y1, z1, thickness)
    local fx = x1 - x0
    local fy = y1 - y0
    local fz = z1 - z0

    thickness = thickness / 2.0

    fx, fy, fz = v3_normalize(fx, fy, fz)

    -- x0, y0, z0 = forward vector
    -- right vector
    local rx, ry, rz = v3_normalize(v3_cross(0,0,-1, fx,fy,fz))
    -- up vector
    local ux, uy, uz = v3_normalize(v3_cross(rx, ry, rz, fx, fy, fz))

    self:_begin_draw(self._white_tex, nil)
    self:_add_quad(
        x0 - rx * thickness, y0 - ry * thickness, z0 - rz * thickness,
        x1 - rx * thickness, y1 - ry * thickness, z1 - rz * thickness,
        x1 + rx * thickness, y1 + ry * thickness, z1 + rz * thickness,
        x0 + rx * thickness, y0 + ry * thickness, z0 + rz * thickness,
        ux, uy, uz,
        0, 0, 1, 1
    )
end

---@private
---@param img love.Texture
---@param transform mat4
---@param u0 number
---@param v0 number
---@param u1 number
---@param v1 number
function Batch:_add_image_uv(img, transform, u0, v0, u1, v1)
    self:_begin_draw(img, nil)

    local mesh = self.mesh
    local col = self._color

    local img_w = math.abs(u1 - u0) * img:getWidth()
    local img_h = math.abs(v1 - v0) * img:getHeight()

    local x0, y0, z0 = 0.0,   0.0,   0.0
    local x1, y1, z1 = 0.0,   img_h, 0.0
    local x2, y2, z2 = img_w, img_h, 0.0
    local x3, y3, z3 = img_w, 0.0,   0.0
    local nx, ny, nz = 0.0,   0.0,   1.0

    x0, y0, z0 = transform:mul_vec(x0, y0, z0)
    x1, y1, z1 = transform:mul_vec(x1, y1, z1)
    x2, y2, z2 = transform:mul_vec(x2, y2, z2)
    x3, y3, z3 = transform:mul_vec(x3, y3, z3)
    nx, ny, nz = self:_transform_normal(transform, nx, ny, nz)

    self:_add_quad(x0, y0, z0,
                   x1, y1, z1,
                   x2, y2, z2,
                   x3, y3, z3,
                   nx, ny, nz,
                   u0, v0, u1, v1)
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

function Batch:draw(draw_ctx)
    self:_flush()

    local draw_calls = self._draw_calls
    local draw_start = 1

    if not self._vtx_map[1] then
        return
    end
    
    self.mesh:setVertexMap(self._vtx_map)
    Lg.setColor(1, 1, 1)
    local last_shader

    for i=1, #draw_calls, 3 do
        local idx_end, tex, shader = draw_calls[i], draw_calls[i+1], draw_calls[i+2]
        
        if last_shader ~= shader then
            draw_ctx:activate_shader(shader)
            last_shader = shader
        end

        self.mesh:setTexture(tex)
        self.mesh:setDrawRange(draw_start, idx_end - draw_start)
        Lg.draw(self.mesh)

        draw_start = idx_end
    end
end

return Batch