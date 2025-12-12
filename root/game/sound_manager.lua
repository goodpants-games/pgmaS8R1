---@class game.SoundManager
---@overload fun():game.SoundManager
local SoundManager = batteries.class {
    name = "game.SoundManager"
}

---@class game.Sound
---@field package _mgr game.SoundManager
---@field package _is_released boolean
---@field src love.Source
---@field positional boolean
---@field pos_x number?
---@field pos_y number?
---@field entity any?
---@overload fun(mgr:game.SoundManager, source:love.Source):game.Sound
local Sound = batteries.class {
    name = "game.Sound"
}

function Sound:new(mgr, source)
    self._mgr = mgr
    self._is_released = false

    self.src = source
    self.positional = false
end

---@param x number
---@param y number
function Sound:set_position(x, y)
    self.entity = nil
    self.pos_x = x
    self.pos_y = y
    self.positional = true
    
    self:_update_pos()
end

function Sound:attach_to(ent)
    self.entity = ent
    self.positional = true

    self:_update_pos()
end

---@package
function Sound:_update_pos()
    if self.positional then
        if self.entity then
            local ent_pos = self.entity.position
            self.src:setPosition(ent_pos.x, 0.0, ent_pos.y)
        else
            self.src:setPosition(self.pos_x, 0.0, self.pos_y)
        end

        self.src:setRelative(false)
    else
        self.src:setRelative(true)
    end
end

function Sound:release()
    self._is_released = true
end

function SoundManager:new()
    self.listener_x = 0
    self.listener_y = 0

    ---@private
    ---@type {[string]:love.Source}
    self._source_cache = {}

    ---@private
    ---@type game.Sound[]
    self._active = {}
end

function SoundManager:release()
    if self._active then
        for _, snd in ipairs(self._active) do
            snd.src:release()
        end
        self._active = nil
    end

    if self._source_cache then
        for _, src in ipairs(self._source_cache) do
            src:release()
        end
        self._source_cache = nil
    end
end

---can be used for preloading
---@param snd_name string
function SoundManager:load_source(snd_name)
    local source = self._source_cache[snd_name]
    if not source then
        local snd_path = ("res/sounds/%s.wav"):format(snd_name)
        source = love.audio.newSource(snd_path, "static")
        self._source_cache[snd_name] = source
    end

    return source
end

---@param snd_name string
---@return game.Sound
function SoundManager:new_sound(snd_name)
    local source = self._source_cache[snd_name]
    if not source then
        local snd_path = ("res/sounds/%s.wav"):format(snd_name)
        source = love.audio.newSource(snd_path, "static")
        self._source_cache[snd_name] = source
    end

    local source_clone = source:clone()
    source_clone:setAttenuationDistances(100.0, 320.0)

    ---@type game.Sound
    local sound = Sound(self, source_clone)

    table.insert(self._active, sound)

    return sound
end

function SoundManager:update()
    love.audio.setPosition(self.listener_x, 90.0, self.listener_y)
    -- love.audio.setOrientation(
    --     0, 0, 1,
    --     0, 1, 0
    -- )

    for i=#self._active, 1, -1 do
        local snd = self._active[i]

        if snd._is_released and not snd.src:isPlaying() then
            print("release sound from sound mgr")
            snd.src:release()
            table.remove(self._active, i)
        else
            snd:_update_pos()
        end
    end
end

SoundManager.Sound = Sound
return SoundManager