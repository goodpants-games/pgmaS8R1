local Concord = require("concord")
local Input = require("input")
local bit = require("bit")

local ecsconfig = require("game.ecsconfig")

---@class Game
---@field world any
---@field cam_x number
---@field cam_y number
---@field cam_follow any
---@field map_width integer Map width in tiles
---@field map_height integer Map height in tiles
---@field tile_width integer Tile width in pixels
---@field tile_height integer Tile height in pixels
---@field private _map integer[]
---@field private _colmap integer[]
---@field private _map_batch love.SpriteBatch
---@field private _dt_accum number
---@overload fun():Game
local Game = batteries.class({ name = "Game" })

Game.TICK_RATE = 60
Game.TICK_LEN = 1 / Game.TICK_RATE

function Game:new()
    self.cam_x = 0.0
    self.cam_y = 0.0
    self._dt_accum = 0.0

    self.world = Concord.world()
    self.world.game = self
    self.world:addSystems(
        ecsconfig.systems.player_controller,
        ecsconfig.systems.actor,
        ecsconfig.systems.physics,
        ecsconfig.systems.render)

    local loaded_tmx = assert(love.filesystem.load("res/maps/map.lua"))()
    local w, h = loaded_tmx.width, loaded_tmx.height
    local tw, th = loaded_tmx.tilewidth, loaded_tmx.tileheight
    self.map_width, self.map_height = w, h
    self.tile_width, self.tile_height = tw, th

    -- parse tmx data
    assert(loaded_tmx.layers[1] and loaded_tmx.layers[1].encoding == "lua")
    self._map = table.copy(loaded_tmx.layers[1].data)

    -- parse tsx data
    local loaded_tsx = assert(loaded_tmx.tilesets[1])
    local tileset_img = Lg.newImage("res/" .. loaded_tsx.image)
    ---@type love.Quad[]
    local tileset_quads = {}
    for i=1, loaded_tsx.tilecount do
        local x = ((i-1) % loaded_tsx.columns) * loaded_tsx.tilewidth
        local y = math.floor((i-1) / loaded_tsx.columns) * loaded_tsx.tileheight
        tileset_quads[i] = Lg.newQuad(x, y, loaded_tsx.tilewidth, loaded_tsx.tileheight, tileset_img)
    end

    -- render map render and collision data
    local batch = Lg.newSpriteBatch(tileset_img, w * h)
    self._map_batch = batch

    self._colmap = {}

    local i = 1
    for y=0, h-1 do
        for x=0, w-1 do
            local cellv = self._map[i]
            local gid = bit.band(cellv,   0x0FFFFFFF)
            local fliph = bit.band(cellv, 0x80000000) ~= 0
            local flipv = bit.band(cellv, 0x40000000) ~= 0
            local flipd = bit.band(cellv, 0x20000000) ~= 0

            -- collision
            if gid > 0 then
                self._colmap[i] = 1
            else
                self._colmap[i] = 0
            end

            -- render
            if gid > 0 then
                local r = 0
                local sx = 1
                local sy = 1

                if flipd then sx = -sx end
                if fliph then sx = -sx end
                if flipv then sy = -sy end
                if flipd then
                    r = math.pi / 2.0
                end

                batch:add(tileset_quads[gid],
                          (x+0.5) * tw, (y+0.5) * th,
                          r, sx, sy,
                          math.floor(tw/2), math.floor(th/2))
            end

            i=i+1
        end
    end

    tileset_img:release()
    for _,q in pairs(tileset_quads) do
        q:release()
    end
end

function Game:release()
    self._map_batch:release()
end

function Game:newEntity()
    return Concord.entity(self.world)
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
    self.world:emit("tick")

    if self.cam_follow then
        local pos = self.cam_follow.position
        if pos then
            self.cam_x = pos.x
            self.cam_y = pos.y
        end
    end
end

function Game:update(dt)
    Debug.draw.push()
    Debug.draw.translate(math.floor(-self.cam_x + DISPLAY_WIDTH / 2.0), math.floor(-self.cam_y + DISPLAY_HEIGHT / 2.0))

    self.world:emit("update", dt)

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

    Debug.draw.pop()
end

function Game:draw()
    Lg.push()
    Lg.translate(math.floor(-self.cam_x + DISPLAY_WIDTH / 2.0), math.floor(-self.cam_y + DISPLAY_HEIGHT / 2.0))

    Lg.draw(self._map_batch, 0, 0)
    self.world:emit("draw")

    Lg.pop()
end

return Game