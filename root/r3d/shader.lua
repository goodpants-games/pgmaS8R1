local bit = require("bit")

---@class r3d.Shader
---@overload fun():r3d.Shader
local Shader = batteries.class({ name = "r3d.Shader" })

---@alias r3d.ShaderVariant "base"|"no_color"|"shadowed"

---Internal
---@class r3d._ShaderResource
---@field hash string?
---@field shaders {[string]:love.Shader}
---@field refs {[r3d.Shader]:boolean}?

local DEFAULT_VERTEX = [[
vec3 r3d_vert(vec3 vertex_position)
{
    return vertex_position;
}
]]

local DEFAULT_FRAGMENT = [[
vec4 r3d_frag(vec4 color, vec4 tex_color, Image tex, vec2 texture_coords,
              vec3 light_influence)
{
    return color * tex_color * vec4(light_influence, 1.0);
}
]]

---@type {[string]:r3d._ShaderResource}
local shader_cache = setmetatable({}, { __mode = "v" })

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
    ---@type r3d._ShaderResource?
    self._sh = nil

    ---@private
    self._unique = false

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
    if self.alpha_discard        then int = bit.bor(int, 4)  end
    if self.light_ignore_normals then int = bit.bor(int, 8)  end

    -- print("A")
    local v = love.data.pack("string", "<I2I2I4",
                             self._max_point_lights, self._max_spot_lights, int)
    -- print("B")
    return v --[[@as string]]
end

function Shader:release()
    self:invalidate()
end

---@param sh r3d._ShaderResource
local function release_resource(sh)
    for _, v in pairs(sh.shaders) do
        v:release()
    end
    table.clear(sh.shaders)
end

function Shader:invalidate()
    local sh = self._sh
    self._sh = nil

    if sh then
        if self._unique then
            release_resource(sh)
        else
            sh.refs[self] = nil
            if not next(sh.refs) then
                shader_cache[sh.hash] = nil
                release_resource(sh)
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

---@private
---@param variant r3d.ShaderVariant
function Shader:_compile_shader(variant)
    local vlines = {}
    local flines = {}

    insert_defines(self, vlines)
    insert_defines(self, flines)

    if variant == "shadowed" then
        table.insert(vlines, "#define R3D_SHADOWS")
        table.insert(flines, "#define R3D_SHADOWS")
    end

    if variant == "no_color" then
        table.insert(vlines, "#include <res/shaders/r3d/r3d_nocolor.vert.glsl>")
        table.insert(flines, "#include <res/shaders/r3d/r3d_nocolor.frag.glsl>")
    else
        table.insert(vlines, "#include <res/shaders/r3d/r3d.vert.glsl>")
        table.insert(flines, "#include <res/shaders/r3d/r3d.frag.glsl>")
    end

    insert_shader(self.custom_vertex or DEFAULT_VERTEX, vlines)
    insert_shader(self.custom_fragment or DEFAULT_FRAGMENT, flines)

    local vsrc = table.concat(vlines, "\n")
    local fsrc = table.concat(flines, "\n")

    print("Compile Shader")
    return Lg.newShader(fsrc, vsrc)
end

---@private
---@param hash string?
function Shader:_create_resource(hash)
    ---@type r3d._ShaderResource
    local res = {
        hash = hash,
        shaders = {}
    }

    res.shaders.base = self:_compile_shader("base")
    res.shaders.no_color = self:_compile_shader("no_color")
    res.shaders.shadowed = self:_compile_shader("shadowed")

    return res
end

---@private
function Shader:_recompile()
    self:invalidate()

    if self.custom_vertex or self.custom_fragment then
        self._unique = true
        self._sh = self:_create_resource()
    else
        self._unique = false
        local hash = self:_pack_config()
        local sh = shader_cache[hash]
        if not sh then
            sh = self:_create_resource(hash)
            sh.refs = setmetatable({}, { __mode = "k" })
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

---@param variant r3d.ShaderVariant?
---@return love.Shader
function Shader:get(variant)
    self:prepare()

    return self._sh.shaders[variant or "base"]
end

---@param variant r3d.ShaderVariant?
function Shader:use(variant)
    Lg.setShader(self:get(variant))
end

return Shader