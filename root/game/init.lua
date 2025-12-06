local Concord = require("concord")
local tiled = require("tiled")
local bit = require("bit")
local r3d = require("r3d")

local ecsconfig = require("game.ecsconfig")
local map_loader = require("game.map_loader")
local consts = require("game.consts")

---@class Game.Attack
---@field x number
---@field y number
---@field radius number
---@field damage number
---@field dx number
---@field dy number
---@field mask integer?
---@field owner any?

---@class Game
---@field ecs_world any
---@field r3d_world r3d.World
---@field r3d_draw_batch r3d.Batch
---@field map_width integer Map width in tiles
---@field map_height integer Map height in tiles
---@field tile_width integer Tile width in pixels
---@field tile_height integer Tile height in pixels
---@field private _dt_accum number
---@field private _colmap integer[]
---@field private _map game.Map
---@field private _map_model r3d.Model
---@overload fun():Game
local Game = batteries.class({ name = "Game" })

function Game:new()
    self._dt_accum = 0.0
    
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

    self.ecs_world = Concord.world()
    self.ecs_world.game = self
    self.ecs_world:addSystems(
        ecsconfig.systems.player_controller,
        ecsconfig.systems.ai,
        ecsconfig.systems.actor,
        ecsconfig.systems.attack,
        ecsconfig.systems.physics,
        ecsconfig.systems.render)

    local map = map_loader.load("res/maps/voxeltest.lua")
    self._map = map

    local w, h = map.w, map.h
    local tw, th = map.tw, map.th
    self.map_width, self.map_height = w, h
    self.tile_width, self.tile_height = tw, th

    ---@type table?
    self.player = nil
    self.player_is_dead = false

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
    local obj_layer = self._map.tiled_map:getLayerByName("Objects") --[[@as pklove.tiled.ObjectLayer]]
    if not obj_layer then
        error("level has no object layer (the layer must be named \"Objects\")")
    else
        for _, obj in ipairs(obj_layer.objects) do
            if obj.type == "entity" then
                assert(obj.shape == "point")
                local x = obj.x
                local y = obj.y

                if obj.name == "enemy" then     
                    local e = self:new_entity()
                        :assemble(
                            ecsconfig.asm.actor,
                            x, y,
                            13, 8,
                            "res/robot.png")
                        :give("ai")
                        :give("attackable")
                    
                    e.sprite.oy = 13
                    e.collision.group =
                        bit.bor(e.collision.group, consts.COLGROUP_ENEMY)
                    e.actor.move_speed = 0.8
                elseif obj.name == "player" then
                    assert(not self.player, "there can not be more than one player in a level")

                    self.player = self:new_entity():assemble(ecsconfig.asm.entity_player, x, y)
                    self.player.sprite.unshaded = true
                    self.player:give("player_control")

                    -- self.cam_follow = self.player
                end
            end
        end
    end

    assert(self.player, "level must have a player")

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

    -- create r3d world
    self.r3d_world = r3d.world()
    self.r3d_draw_batch = r3d.batch(2048)
    self.r3d_draw_batch.opaque = false
    self.r3d_draw_batch.double_sided = true
    self.r3d_draw_batch:set_shader("shaded_ignore_normal")

    self.r3d_world:add_object(self.r3d_draw_batch)
    self.r3d_world:add_object(self._map_model)

    -- ---@type pklove.tiled.TileLayer?
    -- local col_layer

    -- for _, layer in ipairs(loaded_tmx.layers) do
        
    --     if layer.type == "tilelayer" then
    --         ---@cast layer pklove.tiled.TileLayer
            
    --         local is_col_layer = layer.class == "collision"
    --         if not is_col_layer then
    --             layer:syncGraphics()
    --         else
    --             layer.visible = false
    --             col_layer = layer
    --         end
    --     end
    -- end

    -- -- get collision data
    -- self._colmap = {}

    -- if col_layer then
    --     local i = 1
    --     for y=0, h-1 do
    --         for x=0, w-1 do
    --             local cellv = col_layer.data[i]
    --             local gid = bit.band(cellv, 0x0FFFFFFF)

    --             -- collision
    --             if gid > 0 then
    --                 local tile_info = loaded_tmx:getTileInfo(gid)
    --                 self._colmap[i] = tile_info.id
    --             else
    --                 self._colmap[i] = 0
    --             end

    --             i=i+1
    --         end
    --     end
    -- else
    --     print("warning: no collision map")

    --     local i=1
    --     for y=0, h-1 do
    --         for x=0, w-1 do
    --             self._colmap[i] = 0
    --             i=i+1
    --         end
    --     end
    -- end
end

function Game:release()
    self.r3d_world:release()
    self.r3d_draw_batch:release()
    self._map_model:release()
end

function Game:new_entity()
    return Concord.entity(self.ecs_world)
end

---@param x integer 0-based
---@param y integer 0-based
---@return integer
function Game:get_tile(x, y)
    return self._map[y * self.map_width + x + 1]
end

---@param x integer 0-based
---@param y integer 0-based
---@return integer
function Game:get_col(x, y)
    return self._colmap[y * self.map_width + x + 1]
end

function Game:tick()
    if self.player_is_dead then
        return
    end

    if self.player.health.value <= 0 then
        self.player_is_dead = true

        love.audio.pause()
        love.audio.newSource("res/music/death.ogg", "stream"):play()
    end

    self.ecs_world:emit("tick")
    local cam = self.cam

    cam.vel_x = cam.vel_x + (cam.offset_target_x - cam.offset_x) * 0.009 - cam.vel_x * 0.13
    cam.vel_y = cam.vel_y + (cam.offset_target_y - cam.offset_y) * 0.009 - cam.vel_y * 0.13
    cam.offset_x = cam.offset_x + cam.vel_x
    cam.offset_y = cam.offset_y + cam.vel_y

    -- if camera is close enough to target, snap position and velocity
    local dx = cam.offset_target_x - cam.offset_x
    local dy = cam.offset_target_y - cam.offset_y
    local target_dist = math.sqrt(dx*dx + dy*dy)
    local move_speed = math.sqrt(cam.vel_x * cam.vel_x + cam.vel_y * cam.vel_y)
    if target_dist < 0.5 and move_speed < 0.1 then
        cam.offset_x = cam.offset_target_x
        cam.offset_y = cam.offset_target_y
        cam.vel_x = 0.0
        cam.vel_y = 0.0
    end

    local focus_x, focus_y = 0.0, 0.0
    if cam.follow and cam.follow.position then
        local pos = cam.follow.position
        focus_x, focus_y = pos.x, pos.y
    end

    cam.x = focus_x + cam.offset_x
    cam.y = focus_y + cam.offset_y

    -- if self.cam_follow then
    --     local pos = self.cam_follow.position
    --     if pos then
    --         self.cam_x = pos.x
    --         self.cam_y = pos.y
    --     end
    -- end
end

function Game:update(dt)
    Debug.draw:push()
    Debug.draw:translate(math.round(-self.cam.x + DISPLAY_WIDTH / 2.0), math.round(-self.cam.y + DISPLAY_HEIGHT / 2.0))

    if not self.player_is_dead then
        self.ecs_world:emit("update", dt)
    end

    -- dt snap calculation
    -- https://medium.com/@tglaiel/how-to-make-your-game-run-at-60fps-24c61210fe75
    local dt_to_accum = dt
    local DT_SNAP_EPSILON = 0.002
    local tick_len = consts.TICK_LEN

    if math.abs(dt - tick_len) < DT_SNAP_EPSILON then -- 60 fps?
        dt_to_accum = tick_len
    elseif math.abs(dt - tick_len * 2.0) < DT_SNAP_EPSILON then -- 30 fps?
        dt_to_accum = tick_len * 2.0
    elseif math.abs(dt - tick_len * 0.5) < DT_SNAP_EPSILON then -- 120 fps?
        dt_to_accum = tick_len * 0.5
    elseif math.abs(dt - tick_len * 0.25) < DT_SNAP_EPSILON then -- 240 fps?
        dt_to_accum = tick_len * 0.25
    end

    local iter = 1
    self._dt_accum = self._dt_accum + dt_to_accum
    while self._dt_accum >= tick_len do
        if iter > 8 then
            print("too many ticks in one frame!")
            self._dt_accum = self._dt_accum % tick_len
            break
        end
        
        self:tick()

        self._dt_accum = self._dt_accum - tick_len
        iter=iter+1
    end

    Debug.draw:pop()
end

function Game:draw()
    local mat4 = require("r3d.mat4")

    local r3d_world = self.r3d_world
    local cam_x = math.round(self.cam.x)
    local cam_y = math.round(self.cam.y)

    r3d_world.cam.transform:identity()
    r3d_world.cam:set_position(cam_x, cam_y, 0.0)

    if love.keyboard.isDown("e") then
        r3d_world.cam.transform =
            mat4.rotation_z(nil, (MOUSE_Y - DISPLAY_HEIGHT / 2) / 40) *
            r3d_world.cam.transform
        --     mat4.translation(nil, cam_x, cam_y, 0.0)
        
    end

    r3d_world.cam.frustum_width = DISPLAY_WIDTH
    r3d_world.cam.frustum_height = DISPLAY_HEIGHT
    
    r3d_world.sun.r = 0
    r3d_world.sun.g = 0
    r3d_world.sun.b = 0

    r3d_world.ambient.r = 0.04
    r3d_world.ambient.g = 0.04
    r3d_world.ambient.b = 0.04

    self.r3d_draw_batch:clear()

    Lg.push()
    Lg.translate(math.round(-cam_x + DISPLAY_WIDTH / 2.0), math.round(-cam_y + DISPLAY_HEIGHT / 2.0))
    self.ecs_world:emit("draw")
    Lg.pop()

    r3d_world:draw()

    -- display battery ui
    local player_health = self.player.health
    local battery_percentage = player_health.value / player_health.max

    Lg.setColor(1, 1, 1)
    Lg.rectangle("fill", 0, 0, math.round(battery_percentage * DISPLAY_WIDTH), 4)

    -- local tl = self._tiled_map.layers[1] --[[@as pklove.tiled.TileLayer]]
    -- tl:draw()
    -- self.ecs_world:emit("draw")

    -- Lg.pop()
end

---Add attack sphere
---@param attack Game.Attack
function Game:add_attack(attack)
    if not attack.mask then
        attack.mask = consts.COLGROUP_ALL
    end
    if not attack.dx then
        attack.dx = 0.0
    end
    if not attack.dy then
        attack.dy = 0.0
    end

    assert(attack.x, "attack does not have required field 'x'")
    assert(attack.y, "attack does not have required field 'y'")
    assert(attack.radius, "attack does not have required field 'radius'")
    assert(attack.damage, "attack does not have required field 'damage'")

    local attack_system = self.ecs_world:getSystem(ecsconfig.systems.attack)
    table.insert(attack_system.attacks, attack)
end

return Game