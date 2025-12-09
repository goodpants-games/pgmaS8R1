local Concord = require("concord")
local bit = require("bit")
local r3d = require("r3d")
local Sprite = require("sprite")

local ecsconfig = require("game.ecsconfig")
local map_loader = require("game.map_loader")
local consts = require("game.consts")
local Collision = require("game.collision")

local VALID_TRANSPORT_DIRS = {}
for _, v in pairs({"left", "right", "up", "down"}) do
    VALID_TRANSPORT_DIRS[v] = true
end

---@class game.RoomMemory
---@field entities {type:string, x:number, y:number, health:number?}[]

---@class game.Room
---@field map_width integer Map width in tiles
---@field map_height integer Map height in tiles
---@field tile_width integer Tile width in pixels
---@field tile_height integer Tile height in pixels
---@field player_spawn_x number?
---@field player_spawn_y number?
---@field private _colmap integer[]
---@field private _map game.Map
---@field private _map_model r3d.Model
---@overload fun(game:Game, map_path:string, data:{closed_room_sides:{[string]:boolean}, memory:game.RoomMemory?}):game.Room
local Room = batteries.class({ name = "Room" })

---@param game Game
---@param map_path string
---@param data {closed_room_sides:{[string]:boolean}, memory:game.RoomMemory?}
function Room:new(game, map_path, data)
    self.game = game
    data = data or { closed_room_sides = {} }

    self.cam = {
        x = 0.0,
        y = 0.0,
        offset_x = 0.0,
        offset_y = 0.0,
        ---@type any?
        follow = nil,
        offset_target_x = 0.0,
        offset_target_y = 0.0,
        vel_x = 0.0,
        vel_y = 0.0,
    }

    local map = map_loader.load(map_path)
    self._map = map

    local w, h = map.w, map.h
    local tw, th = map.tw, map.th
    self.map_width, self.map_height = w, h
    self.tile_width, self.tile_height = tw, th

    local obj_layer = self._map.tiled_map:getLayerByName("Objects") --[[@as pklove.tiled.ObjectLayer]]
    if not obj_layer then
        error("level has no object layer (the layer must be named \"Objects\")")
    end

    ---@private
    self._entities = {}
    ---@private
    ---@type {[any]:string}
    self._entity_types = {}

    -- apply dynamic geo
    for _, obj in ipairs(obj_layer.objects) do
        if obj.type == "special" and obj.name == "dynamic_geo" then
            assert(obj.shape == "rectangle", "special dynamic_geo object must be a rect!")

            if data.closed_room_sides[obj.properties.side] then
                local ox = math.round(obj.x / tw)
                local oy = math.round(obj.y / th)
                local ow = math.round(obj.width / tw)
                local oh = math.round(obj.height / th)
                local height = obj.properties.height
                if not height then
                    height = 1
                end
                assert(type(height) == "number" and height > 0, "dynamic_geo.height must be a positive non-zero integer!")

                local tile = obj.properties.tile
                assert(type(tile) == "number" and tile > 0, "dynamic_geo.tile must be a positive non-zero integer!")

                for z=2, height+1 do
                    for y=oy, oy+oh-1  do
                        for x=ox, ox+ow-1 do
                            map.data[z][y*map.w+x+1] = tile
                        end
                    end
                end
            end
        
        elseif obj.type == "special" and obj.name == "player_spawn" then
            assert(obj.shape == "point", "player_spawn must be a point!")
            self.player_spawn_x = obj.x
            self.player_spawn_y = obj.y
        end
    end

    -- get collision data
    self._colmap = {}

    if map.data[2] then
        local col_layer = map.data[2]
        local i = 1
        for y=0, h-1 do
            for x=0, w-1 do
                local tid = col_layer[i]

                if tid > 0 then
                    self._colmap[i] = 1
                else
                    self._colmap[i] = 0
                end

                i=i+1
            end
        end
    else
        print("warning: no collision map")

        local i=1
        for y=0, h-1 do
            for x=0, w-1 do
                self._colmap[i] = 0
                i=i+1
            end
        end
    end

    -- create actors
    for _, obj in ipairs(obj_layer.objects) do
        local new_ent

        if obj.type == "entity" then
            assert(obj.shape == "point")
            local x = obj.x
            local y = obj.y

            if not ecsconfig.asm.entity[obj.name] then
                print(("WARN: no entity assembler for '%s'"):format(obj.name))
                goto continue
            end

            new_ent = game:new_entity()
                            :assemble(ecsconfig.asm.entity[obj.name], x, y)
            self._entity_types[new_ent] = obj.name
            -- if obj.name == "player" then
            --     assert(not game.player, "there can not be more than one player in a level")
            --     game.player = e
            --     -- self.cam_follow = self.player
            -- end
        
        elseif obj.type == "special" then
            if obj.name == "room_transport" then
                local transport_dir = obj.properties.direction
                if not VALID_TRANSPORT_DIRS[transport_dir] then
                    error(("invalid room_transport direction '%s'"):format(transport_dir))
                end

                assert(obj.shape == "rectangle", "room_transport object is not a rect!")

                local x = obj.x + obj.width / 2.0
                local y = obj.y + obj.height / 2.0
                new_ent = game:new_entity()
                new_ent:give("position", x, y)
                       :give("collision", obj.width, obj.height)
                       :give("room_transport", transport_dir)
                
                new_ent.collision.group = 0
            end
        end

        if new_ent then
            table.insert(self._entities, new_ent)
        end

        ::continue::
    end

    if data.memory then
        -- load entities from memory
        for _, ent_data in ipairs(data.memory.entities) do
            local new_ent =
                game:new_entity()
                    :assemble(ecsconfig.asm.entity[ent_data.type], ent_data.x, ent_data.y)
            
            if ent_data.health then
                new_ent.health.value = ent_data.health
            end
        end
    else
        -- randomly spawn enemies
        local entity_type_list = {"basic_enemy", "flying_enemy", "weeping_angel"}

        local enemy_count = love.math.random(3, 7)
        for _=1, enemy_count do
            while true do
                local tx = love.math.random(0, self.map_width - 1)
                local ty = love.math.random(0, self.map_height - 1)
                if self:get_col(tx, ty) == 0 then
                    local x = tx * self.tile_width + 8
                    local y = ty * self.tile_height + 8
                    local type = table.pick_random(entity_type_list)

                    local new_ent =
                        game:new_entity()
                            :assemble(ecsconfig.asm.entity[type], x, y)
                    
                    table.insert(self._entities, new_ent)
                    self._entity_types[new_ent] = type
                    break
                end
            end
        end
    end

    -- assert(self.player, "level must have a player")

    -- create map model
    local map_mesh = map_loader.create_mesh(map)
    do
        local tilemap = Lg.newImage("res/tilesets/test_tileset.png")
        map_mesh:setTexture(tilemap)
        tilemap:release()
    end
    self._map_model = r3d.model(map_mesh)
    self._map_model.shader = "shaded_alpha_influence"
    self._map_model:set_scale(16, 16, 16)
    self._map_model:set_position(0, 0, -16) -- second layer is play layer

    game.r3d_world:add_object(self._map_model)
end

function Room:release()
    for _, ent in ipairs(self._entities) do
        ent:destroy()
    end
    table.clear(self._entities)
    
    self.game.r3d_world:remove_object(self._map_model)
    self._map_model:release()
end

---@param x integer 0-based
---@param y integer 0-based
---@return boolean
function Room:is_tile_in_bounds(x, y)
    return x >= 0 and y >= 0 and x < self.map_width and y < self.map_height
end

---@param x integer 0-based
---@param y integer 0-based
---@return integer
function Room:get_tile(x, y)
    return self._map[y * self.map_width + x + 1]
end

---@param x integer 0-based
---@param y integer 0-based
---@return integer
function Room:get_col(x, y)
    if not self:is_tile_in_bounds(x, y) then
        return 1
    end
    
    return self._colmap[y * self.map_width + x + 1]
end

---Get a list of entities created by the room load process.
function Room:get_entities()
    return self._entities
end

---@private
---@param ray_x number
---@param ray_y number
---@param ray_dx number
---@param ray_dy number
---@return number? distance, number? dx, number? dy
function Room:_tile_raycast(ray_x, ray_y, ray_dx, ray_dy)
    local ray_len = math.length(ray_dx, ray_dy)
    if ray_len == 0.0 then return end

    ray_dx = ray_dx / ray_len
    ray_dy = ray_dy / ray_len

    local tw = self.tile_width
    local th = self.tile_height

    local dir_sign_x = math.binsign(ray_dx)
    local dir_sign_y = math.binsign(ray_dy)
    local tile_offset_x = (ray_dx >= 0.0) and 1 or 0
    local tile_offset_y = (ray_dy >= 0.0) and 1 or 0

    local cur_x = ray_x
    local cur_y = ray_y
    local tile_x = math.floor(cur_x / tw)
    local tile_y = math.floor(cur_y / th)
    
    local t = 0.0
    local dt = 0.0
    local dt_x = ((tile_x + tile_offset_x) * tw - cur_x) / ray_dx
    local dt_y = ((tile_y + tile_offset_y) * th - cur_y) / ray_dy
    local side = 0

    while (self:is_tile_in_bounds(tile_x, tile_y) and t < ray_len) do
        local col = self:get_col(tile_x, tile_y)
        if col > 0 --[[and not NONCOLLIDABLE_TILES[col])]] then
            local nx, ny
            if side == 0 then
                nx = dir_sign_x
                ny = 0.0
            else
                nx = 0
                ny = dir_sign_y
            end

            return t, nx, ny
        end

        if dt_x < dt_y then
            tile_x = tile_x + dir_sign_x
            side = 0
            dt = dt_x
            t = t + dt
            dt_x = dt_x + dir_sign_x * tw / ray_dx - dt
            dt_y = dt_y - dt
        else
            tile_y = tile_y + dir_sign_y
            side = 1
            dt = dt_y
            t = t + dt
            dt_x = dt_x - dt
            dt_y = dt_y + dir_sign_y * th / ray_dy - dt
        end
    end
end

---@private
---@param ray_x number
---@param ray_y number
---@param ray_dx number
---@param ray_dy number
---@param col_flags integer
---@param ignore any[]?
---@return any|nil entity
---@return number? distance
---@return number? nx
---@return number? ny
function Room:_entity_raycast(ray_x, ray_y, ray_dx, ray_dy, col_flags, ignore)
    local min_dist = math.huge

    ---@type any?, number?, number?
    local result_ent, result_nx, result_ny

    for _, ent in ipairs(self.game.ecs_world:getEntities()) do
        local position = ent.position
        local collision = ent.collision

        if position and collision and bit.band(collision.group, col_flags) ~= 0 then
            local dist, nx, ny = Collision.ray_rect_intersection(
                ray_x, ray_y, ray_dx, ray_dy,
                position.x, position.y, collision.w, collision.h)

            if dist and dist < min_dist and (ignore == nil or table.index_of(ignore, ent) == nil) then
                assert(nx and ny)
                min_dist = dist
                result_ent = ent
                result_nx = nx
                result_ny = ny
            end
        end
    end

    if min_dist then
        return min_dist, result_ent, result_nx, result_ny
    end
end

---@param x number
---@param y number
---@param dx number
---@param dy number
---@param col_flags integer?
---@param entity_ignore any[]?
---@return number? distance, number? nx, number? ny, any|nil entity
function Room:raycast(x, y, dx, dy, col_flags, entity_ignore)
    if col_flags == nil then
        col_flags = consts.COLGROUP_ALL
    end

    if col_flags == 0 then return end

    -- get tile raycast
    ---@type number?, number?, number?
    local tile_dist, tile_nx, tile_ny
    if bit.band(col_flags, consts.COLGROUP_DEFAULT) ~= 0 then
        tile_dist, tile_nx, tile_ny = self:_tile_raycast(x, y, dx, dy)
    end

    local ent_dist, ent_hit, ent_nx, ent_ny = self:_entity_raycast(x, y, dx, dy, col_flags, entity_ignore)

    if tile_dist ~= nil and (not ent_dist or tile_dist < ent_dist) then
        return tile_dist, tile_nx, tile_ny
    elseif ent_dist ~= nil and (not tile_dist or ent_dist < tile_dist) then
        return ent_dist, ent_nx, ent_ny, ent_hit
    else
        return
    end
end

---@return game.RoomMemory
function Room:create_memory()
    local entities = {}

    for ent, ent_type in pairs(self._entity_types) do
        local position = ent.position
        local health = ent.health

        assert(position, "entity does not have position")

        table.insert(entities, {
            type = ent_type,
            x = position.x,
            y = position.y,
            health = health and health.value
        })
    end

    return {
        entities = entities
    }
end

return Room