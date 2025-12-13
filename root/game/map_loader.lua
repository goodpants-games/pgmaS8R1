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
local bnot = bit.bnot

local ADJBIT_R  = 0x1
local ADJBIT_U  = 0x2
local ADJBIT_L  = 0x4
local ADJBIT_D  = 0x8
local ADJBIT_TR = 0x10
local ADJBIT_TL = 0x20
local ADJBIT_BL = 0x40
local ADJBIT_BR = 0x80

local TILE_TEXTURE_DATA = {
    [1] = {
        side = 5,
        edge = "metal"
    },
    [2] = {
        side = 6,
    },
    [3] = {
        side = 7,
    },
    [4] = {
        side = 37,
        edge = "concrete"
    },
    [5] = {
        side = -1,
        top = 8,
        transparent = true,
    },
    [6] = {
        side = 9,
        edge = "concrete",
    },
    [7] = {
        side = 10,
        edge = "concrete",
    },
    [8] = {
        side = 11,
        edge = "concrete",
    },
    [9] = {
        side = 12,
        edge = "concrete",
    },
    [10] = {
        side = 13,
        edge = "concrete",
    },
    [11] = {
        side = 14,
        edge = "concrete",
    },
    [12] = {
        side = 15,
        edge = "concrete",
    },
    [13] = {
        side = 11,
        edge = "flesh",
    },
    [14] = {
        side = 14,
        edge = "flesh",
    },
    [15] = {
        side = 15,
        edge = "flesh",
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

    -- collect inner corners (must be done before diagonal connections are proc)
    local itr,itl,ibl,ibr = tr,tl,bl,br
    if l then
        itl = false
        ibl = false
    end
    if r then
        itr = false
        ibr = false
    end
    if u then
        itl = false
        itr = false
    end
    if d then
        ibl = false
        ibr = false
    end

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
    -- (aka outer corner)
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
    local inner_corner_count = 0
    if itr then inner_corner_count=inner_corner_count+1 end
    if itl then inner_corner_count=inner_corner_count+1 end
    if ibl then inner_corner_count=inner_corner_count+1 end
    if ibr then inner_corner_count=inner_corner_count+1 end

    local edge_dx = (r and 1 or 0) - (l and 1 or 0)
    local edge_dy = (d and 1 or 0) - (u and 1 or 0)

    -- straght edge (corners:0 edges:1)
    -- (or inside)
    -- only a quad is needed. normal for all vertices is wall direction
    if (edge_count == 1 and inner_corner_count == 0) or (edge_count == 0 and corner_count == 0) then
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
    -- local inner_corner = corner_count == 1 and open_corner_count == 0
    -- local outer_corner = open_corner_count == 1
    local inner_corner = edge_count == 0 and inner_corner_count == 1 and open_corner_count == 0
    local outer_corner = edge_count == 2 and open_corner_count == 1 and inner_corner_count == 0
    if inner_corner or outer_corner then
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

---Like ImageData:paste, but with alpha blending
---@param dst_img love.ImageData
---@param src_img love.ImageData
---@param dx integer?
---@param dy integer?
---@param sx integer?
---@param sy integer?
---@param sw integer?
---@param sh integer?
local function img_paste(dst_img, src_img, dx, dy, sx, sy, sw, sh)
    dx = dx or 0
    dy = dy or 0
    sx = sx or 0
    sy = sy or 0
    sw = sw or src_img:getWidth()
    sh = sh or src_img:getHeight()

    -- local src_w = src_img:getWidth()
    -- local src_h = src_img:getHeight()
    -- local dst_w = dst_img:getWidth()
    -- local dst_h = dst_img:getHeight()

    -- if sw < 0 or sh < 0 then
    --     error("invalid source rect", 2)
    -- end

    -- if dx >= dst_w or dy >= dst_h then
    --     return
    -- end

    -- if sx < 0 then
    --     sw = sw + sx
    --     sx = 0
    -- end
    -- if sy < 0 then
    --     sh = sh + sy
    --     sy = 0
    -- end
    -- if sx + sw > src_w then
        
    -- end
    -- if sx >= src_img:getWidth() or
    --    sy >= src_img:getHeight()
    -- then
    --     return
    -- end

    -- if dx < 0 then
    --     sx = sx - dx
    --     sw = sw + dx
    --     dx = 0
    -- end
    -- if dy < 0 then
    --     sy = sy - dy
    --     sh = sh + dy
    --     dy = 0
    -- end
    -- if dx + sw > dst_w then
    --     sw = dst_w - dx
    -- end
    -- if dy + sh > dst_h then
    --     sh = dst_h - dy
    -- end

    if    dx < 0 or dy < 0
       or sx < 0 or sy < 0
       or dx + sw > dst_img:getWidth()
       or dy + sh > dst_img:getHeight()
       or sx + sw > src_img:getWidth()
       or sy + sh > src_img:getHeight()
    then
        error("rect out of bounds", 2)
    end

    local getp = dst_img.getPixel
    local setp = src_img.setPixel
    for y=0, sh-1 do
        local dsty = dy + y
        local srcy = sy + y

        for x=0, sw-1 do
            local dstx = dx + x
            local srcx = sx + x

            local sr, sg, sb, sa = getp(src_img, srcx, srcy)
            local dr, dg, db, da = getp(dst_img, dstx, dsty)
            local inv_sa = 1.0 - sa

            local r, g, b, a
            if da == 0.0 then
                r, g, b = sr, sg, sb
            else
                r = sr * sa + dr * inv_sa
                g = sg * sa + dg * inv_sa
                b = sb * sa + db * inv_sa
            end
            a = sa + da * inv_sa

            setp(dst_img, dstx, dsty, r, g, b, a)
        end
    end
end

---@param names string[]
---@return love.Image
---@return {[string]:{[integer]:{u0:number, v0:number, u1:number, v1:number}}}
local function create_edge_atlas(names)
    local cell_rows = 32
    local cell_cols = 32

    local img_w = cell_cols * 16
    local img_h = cell_rows * 16
    local img = love.image.newImageData(img_w, img_h)

    ---@type {[string]:love.ImageData}
    local sets = {}
    ---@type {[string]:{[integer]:{u0:number, v0:number, u1:number, v1:number}}}
    local tex_data = {}
    for _, name in ipairs(names) do
        sets[name] = love.image.newImageData(("res/tilesets/edge_sets/%s.png"):format(name))
        tex_data[name] = {}
    end
    
    local ci = 1 -- leave first cell empty

    for _, set_name in ipairs(names) do
        tex_data[set_name][0] = {
            u0 = 0        / img_w,
            v0 = 0        / img_h,
            u1 = (0 + 16) / img_w,
            v1 = (0 + 16) / img_h,
        }

        for flags=1, 0xFF do
            -- first, check if configuration is impossible
            -- note that corners refer to inner corners, not outer corners; outer
            -- corners are simply a combination of the two adjacent edges being set.
            -- i must not have ambiguity.
            if    band(flags, ADJBIT_R)~=0 and band(flags, bor(ADJBIT_BR, ADJBIT_TR))~=0
               or band(flags, ADJBIT_U)~=0 and band(flags, bor(ADJBIT_TR, ADJBIT_TL))~=0
               or band(flags, ADJBIT_L)~=0 and band(flags, bor(ADJBIT_TL, ADJBIT_BL))~=0
               or band(flags, ADJBIT_D)~=0 and band(flags, bor(ADJBIT_BL, ADJBIT_BR))~=0
            then
                goto continue
            end

            local cx = ci % cell_cols
            local cy = math.floor(ci / cell_cols)
            local px = cx * 16
            local py = cy * 16

            local src_img = sets[set_name]
            tex_data[set_name][flags] = {
                u0 = px        / img_w,
                v0 = py        / img_h,
                u1 = (px + 16) / img_w,
                v1 = (py + 16) / img_h,
            }
            
            -- edges
            if band(flags, ADJBIT_R)~=0 then
                img_paste(img, src_img, px, py, 0, 0, 16, 16)
            end
            if band(flags, ADJBIT_U)~=0 then
                img_paste(img, src_img, px, py, 16, 0, 16, 16)
            end
            if band(flags, ADJBIT_L)~=0 then
                img_paste(img, src_img, px, py, 32, 0, 16, 16)
            end
            if band(flags, ADJBIT_D)~=0 then
                img_paste(img, src_img, px, py, 48, 0, 16, 16)
            end

            -- edge corners
            if band(bnot(flags), bor(ADJBIT_R, ADJBIT_D))==0 then
                img_paste(img, src_img, px, py, 0, 32, 16, 16)
            end
            if band(bnot(flags), bor(ADJBIT_R, ADJBIT_U))==0 then
                img_paste(img, src_img, px, py, 16, 32, 16, 16)
            end
            if band(bnot(flags), bor(ADJBIT_L, ADJBIT_U))==0 then
                img_paste(img, src_img, px, py, 32, 32, 16, 16)
            end
            if band(bnot(flags), bor(ADJBIT_L, ADJBIT_D))==0 then
                img_paste(img, src_img, px, py, 48, 32, 16, 16)
            end

            -- corners
            if band(flags, ADJBIT_BR)~=0 then
                img_paste(img, src_img, px, py, 0, 16, 16, 16)
            end
            if band(flags, ADJBIT_TR)~=0 then
                img_paste(img, src_img, px, py, 16, 16, 16, 16)
            end
            if band(flags, ADJBIT_TL)~=0 then
                img_paste(img, src_img, px, py, 32, 16, 16, 16)
            end
            if band(flags, ADJBIT_BL)~=0 then
                img_paste(img, src_img, px, py, 48, 16, 16, 16)
            end
            
            ci=ci+1
            ::continue::
        end
    end

    for _, v in pairs(sets) do
        v:release()
    end

    local out_tex = Lg.newImage(img)
    img:release()

    return out_tex, tex_data
end

map_loader.create_edge_atlas = create_edge_atlas

---@param map game.Map
---@param edge_data {[string]:{[integer]:{u0:number, v0:number, u1:number, v1:number}}}
---@return love.Mesh mesh, love.Mesh? edge_mesh
function map_loader.create_mesh(map, edge_data)
    assert(map.tw == 16)
    assert(map.th == 16)
    
    ---@type number[][]
    local vertices = {}
    ---@type integer[]
    local indices = {}
    local vi = 1

    ---@type number[][]
    local evertices = {}
    ---@type integer[]
    local eindices = {}
    local evi = 1

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
        local cn_type = TILE_TEXTURE_DATA[tid].edge
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

    local function calc_edge_uv(edge, adj)
        -- change meaning of corner flags. it should only mean inner corners,
        -- not outer corners
        if band(adj, bor(ADJBIT_R, ADJBIT_D))~=0 then
            adj = band(adj, bnot(ADJBIT_BR))
        end
        if band(adj, bor(ADJBIT_R, ADJBIT_U))~=0 then
            adj = band(adj, bnot(ADJBIT_TR))
        end
        if band(adj, bor(ADJBIT_L, ADJBIT_U))~=0 then
            adj = band(adj, bnot(ADJBIT_TL))
        end
        if band(adj, bor(ADJBIT_L, ADJBIT_D))~=0 then
            adj = band(adj, bnot(ADJBIT_BL))
        end
        
        local data = edge_data[edge][adj]
        return data.u0, data.v0, data.u1, data.v1
    end

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
                math.lerp(u0, u1, i), math.lerp(v0, v1, j)
            vert[6], vert[7], vert[8] =
                nx, ny, (nx == 0 and ny == 0) and 1 or 0
            vert[9], vert[10], vert[11], vert[12] =
                r, g, b, a
            
            table.insert(evertices, vert)
        end

        for i=1, #edge_calc_verts, 3 do
            tappend(eindices, evi+0, evi+1, evi+2)
            evi=evi+3
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

                local tex_dat = TILE_TEXTURE_DATA[tid]
                assert(tex_dat)

                local side_u0, side_u1, side_v0, side_v1 = calc_tex_uv(tex_dat.side)

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
                    if z == 0 or not tex_dat.edge then
                        local u0, v0, u1, v1 = calc_tex_uv(tex_dat.top or tex_dat.side)

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
                    else
                        local adj = calc_adjacency(x, y, z)
                        local u0, v0, u1, v1 = calc_edge_uv(tex_dat.edge, adj)

                        edge_calc_push(
                            x, y, z + 1,
                            adj,
                            u0, v0, u1, v1,
                            1, 1, 1, 1)
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

    local edge_mesh ---@type love.Mesh?
    if evi > 1 then
        edge_mesh = r3d.mesh.new(evertices, "triangles", "static")
        edge_mesh:setVertexMap(eindices)
    end

    return mesh, edge_mesh

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