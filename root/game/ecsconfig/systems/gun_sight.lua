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
        
        local target_ent = nil
        ent_ignore[1] = ent

        if gun_sight.auto_aim then
            local min_ang_diff = math.rad(20)

            for _, target in ipairs(self.target_pool) do
                if target.health and target.health.value <= 0.0 then
                    goto continue
                end

                local t_position = target.position

                local dx = t_position.x - position.x
                local dy = t_position.y - position.y

                local ang_to_target = math.atan2(dy, dx)
                local ang_diff = math.abs(math.angle_difference(ang_to_target, rotation))

                if ang_diff < min_ang_diff then
                    local _, _, _, hit_ent = game:raycast(
                        position.x, position.y,
                        dx, dy,
                        consts.COLGROUP_ALL, ent_ignore)

                    if hit_ent == target then
                        min_ang_diff = ang_diff
                        rotation = ang_to_target
                        target_ent = target
                    end
                end

                ::continue::
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

        gun_sight.target_zoff = 0.0
        gun_sight.cur_dx = look_x * raydist
        gun_sight.cur_dy = look_y * raydist
        
        if target_ent then
            local target_sprite = target_ent.sprite
            local target_position = target_ent.position

            if target_sprite then
                gun_sight.target_zoff = target_sprite.z_offset
            end

            if target_position then
                gun_sight.cur_dx = target_position.x - position.x
                gun_sight.cur_dy = target_position.y - position.y 
            end
        else
            gun_sight.target_zoff = 0.0
            gun_sight.cur_dx = look_x * raydist
            gun_sight.cur_dy = look_y * raydist
        end
    end
end

return system
