local Concord = require("concord")
local collision = require("game.collision")

local system = Concord.system({
    pool = {"position", "velocity"}
})

local function get_tile_collision_bounds(cx, cy, tw, th, colv)
    local colx, coly, colw, colh
    if colv == 1 then
        colx = (cx+0.5) * tw
        coly = (cy+0.5) * th
        colw = tw
        colh = th
    elseif colv == 2 then
        colx = (cx+0.5) * tw
        coly = (cy+0.75) * th
        colw = tw
        colh = th / 2
    else
        error("unknown collision type " .. colv)
    end

    return colx, coly, colw, colh
end

---@param ent any
---@param game Game
local function resolve_tilemap_collisions(ent, game)
    local pos = assert(ent.position)
    local vel = assert(ent.velocity)
    local collider = assert(ent.collision)
    local cxe = collider.w / 2 -- collider x extents
    local cye = collider.h / 2 -- collider y extents

    local tw, th = game.tile_width, game.tile_height
    local margin = collision.margin

    for _=1, 4 do
        local minx = math.floor((pos.x - cxe + margin) / tw)
        local maxx = math.ceil((pos.x + cxe - margin) / th)
        local miny = math.floor((pos.y - cye + margin) / tw)
        local maxy = math.ceil((pos.y + cye - margin) / th)

        -- find the closest intersecting cell
        -- local cell_value = 0
        local cx = -1
        local cy = -1
        local cell_min_dist = math.huge
        local col_pn, col_nx, col_ny

        for y=miny, maxy-1 do
            for x=minx, maxx-1 do
                local v = game:get_col(x, y)
                if v ~= 0 then
                    local dx = (x+0.5) * tw - pos.x
                    local dy = (y+0.5) * th - pos.y
                    local dist = dx*dx + dy*dy

                    if dist < cell_min_dist or true then
                        local colx, coly, colw, colh =
                            get_tile_collision_bounds(x, y, tw, th, v)
                        local pn, nx, ny =
                            collision.rect_rect_intersection(
                                pos.x, pos.y, collider.w, collider.h,
                                colx, coly, colw, colh)

                        if pn and (col_pn == nil or pn > col_pn) then
                            cx = x
                            cy = y
                            cell_min_dist = dist
                            col_pn, col_nx, col_ny = pn, nx, ny

                            Debug.draw:color(1, 1, 1)
                            Debug.draw:rect_lines(colx - colw / 2.0,
                                                  coly - colh / 2.0,
                                                  colw, colh)
                        end
                    end

                    -- if dist < cell_min_dist then
                    --     cell_value = v
                    --     cx = x
                    --     cy = y
                    --     cell_min_dist = dist
                    -- end
                end
            end
        end

        if col_pn then
            Debug.draw:color(1, 0, 0)
            Debug.draw:rect_lines(cx * tw, cy * th, tw, th)
            -- -- print("intersection!")
            -- local colx, coly, colw, colh
            -- if cell_value == 1 then
            --     colx = (cx+0.5) * tw
            --     coly = (cy+0.5) * th
            --     colw = tw
            --     colh = th
            -- elseif cell_value == 2 then
            --     colx = (cx+0.5) * tw
            --     coly = (cy+0.75) * th
            --     colw = tw
            --     colh = th / 2
            -- else
            --     error("unknown collision type " .. cell_value)
            -- end

            -- local penetration, nx, ny =
            --     rect_collision_resolution(pos.x, pos.y, collider.w, collider.h,
            --                               colx, coly, colw, colh)
            local penetration, nx, ny = col_pn, col_nx, col_ny

            if penetration then
                pos.x = pos.x + nx * penetration
                pos.y = pos.y + ny * penetration

                local px, py = -ny, nx
                local pdot = px * vel.x + py * vel.y

                vel.x = px * pdot
                vel.y = py * pdot
            end
        else
            break
        end
    end
end

function system:tick()
    local game = self:getWorld().game

    for _, ent in ipairs(self.pool) do
        local pos = ent.position
        local vel = ent.velocity

        pos.x = pos.x + vel.x
        pos.y = pos.y + vel.y

        if ent.collision then
            resolve_tilemap_collisions(ent, game)
        end
    end
end

return system