local mat4 = require("r3d.mat4")
local mat3 = require("r3d.mat3")
local Object = require("r3d.object")

---@class r3d.World
---@overload fun():r3d.World
local World = batteries.class({ name = "r3d.World" })

---@class r3d.Camera: r3d.Object
---@field frustum_width number
---@field frustum_height number
---@overload fun():r3d.Camera
local Camera = batteries.class({ name = "r3d.Camera", extends = Object })

function Camera:new()
    self:super() ---@diagnostic disable-line
    self.frustum_width = 1
    self.frustum_height = 1
end

function World:new()
    self.sun = {
        -- 0.4, -0.8, -1.0
        x = 0.4,
        y = -0.8,
        z = -1.0,

        r = 1.0,
        g = 1.0,
        b = 1.0,
    }

    self.ambient = {
        r = 0.1,
        g = 0.1,
        b = 0.1
    }

    self.cam = Camera()

    ---@type r3d.Model[]
    self.models = {}

    ---@type {[string]: love.Shader}
    self.shaders = {}
    self.shaders.base = Lg.newShader("res/shaders/r3d/r3d.frag.glsl",
                                     "res/shaders/r3d/r3d.vert.glsl")

    ---@private
    ---@type mat4[]
    self._tmp_mat = {}
    ---@private
    self._tmp_mat_i = 1
    for i=1, 16 do
        table.insert(self._tmp_mat, mat4.new())
    end

    ---@private
    ---@type number[]
    self._tmp_mat3 = mat3.new()

    ---@private
    ---@type number[]
    self._tmp_vec3 = { 0, 0, 0 }
end

function World:release()
    for _, shader in pairs(self.shaders) do
        shader:release()
    end

    self.shaders = nil
end

---@private
function World:_push_mat()
    local mat = self._tmp_mat[self._tmp_mat_i]
    self._tmp_mat_i = self._tmp_mat_i + 1
    return mat:identity()
end

---@private
---@param count integer?
function World:_pop_mat(count)
    count = count or 1
    self._tmp_mat_i = self._tmp_mat_i - count
    local mat = self._tmp_mat[self._tmp_mat_i + 1]
    return mat
end

---@private
---@param pos integer
function World:_restore_mat_stack(pos)
    local c = self._tmp_mat_i - pos
    if c > 0 then
        self:_pop_mat(c)
    end
end

---@private
---@param r number
---@param g number
---@param b number
---@overload fun(self:r3d.World, color:{r:number, g:number, b:number}):number[]
function World:_pack_color(r, g, b)
    if type(r) == "table" then
        r, g, b = r.r, r.g, r.b
    end

    self._tmp_vec3[1], self._tmp_vec3[2], self._tmp_vec3[3] = r, g, b
    return self._tmp_vec3
end

---@private
---@param x number
---@param y number
---@param z number
---@param mat mat3?
---@overload fun(self:r3d.World, vec:{xyz:number, y:number, z:number}, mat:mat3?):number[]
function World:_pack_vec(x, y, z, mat)
    if type(x) == "table" then
        ---@diagnostic disable-next-line
        mat = y
        x, y, z = x.x, x.y, x.z
    end

    if mat then
        ---@diagnostic disable-next-line
        x, y, z = mat:mul_vec(x, y, z)
    end

    self._tmp_vec3[1], self._tmp_vec3[2], self._tmp_vec3[3] = x, y, z
    return self._tmp_vec3
end

function World:draw()
    self._tmp_mat_i = 1

    Lg.push("all")
    Lg.setMeshCullMode("back")
    Lg.setDepthMode("less", true)

    local shader = self.shaders.base
    Lg.setShader(shader)

    local projection =
        mat4.oblique(self:_push_mat(), 0, self.cam.frustum_width, 0, self.cam.frustum_height, -5, 5)
    shader:send("u_mat_projection", projection)
    self:_pop_mat()

    local view_mat =
        self.cam.transform:inverse(self:_push_mat())
        * mat4.translation(self:_push_mat(), self.cam.frustum_width / 2, self.cam.frustum_height / 2, 0)

    local sp = self._tmp_mat_i
    local view_normal = view_mat:inverse(self:_push_mat())
                                :transpose(self:_push_mat())
                                :to_mat3(self._tmp_mat3)
    
    shader:send("u_light_ambient_color", self:_pack_color(self.ambient))
    shader:send("u_light_sun_color", self:_pack_color(self.sun))
    shader:send("u_light_sun_direction", self:_pack_vec(self.sun, view_normal))
    
    self:_restore_mat_stack(sp)

    for _, model in ipairs(self.models) do
        sp = self._tmp_mat_i

        -- local mv = model.transform * view_mat
        local mv = model.transform:mul(view_mat, self:_push_mat())
        shader:send("u_mat_modelview", mv)

        if shader:hasUniform("u_mat_modelview_norm") then
            local mv_it = mv:inverse(self:_push_mat())
                            :transpose(self:_push_mat())

            shader:send("u_mat_modelview_norm", mv_it:to_mat3(self._tmp_mat3))
        end

        Lg.draw(model.mesh)

        self:_restore_mat_stack(sp)
    end

    self:_pop_mat(2)
    assert(self._tmp_mat_i == 1)
    Lg.pop()
end

---@param model r3d.Model
function World:add_model(model)
    if not table.index_of(self.models, model) then
        table.insert(self.models, model)
    end
end

---@param model r3d.Model
function World:remove_model(model)
    local idx = table.index_of(self.models, model)
    if idx then
        table.remove(self.models, idx)
        return true
    end

    return false
end

return World