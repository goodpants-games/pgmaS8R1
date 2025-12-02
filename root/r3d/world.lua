local mat4 = require("r3d.mat4")
local mat3 = require("r3d.mat3")
local Object = require("r3d.object")
local Drawable = require("r3d.drawable")
local Light = require("r3d.light").light
local SpotLight = require("r3d.light").spotlight

-- these are inserted as defines into the shader files
local SPOTLIGHT_COUNT = 4

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

---@param path string
---@return string?
local function shader_preproc(path)
    if path == nil then
        return nil
    end

    local lines = {
        "#define SPOTLIGHT_COUNT " .. SPOTLIGHT_COUNT,
        -- "#line 0 0"
        "#include <" .. path .. ">"
    }

    -- for line in love.filesystem.lines(path) do
    --     table.insert(lines, line)
    -- end

    return table.concat(lines, "\n")
end

---@param vertexcode string?
---@param pixelcode string?
---@return love.Shader
local function new_shader(vertexcode, pixelcode)
    return Lg.newShader(
        ---@diagnostic disable-next-line
        shader_preproc(vertexcode),
        ---@diagnostic disable-next-line
        shader_preproc(pixelcode)
    )
end

---@param shader love.Shader
---@param name string
---@param ... any
local function shader_try_send(shader, name, ...)
    if shader:hasUniform(name) then
        shader:send(name, ...)
    end
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

    ---@type r3d.Object[]
    self.objects = {}

    ---@type {[string]: love.Shader}
    self.shaders = {}
    self.shaders.shaded = new_shader("res/shaders/r3d/r3d_shaded.frag.glsl",
                                     "res/shaders/r3d/r3d.vert.glsl")
    self.shaders.basic = new_shader(nil,
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

    ---@private
    ---@type {pos:number[][], dir_angle:number[][], color_pow:number[][], control:number[][]}
    self._u_spotlights = {
        pos = {},
        dir_angle = {},
        color_pow = {},
        control = {}
    }

    for i=1, SPOTLIGHT_COUNT do
        self._u_spotlights.pos[i] = { 0.0, 0.0, 0.0 }
        self._u_spotlights.dir_angle[i] = { 0.0, 0.0, 0.0, 0.0 }
        self._u_spotlights.color_pow[i] = { 0.0, 0.0, 0.0, 0.0 }
        self._u_spotlights.control[i] = { 0.0, 0.0, 0.0, 0.0 }
    end
end

function World:release()
    if self.shaders then
        for _, shader in pairs(self.shaders) do
            shader:release()
        end
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

---@private
---@param obj r3d.Drawable
---@param view_mat mat4
function World:_draw_object(obj, view_mat)
    local shader
    if obj.use_shading then
        shader = self.shaders.shaded
    else
        shader = self.shaders.basic
    end

    Lg.setShader(shader)

    local sp = self._tmp_mat_i

    -- local mv = model.transform * view_mat
    local mv = obj.transform:mul(view_mat, self:_push_mat())
    shader:send("u_mat_modelview", mv)

    if shader:hasUniform("u_mat_modelview_norm") then
        local mv_it = mv:inverse(self:_push_mat())
                        :transpose(self:_push_mat())

        shader:send("u_mat_modelview_norm", mv_it:to_mat3(self._tmp_mat3))
    end

    if obj.double_sided then
        Lg.setMeshCullMode("none")
    else
        Lg.setMeshCullMode("back")
    end

    obj:draw()

    self:_restore_mat_stack(sp)
end

function World:draw()
    self._tmp_mat_i = 1

    Lg.push("all")
    Lg.setColor(1, 1, 1)

    -- local shader = self.shaders.base

    local projection =
        mat4.oblique(self:_push_mat(), 0, self.cam.frustum_width, 0, self.cam.frustum_height, -32, 32)

    for _, shader in pairs(self.shaders) do
        shader:send("u_mat_projection", projection)
    end

    self:_pop_mat()

    local view_mat =
        self.cam.transform:inverse(self:_push_mat())
        * mat4.translation(self:_push_mat(), self.cam.frustum_width / 2, self.cam.frustum_height / 2, 0)

    local sp = self._tmp_mat_i
    local view_normal = view_mat:inverse(self:_push_mat())
                                :transpose(self:_push_mat())
                                :to_mat3(self._tmp_mat3)
    
    -- update spotlights
    do
        local spotlight_i = 1
        for _, obj in ipairs(self.objects) do
            -- ran out of slots
            if spotlight_i > SPOTLIGHT_COUNT then
                break
            end

            if obj:is(SpotLight) then
                ---@cast obj r3d.SpotLight
                if not obj.enabled then
                    goto continue
                end

                local px, py, pz = obj:get_position()
                local dx, dy, dz = obj:get_light_direction()

                local u_pos       = self._u_spotlights.pos[spotlight_i]
                local u_dir_ang   = self._u_spotlights.dir_angle[spotlight_i]
                local u_color_pow = self._u_spotlights.color_pow[spotlight_i]
                local u_control   = self._u_spotlights.control[spotlight_i]
                
                u_pos[1], u_pos[2], u_pos[3] = view_mat:mul_vec(px, py, pz)

                u_dir_ang[1], u_dir_ang[2], u_dir_ang[3] = view_normal:mul_vec(dx, dy, dz)
                u_dir_ang[4] = obj.angle

                u_color_pow[1], u_color_pow[2], u_color_pow[3] = obj.r, obj.g, obj.b
                u_color_pow[4] = obj.power

                u_control[1], u_control[2], u_control[3] = obj.constant, obj.linear, obj.quadratic

                spotlight_i = spotlight_i + 1
            end

            ::continue::
        end

        -- zero out unused slots
        for i=spotlight_i, SPOTLIGHT_COUNT do
            local u_pos       = self._u_spotlights.pos[i]
            local u_dir_ang   = self._u_spotlights.dir_angle[i]
            local u_color_pow = self._u_spotlights.color_pow[i]
            local u_control   = self._u_spotlights.control[i]

            u_pos[1], u_pos[2], u_pos[3] = 0, 0, 0
            u_dir_ang[1], u_dir_ang[2], u_dir_ang[3], u_dir_ang[4] = 0, 0, 0, 0
            u_color_pow[1], u_color_pow[2], u_color_pow[3], u_color_pow[4] = 0, 0, 0, 0
            u_control[1], u_control[2], u_control[3], u_control[4] = 1, 0, 0, 0
        end
    end

    -- send light information to shaders
    for _, shader in pairs(self.shaders) do
        shader_try_send(shader, "u_light_ambient_color", self:_pack_color(self.ambient))
        shader_try_send(shader, "u_light_sun_color", self:_pack_color(self.sun))
        shader_try_send(shader, "u_light_sun_direction", self:_pack_vec(self.sun, view_normal))

        shader_try_send(shader, "u_light_spot_pos", unpack(self._u_spotlights.pos))
        shader_try_send(shader, "u_light_spot_dir_angle", unpack(self._u_spotlights.dir_angle))
        shader_try_send(shader, "u_light_spot_color_pow", unpack(self._u_spotlights.color_pow))
        shader_try_send(shader, "u_light_spot_control", unpack(self._u_spotlights.control))
    end
    
    self:_restore_mat_stack(sp)

    -- opaque pass
    Lg.setDepthMode("less", true)
    for _, obj in ipairs(self.objects) do
        if obj:is(Drawable) then
            ---@cast obj r3d.Drawable
            if obj.opaque then
                self:_draw_object(obj, view_mat)
            end
        end
    end

    -- transparent pass
    Lg.setDepthMode("less", false)
    for _, obj in ipairs(self.objects) do
        if obj:is(Drawable) then
            ---@cast obj r3d.Drawable
            if not obj.opaque then
                self:_draw_object(obj, view_mat)
            end
        end
    end

    self:_pop_mat(2)
    assert(self._tmp_mat_i == 1)
    Lg.pop()
end

---@param object r3d.Object
function World:add_object(object)
    if not table.index_of(self.objects, object) then
        table.insert(self.objects, object)
    end
end

---@param object r3d.Object
function World:remove_object(object)
    local idx = table.index_of(self.objects, object)
    if idx then
        table.remove(self.objects, idx)
        return true
    end

    return false
end

return World