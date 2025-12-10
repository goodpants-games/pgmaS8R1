local map_loader = {}
local tiled = require("tiled")
local r3d = require("r3d")
local bit = require("bit")

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

local bor = bit.bor
local band = bit.band

local ADJBIT_R  = 0x1
local ADJBIT_U  = 0x2
local ADJBIT_L  = 0x4
local ADJBIT_D  = 0x8
local ADJBIT_TR = 0x10
local ADJBIT_TL = 0x20
local ADJBIT_BL = 0x40
local ADJBIT_BR = 0x80

local TOP_TEXTURES = {
    metal = {
        edge_bottom           = 1,
        edge_left             = 2,
        edge_bl_corner_in     = 3,
        edge_bl_corner_out    = 4,
        edge_all              = 16,
        top                   = 0,
    },
    concrete = {
        edge_bottom           = 1,
        edge_left             = 2,
        edge_bl_corner_in     = 3,
        edge_bl_corner_out    = 4,
        edge_all              = 16,
        top                   = 0,
    },
    mesh_chain = {
        edge_bottom           = 8,
        edge_left             = 8,
        edge_bl_corner_in     = 8,
        edge_bl_corner_out    = 8,
        edge_all              = 8,
        top                   = 8,
    },
    flesh = {
        edge_bottom           = 96,
        edge_left             = 97,
        edge_bl_corner_in     = 98,
        edge_bl_corner_out    = 99,
        edge_all              = 100,
        top                   = 8,
    }
}

local TILE_TEXTURE_DATA = {
    [1] = {
        side =   5,
        top     = "metal"
    },
    [2] = {
        side                  = 6,
    },
    [3] = {
        side                  = 7,
    },
    [4] = {
        side                  = 37,
        top                  = "concrete"
    },
    [5] = {
        side  = -1,
        top = "mesh_chain",
        transparent           = true,
    },
    [6] = {
        side = 9,
        top = "concrete",
    },
    [7] = {
        side = 10,
        top = "concrete",
    },
    [8] = {
        side = 11,
        top = "concrete",
    },
    [9] = {
        side = 12,
        top = "concrete",
    },
    [10] = {
        side = 13,
        top = "concrete",
    },
    [11] = {
        side = 14,
        top = "concrete",
    },
    [12] = {
        side = 15,
        top = "concrete",
    },
    [13] = {
        side = 11,
        top = "flesh",
    },
    [14] = {
        side = 14,
        top = "flesh",
    },
    [15] = {
        side = 15,
        top = "flesh",
    },
    [64] = {
        transparent = true,
    }
}

---@param out number[][]
---@param r boolean
---@param u boolean
---@param l boolean
---@param d boolean
---@param tr boolean
---@param tl boolean
---@param bl boolean
---@param br boolean
---@param u0 number
---@param v0 number
---@param u1 number
---@param v1 number
local function edge_calc_rec(out, r,u,l,d, tr,tl,bl,br, u0,v0,u1,v1, depth)
    assert(depth <= 2)

    -- handle diagonal connections
    if r and d then
        br = true
    end
    if l and d then
        bl = true
    end
    if l and u then
        tl = true
    end
    if r and u then
        tr = true
    end
    
    -- open corner count
    local otr,otl,obl,obr = tr,tl,bl,br
    if not l then
        otl = false
        obl = false
    end
    
    if not r then
        otr = false
        obr = false
    end
    
    if not u then
        otl = false
        otr = false
    end

    if not d then
        obl = false
        obr = false
    end

    -- count edges and corners
    local edge_count = 0
    if r then edge_count=edge_count+1 end
    if u then edge_count=edge_count+1 end
    if l then edge_count=edge_count+1 end
    if d then edge_count=edge_count+1 end
    local corner_count = 0
    if tr then corner_count=corner_count+1 end
    if tl then corner_count=corner_count+1 end
    if bl then corner_count=corner_count+1 end
    if br then corner_count=corner_count+1 end
    local open_corner_count = 0
    if otr then open_corner_count=open_corner_count+1 end
    if otl then open_corner_count=open_corner_count+1 end
    if obl then open_corner_count=open_corner_count+1 end
    if obr then open_corner_count=open_corner_count+1 end

    local edge_dx = (r and 1 or 0) - (l and 1 or 0)
    local edge_dy = (d and 1 or 0) - (u and 1 or 0)

    -- straght edge (corners:0 edges:1)
    -- (or inside)
    -- only a quad is needed. normal for all vertices is wall direction
    if (open_corner_count == 0 and edge_count == 1) or (edge_count == 0 and corner_count == 0) then
        tappend(out,
            { u0, v0, edge_dx, edge_dy },
            { u0, v1, edge_dx, edge_dy },
            { u1, v1, edge_dx, edge_dy },

            { u1, v1, edge_dx, edge_dy },
            { u1, v0, edge_dx, edge_dy },
            { u0, v0, edge_dx, edge_dy }
        )
        return
    end

    -- outer corner: (corners: 1  edges: 2)
    -- inner corner: (corners: 1  edges: 0)
    -- split a quad into two triangles such that the split line touches the corner.
    -- reference point is at the opposite corner of the open corner
    -- calculate direction from reference point to quad edges
    -- normal of triangle will be the largest axis of the direction
    local inner_corner = corner_count == 1 and open_corner_count == 0
    local outer_corner = open_corner_count == 1
    if (inner_corner or outer_corner) and (edge_count == 2 or edge_count == 0) then
        if inner_corner then
            otr = tr
            otl = tl
            obl = bl
            obr = br
        end

        if obr or otl then
            local tri0x, tri0y -- left triangle normal x
            local tri1x, tri1y -- right triangle normal y

            if obr then
                tri0x, tri0y = 0.0, 1.0
                tri1x, tri1y = 1.0, 0.0
            else
                tri0x, tri0y = -1.0, 0.0
                tri1x, tri1y = 0.0, -1.0
            end

            if inner_corner then
                tri0x, tri1x = tri1x, tri0x
                tri0y, tri1y = tri1y, tri0y
            end

            tappend(out,
                { u0, v0, tri0x, tri0y },
                { u0, v1, tri0x, tri0y },
                { u1, v1, tri0x, tri0y },

                { u1, v1, tri1x, tri1y },
                { u1, v0, tri1x, tri1y },
                { u0, v0, tri1x, tri1y }
            )
        else
            assert(tr or bl)

            local tri0x, tri0y -- left triangle normal x
            local tri1x, tri1y -- right triangle normal y

            if obl then
                tri0x, tri0y = -1.0, 0.0
                tri1x, tri1y = 0.0, 1.0
            else
                tri0x, tri0y = 0.0, -1.0
                tri1x, tri1y = 1.0, 0.0
            end

            if inner_corner then
                tri0x, tri1x = tri1x, tri0x
                tri0y, tri1y = tri1y, tri0y
            end

            tappend(out,
                { u0, v0, tri0x, tri0y },
                { u0, v1, tri0x, tri0y },
                { u1, v0, tri0x, tri0y },

                { u1, v0, tri1x, tri1y },
                { u0, v1, tri1x, tri1y },
                { u1, v1, tri1x, tri1y }
            )
        end
        return
    end

    -- too complex! divide and conquer.
    local uc = (u0 + u1) / 2.0
    local vc = (v0 + v1) / 2.0

    -- top-left
    edge_calc_rec(
        out,
        false,u,l,false,
        false,tl,false,false,
        u0, v0, uc, vc,
        depth+1
    )

    -- bottom-left
    edge_calc_rec(
        out,
        false,false,l,d,
        false,false,bl,false,
        u0, vc, uc, v1,
        depth+1
    )

    -- bottom-right
    edge_calc_rec(
        out,
        r,false,false,d,
        false,false,false,br,
        uc, vc, u1, v1,
        depth+1
    )

    -- top-right
    edge_calc_rec(
        out,
        r,u,false,false,
        tr,false,false,false,
        uc, v0, u1, vc,
        depth+1
    )
end

---@param out number[][]
---@param adj integer
---@return nil
local function edge_calc(out, adj)
    return edge_calc_rec(
        out,
        
        band(adj, ADJBIT_R) ~= 0,
        band(adj, ADJBIT_U) ~= 0,
        band(adj, ADJBIT_L) ~= 0,
        band(adj, ADJBIT_D) ~= 0,

        band(adj, ADJBIT_TR) ~= 0,
        band(adj, ADJBIT_TL) ~= 0,
        band(adj, ADJBIT_BL) ~= 0,
        band(adj, ADJBIT_BR) ~= 0,

        0, 0, 1, 1,
        1
    )
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

    local function voxel_trans(x, y, z)
        local tid = get_voxel(x, y, z)
        if tid == 0 then return true end

        return TILE_TEXTURE_DATA[tid].transparent
    end

    ---@param tid integer
    ---@return string|integer|nil
    local function get_adj_connection_id(tid)
        if tid == 0 then
            return nil
        end

        ---@type string|integer
        local cn_type = TILE_TEXTURE_DATA[tid].top
        if not cn_type then
            cn_type = tid
        end

        return cn_type
    end

    local function calc_adjacency(x, y, z)
        local tid = get_voxel(x, y, z)
        if tid == 0 then return 0 end

        local cn_tp = get_adj_connection_id(tid)

        -- true if open, false if closed
        local r  = get_adj_connection_id(get_voxel(x+1, y, z)) ~= cn_tp
        local l  = get_adj_connection_id(get_voxel(x-1, y, z)) ~= cn_tp
        local u  = get_adj_connection_id(get_voxel(x, y-1, z)) ~= cn_tp
        local d  = get_adj_connection_id(get_voxel(x, y+1, z)) ~= cn_tp
        local br = get_adj_connection_id(get_voxel(x+1, y+1, z)) ~= cn_tp
        local bl = get_adj_connection_id(get_voxel(x-1, y+1, z)) ~= cn_tp
        local tl = get_adj_connection_id(get_voxel(x-1, y-1, z)) ~= cn_tp
        local tr = get_adj_connection_id(get_voxel(x+1, y-1, z)) ~= cn_tp

        local out = 0

        if r then out = bor(out, ADJBIT_R) end
        if u then out = bor(out, ADJBIT_U) end
        if l then out = bor(out, ADJBIT_L) end
        if d then out = bor(out, ADJBIT_D) end

        if tr then out = bor(out, ADJBIT_TR) end
        if tl then out = bor(out, ADJBIT_TL) end
        if bl then out = bor(out, ADJBIT_BL) end
        if br then out = bor(out, ADJBIT_BR) end

        return out
    end

    local function calc_tex_id(x, y, z, adj)
        local tid = get_voxel(x, y, z)
        if tid == 0 then return end

        local tile_info = TILE_TEXTURE_DATA[tid]
        if not tile_info then return end

        if not tile_info.top then
            return tile_info.side
        end

        local tinfo = TOP_TEXTURES[tile_info.top]

        -- if not adj then
        --     adj = calc_adjacency(x, y, z)
        -- end

        -- true if open, false if closed
        local r  = band(adj, ADJBIT_R) ~= 0
        local l  = band(adj, ADJBIT_L) ~= 0
        local u  = band(adj, ADJBIT_U) ~= 0
        local d  = band(adj, ADJBIT_D) ~= 0
        local br = band(adj, ADJBIT_BR) ~= 0
        local bl = band(adj, ADJBIT_BL) ~= 0
        local tl = band(adj, ADJBIT_TL) ~= 0
        local tr = band(adj, ADJBIT_TR) ~= 0

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
        return tinfo.edge_all
        -- if r and not l and not u and not d then
        --     return tinfo.edge_left, "x"
        -- end
    end

    ---@param id integer
    ---@param flip string?
    ---@return number?
    ---@return number?
    ---@return number?
    ---@return number?
    local function calc_tex_uv(id, flip)
        if id == -1 then
            return
        end

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
    local edge_calc_verts = {}

    local function edge_calc_push(x, y, z, adj, u0, v0, u1, v1, r, g, b, a)
        table.clear(edge_calc_verts)
        edge_calc(edge_calc_verts, adj)

        assert(#edge_calc_verts % 3 == 0)

        for _, vert in ipairs(edge_calc_verts) do
            local i, j, nx, ny = unpack(vert)

            vert[1], vert[2], vert[3] =
                x + i, y + j, z
            vert[4], vert[5] =
                math.lerp(u0, u1, i), math.lerp(v0, v1, 1 - j)
            vert[6], vert[7], vert[8] =
                nx, ny, (nx == 0 and ny == 0) and 1 or 0
            vert[9], vert[10], vert[11], vert[12] =
                r, g, b, a
            
            table.insert(vertices, vert)
        end

        for i=1, #edge_calc_verts, 3 do
            tappend(indices, vi+0, vi+1, vi+2)
            vi=vi+3
        end
    end

    for z=0, voxel_depth-1 do
        local i=1
        for y=0, map.h-1 do
            for x=0, map.w-1 do
                local tid = get_voxel(x, y, z)
                if tid == 0 or tid == 64 then
                    goto continue
                end

                assert(TILE_TEXTURE_DATA[tid])
                local side_u0, side_u1, side_v0, side_v1 = calc_tex_uv(TILE_TEXTURE_DATA[tid].side)

                -- right
                if side_u0 and voxel_trans(x + 1, y, z) then
                    local u0, v0, u1, v1 = side_u0, side_u1, side_v0, side_v1

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
                if side_u0 and voxel_trans(x - 1, y, z) then
                    local u0, v0, u1, v1 = side_u0, side_u1, side_v0, side_v1
                    
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
                if side_u0 and voxel_trans(x, y + 1, z) then
                    local u0, v0, u1, v1 = side_u0, side_u1, side_v0, side_v1

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
                if side_u0 and voxel_trans(x, y - 1, z) then
                    local u0, v0, u1, v1 = side_u0, side_u1, side_v0, side_v1

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
                if voxel_trans(x, y, z + 1) then                    
                    local adj = calc_adjacency(x, y, z)
                    local id, flip = calc_tex_id(x, y, z, adj)
                    local u0, v0, u1, v1 = calc_tex_uv(id, flip)

                    if z >= 1 then
                        edge_calc_push(
                            x, y, z + 1,
                            adj,
                            u0, v0, u1, v1,
                            1, 1, 1, 1)
                    else
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