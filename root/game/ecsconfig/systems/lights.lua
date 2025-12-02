local Concord = require("concord")
local mat4 = require("r3d.mat4")
local Light = require("r3d.light")

local light_system = Concord.system({
    pool = {"position", "light"}
})

function light_system:init(world)
    self.lights = {}
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

    local px, py, pz = pos.x, pos.y, info.z_offset

    if info.type == "spot" then
        ---@cast light r3d.SpotLight
        light.angle = info.spot_angle

        light.transform =
            mat4.translation(nil, px, py, pz) *
            mat4.rotation_x(nil, info.spot_rx)
            mat4.rotation_z(nil, info.spot_rz)
    else
        light.transform:identity()
        light:set_position(px, py, pz)
    end

    return light
end

function light_system:draw()
    ---@type r3d.World
    local world = self:getWorld().game.r3d_world
    
    local ents_to_remove = {}
    for ent, _ in pairs(self.lights) do
        ents_to_remove[ent] = true
    end

    -- handle new entities
    for _, ent in ipairs(self.pool) do
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

return light_system