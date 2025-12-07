local Concord = require("concord")
local consts = require("game.consts")
local system = Concord.system({
    pool = {"position", "gun_sight"},
    target_pool = {"position", "attackable"}
})

function system:tick()
    ---@type Game
    local game = self:getWorld().game
    local ent_ignore = {}

    for _, ent in ipairs(self.pool) do
        local position = ent.position
        local gun_sight = ent.gun_sight
        local rotation = ent.rotation and ent.rotation.ang or 0

        ent_ignore[1] = ent

        if gun_sight.auto_aim then
            local min_ang_diff = math.rad(10)

            for _, target in ipairs(self.target_pool) do
                local t_position = target.position

                local ang_to_target = math.atan2(t_position.y - position.y, t_position.x - position.x)
                local ang_diff = math.abs(math.angle_difference(ang_to_target, rotation))

                if ang_diff < min_ang_diff then
                    rotation = ang_to_target
                end
            end
        end

        local look_x = math.cos(rotation)
        local look_y = math.sin(rotation)
        local raydist = game:raycast(position.x, position.y,
                                     look_x * gun_sight.max_dist, look_y * gun_sight.max_dist,
                                     consts.COLGROUP_ALL, ent_ignore)
        
        if not raydist then
            raydist = gun_sight.max_dist
        end 
        
        gun_sight.cur_dx = look_x * raydist
        gun_sight.cur_dy = look_y * raydist
    end
end

return system
