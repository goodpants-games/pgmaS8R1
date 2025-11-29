local Concord = require("concord")
local Input = require("input")

Concord.component("position", function(cmp, x, y)
    cmp.x = x or 0
    cmp.y = y or 0
end)

Concord.component("rotation", function(cmp, ang)
    cmp.ang = ang or 0
end)

Concord.component("sprite", function(cmp, img)
    cmp.img = img
    cmp.r = 1
    cmp.g = 1
    cmp.b = 1
    cmp.a = 1
    cmp.sx = 1
    cmp.sy = 1
end)

-- Concord.component("draw_rect", function(self, r, g, b)
--     self.r = r
--     self.g = g
--     self.b = b
-- end)

local renderSystem = Concord.system({
    pool = {"position", "sprite"}
})

function renderSystem:draw()
    for _, entity in ipairs(self.pool) do
        local pos = entity.position
        local rot = 0
        local sprite = entity.sprite

        if entity.rotation then
            rot = entity.rotation.ang
        end

        Lg.setColor(sprite.r, sprite.g, sprite.b)
        Lg.draw(sprite.img,
                math.floor(pos.x), math.floor(pos.y), rot,
                sprite.sx, sprite.sy,
                math.floor(sprite.img:getWidth() / 2), math.floor(sprite.img:getHeight() / 2))
    end
end

---@class Game
---@field world any
---@field cam_x number
---@field cam_y number
---@field map_width integer Map width in tiles
---@field map_height integer Map height in tiles
---@field tile_width integer Tile width in pixels
---@field tile_height integer Tile height in pixels
---@field private _map integer[]
---@field private _map_batch love.SpriteBatch
---@overload fun():Game
local Game = batteries.class({ name = "Game" })

function Game:new()
    self.cam_x = 0
    self.cam_y = 0

    self.world = Concord.world()
    self.world:addSystems(renderSystem)

    local loaded_tmx = assert(love.filesystem.load("res/maps/map.lua"))()
    local w, h = loaded_tmx.width, loaded_tmx.height
    local tw, th = loaded_tmx.tilewidth, loaded_tmx.tileheight
    self.map_width, self.map_height = w, h

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

    -- render map
    local batch = Lg.newSpriteBatch(tileset_img, w * h)
    self._map_batch = batch

    local i = 1
    for y=0, h-1 do
        for x=0, w-1 do
            local gid = self._map[i]
            if gid > 0 then
                batch:add(tileset_quads[gid], x * tw, y * th)
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
    return self._map[y * self.map_width + x]
end

function Game:update(dt)
    local mx, my = Input.players[1]:get("move")
    self.cam_x = self.cam_x + mx * 2.0
    self.cam_y = self.cam_y + my * 2.0

    self.world:emit("update", dt)
end

function Game:draw()
    Lg.push()
    Lg.translate(math.floor(-self.cam_x), math.floor(-self.cam_y))

    Lg.draw(self._map_batch, 0, 0)
    self.world:emit("draw")

    Lg.pop()
end

return Game