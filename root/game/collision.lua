local collision = {}

collision.margin = 0.001

---@param rx0 number rect 0 center x
---@param ry0 number rect 0 center y
---@param rw0 number rect 0 width
---@param rh0 number rect 0 height
---@param rx1 number rect 1 center x
---@param ry1 number rect 1 center y
---@param rw1 number rect 1 width
---@param rh1 number rect 1 height
---@return number? penetration
---@return number? dx
---@return number? dy
function collision.rect_rect_intersection(rx0, ry0, rw0, rh0, rx1, ry1, rw1, rh1)
    local xe0 = rw0 / 2.0
    local ye0 = rh0 / 2.0
    local xe1 = rw1 / 2.0
    local ye1 = rh1 / 2.0

    local l0 = rx0 - xe0 + collision.margin
    local r0 = rx0 + xe0 - collision.margin
    local t0 = ry0 - ye0 + collision.margin
    local b0 = ry0 + ye0 - collision.margin

    local l1 = rx1 - xe1
    local r1 = rx1 + xe1
    local t1 = ry1 - ye1
    local b1 = ry1 + ye1
    
    -- local pr = r0 - l1
    -- local pt = b0 - t1
    -- local pl = r1 - l0
    -- local pb = b1 - t0
    local pl = r0 - l1
    local pt = b0 - t1
    local pr = r1 - l0
    local pb = b1 - t0
    local mp = math.min(pr, pt, pl, pb)
    if mp < 0 then
        return
    end

    local nx, ny

    if mp == pl then
        nx, ny = -1, 0
    elseif mp == pt then
        nx, ny = 0, -1
    elseif mp == pr then
        nx, ny = 1, 0
    elseif mp == pb then
        nx, ny = 0, 1
    end

    return mp + collision.margin, nx, ny
end

---@param cx number circle center x
---@param cy number circle center y
---@param cr number circle radius
---@param rx number rect center x
---@param ry number rect center y
---@param rw number rect width
---@param rh number rect height
---@return number? penetration
---@return number? dx
---@return number? dy
function collision.circle_rect_intersection(cx, cy, cr, rx, ry, rw, rh)
    local rxe = rw / 2.0
    local rye = rh / 2.0
    local rl = rx - rxe
    local rr = rx + rxe
    local rt = ry - rye
    local rb = ry + rye

    local px = math.clamp(cx, rl, rr)
    local py = math.clamp(cy, rt, rb)
    local dx = cx - px
    local dy = cy - py
    local dsq = dx * dx + dy * dy
    local test_radius = cr - collision.margin

    if dsq <= test_radius * test_radius then
        local dist = math.sqrt(dsq)
        return cr - dist, dx, dy
    end
end

---@param ray_x number
---@param ray_y number
---@param ray_dx number
---@param ray_dy number
---@param rx number
---@param ry number
---@param rw number
---@param rh number
---@return number? distance, number? nx, number? ny
function collision.ray_rect_intersection(ray_x, ray_y, ray_dx, ray_dy,
                                         rx, ry, rw, rh)
    -- if (rayDir.lengthSquared() == 0) return null;
    local ray_len = math.length(ray_dx, ray_dy)
    if ray_len == 0.0 then
        return
    end

    ray_dx = ray_dx / ray_len
    ray_dy = ray_dy / ray_len

    local rxe = rw / 2.0
    local rye = rh / 2.0
    local rl = rx - rxe
    local rr = rx + rxe
    local rt = ry - rye
    local rb = ry + rye

    -- get ray distances for all four rect sides
    local d_left  = (rl - ray_x) / ray_dx
    local d_right = (rr - ray_x) / ray_dx
    local d_top   = (rt - ray_y) / ray_dy
    local d_bot   = (rb - ray_y) / ray_dy

    -- get intersections for each side (the other component is inferred by the side)
    local p_left  = ray_y + ray_dy * d_left;
    local p_right = ray_y + ray_dy * d_right;
    local p_top   = ray_x + ray_dx * d_top;
    local p_bot   = ray_x + ray_dx * d_bot;

    -- get the minimum positive distance
    local min_dist = math.huge
    if d_left >= 0.0 and p_left > rt and p_left < rb then
        min_dist = math.min(d_left, min_dist)
    end
    if d_right >= 0.0 and p_right > rt and p_right < rb then
        min_dist = math.min(d_right, min_dist)
    end
    if d_top >= 0.0 and p_top > rl and p_top < rr then
        min_dist = math.min(d_top, min_dist)
    end
    if d_bot >= 0.0 and p_bot > rl and p_bot < rr then
        min_dist = math.min(d_bot, min_dist)
    end

    -- if minDist is still POSITIVE_INFINITY, no intersections were found
    if min_dist == math.huge then
        return
    end

    -- get the normal of the intersecting side
    local nx, ny
    if min_dist == d_left then
        nx, ny = -1, 0
    elseif min_dist == d_right then
        nx, ny = 1, 0
    elseif min_dist == d_top then
        nx, ny = 0, -1
    elseif min_dist == d_bot then
        nx, ny = 0, 1
    else
        error("impossible else branch")
    end

    return min_dist, nx, ny
end

return collision