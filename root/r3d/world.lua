local mat4 = require("r3d.mat4")
local mat3 = require("r3d.mat3")
local Object = require("r3d.object")
local Drawable = require("r3d.drawable")
local Light = require("r3d.light")
local SpotLight = Light.spotlight
local PointLight = Light.point

-- these are inserted as defines into the shader files
local SPOTLIGHT_COUNT = 2
local POINT_LIGHT_COUNT = 2

local SPOT_LIGHT_SMAP_WIDTH = 512
local SPOT_LIGHT_SMAP_HEIGHT = 512

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

---@class r3d.World
---@overload fun():r3d.World
local World = batteries.class({ name = "r3d.World" })

---@class r3d.Camera: r3d.Object
---@field frustum_width number Used for the "top_down_oblique" projection type
---@field frustum_height number Used for the "top_down_oblique" projection type
---@field fovy number Used for the "perspective" projection type. In radians.
---@field near number For "top_down_oblique", recommended to be negative.
---@field far number
---@field type "perspective"|"top_down_oblique"
---@overload fun():r3d.Camera
local Camera = batteries.class({ name = "r3d.Camera", extends = Object })

function Camera:new()
    self:super() ---@diagnostic disable-line
    self.frustum_width = 1
    self.frustum_height = 1
    self.type = "top_down_oblique"
    self.near = -32.0
    self.far = 32.0
    self.fovy = math.rad(70.0)
end

---@class r3d.DrawContext
---@field package _obj r3d.Drawable
---@field package _mv mat4
---@field package _mv_norm mat3
---@field package _proj mat4
---@field package _vn mat3
---@field package _processed_shaders {[love.Shader]:boolean}
---@field package _shadow_pass boolean
---@field package _world r3d.World
---@overload fun(world:r3d.World):r3d.DrawContext
local DrawContext = batteries.class({ name = "r3d.DrawContext" })

function DrawContext:new(world)
    self._world = world
end

---@param shader r3d.Shader
function DrawContext:activate_shader(shader)
    ---@type r3d.ShaderVariant
    local sh_variant = "base"
    if self._shadow_pass then
        sh_variant = "no_color"
    elseif self._obj.receive_shadow then
        sh_variant = "shadowed"
    end

    local sh = shader:get(sh_variant)
    Lg.setShader(sh)

    if not self._processed_shaders[sh] then
        shader_try_send(sh, "u_mat_modelview", self._mv)
        shader_try_send(sh, "u_mat_modelview_norm", self._mv_norm)
        self._processed_shaders[sh] = true
    end

    local world = self._world
    if not world._global_processed_shaders[sh] then
        -- send light information to shader
        shader._max_point_lights = POINT_LIGHT_COUNT
        shader._max_spot_lights = SPOTLIGHT_COUNT

        if not self._shadow_pass then
            shader_try_send(sh, "u_light_ambient_color", world:_pack_color(world.ambient))
            shader_try_send(sh, "u_light_sun_color", world:_pack_color(world.sun))
            shader_try_send(sh, "u_light_sun_direction", world:_pack_vec(world.sun, self._vn))

            shader_try_send(sh, "u_light_spot_pos", unpack(world._u_spotlights.pos))
            shader_try_send(sh, "u_light_spot_dir_angle", unpack(world._u_spotlights.dir_angle))
            shader_try_send(sh, "u_light_spot_color_pow", unpack(world._u_spotlights.color_pow))
            shader_try_send(sh, "u_light_spot_control", unpack(world._u_spotlights.control))
            shader_try_send(sh, "u_light_spot_mat_vp", unpack(world._u_spotlights.mat_vp))
            shader_try_send(sh, "u_light_spot_depth", unpack(world._u_spotlights.depth_buffers))

            shader_try_send(sh, "u_light_point_pos", unpack(world._u_pointlights.pos))
            shader_try_send(sh, "u_light_point_color_pow", unpack(world._u_pointlights.color_pow))
            shader_try_send(sh, "u_light_point_control", unpack(world._u_pointlights.control))
        end
        
        shader_try_send(sh, "u_mat_projection", self._proj)

        world._global_processed_shaders[sh] = true
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

    ---@private
    ---@type mat4[]
    self._tmp_mat = {}
    ---@package
    self._tmp_mat_i = 1
    for i=1, 32 do
        table.insert(self._tmp_mat, mat4.new())
    end

    ---@private
    ---@type number[]
    self._tmp_vec3 = { 0, 0, 0 }

    ---@private
    self._draw_ctx = DrawContext(self)

    ---@package
    self._u_spotlights = {
        pos = {},
        dir_angle = {},
        color_pow = {},
        control = {},
        mat_vp = {},
        depth_buffers = {}
    }

    ---@package
    ---@type {pos:number[][], color_pow:number[][], control:number[][]}
    self._u_pointlights = {
        pos = {},
        color_pow = {},
        control = {}
    }

    for i=1, SPOTLIGHT_COUNT do
        self._u_spotlights.pos[i] = { 0.0, 0.0, 0.0 }
        self._u_spotlights.dir_angle[i] = { 0.0, 0.0, 0.0, 0.0 }
        self._u_spotlights.color_pow[i] = { 0.0, 0.0, 0.0, 0.0 }
        self._u_spotlights.control[i] = { 0.0, 0.0, 0.0, 0.0 }
        self._u_spotlights.mat_vp[i] = mat4.new()
        self._u_spotlights.depth_buffers[i] =
            Lg.newCanvas(SPOT_LIGHT_SMAP_WIDTH, SPOT_LIGHT_SMAP_HEIGHT,
                         { format = "depth16", dpiscale = 1.0, readable = true })
    end

    for i=1, POINT_LIGHT_COUNT do
        self._u_pointlights.pos[i] = { 0.0, 0.0, 0.0 }
        self._u_pointlights.color_pow[i] = { 0.0, 0.0, 0.0, 0.0 }
        self._u_pointlights.control[i] = { 0.0, 0.0, 0.0, 0.0 }
    end

    ---@package
    self._global_processed_shaders = {}
end

function World:release()
    for _, fb in ipairs(self._u_spotlights.depth_buffers) do
        fb:release()
    end
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

---@package
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

---@package
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
---@param proj_mat mat4
---@param view_mat mat4
---@param view_normal mat3
---@param shadow_pass boolean
function World:_draw_object(obj, proj_mat, view_mat, view_normal, shadow_pass)
    if not obj.visible then
        return
    end
    
    self._draw_ctx._processed_shaders = {}
    self._draw_ctx._obj = obj
    local sp = self._tmp_mat_i

    -- local mv = model.transform * view_mat
    local mv = obj.transform:mul(view_mat, self:_push_mat())
    self._draw_ctx._mv = mv

    local mv_it = mv:inverse(self:_push_mat())
                    :transpose(self:_push_mat())
    self._draw_ctx._mv_norm = mv_it:to_mat3()

    self._draw_ctx._proj = proj_mat
    self._draw_ctx._vn = view_normal
    self._draw_ctx._shadow_pass = shadow_pass

    if obj.double_sided then
        Lg.setMeshCullMode("none")
    else
        Lg.setMeshCullMode("back")
    end

    obj:draw(self._draw_ctx)

    self:_restore_mat_stack(sp)
end

---@private
---@param proj_mat mat4
---@param view_mat mat4
---@param view_normal mat3
---@param shadow_pass boolean
function World:_draw_objects(proj_mat, view_mat, view_normal, shadow_pass)
    self._global_processed_shaders = {}

    -- opaque pass
    Lg.setDepthMode("less", true)
    for _, obj in ipairs(self.objects) do
        if obj:is(Drawable) then
            ---@cast obj r3d.Drawable
            if obj.opaque and obj.visible and (not shadow_pass or obj.cast_shadow) then
                self:_draw_object(obj, proj_mat, view_mat, view_normal, shadow_pass)
            end
        end
    end

    -- transparent pass
    -- objects are assumed to be already sorted from back-to-front. or at least,
    -- adequately so.
    Lg.setDepthMode("less", false)
    for _, obj in ipairs(self.objects) do
        if obj:is(Drawable) then
            ---@cast obj r3d.Drawable
            if not obj.opaque and obj.visible and (not shadow_pass or obj.cast_shadow) then
                self:_draw_object(obj, proj_mat, view_mat, view_normal, shadow_pass)
            end
        end
    end
end

function World:draw()
    self._tmp_mat_i = 1

    Lg.push("all")
    Lg.setColor(1, 1, 1)

    local projection = self:_push_mat()
    if self.cam.type == "top_down_oblique" then
        local we = self.cam.frustum_width / 2.0
        local he = self.cam.frustum_height / 2.0
        mat4.oblique(projection, -we, we, -he, he, self.cam.near, self.cam.far)
    elseif self.cam.type == "perspective" then
        local aspect = DISPLAY_WIDTH / DISPLAY_HEIGHT
        mat4.perspective(projection, self.cam.fovy, aspect, self.cam.near, self.cam.far)
    else
        error("unknown camera projection type")
    end

    local view_mat =
        self.cam.transform:inverse(self:_push_mat())

    local view_normal = view_mat:inverse(self:_push_mat())
                                :transpose(self:_push_mat())
                                :to_mat3()
    
    -- update lights
    do
        local light_view_normal = mat3.new()
        local spotlight_i = 1
        local pointlight_i = 1

        for _, obj in ipairs(self.objects) do
            if spotlight_i <= SPOTLIGHT_COUNT and obj:is(SpotLight) then
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
                local u_mat_vp    = self._u_spotlights.mat_vp[spotlight_i]
                local depth_buf   = self._u_spotlights.depth_buffers[spotlight_i]
                
                u_pos[1], u_pos[2], u_pos[3] = view_mat:mul_vec(px, py, pz)

                u_dir_ang[1], u_dir_ang[2], u_dir_ang[3] = view_normal:mul_vec(dx, dy, dz)
                u_dir_ang[4] = math.cos(obj.angle)

                u_color_pow[1], u_color_pow[2], u_color_pow[3] = obj.r, obj.g, obj.b
                u_color_pow[4] = obj.power

                u_control[1], u_control[2], u_control[3], u_control[4] =
                    obj.constant, obj.linear, obj.quadratic, obj.shadow_bias

                -- render shadow map
                Lg.push("all")
                Lg.setCanvas({ depthstencil = depth_buf })
                Lg.clear()

                if obj.shadows then
                    local sp = self._tmp_mat_i

                    local light_proj =
                        self:_push_mat()
                        :perspective(obj.angle * 2.0, 1.0, 1.0, 500.0)
                    local light_view_mat =
                        self:_push_mat()
                        :rotation_y(math.pi / 2.0)
                        :mul(obj.transform, self:_push_mat())
                        :inverse(self:_push_mat())
                    light_view_mat:inverse(self:_push_mat())
                                :transpose(self:_push_mat())
                                :to_mat3(light_view_normal)

                    -- *u_mat_vp = view_mat:inverse() * light_view_mat * light_proj
                    view_mat
                        :inverse(self:_push_mat())
                        :mul(light_view_mat, self:_push_mat())
                        :mul(light_proj, u_mat_vp)

                    self:_draw_objects(light_proj, light_view_mat, light_view_normal, true)

                    self:_restore_mat_stack(sp)
                end

                Lg.pop()

                spotlight_i = spotlight_i + 1


            elseif pointlight_i <= POINT_LIGHT_COUNT and obj:is(PointLight) then
                ---@cast obj r3d.PointLight
                if not obj.enabled then
                    goto continue
                end

                local px, py, pz = obj:get_position()

                local u_pos       = self._u_pointlights.pos[pointlight_i]
                local u_color_pow = self._u_pointlights.color_pow[pointlight_i]
                local u_control   = self._u_pointlights.control[pointlight_i]
                
                u_pos[1], u_pos[2], u_pos[3] = view_mat:mul_vec(px, py, pz)
                u_color_pow[1], u_color_pow[2], u_color_pow[3] = obj.r, obj.g, obj.b
                u_color_pow[4] = obj.power

                u_control[1], u_control[2], u_control[3] = obj.constant, obj.linear, obj.quadratic

                pointlight_i = pointlight_i + 1
            end

            ::continue::
        end

        -- zero out unused slots
        for i=spotlight_i, SPOTLIGHT_COUNT do
            local u_pos       = self._u_spotlights.pos[i]
            local u_dir_ang   = self._u_spotlights.dir_angle[i]
            local u_color_pow = self._u_spotlights.color_pow[i]
            local u_control   = self._u_spotlights.control[i]
            local u_mat_vp    = self._u_spotlights.mat_vp[i]

            u_pos[1], u_pos[2], u_pos[3] = 0, 0, 0
            u_dir_ang[1], u_dir_ang[2], u_dir_ang[3], u_dir_ang[4] = 0, 0, 0, 0
            u_color_pow[1], u_color_pow[2], u_color_pow[3], u_color_pow[4] = 0, 0, 0, 0
            u_control[1], u_control[2], u_control[3], u_control[4] = 1, 0, 0, 0
            u_mat_vp:identity()
        end

        for i=pointlight_i, POINT_LIGHT_COUNT do
            local u_pos       = self._u_pointlights.pos[i]
            local u_color_pow = self._u_pointlights.color_pow[i]
            local u_control   = self._u_pointlights.control[i]

            u_pos[1], u_pos[2], u_pos[3] = 0, 0, 0
            u_color_pow[1], u_color_pow[2], u_color_pow[3], u_color_pow[4] = 0, 0, 0, 0
            u_control[1], u_control[2], u_control[3], u_control[4] = 1, 0, 0, 0
        end
    end
    
    self:_draw_objects(projection, view_mat, view_normal, false)
    self:_restore_mat_stack(1)
    assert(self._tmp_mat_i == 1)
    Lg.pop()

    -- Lg.setColor(1, 1, 1)
    -- Lg.draw(self._u_spotlights.depth_buffers[1], 0, 0, 0., 0.25, 0.25)
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