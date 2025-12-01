local scene = require("sceneman").scene()
local tiled = require("tiled")
local Input = require("input")
local mat4 = require("util.mat4")

local self

local V3D_VS = [[
attribute vec3 VertexNormal;
uniform mat4 u_projection;
uniform mat4 u_modelview;

varying vec3 v_normal;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    v_normal = VertexNormal;
    return u_projection * u_modelview * vec4(vertex_position.xyz, 1.0);
}
]]

local V3D_FS = [[
varying vec3 v_normal;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec3 sun_influence =
        vec3(1.0, 1.0, 1.0) * max(0.0, dot(v_normal, -normalize(vec3(0.4, -0.8, -1.0))));
    vec3 ambient_influence = vec3(0.1, 0.1, 0.1);

    vec4 texturecolor = Texel(tex, texture_coords);
    texturecolor.rgb *= ambient_influence + sun_influence;
    return texturecolor * color;
}
]]

local v3d_format = {
    {"VertexPosition", "float", 3},
    {"VertexTexCoord", "float", 2},
    {"VertexNormal", "float", 3},
    {"VertexColor", "float", 4}
}

local function tappend(t, ...)
    local tinsert = table.insert
    for i=1, select("#", ...) do
        local v = select(i, ...)
        tinsert(t, v)
    end
end

---@param voxel {w:integer, h:integer, data:integer[][]}
local function create_mesh(voxel)
    ---@type number[][]
    local vertices = {}
    ---@type integer[]
    local indices = {}
    local tinsert = table.insert

    local voxel_depth = #voxel.data
    local function get_voxel(x, y, z)
        if x < 0 or y < 0 or z < 0 or x >= voxel.w or y >= voxel.h or z >= voxel_depth then
            return 0
        end

        return voxel.data[z+1][y * voxel.w + x + 1]
    end

    local vi = 1
    for z=0, voxel_depth-1 do
        local i=1
        for y=0, voxel.h-1 do
            for x=0, voxel.w-1 do
                if get_voxel(x, y, z) == 0 then
                    goto continue
                end

                -- right
                if get_voxel(x + 1, y, z) == 0 then
                    tappend(vertices,
                        {
                            x + 1, y, z,
                            1, 0,
                            1, 0, 0,
                            1, 1, 1, 1
                        },
                        {
                            x + 1, y + 1, z,
                            0, 0,
                            1, 0, 0,
                            1, 1, 1, 1
                        },
                        {
                            x + 1, y + 1, z + 1,
                            0, 1,
                            1, 0, 0,
                            1, 1, 1, 1
                        },
                        {
                            x + 1, y, z + 1,
                            1, 1,
                            1, 0, 0,
                            1, 1, 1, 1
                        }
                    )

                    tappend(indices,
                        vi+0, vi+2, vi+1,
                        vi+0, vi+3, vi+2
                    )

                    vi = vi + 4
                end

                -- left
                if get_voxel(x - 1, y, z) == 0 then
                    tappend(vertices,
                        {
                            x, y + 1, z,
                            1, 0,
                            -1, 0, 0,
                            1, 1, 1, 1
                        },
                        {
                            x, y, z,
                            0, 0,
                            -1, 0, 0,
                            1, 1, 1, 1
                        },
                        {
                            x, y, z + 1,
                            0, 1,
                            -1, 0, 0,
                            1, 1, 1, 1
                        },
                        {
                            x, y + 1, z + 1,
                            1, 1,
                            -1, 0, 0,
                            1, 1, 1, 1
                        }
                    )

                    tappend(indices,
                        vi+0, vi+2, vi+1,
                        vi+0, vi+3, vi+2
                    )

                    vi = vi + 4
                end

                -- front
                if get_voxel(x, y + 1, z) == 0 then
                    tappend(vertices,
                        {
                            x + 1, y + 1, z,
                            1, 0,
                            0, 1, 0,
                            1, 1, 1, 1
                        },
                        {
                            x, y + 1, z,
                            0, 0,
                            0, 1, 0,
                            1, 1, 1, 1
                        },
                        {
                            x, y + 1, z + 1,
                            0, 1,
                            0, 1, 0,
                            1, 1, 1, 1
                        },
                        {
                            x + 1, y + 1, z + 1,
                            1, 1,
                            0, 1, 0,
                            1, 1, 1, 1
                        }
                    )

                    tappend(indices,
                        vi+0, vi+2, vi+1,
                        vi+0, vi+3, vi+2
                    )

                    vi = vi + 4
                end

                -- back
                if get_voxel(x, y - 1, z) == 0 then
                    tappend(vertices,
                        {
                            x, y, z,
                            1, 0,
                            0, -1, 0,
                            1, 1, 1, 1
                        },
                        {
                            x + 1, y, z,
                            0, 0,
                            0, -1, 0,
                            1, 1, 1, 1
                        },
                        {
                            x + 1, y, z + 1,
                            0, 1,
                            0, -1, 0,
                            1, 1, 1, 1
                        },
                        {
                            x, y, z + 1,
                            1, 1,
                            0, -1, 0,
                            1, 1, 1, 1
                        }
                    )

                    tappend(indices,
                        vi+0, vi+2, vi+1,
                        vi+0, vi+3, vi+2
                    )

                    vi = vi + 4
                end

                -- top
                if get_voxel(x, y, z + 1) == 0 then
                    tappend(vertices,
                        {
                            x + 1, y + 1, z + 1,
                            1, 0,
                            0, 0, 1,
                            1, 1, 1, 1
                        },
                        {
                            x, y + 1, z + 1,
                            0, 0,
                            0, 0, 1,
                            1, 1, 1, 1
                        },
                        {
                            x, y, z + 1,
                            0, 1,
                            0, 0, 1,
                            1, 1, 1, 1
                        },
                        {
                            x + 1, y, z + 1,
                            1, 1,
                            0, 0, 1,
                            1, 1, 1, 1
                        }
                    )

                    tappend(indices,
                        vi+0, vi+2, vi+1,
                        vi+0, vi+3, vi+2
                    )

                    vi = vi + 4
                end

                -- bottom
                -- if get_voxel(x, y, z - 1) == 0 then
                --     tappend(vertices,
                --         {
                --             x + 1, y, z,
                --             1, 0,
                --             0, 0, -1,
                --             1, 1, 1, 1
                --         },
                --         {
                --             x, y, z,
                --             0, 0,
                --             0, 0, -1,
                --             1, 1, 1, 1
                --         },
                --         {
                --             x, y + 1, z,
                --             0, 1,
                --             0, 0, -1,
                --             1, 1, 1, 1
                --         },
                --         {
                --             x + 1, y + 1, z,
                --             1, 1,
                --             0, 0, -1,
                --             1, 1, 1, 1
                --         }
                --     )

                --     tappend(indices,
                --         vi+0, vi+1, vi+2,
                --         vi+0, vi+2, vi+3
                --     )

                --     vi = vi + 4
                -- end

                ::continue::
            end
        end
    end

    local mesh = Lg.newMesh(v3d_format, vertices, "triangles", "static")
    mesh:setVertexMap(indices)

    local out = io.open("../test.obj", "w")
    assert(out, "could not open test.obj")

    for _, vertex in ipairs(vertices) do
        out:write(("v %f %f %f\n"):format(vertex[1], vertex[2], vertex[3]))
        out:write(("vt %f %f\n"):format(vertex[4], vertex[5]))
    end

    for i=1, #indices, 3 do
        local a, b, c = indices[i], indices[i+1], indices[i+2]
        out:write(("f %i/%i %i/%i %i/%i\n"):format(a,a, b,b, c,c))
    end

    out:close()

    return mesh
end

function scene.load()
    self = {}
    local map = tiled.loadMap("res/maps/voxeltest.lua")
    self.map = map
    self.cam_x = 0
    self.cam_y = 0

    local vox_w = self.map.width
    local vox_h = self.map.height
    local vox_data = {}

    for _, layer in ipairs(self.map.layers) do
        if layer.type ~= "tilelayer" then goto continue end
        ---@cast layer pklove.tiled.TileLayer
        
        local vox_layer = {}
        local i = 1
        for y=0, layer.height - 1 do
            for x=0, layer.width - 1 do
                local gid = layer:get(x, y)
                assert(gid)

                if gid == 0 then
                    vox_layer[i] = 0
                else
                    local tile_info = map:getTileInfo(gid)
                    assert(map.tilesets[tile_info.tilesetId].name == "voxel")

                    vox_layer[i] = tile_info.id
                end

                i=i+1
            end
        end

        vox_data[#vox_data+1] = vox_layer

        ::continue::
    end

    self.mesh = create_mesh({ w = vox_w, h = vox_h, data = vox_data })
    self.shader = Lg.newShader(V3D_FS, V3D_VS)

    local tex = Lg.newImage("res/test_tex.png")
    self.mesh:setTexture(tex)
    tex:release()
end

function scene.unload()
    assert(self)
    self.map:release()
    self.mesh:release()
    self.shader:release()
    self = nil
end

function scene.update(dt)
    local pan_speed = 10.0
    local mx, my = Input.players[1]:get("move")

    self.cam_x = self.cam_x + mx * pan_speed * dt
    self.cam_y = self.cam_y + my * pan_speed * dt
end

function scene.draw()
    Lg.push("all")
    Lg.setShader(self.shader)
    Lg.setMeshCullMode("back")
    Lg.setDepthMode("less", true)

    local view_mat = mat4.translation(-self.cam_x, -self.cam_y, 0.0)
    local model_mat = mat4.rotation_z(-MOUSE_Y / DISPLAY_HEIGHT * (math.pi / 2))

    local view_x = self.cam_x
    local view_y = self.cam_y

    -- local f_left = view_x
    -- local f_right = view_x + DISPLAY_WIDTH / 16
    -- local f_top = view_y
    -- local f_bottom = view_y + DISPLAY_HEIGHT / 16
    local frustum_width = DISPLAY_WIDTH / 16
    local frustum_height = DISPLAY_HEIGHT / 16
    local z_min = 0.0
    local z_max = 4.0

    local projection = mat4.oblique(0, frustum_width, 0, frustum_height, z_min, z_max)
    -- projection = mat4.rotation_z(love.timer.getTime()) * projection
    self.shader:send("u_projection", projection)
    self.shader:send("u_modelview", model_mat * view_mat)
    
    -- local sx = (f_right - f_left) / 2.0
    -- local sy = (f_bottom - f_top) / 2.0

    -- local cza = -1 - (2.0 * z_min) / (f_top - f_bottom)
    -- local czb = -1 + (2.0 * z_max) / (f_bottom - f_top)
    -- local czm = (czb - 1.0) / (1.0 - cza)

    -- local zf = czm * 2.0 / (f_bottom - f_top)
    -- local zc = czm * ((-2.0 * f_top) / (f_bottom - f_top) - cza - 1.0) + 1.0

    -- -- print("b", f_top, f_bottom)
    -- -- print("m", zf, zc)

    -- -- assert(math.abs((f_top * zf + zc) - (1.0)) < 1e-5)
    -- -- assert(math.abs((f_bottom * zf + zc) - (-1.0)) < 1e-5)

    -- self.shader:send("u_projection", {
    --     1 / sx, 0,      0,       -1 - f_left / sx,
    --     0,      1 / sy, -1 / sy,  -1 - f_top / sy,
    --     0,      zf,     0,       zc,
    --     -- 0,      0,      0,       0,
    --     0,      0,      0,       1
    -- })
    Lg.draw(self.mesh)

    -- (-1) * (-1 + (b) / (b - a)) + 1.0
    
    Lg.pop()
end

return scene