local Concord = require("concord")

local COLLISION_MARGIN = 1

local system = Concord.system({
    pool = {"position", "velocity"}
})

local function rect_collision_resolution(rx0, ry0, rw0, rh0, rx1, ry1, rw1, rh1)
    local xe0 = rw0 / 2.0
    local ye0 = rh0 / 2.0
    local xe1 = rw1 / 2.0
    local ye1 = rh1 / 2.0

    local l0 = rx0 - xe0
    local r0 = rx0 + xe0
    local t0 = ry0 - ye0
    local b0 = ry0 + ye0

    local l1 = rx1 - xe1
    local r1 = rx1 + xe1
    local t1 = ry1 - ye1
    local b1 = ry1 + ye1
    
    local pr = r0 - l1
    local pt = b0 - t1
    local pl = r1 - l0
    local pb = b1 - t0
    local mp = math.min(pr, pt, pl, pb)
    if mp < 0 then
        return
    end

    local nx, ny

    if mp == pl then
        nx, ny = -1, 0
    elseif mp == pt then
        nx, ny = 0, 1
    elseif mp == pr then
        nx, ny = 1, 0
    elseif mp == pb then
        nx, ny = 0, -1
    end

    return mp, nx, ny
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

    for _=0, 4 do
        local minx = math.floor((pos.x - cxe + COLLISION_MARGIN) / tw)
        local maxx = math.ceil((pos.x + cxe - COLLISION_MARGIN) / th)
        local miny = math.floor((pos.y - cye + COLLISION_MARGIN) / tw)
        local maxy = math.ceil((pos.y + cye - COLLISION_MARGIN) / th)

        -- find the closest intersecting cell
        local cell_found = false
        local cx = -1
        local cy = -1
        local cell_min_dist = math.huge
        for y=miny, maxy-1 do
            for x=minx, maxx-1 do
                if game:get_col(x, y) ~= 0 then
                    local dx = (x+0.5) * tw - pos.x
                    local dy = (y+0.5) * th - pos.y
                    local dist = dx*dx + dy*dy

                    if dist < cell_min_dist then
                        cell_found = true
                        cx = x
                        cy = y
                        cell_min_dist = dist
                    end
                end
            end
        end

        if cell_found then
            -- print("intersection!")
            Debug.draw.rect_lines(cx * game.tile_width, cy * game.tile_height, game.tile_width, game.tile_height)

            local penetration, nx, ny =
                rect_collision_resolution(pos.x, pos.y, collider.w, collider.h,
                                        (cx+0.5) * tw, (cy+0.5) * th, tw, th)

            assert(penetration)
            pos.x = pos.x - nx * penetration
            pos.y = pos.y - ny * penetration

            local px, py = ny, -nx
            local pdot = px * vel.x + py * vel.y

            vel.x = px * pdot
            vel.y = py * pdot
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