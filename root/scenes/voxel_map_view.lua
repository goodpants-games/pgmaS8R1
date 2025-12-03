local scene = require("sceneman").scene()
local tiled = require("tiled")
local Input = require("input")
local mat4 = require("r3d.mat4")
local r3d = require("r3d")

local self

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

    local voxel_depth = #voxel.data
    local function get_voxel(x, y, z)
        if x < 0 or y < 0 or z < 0 or x >= voxel.w or y >= voxel.h or z >= voxel_depth then
            return 0
        end

        return voxel.data[z+1][y * voxel.w + x + 1]
    end

    local tile_data = {
        [1] = {
            side                  = 5,
            edge_bottom           = 1,
            edge_left             = 2,
            edge_bl_corner_in     = 3,
            edge_bl_corner_out    = 4,
            top                   = 0,
        }
    }

    local function calc_tex_id(x, y, z, is_side)
        local tid = get_voxel(x, y, z)
        if tid == 0 then return end

        local tinfo = tile_data[tid]
        if not tinfo then return end

        if is_side then
            return tinfo.side
        end

        -- true if open, false if closed
        local r = get_voxel(x+1, y, z) ~= tid
        local l = get_voxel(x-1, y, z) ~= tid
        local u = get_voxel(x, y-1, z) ~= tid
        local d = get_voxel(x, y+1, z) ~= tid
        local br = get_voxel(x+1, y+1, z) ~= tid
        local bl = get_voxel(x-1, y+1, z) ~= tid
        local tl = get_voxel(x-1, y-1, z) ~= tid
        local tr = get_voxel(x+1, y-1, z) ~= tid

        local count = 0
        if r then count=count+1 end
        if l then count=count+1 end
        if u then count=count+1 end
        if d then count=count+1 end

        local dcount = 0
        if tr then dcount=dcount+1 end
        if tl then dcount=dcount+1 end
        if br then dcount=dcount+1 end
        if bl then dcount=dcount+1 end

        if count == 0 then
            if tr then
                return tinfo.edge_bl_corner_in, "xy"
            end

            if tl then
                return tinfo.edge_bl_corner_in, "y"
            end

            if bl then
                return tinfo.edge_bl_corner_in
            end

            if br then
                return tinfo.edge_bl_corner_in, "x"
            end

            return tinfo.top
        elseif count == 1 then
            if r then
                return tinfo.edge_left, "x"
            end

            if u then
                return tinfo.edge_bottom, "y"
            end

            if l then
                return tinfo.edge_left
            end

            if d then
                return tinfo.edge_bottom
            end
        elseif count == 2 then
            if u and r then
                return tinfo.edge_bl_corner_out, "xy"
            end

            if r and d then
                return tinfo.edge_bl_corner_out, "x"
            end

            if d and l then
                return tinfo.edge_bl_corner_out
            end

            if l and u then
                return tinfo.edge_bl_corner_out, "y"
            end
        else
            goto unknown
        end

        ::unknown::
        return tinfo.top
        -- if r and not l and not u and not d then
        --     return tinfo.edge_left, "x"
        -- end
    end

    local function calc_tex_uv(x, y, z, is_side)
        local id, flip = calc_tex_id(x, y, z, is_side)

        local cols = 16
        local rows = 16
        local tw = 1.0 / cols
        local th = 1.0 / rows

        local tx = id % cols * tw
        local ty = math.floor(id / cols) * th

        local u0, v0 = tx, ty
        local u1, v1 = tx + tw, ty + th

        if flip then
            if string.find(flip, "x", 1, true) then
                u0, u1 = u1, u0
            end

            if string.find(flip, "y", 1, true) then
                v0, v1 = v1, v0
            end
        end

        v1, v0 = v0, v1
        return u0, v0, u1, v1
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
                    local u0, v0, u1, v1 = calc_tex_uv(x, y, z, true)

                    tappend(vertices,
                        {
                            x + 1, y, z,
                            u1, v0,
                            1, 0, 0,
                            1, 1, 1, 1
                        },
                        {
                            x + 1, y + 1, z,
                            u0, v0,
                            1, 0, 0,
                            1, 1, 1, 1
                        },
                        {
                            x + 1, y + 1, z + 1,
                            u0, v1,
                            1, 0, 0,
                            1, 1, 1, 1
                        },
                        {
                            x + 1, y, z + 1,
                            u1, v1,
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
                    local u0, v0, u1, v1 = calc_tex_uv(x, y, z, true)
                    
                    tappend(vertices,
                        {
                            x, y + 1, z,
                            u1, v0,
                            -1, 0, 0,
                            1, 1, 1, 1
                        },
                        {
                            x, y, z,
                            u0, v0,
                            -1, 0, 0,
                            1, 1, 1, 1
                        },
                        {
                            x, y, z + 1,
                            u0, v1,
                            -1, 0, 0,
                            1, 1, 1, 1
                        },
                        {
                            x, y + 1, z + 1,
                            u1, v1,
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
                    local u0, v0, u1, v1 = calc_tex_uv(x, y, z, true)

                    tappend(vertices,
                        {
                            x + 1, y + 1, z,
                            u1, v0,
                            0, 1, 0,
                            1, 1, 1, 1
                        },
                        {
                            x, y + 1, z,
                            u0, v0,
                            0, 1, 0,
                            1, 1, 1, 1
                        },
                        {
                            x, y + 1, z + 1,
                            u0, v1,
                            0, 1, 0,
                            1, 1, 1, 1
                        },
                        {
                            x + 1, y + 1, z + 1,
                            u1, v1,
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
                    local u0, v0, u1, v1 = calc_tex_uv(x, y, z, true)

                    tappend(vertices,
                        {
                            x, y, z,
                            u1, v0,
                            0, -1, 0,
                            1, 1, 1, 1
                        },
                        {
                            x + 1, y, z,
                            u0, v0,
                            0, -1, 0,
                            1, 1, 1, 1
                        },
                        {
                            x + 1, y, z + 1,
                            u0, v1,
                            0, -1, 0,
                            1, 1, 1, 1
                        },
                        {
                            x, y, z + 1,
                            u1, v1,
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
                    local u0, v0, u1, v1 = calc_tex_uv(x, y, z, false)

                    tappend(vertices,
                        {
                            x + 1, y + 1, z + 1,
                            u1, v0,
                            0, 0, 1,
                            1, 1, 1, 1
                        },
                        {
                            x, y + 1, z + 1,
                            u0, v0,
                            0, 0, 1,
                            1, 1, 1, 1
                        },
                        {
                            x, y, z + 1,
                            u0, v1,
                            0, 0, 1,
                            1, 1, 1, 1
                        },
                        {
                            x + 1, y, z + 1,
                            u1, v1,
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

    local mesh = r3d.mesh.new(vertices, "triangles", "static")
    mesh:setVertexMap(indices)

    return mesh

    -- local out = io.open("../test.obj", "w")
    -- assert(out, "could not open test.obj")

    -- for _, vertex in ipairs(vertices) do
    --     out:write(("v %f %f %f\n"):format(vertex[1], vertex[2], vertex[3]))
    --     out:write(("vt %f %f\n"):format(vertex[4], vertex[5]))
    -- end

    -- for i=1, #indices, 3 do
    --     local a, b, c = indices[i], indices[i+1], indices[i+2]
    --     out:write(("f %i/%i %i/%i %i/%i\n"):format(a,a, b,b, c,c))
    -- end

    -- out:close()
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

    self.world = r3d.world()

    local mesh = create_mesh({ w = vox_w, h = vox_h, data = vox_data })
    local tex = Lg.newImage("res/tilesets/test_tileset.png")
    mesh:setTexture(tex)
    tex:release()

    self.test_tex = Lg.newImage("res/robot.png")
    self.test_tex2 = Lg.newImage("res/swatPixelart.png")

    self.model = r3d.model(mesh)
    self.model2 = r3d.model(mesh)
    self.batch = r3d.batch()
    self.batch.opaque = false
    self.batch.shader = "shaded_ignore_normal"
    self.batch.double_sided = true

    self.model.shader = "shaded_alpha_influenceg"
    self.model:set_scale(16, 16, 16)
    -- self.model2:set_position(5, 0, -4)

    self.world:add_object(self.model)
    self.world:add_object(self.model2)
    self.world:add_object(self.batch)
end

function scene.unload()
    assert(self)
    self.model:release()
    self.world:release()
    self = nil
end

function scene.update(dt)
    local pan_speed = 160.0
    local mx, my = Input.players[1]:get("move")

    self.cam_x = self.cam_x + mx * pan_speed * dt
    self.cam_y = self.cam_y + my * pan_speed * dt
end

function scene.draw()
    local cam_x = math.floor(self.cam_x)
    local cam_y = math.floor(self.cam_y)

    self.world.cam.transform =
        -- mat4.scale(nil, 1.0, 1.0, 1.0) *
        mat4.rotation_z(nil, -MOUSE_Y / 100) *
        mat4.translation(nil, cam_x, cam_y, 0.0)
    
    -- self.world.cam:set_position(self.cam_x, self.cam_y, 0.0)
    self.world.cam.frustum_width = DISPLAY_WIDTH
    self.world.cam.frustum_height = DISPLAY_HEIGHT

    self.model.transform =
        mat4.scale(nil, 16.0, 16.0, 16.0)
        -- * mat4.rotation_z(nil, -MOUSE_Y / 100)
    
    self.batch:clear()

    self.batch:add_image(self.test_tex,
        mat4.identity()
        :translation(cam_x, cam_y, math.sin(love.timer.getTime()) * 32.0)
        :rotation_x(math.pi / 2))

    self.batch:add_image(self.test_tex,
        mat4.identity()
        :translation(cam_x + 20, cam_y, math.sin(love.timer.getTime()) * 32.0)
        :rotation_x(math.pi / 2))

    self.batch:add_image(self.test_tex2,
        mat4.identity()
        :translation(cam_x + 20, cam_y + 20, math.sin(love.timer.getTime()) * 32.0)
        :rotation_x(math.pi / 2))

    self.batch:add_image(self.test_tex2,
        mat4.identity()
        :translation(cam_x, cam_y + 20, math.sin(love.timer.getTime()) * 32.0)
        :rotation_x(math.pi / 2))
    
    self.world:draw()

    -- sun direction: vec3(0.4, -0.8, -1.0)

    -- local projection = mat4.oblique(0, frustum_width, 0, frustum_height, z_min, z_max)
    -- -- projection = mat4.rotation_z(love.timer.getTime()) * projection
    -- self.shader:send("u_projection", projection)
    -- self.shader:send("u_modelview", model_mat * view_mat)
    
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
    -- Lg.draw(self.mesh)

    -- (-1) * (-1 + (b) / (b - a)) + 1.0
    
    -- Lg.pop()
end

return scene