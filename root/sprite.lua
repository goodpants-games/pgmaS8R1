--[[
    sprite: atlas/animation loader.

    loading/managing sprite resources
    ----
    call module.loadResource(path) to load a sprite resource. sprite resource data is contained in a separate png and json file,
    in the json format used by aseprite. the path given must be the path to the json file.

    to create a sprite, call module.load(resourceOrPath) with either a resource table returned from loadResource, or the path to
    the resource file to load.

    you can clone a sprite with sprite:clone(). the cloned sprite will share the same resources as the original sprite. sprite
    resources can also be released with sprite:release(). it will release the resource only if it is the only sprite not yet
    garbage-collected that is using it.

    rendering
    ----
    once you have a sprite, you can render it using the following two functions:
        sprite:draw(x, y, r, sx, sy, kx, ky)
        sprite:drawCel(index, x, y, r, sx, sy, kx, ky)
    
    x and y is where the center of the cell will be located. r is rotation, sx and sy is scale,
    kx and ky is shear factor. sprite.draw draws the current frame of the animation, and drawCel
    draws the index of a specific cel (indexed from 1).


    animations
    ----
    play animations with sprite:play(animName).
    stop playback with sprite:stop().
    check if an animation exists with sprite:hasAnim(animName).
    update the animation on each frame with sprite:update(dt).


    object structure
    ----
    each sprite object also has certain properties you can inspect:
        - sprite.curAnim: a string describing the name of the currently playing animation
        - sprite.cel: an integer describing the current cel that should be displayed
        - sprite.res: the sprite resource data
    
    in addition, each sprite resource has these properties:
        - res.atlas: the sprite atlas, as a love Image.
        - res.animations: table of animation names paired with animation data in the following format:
            {
                from: integer, index of first cel in the animation
                to: integer, index of last cel in the animation
                loopCount: integer, number of times animation should loop before stopping
                loopPoint: integer, start index of looping portion of the cell. always present.
            }
        - res.cels: the cel list. each item is a table in the following format:
            {
                quad: the love Quad.
                ox: offset X of drawing operations (this is why x and y are centered)
                oy: offset Y of drawing operations
                duration: the duration of the cel in milliseconds
            }


    creating animations in aseprite
    ----
    animations are created using the aseprite tags feature. the name of the tag is the name of the animation. the repeat
    property of the tag works as expected in-game as well.

    this library has the ability to represent loop points -- points the animation returns to when it loops that is different than
    the start point of the animation. however, aseprite has no mechanism for representing this, so there is a workaround:
    
    if you were to create two tags that share an end point but have different start points, those two tags become part of the same animation.
    the long tag is the one whose name gets associated with the animation, and its start point becomes the animation's initial frame. the start
    point of the short tag (which is therefore the tag with the later start point) is the point the animation returns to when it loops.

    confusing explanation? maybe a visual will help:

    A     B                C
    +--------[jump]--------+
    |     +---[jump-loop]--+
    |     |                |

    animation name: jump
    A: start point
    B: point animation returns to when it loops
    C: end point

    note the tag named "jump-loop" can be named anything, it only detects which tag is the looping area from shared end points.
    
    
    copyright notice
    ----
    
    Copyright (c) 2025 pkhead

    This software is provided 'as-is', without any express or implied
    warranty. In no event will the authors be held liable for any damages
    arising from the use of this software.

    Permission is granted to anyone to use this software for any purpose,
    including commercial applications, and to alter it and redistribute it
    freely, subject to the following restrictions:

    1. The origin of this software must not be misrepresented; you must not
       claim that you wrote the original software. If you use this software
       in a product, an acknowledgment in the product documentation would be
       appreciated but is not required.
    2. Altered source versions must be plainly marked as such, and must not be
       misrepresented as being the original software.
    3. This notice may not be removed or altered from any source distribution.
--]]

local JSON = require("json")

local module = {}
module._version = "0.1.0"

---@class pklove.SpriteResource
---@field _refs {[pklove.Sprite]: boolean}
---@field atlas love.Image
---@field cels {quad: love.Quad, ox: number, oy: number, duration: number}[]
---@field animations {from: integer, to: integer, loopCount: integer, loopPoint: integer}[]
local SpriteResource = {}
SpriteResource.__index = SpriteResource

---@class pklove.Sprite
---@field private _timeAccum number
---@field private _loopCount integer
---@field private _animChanged boolean
---@field cel integer
---@field res pklove.SpriteResource
local Sprite = {}
Sprite.__index = Sprite

local function pathSplit(path)
    local res = {}
    local i = 1

    while true do
        local idx = string.find(path, "/", i, true)
        if idx == nil then
            table.insert(res, string.sub(path, i))
            break
        end

        table.insert(res, string.sub(path, i, idx-1))
        i = idx + 1
    end
    
    return res
end

local function pathNormalize(path)
    local stack = {}
    local depth = 0

    for _, v in pairs(path) do
        if v == ".." then
            if depth <= 0 then
                stack[#stack+1] = v
            else
                stack[#stack] = nil
            end

            depth = depth - 1
        elseif v ~= "." then
            stack[#stack+1] = v
            depth = depth + 1
        end
    end

    if #stack == 0 then
        return "."
    else
        return table.concat(stack, "/")
    end
end

---Load an Aseprite export from preloaded data.
---@param data table The Aseprite export data; the JSON data converted into a Lua table.
---@param atlas love.Image The image atlas.
---@return pklove.SpriteResource
function module.loadResourceFromMemory(data, atlas)
    local resource = setmetatable({}, SpriteResource)
    
    -- used for release call
    resource._refs = setmetatable({}, {
        __mode = "k"
    })

    resource.atlas = atlas

    -- load cels
    resource.cels = {}
    for _, cel in ipairs(data.frames) do
        local frame = cel.frame

        -- frame render offset
        local ox = cel.sourceSize.w / 2 - cel.spriteSourceSize.x
        local oy = cel.sourceSize.h / 2 - cel.spriteSourceSize.y

        table.insert(resource.cels, {
            quad = love.graphics.newQuad(frame.x, frame.y, frame.w, frame.h, atlas:getWidth(), atlas:getHeight()),
            ox = ox,
            oy = oy,
            duration = cel.duration
        })
    end

    -- load animation data
    resource.animations = {}
    if data.meta.frameTags then
        for _, anim in ipairs(data.meta.frameTags) do
            resource.animations[anim.name] = {
                from = anim.from + 1,
                to = anim.to + 1,
                loopCount = tonumber(anim["repeat"]) or 0,
                loopPoint = anim.from + 1
            }
        end

        -- custom loop points
        for _, start_anim in pairs(resource.animations) do
            for _, loop_anim in pairs(resource.animations) do
                -- if two animations share the same endpoint but have different starting points,
                -- the longer one is the original animation, and the shorter one is the loop section
                if start_anim ~= loop_anim and start_anim.to == loop_anim.to and start_anim.from < loop_anim.from then
                    start_anim.loopPoint = loop_anim.from
                end
            end
        end
    end

    return resource
end

---Load an Aseprite export from its JSON file.
---@param jsonPath string Path to the JSON file.
---@return pklove.SpriteResource
function module.loadResource(jsonPath)
    local data = JSON.decode(love.filesystem.read(jsonPath))
    
    -- load atlas texture
    local pngPath ---@type string
    do
        local path = pathSplit(jsonPath)
        local imagePath = pathSplit(data.meta.image)
        table.remove(path)
        for _, v in ipairs(imagePath) do
            table.insert(path, v)
        end

        pngPath = pathNormalize(path)
    end

    local atlas = love.graphics.newImage(pngPath)
    
    return module.loadResourceFromMemory(data, atlas)
end

---Create a sprite from a sprite resource. (see loadResource or loadResourceFromMemory)
---@param pathOrResource pklove.SpriteResource|string A sprite resource or the path to it.
function module.new(pathOrResource)
    local resource
    if type(pathOrResource) == "string" then
        resource = module.loadResource(pathOrResource)
    else
        resource = pathOrResource
    end

    ---@class pklove.Sprite
    local self = setmetatable({}, Sprite)
    self.res = resource
    self.cel = 1
    resource._refs[self] = true

    ---(Read-only) The name of the currently playing animation.
    self.curAnim = nil ---@type string?
    
    self._timeAccum = 0
    self._loopCount = 0
    self._animChanged = false

    return self
end

---@param sprite table
---@return boolean
function module.isSprite(sprite)
    return getmetatable(sprite) == Sprite
end

---@param spriteRes table
---@return boolean
function module.isSpriteResource(spriteRes)
    return getmetatable(spriteRes) == SpriteResource
end

---Release this SpriteResource.
function SpriteResource:release()
    if self.cels then
        for _, cel in pairs(self.cels) do
            cel.quad:release()
        end
    end
    
    if self.atlas then
        self.atlas:release()
    end

    self.cels = nil
    self.atlas = nil
    self.animations = nil
end

--- Release the resources associated with the sprite.
--- 
--- This will unlink it with the resource, and if it is the
--- only sprite remaining using it, will release the resource
--- as well.
function Sprite:release()
    self.res._refs[self] = nil

    if not next(self.res._refs) then
        self.res:release()
    end

    self.res = nil
end

--- Clone the sprite, keeping frame and animation data linked
function Sprite:clone()
    local clone = setmetatable({}, Sprite)

    for i, v in pairs(self) do
        clone[i] = v
    end

    clone.res._refs[clone] = true
    return clone
end

---Update the sprite animation
---@param dt number Delta-time in seconds
---@return boolean new True if the animation switched to a new cel
function Sprite:update(dt)
    if not self.curAnim then
        return false
    end

    local newCel = false
    local cel = self.res.cels[self.cel]
    local curAnim = self.res.animations[self.curAnim]
    
    self._timeAccum = self._timeAccum + dt
    local celDuration = cel.duration / 1000;
    while self._timeAccum >= celDuration do
        self._timeAccum = self._timeAccum - celDuration
        
        if self.cel >= curAnim.to then
            self._loopCount = self._loopCount + 1

            if curAnim.loopCount > 0 and self._loopCount >= curAnim.loopCount then
                self:stop()
                break
            else
                self.cel = curAnim.loopPoint
                newCel = true
            end
        else
            self.cel = self.cel + 1
            newCel = true
        end
    end

    if self._animChanged then
        self._animChanged = false
        return true
    else
        return newCel
    end
end

---Play an animation
---@param animName string
function Sprite:play(animName)
    if self.res.animations[animName] == nil then
        error(("unknown animation '%s'"):format(animName), 2)
    end

    self._loopCount = 0
    self._timeAccum = 0
    self._animChanged = true
    self.curAnim = animName
    self.cel = self.res.animations[animName].from
end

---Stop currently playing animation, if any
function Sprite:stop()
    self.curAnim = nil
end

---Return true if the sprite has an animation
---@param animName string
function Sprite:hasAnim(animName)
    return self.res.animations[animName] ~= nil
end

---Get the index of the current frame relative to the start of the animation.
---@return integer animFrame The current frame, starting from 1. Returns 0 if no animation is playing.
function Sprite:getAnimFrame()
    if not self.curAnim then
        return 0
    end

    return self.cel - self.res.animations[self.curAnim].from + 1
end

---Draw a specific cel of the sprite
---@param index integer Index of the cel to draw
---@param x number The X coordinate of the sprite's center
---@param y number The Y coordinate of the sprite's center
---@param r? number Rotation in radians
---@param sx? number X scale factor
---@param sy? number Y scale factor
---@param kx? number X skew factor
---@param ky? number Y skew factor
function Sprite:drawCel(index, x, y, r, sx, sy, kx, ky)
    local cel = self.res.cels[index]
    love.graphics.draw(self.res.atlas, cel.quad, x, y, r, sx, sy, cel.ox, cel.oy, kx, ky)
end

---Draw the sprite
---@param x number The X coordinate of the sprite's center
---@param y number The Y coordinate of the sprite's center
---@param r? number Rotation in radians
---@param sx? number X scale factor
---@param sy? number Y scale factor
---@param kx? number X skew factor
---@param ky? number Y skew factor
function Sprite:draw(x, y, r, sx, sy, kx, ky)
    self:drawCel(self.cel, x, y, r, sx, sy, kx, ky)
end

return module
