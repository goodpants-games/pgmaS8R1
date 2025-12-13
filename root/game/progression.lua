local GameProgression = {}

local consts = require("game.consts")

---@class Game.ProgressionRoom
---@field heart_color integer?
---@field heart_visible boolean?
---@field heart_destroyed boolean
---@field room_id string

---@class Game.Progression
---@field difficulty integer
---@field player_color integer
---@field rooms Game.ProgressionRoom[]

---@type Game.Progression?
GameProgression.progression = nil

---@param difficulty integer
---@return Game.Progression
function GameProgression.reset_progression(difficulty)
    assert(difficulty >= 1 and difficulty <= 4)

    local room_pool = {
        "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12",
    }

    ---@type Game.Progression
    local out = {
        difficulty = difficulty,
        player_color = 1,
        rooms = {}
    }

    table.insert(out.rooms, {
        room_id = "start",
    })

    for i=1, consts.LAYOUT_WIDTH * consts.LAYOUT_HEIGHT - 1 do
        local room_id = table.take_random(room_pool)
        assert(room_id, "room pool is empty!")

        table.insert(out.rooms, {
            room_id = room_id,
        })
    end

    -- place red hearts
    for i=1, 3 do
        out.rooms[i].heart_color = 1
        out.rooms[i].heart_visible = true
    end

    -- place green hearts
    for i=4, 6 do
        out.rooms[i].heart_color = 2
        out.rooms[i].heart_visible = true
    end

    -- place blue hearts
    for i=7, 9 do
        out.rooms[i].heart_color = 3
        out.rooms[i].heart_visible = true
    end

    GameProgression.progression = out
    return out
end

return GameProgression