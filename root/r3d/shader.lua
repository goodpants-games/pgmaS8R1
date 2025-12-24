local bit = require("bit")

---@class r3d.Shader
---@overload fun():r3d.Shader
local Shader = batteries.class({ name = "r3d.Shader" })

---Internal
---@class r3d.ShaderResource
---@field hash string
---@field shader love.Shader
---@field refs {[r3d.Shader]:boolean}

local DEFAULT_VERTEX = [[
vec3 r3d_vert(vec3 vertex_position)
{
    return vertex_position;
}
]]

local DEFAULT_FRAGMENT = [[
vec4 r3d_frag(vec4 color, vec4 tex_color, Image tex, vec2 texture_coords,
              vec2 screen_coords, vec3 light_influence)
{
    return color * tex_color * vec4(light_influence, 1.0);
}
]]

---@type {[string]:r3d.ShaderResource}
local shader_cache = setmetatable({}, { __mode = "v" })

---@param obj any
---@return boolean
local function is_love_shader(obj)
    if obj == nil or type(obj.typeOf) ~= "function" then
        return false
    end
    return not not obj:typeOf("Shader")
end

function Shader:new()
    self._max_spot_lights = 4
    self._max_point_lights = 4

    self.alpha_discard = false
    self.light_ignore_normals = false

    ---@type "none"|"normal"|"vertex"
    self.shading = "normal"

    ---@type string?
    self.custom_vertex = nil
    ---@type string?
    self.custom_fragment = nil

    ---@private
    ---@type r3d.ShaderResource|love.Shader
    self._sh = nil

    ---@private
    ---@type string
    self._last_hash = self:_pack_config()
end

---@private
---@return string
function Shader:_pack_config()
    assert(self._max_point_lights > 0, "_max_point_lights must be positive or zero")
    assert(self._max_spot_lights > 0, "_max_spot_lights must be positive or zero")

    -- overengineered hash calculation
    local int = 0
    local shtype = 0
    if self.shading == "vertex" then
        shtype = 2
    elseif self.shading == "normal" then
        shtype = 1
    elseif self.shading == "none" then
        shtype = 0
    end

    assert(shtype <= 2)

    int = bit.bor(int, shtype)
    if self.alpha_discard        then int = bit.bor(int, 4) end
    if self.light_ignore_normals then int = bit.bor(int, 8) end

    -- print("A")
    local v = love.data.pack("string", "<I2I2I4",
                             self._max_point_lights, self._max_spot_lights, int)
    -- print("B")
    return v --[[@as string]]
end

function Shader:release()
    self:invalidate()
end

function Shader:invalidate()
    local sh = self._sh
    self._sh = nil

    if sh then
        if is_love_shader(sh) then
            ---@cast sh love.Shader
            sh:release()
        else
            ---@cast sh r3d.ShaderResource
            sh.refs[self] = nil
            if not next(sh.refs) then
                shader_cache[sh.hash] = nil
                sh.shader:release()
            end
        end
    end
end

---@param self r3d.Shader
---@param lines string[]
local function insert_defines(self, lines)
    local tinsert = table.insert
    tinsert(lines, "#define R3D_MAX_SPOT_LIGHTS " .. self._max_spot_lights)
    tinsert(lines, "#define R3D_MAX_POINT_LIGHTS " .. self._max_point_lights)

    if self.light_ignore_normals then
        tinsert(lines, "#define R3D_LIGHT_IGNORE_NORMALS")
    end

    if self.alpha_discard then
        tinsert(lines, "#define R3D_ALPHA_DISCARD")
    end

    if self.shading == "vertex" then
        tinsert(lines, "#define R3D_SHADING")
        tinsert(lines, "#define R3D_SHADING_VERTEX")
    elseif self.shading == "normal" then
        tinsert(lines, "#define R3D_SHADING")
    elseif self.shading ~= "none" then
        error("invalid shading type. expected 'none', 'vertex', or 'normal'.")
    end
end

---@param src string
---@param lines string[]
local function insert_shader(src, lines)
    if love.filesystem.getInfo(src) then
        table.insert(lines, "#include <" .. src .. ">")
    else
        table.insert(lines, src)
    end
end

---@param self r3d.Shader
---@param vert string?
---@param frag string?
local function create_shader(self, vert, frag)
    local vlines = {}
    local flines = {}

    insert_defines(self, vlines)
    insert_defines(self, flines)

    table.insert(vlines, "#include <res/shaders/r3d/r3d.vert.glsl>")
    table.insert(flines, "#include <res/shaders/r3d/r3d.frag.glsl>")

    insert_shader(vert or DEFAULT_VERTEX, vlines)
    insert_shader(frag or DEFAULT_FRAGMENT, flines)

    local vsrc = table.concat(vlines, "\n")
    local fsrc = table.concat(flines, "\n")

    return Lg.newShader(fsrc, vsrc)
end

---@private
function Shader:_recompile()
    self:invalidate()

    if self.custom_vertex or self.custom_fragment then
        self._sh = create_shader(self, self.custom_vertex, self.custom_fragment)
    else
        local hash = self:_pack_config()
        local sh = shader_cache[hash]
        if not sh then
            sh = {
                hash = hash,
                shader = create_shader(self, self.custom_vertex, self.custom_fragment),
                refs = setmetatable({}, { __mode = "k" })
            }
            shader_cache[hash] = sh
        end
        sh.refs[self] = true
        self._sh = sh
    end
end

function Shader:prepare()
    local new_hash = self:_pack_config()
    if not self._sh or new_hash ~= self._last_hash then
        self:_recompile()
        self._last_hash = new_hash
    end
end

---@return love.Shader
function Shader:get_raw()
    self:prepare()

    if is_love_shader(self._sh) then
        return self._sh --[[@as love.Shader]]
    else
        return self._sh.shader
    end
end

function Shader:use()
    Lg.setShader(self:get_raw())
end

---@param name any
---@param ... any
function Shader:send(name, ...)
    self:get_raw():send(name, ...)
end

---@param name string
---@return boolean
function Shader:hasUniform(name)
    return self:get_raw():hasUniform(name)
end

return Shader