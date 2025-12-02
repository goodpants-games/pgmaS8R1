local Concord = require("concord")
local tiled = require("tiled")
local bit = require("bit")
local r3d = require("r3d")

local ecsconfig = require("game.ecsconfig")
local map_loader = require("game.map_loader")

---@class Game
---@field ecs_world any
---@field r3d_world r3d.World
---@field r3d_draw_batch r3d.Batch
---@field cam_x number
---@field cam_y number
---@field cam_follow any
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

Game.TICK_RATE = 60
Game.TICK_LEN = 1 / Game.TICK_RATE

function Game:new()
    self.cam_x = 0.0
    self.cam_y = 0.0
    self._dt_accum = 0.0

    self.ecs_world = Concord.world()
    self.ecs_world.game = self
    self.ecs_world:addSystems(
        ecsconfig.systems.player_controller,
        ecsconfig.systems.actor,
        ecsconfig.systems.physics,
        ecsconfig.systems.render)

    local map = map_loader.load("res/maps/voxeltest.lua")
    self._map = map

    local w, h = map.w, map.h
    local tw, th = map.tw, map.th
    self.map_width, self.map_height = w, h
    self.tile_width, self.tile_height = tw, th

    -- get collision data
    self._colmap = {}

    if map.data[1] then
        local col_layer = map.data[1]
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

    -- create map model
    local map_mesh = map_loader.create_mesh(map)
    do
        local tilemap = Lg.newImage("res/tilesets/test_tileset.png")
        map_mesh:setTexture(tilemap)
        tilemap:release()
    end
    self._map_model = r3d.model(map_mesh)
    self._map_model:set_scale(16, 16, 16)
    self._map_model.use_shading = false

    -- create r3d world
    self.r3d_world = r3d.world()
    self.r3d_draw_batch = r3d.batch(2048)
    self.r3d_draw_batch.use_shading = false
    self.r3d_draw_batch.opaque = false

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

function Game:newEntity()
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
    self.ecs_world:emit("tick")

    if self.cam_follow then
        local pos = self.cam_follow.position
        if pos then
            self.cam_x = pos.x
            self.cam_y = pos.y
        end
    end
end

function Game:update(dt)
    Debug.draw:push()
    Debug.draw:translate(math.floor(-self.cam_x + DISPLAY_WIDTH / 2.0), math.floor(-self.cam_y + DISPLAY_HEIGHT / 2.0))

    self.ecs_world:emit("update", dt)

    -- dt snap calculation
    -- https://medium.com/@tglaiel/how-to-make-your-game-run-at-60fps-24c61210fe75
    local dt_to_accum = dt
    local DT_SNAP_EPSILON = 0.002

    if math.abs(dt - Game.TICK_LEN) < DT_SNAP_EPSILON then -- 30 fps?
        dt_to_accum = Game.TICK_LEN
    elseif math.abs(dt - Game.TICK_LEN * 2.0) < DT_SNAP_EPSILON then -- 15 fps?
        dt_to_accum = Game.TICK_LEN * 2.0
    elseif math.abs(dt - Game.TICK_LEN * 0.5) < DT_SNAP_EPSILON then -- 60 fps?
        dt_to_accum = Game.TICK_LEN * 0.5
    elseif math.abs(dt - Game.TICK_LEN * 0.25) < DT_SNAP_EPSILON then -- 120 fps?
        dt_to_accum = Game.TICK_LEN * 0.25
    else
        print("no dt snap")
    end

    local iter = 1
    self._dt_accum = self._dt_accum + dt_to_accum
    while self._dt_accum >= Game.TICK_LEN do
        if iter > 8 then
            print("too many ticks in one frame!")
            self._dt_accum = self._dt_accum % Game.TICK_LEN
            break
        end
        
        self:tick()

        self._dt_accum = self._dt_accum - Game.TICK_LEN
        iter=iter+1
    end

    Debug.draw:pop()
end

function Game:draw()
    local mat4 = require("r3d.mat4")

    local r3d_world = self.r3d_world
    local cam_x = math.floor(self.cam_x)
    local cam_y = math.floor(self.cam_y)

    -- r3d_world.cam:set_position(cam_x, cam_y, 0.0)
    r3d_world.cam.transform =
        mat4.rotation_z(nil, MOUSE_Y / -100) *
        mat4.translation(nil, cam_x, cam_y, 0.0)

    r3d_world.cam.frustum_width = DISPLAY_WIDTH
    r3d_world.cam.frustum_height = DISPLAY_HEIGHT

    self.r3d_draw_batch:clear()

    Lg.push()
    Lg.translate(math.floor(-cam_x + DISPLAY_WIDTH / 2.0), math.floor(-cam_y + DISPLAY_HEIGHT / 2.0))
    self.ecs_world:emit("draw")
    Lg.pop()

    r3d_world:draw()

    -- local tl = self._tiled_map.layers[1] --[[@as pklove.tiled.TileLayer]]
    -- tl:draw()
    -- self.ecs_world:emit("draw")

    -- Lg.pop()
end

function Game:make_3d_model()
    ---@type number
    local heightmap = {}
    local tinsert = table.insert

    local i = 1
    for y=0, self.map_height - 1 do
        for x=0, self.map_width - 1 do
            local col = self:get_col(x, y)

            i=i+1
        end
    end
end

return Game