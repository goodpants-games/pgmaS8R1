local Concord = require("concord")
local mat4 = require("r3d.mat4")
local Light = require("r3d.light")

local render_system = Concord.system({
    sprite_pool = {"position", "sprite"},
    light_pool = {"position", "light"},
    dbgdraw_pool = {"position", "collision"}
})

---Perform a binary search on an array.
---If the element was found, it returns true and the index of the element. If
---not, it returns false and the index where the element was expected to be.
---@param t any[]
---@param f fun(v,...):integer
---@param min integer?
---@param max integer?
---@param ... any
---@return boolean s, integer idx
local function binary_search(t, f, min, max, ...)
    min = min or 1
    max = max or #t

    if min > max then
        return false, min
    end

    local center = math.floor((max + min - 2) / 2) + 1
    local eval = f(t[center], ...)
    
    if eval == 0 then
        return true, center
    elseif eval < 0 then
        return binary_search(t, f, center + 1, max, ...) 
    else
        return binary_search(t, f, min, center - 1, ...)
    end
end

function render_system:init(world)
    print("render system initialized")
    self.render_list = {}
    self.known_entities = {}
    self.texture_cache = {}
    self.lights = {}
end

local function sprite_y_search(entity, ypos)
    return entity.position.y - ypos
end

local function sprite_y_sort(a, b)
    return a.position.y < b.position.y
end

---@param world r3d.World
---@param light r3d.Light
---@param info any
---@param pos {x:number, y:number}
---@return r3d.Light
local function sync_light(world, light, info, pos)
    -- replace light object if necessary
    local old_type

    if light then
        if light:is(Light.spotlight) then
            old_type = "spot"
        end
    end

    if old_type ~= info.type or not info.type then
        if light then
            world:remove_object(light)
        end

        if info.type == "spot" then
            light = Light.spotlight()
        else
            error(("unknown light type '%s', expected 'spot'"):format(tostring(info.type)))
        end

        world:add_object(light)
        print("create new " .. info.type)
    end
    
    -- sync properties
    light.r = info.r
    light.g = info.g
    light.b = info.b
    light.power = info.power
    light.enabled = info.enabled
    light.constant = info.constant
    light.linear = info.linear
    light.quadratic = info.quadratic

    local px, py, pz = pos.x, pos.y, info.z_offset

    if info.type == "spot" then
        ---@cast light r3d.SpotLight
        light.angle = info.spot_angle

        light.transform =
            mat4.rotation_z(nil, info.spot_rz)
            * mat4.rotation_x(nil, info.spot_rx)
            * mat4.translation(nil, px, py, pz)        
    else
        light.transform:identity()
        light:set_position(px, py, pz)
    end

    return light
end

function render_system:sync_lights()
    ---@type r3d.World
    local world = self:getWorld().game.r3d_world
    
    local ents_to_remove = {}
    for ent, _ in pairs(self.lights) do
        ents_to_remove[ent] = true
    end

    -- handle new entities
    for _, ent in ipairs(self.light_pool) do
        ents_to_remove[ent] = nil
        
        local pos = ent.position
        self.lights[ent] = sync_light(world, self.lights[ent], ent.light, pos)
    end
    
    -- prune entities no longer in world
    for ent, _ in ipairs(ents_to_remove) do
        print("destroy a light")
        world:remove_object(self.lights[ent])
        self.lights[ent] = nil
    end
end

function render_system:draw_sprites()
    ---@type r3d.Batch
    local draw_batch = self:getWorld().game.r3d_draw_batch

    local transform0 = mat4.new()
    local rot_matrix = mat4.new()
    local transform1 = mat4.new()
    rot_matrix:rotation_x(math.pi / 2)

    local existing = {}
    local newly_added = 0
    local newly_removed = 0

    -- im assuming the lua-based sort will be faster than the C sort only in
    -- luaJIT, from what i know of how the tracing JIT works.
    if jit then
        table.insertion_sort(self.render_list, sprite_y_sort)
    else
        table.sort(self.render_list, sprite_y_sort)
    end

    -- find new entities
    for _, entity in ipairs(self.sprite_pool) do
        local pos = entity.position

        if not self.known_entities[entity] then
            local s, idx = binary_search(self.render_list, sprite_y_search, nil, nil, pos.y)
            -- assert(not s)
            table.insert(self.render_list, idx, entity)
            newly_added = newly_added + 1

            self.known_entities[entity] = true
        end

        existing[entity] = true
    end

    -- remove entities that no longer exist
    for i=#self.render_list, 1, -1 do
        local entity = self.render_list[i]
        if not existing[entity] then
            self.known_entities[entity] = nil
            table.remove(self.render_list, i)
            newly_removed = newly_removed + 1
        end
    end

    if newly_added > 0 then
        print(newly_added .. " new entities")
    end

    if newly_removed > 0 then
        print(newly_removed .. " removed entities")
    end

    for _, entity in ipairs(self.render_list) do
        local pos = entity.position
        local rot = 0
        local sprite = entity.sprite

        if entity.rotation then
            rot = entity.rotation.ang
        end

        local img = sprite.img
        if type(img) == "string" then
            img = self.texture_cache[sprite.img]
            if not img then
                img = Lg.newImage(sprite.img)
                self.texture_cache[sprite.img] = img
            end
        end

        local px, py = math.round(pos.x), math.round(pos.y)
        local sx, sy = sprite.sx, sprite.sy
        local ox = math.round(img:getWidth() / 2 + sprite.ox)
        local oy = math.round(img:getHeight() + sprite.oy)

        -- TODO: respect entity rotation
        transform0:identity()
        transform0:set(0, 3, -ox)
        transform0:set(2, 3, -oy)
        transform0:set(0, 0, sx)
        transform0:set(1, 1, sy)

        rot_matrix:mul(transform0, transform1)

        transform1:set(0, 3, px - ox)
        transform1:set(1, 3, py)
        transform1:set(2, 3, img:getHeight())

        if sprite.unshaded then
            draw_batch:set_shader("basic")
            draw_batch:set_color(sprite.r, sprite.g, sprite.b)
        else
            draw_batch:set_shader("shaded_ignore_normal")

            -- darken sprite so that it's not too bright when close to the light
            draw_batch:set_color(sprite.r * 0.4, sprite.g * 0.4, sprite.b * 0.4)
        end
        
        draw_batch:add_image(img, transform1)
    end
end

function render_system:draw()
    self:draw_sprites()
    self:sync_lights()

    if Debug.enabled then
        for _, entity in ipairs(self.dbgdraw_pool) do
            local pos = entity.position
            local rect = entity.collision
            local actor = entity.actor

            Lg.setColor(1, 0, 0, 0.2)
            Lg.setLineWidth(1)
            Lg.setLineStyle("rough")
            Lg.rectangle("line",
                         math.floor(pos.x - rect.w / 2.0) + 0.5,
                         math.floor(pos.y - rect.h / 2.0) + 0.5,
                         rect.w,
                         rect.h)
            
            if actor then
                local lookx = math.cos(actor.look_angle)
                local looky = math.sin(actor.look_angle)

                Lg.setColor(1, 0, 0, 0.8)
                Lg.line(
                    math.floor(pos.x) + 0.5, math.floor(pos.y) + 0.5,
                    math.floor(pos.x + lookx * 10) + 0.5, math.floor(pos.y + looky * 10) + 0.5)
            end
        end
    end
end

return render_system