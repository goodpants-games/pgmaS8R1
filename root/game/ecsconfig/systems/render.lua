local Concord = require("concord")
local Sprite = require("sprite")
local mat4 = require("r3d.mat4")
local Light = require("r3d.light")
local consts = require("game.consts")

local render_system = Concord.system({
    sprite_pool = {"position", "sprite"},
    gun_sight_pool = {"position", "gun_sight"},
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

    -- TODO: maybe add circle drawing function to sprite batch renderer
    --       but i think this should be good enough
    self._shadow_tex = self:get_resource("res/img/shadow16x8.png")
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

---@param path string
---@return pklove.SpriteResource|love.Texture
function render_system:get_resource(path)
    ---@type pklove.SpriteResource|love.Texture
    local cached = self.texture_cache[path]
    local is_sprite = string.match(path, ".*(%..*)$") == ".json"

    if not cached then
        if is_sprite then
            cached = Sprite.loadResource(path)
        else
            cached = Lg.newImage(path)
        end
        self.texture_cache[path] = cached
    end

    return cached
end

---@param sprite table
---@param rotation number
---@return love.Texture img, number ox, number oy, love.Quad? quad
function render_system:sync_sprite_graphic(sprite, rotation)
    ---@type number, number, love.Texture, love.Quad?
    local img_ox, img_oy, img, img_quad
    
    local is_sprite = string.match(sprite.img, ".*(%..*)$") == ".json"
    local cached = self:get_resource(sprite.img)

    if is_sprite then
        assert(Sprite.isSpriteResource(cached), 
                "cached value is not a SpriteResource")
        ---@cast cached pklove.SpriteResource

        ---@type pklove.Sprite
        local spr = sprite._spr
        if spr == nil or spr.res ~= cached then
            print("new sprite")
            spr = Sprite.new(cached)
            sprite._spr = spr
        end

        if sprite._cmd then
            if sprite._cmd == "play" then
                spr:play(sprite._cmd_arg)
            elseif sprite._cmd == "stop" then
                spr:stop()
            else
                print(("warn: invalid sprite component command '%s'"):format(sprite._cmd))
            end
        end

        sprite._cmd = nil
        sprite._cmd_arg = nil

        sprite.anim = spr.curAnim

        img = spr.res.atlas
        local cel = spr.res.cels[spr.cel]
        img_quad = cel.quad
        img_ox = cel.ox
        img_oy = cel.oy
    else
        assert(cached.typeOf and cached:typeOf("Texture"))
        ---@cast cached love.Texture
        
        img = cached
        img_ox = img:getWidth() / 2.0
        img_oy = img:getHeight() / 2.0
    end

    return img, img_ox, img_oy, img_quad
end

function render_system:draw_sprites()
    ---@type r3d.Batch
    local draw_batch = self:getWorld().game.r3d_sprite_batch

    local tmpmat0 = mat4.new()
    local tmpmat1 = mat4.new()
    local tmpmat2 = mat4.new()

    local rot_matrix = mat4.new()
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
        local sprite = entity.sprite
        local rot = entity.rotation and entity.rotation.ang or 0.0
        rot = math.normalise_angle(rot)

        local img, img_ox, img_oy, img_quad = self:sync_sprite_graphic(sprite, rot)

        local px, py = math.round(pos.x), math.round(pos.y)
        local sx, sy = sprite.sx, sprite.sy

        if math.abs(rot) > math.pi / 2.0 then
            sx = -sx
        end

        -- draw shadow circle
        local shadow_transform = mat4.translation(nil, px - 8, py - 4, 1.0)
        draw_batch:set_shader("basic")
        draw_batch:set_color(0.0, 0.0, 0.0, 0.5)
        draw_batch:add_image(self._shadow_tex --[[@as love.Texture]], shadow_transform)

        -- transform1 =
        --     mat4.translation(nil, -img_ox, -img_oy, 0.0)
        --     * mat4.scale(nil, sx, sy, 1.0)
        --     * rot_matrix
        --     * mat4.translation(nil, px, py, sprite.oy)
        local sprite_transform =
            tmpmat0:identity():translation(-img_ox, -img_oy, 0)
            :mul(tmpmat1:identity():scale(sx, sy, 1.0), tmpmat2)
            :mul(rot_matrix, tmpmat0)
            :mul(tmpmat1:identity():translation(px, py, sprite.oy + sprite.z_offset), tmpmat2)

        if sprite.unshaded then
            draw_batch:set_shader("basic")
            draw_batch:set_color(sprite.r, sprite.g, sprite.b)
        else
            draw_batch:set_shader("shaded_ignore_normal")

            -- darken sprite so that it's not too bright when close to the light
            draw_batch:set_color(sprite.r * 0.3, sprite.g * 0.3, sprite.b * 0.3)
        end

        if img_quad then
            draw_batch:add_image(img, img_quad, sprite_transform)
        else
            draw_batch:add_image(img, sprite_transform)
        end

        -- if img_quad then
        --     draw_batch:add_image(img, img_quad, transform1)
        -- else
        --     ---@diagnostic disable-next-line
        --     draw_batch:add_image(img, transform1)
        -- end
    end
end

function render_system:draw_gun_sights()
    ---@type Game
    local game = self:getWorld().game
    local batch = game.r3d_batch

    for _, ent in ipairs(self.gun_sight_pool) do
        local position = ent.position
        local gun_sight = ent.gun_sight

        if gun_sight.visible then
            local end_x = position.x + gun_sight.cur_dx
            local end_y = position.y + gun_sight.cur_dy

            local zpos = 8

            if game.frame % 3 == 0 then
                batch:set_shader("basic")
                batch:set_color(gun_sight.r, gun_sight.g, gun_sight.b)
                print(gun_sight.target_zoff)
                batch:add_line(position.x, position.y, zpos, end_x, end_y, zpos + gun_sight.target_zoff, 1)
            end
        end
    end
end

function render_system:tick()
    for _, ent in ipairs(self.sprite_pool) do
        local sprite = ent.sprite._spr --[[@as pklove.Sprite?]]
        if sprite then
            sprite:update(consts.TICK_LEN)
        end
    end
end

function render_system:draw()
    self:draw_gun_sights()
    self:draw_sprites()
    self:sync_lights()

    if Debug.enabled then
        for _, entity in ipairs(self.dbgdraw_pool) do
            local pos = entity.position
            local rect = entity.collision
            local rotation = entity.rotation

            Lg.setColor(1, 0, 0, 0.2)
            Lg.setLineWidth(1)
            Lg.setLineStyle("rough")
            Lg.rectangle("line",
                         math.round(pos.x - rect.w / 2.0) + 0.5,
                         math.round(pos.y - rect.h / 2.0) + 0.5,
                         rect.w,
                         rect.h)
            
            if rotation then
                local lookx = math.cos(rotation.ang)
                local looky = math.sin(rotation.ang)

                Lg.setColor(1, 0, 0, 0.8)
                Lg.line(
                    math.round(pos.x) + 0.5, math.round(pos.y) + 0.5,
                    math.round(pos.x + lookx * 10) + 0.5, math.round(pos.y + looky * 10) + 0.5)
            end
        end
    end
end

return render_system