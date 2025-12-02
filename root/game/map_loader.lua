local map_loader = {}
local tiled = require("tiled")
local r3d = require("r3d")

---@class game.Map
---@field w integer
---@field h integer
---@field tw integer
---@field th integer
---@field data integer[][]
---@field tiled_map pklove.tiled.Map

local tinsert = table.insert

local function tappend(t, ...)
    for i=1, select("#", ...) do
        local v = select(i, ...)
        tinsert(t, v)
    end
end

---@param map game.Map
function map_loader.create_mesh(map)
    assert(map.tw == 16)
    assert(map.th == 16)
    
    ---@type number[][]
    local vertices = {}
    ---@type integer[]
    local indices = {}

    local voxel_depth = #map.data
    local function get_voxel(x, y, z)
        if x < 0 or y < 0 or z < 0 or x >= map.w or y >= map.h or z >= voxel_depth then
            return 0
        end

        return map.data[z+1][y * map.w + x + 1]
    end

    local tile_data = {
        [1] = {
            side                  = 5,
            edge_bottom           = 1,
            edge_left             = 2,
            edge_bl_corner_in     = 3,
            edge_bl_corner_out    = 4,
            top                   = 0,
        },
        [2] = {
            side                  = 6,
            edge_bottom           = 6,
            edge_left             = 6,
            edge_bl_corner_in     = 6,
            edge_bl_corner_out    = 6,
            top                   = 6,
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
        for y=0, map.h-1 do
            for x=0, map.w-1 do
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

---@param map_path string
---@return game.Map
function map_loader.load(map_path)
    local map = tiled.loadMap(map_path)

    local vox_w = map.width
    local vox_h = map.height

    ---@type {w:integer, h:integer, data:integer[][]}
    local vox_data = {}

    for _, layer in ipairs(map.layers) do
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

    ---@type game.Map
    local map_data = {
        tiled_map = map,
        w = vox_w,
        h = vox_h,
        tw = 16,
        th = 16,
        data = vox_data
    }

    return map_data
end


return map_loader