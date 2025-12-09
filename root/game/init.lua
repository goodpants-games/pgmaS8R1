local Concord = require("concord")
local r3d = require("r3d")
local Sprite = require("sprite")
local Room = require("game.room")
local Collision = require("game.collision")

local ecsconfig = require("game.ecsconfig")
local consts = require("game.consts")

---@class Game.Attack
---@field x number
---@field y number
---@field radius number
---@field damage number
---@field dx number
---@field dy number
---@field ground_only boolean?
---@field knockback number?
---@field mask integer?
---@field owner any?

---@class Game
---@field frame integer
---@field ecs_world any
---@field r3d_world r3d.World
---@field r3d_sprite_batch r3d.Batch Transparency-allowed draw batch
---@field r3d_batch r3d.Batch Opaque draw batch
---@field private _dt_accum number
---@overload fun():Game
local Game = batteries.class({ name = "Game" })

function Game:new()
    self._dt_accum = 0.0
    self.frame = 0

    self.ecs_world = Concord.world()
    self.ecs_world.game = self
    self.ecs_world:addSystems(
        ecsconfig.systems.player_controller,
        ecsconfig.systems.behavior,
        ecsconfig.systems.actor,
        ecsconfig.systems.attack,
        ecsconfig.systems.physics,
        ecsconfig.systems.gun_sight,
        ecsconfig.systems.special,
        ecsconfig.systems.render)

    ---@type table?
    self.player = nil
    self.player_is_dead = false

    -- create r3d world
    self.r3d_world = r3d.world()

    self.r3d_sprite_batch = r3d.batch(2048)
    self.r3d_sprite_batch.opaque = false
    self.r3d_sprite_batch.double_sided = true
    self.r3d_sprite_batch:set_shader("shaded_ignore_normal")

    self.r3d_batch = r3d.batch(2048)
    self.r3d_batch.opaque = true
    self.r3d_batch.double_sided = false
    self.r3d_batch:set_shader("basic")

    self.r3d_world:add_object(self.r3d_batch)
    self.r3d_world:add_object(self.r3d_sprite_batch)

    self._ui_icons_sprite = Sprite.new("res/sprites/ui_icons.json")
    self._font = Lg.newFont("res/fonts/DepartureMono-Regular.otf", 11, "mono", 1.0)

    self.layout_width = 4
    self.layout_height = 4
    self.layout_x = 0
    self.layout_y = 0

    self.layout = {
        {"01", "02", "01", "02"},
        {"02", "01", "02", "01"},
        {"01", "02", "01", "02"},
        {"02", "01", "02", "01"},
    }

    self.layout_visited = {}
    for y=1, self.layout_height do
        self.layout_visited[y] = {}
        for x=1, self.layout_width do
            self.layout_visited[y][x] = false
        end
    end

    -- self.room = Room(self, "res/maps/units/01.lua")
    self:_load_room_at_current()
    self.player = self:new_entity():assemble(ecsconfig.asm.entity.player, 64, 64)

    ---@private
    self._transport_trans_state = 0
    ---@private
    self._transport_dx = 0
    ---@private
    self._transport_dy = 0
    ---@private
    self._transport_timer = 0.0
    ---@private
    self._transport_debounce = false
    ---@private
    self._transport_triggered = false

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
    self.room:release()
    self.r3d_world:release()
    self.r3d_batch:release()
    self.r3d_sprite_batch:release()
    self._ui_icons_sprite:release()
    self._font:release()
end

function Game:new_entity()
    return Concord.entity(self.ecs_world)
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
    assert(self.room, "room is not loaded")
    local cam = self.room.cam

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

    if self._transport_trans_state == 1 then
        self._transport_timer = self._transport_timer + (1.0 / 40.0)
        if self._transport_timer >= 1.0 then
            self:_complete_room_transport(self._transport_dx, self._transport_dy)
        end
    elseif self._transport_trans_state == 2 then
        self._transport_timer = self._transport_timer - (1.0 / 40.0)
        if self._transport_timer <= 0.0 then
            self._transport_dx = 0
            self._transport_dy = 0
            self._transport_trans_state = 0
        end
    elseif self._transport_debounce and not self._transport_triggered then
        self._transport_debounce = false
    end

    self._transport_triggered = false

    -- if self.cam_follow then
    --     local pos = self.cam_follow.position
    --     if pos then
    --         self.cam_x = pos.x
    --         self.cam_y = pos.y
    --     end
    -- end

    self.frame = self.frame + 1
end

function Game:update(dt)
    assert(self.room, "a room is not loaded")

    Debug.draw:push()
    Debug.draw:translate(math.round(-self.room.cam.x + DISPLAY_WIDTH / 2.0), math.round(-self.room.cam.y + DISPLAY_HEIGHT / 2.0))

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
    local cam_x = math.round(self.room.cam.x)
    local cam_y = math.round(self.room.cam.y)

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

    self.r3d_batch:clear()
    self.r3d_sprite_batch:clear()

    Lg.push()
    Lg.translate(math.round(-cam_x + DISPLAY_WIDTH / 2.0), math.round(-cam_y + DISPLAY_HEIGHT / 2.0))
    self.ecs_world:emit("draw")
    Lg.pop()

    r3d_world:draw()

    self:_draw_ui()

    if self._transport_trans_state > 0 then
        Lg.setColor(0, 0, 0, self._transport_timer)
        Lg.rectangle("fill", 0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT)
    end

    -- local tl = self._tiled_map.layers[1] --[[@as pklove.tiled.TileLayer]]
    -- tl:draw()
    -- self.ecs_world:emit("draw")

    -- Lg.pop()
end

---@private
function Game:_draw_ui()
    local old_font = Lg.getFont()
    Lg.setFont(self._font)

    -- display battery ui
    local player_health = self.player.health
    local battery_percentage = player_health.value / player_health.max
    if battery_percentage < 0.0 then
        battery_percentage = 0.0
    end

    -- Lg.setColor(1, 1, 1)
    -- Lg.rectangle("fill", 0, 0, math.round(battery_percentage * DISPLAY_WIDTH), 4)

    if battery_percentage < 0.2 then
        Lg.setColor(1, 0, 0)
    elseif battery_percentage < 0.5 then
        Lg.setColor(1, 1, 0)
    else
        Lg.setColor(1, 1, 1)
    end

    local sprite_ox = 5.5
    local sprite_oy = 5.5

    local text_origin_y = DISPLAY_HEIGHT - 15

    do
        local height = math.round(6.0 * battery_percentage)
        self._ui_icons_sprite:drawCel(1, sprite_ox, text_origin_y + sprite_oy)
        Lg.rectangle("fill", 4, DISPLAY_HEIGHT - 5 - height, 5, height)
    end

    Lg.print(("%.0f%%"):format(battery_percentage * 100.0), 12, DISPLAY_HEIGHT - 15)

    local selected_weapon = self.player.behavior.inst.selected_weapon

    -- melee
    if selected_weapon == 1 then
        Lg.setColor(batteries.color.unpack_rgb(0x4266f5))
    else
        Lg.setColor(1, 1, 1, 0.5)
    end
    self._ui_icons_sprite:drawCel(2, sprite_ox + 42, text_origin_y + sprite_oy)

    -- gun
    if selected_weapon == 2 then
        Lg.setColor(batteries.color.unpack_rgb(0xff3826))
    else
        Lg.setColor(1, 1, 1, 0.5)
    end
    self._ui_icons_sprite:drawCel(3, sprite_ox + 54, text_origin_y + sprite_oy)

    -- map
    local MAP_CELL_SIZE = 5
    Lg.push()
    Lg.translate(DISPLAY_WIDTH - self.layout_width * MAP_CELL_SIZE - 4,
                 DISPLAY_HEIGHT - self.layout_height * MAP_CELL_SIZE - 4)

    for ly=0, self.layout_height - 1 do
        for lx=0, self.layout_width - 1 do
            local room_visited = self.layout_visited[ly+1][lx+1]

            if self.layout_x == lx and self.layout_y == ly then
                if not room_visited then
                    if self.frame % 30 < 15 then
                        Lg.setColor(1, 1, 1)
                    else
                        Lg.setColor(batteries.color.unpack_rgb(0x4266f5))
                    end
                else
                    Lg.setColor(1, 1, 1)
                end
            else
                if room_visited then
                    Lg.setColor(0.3, 0.3, 0.3)
                else
                    Lg.setColor(0.1, 0.1, 0.1)
                end
            end

            Lg.rectangle("fill",
                         lx * MAP_CELL_SIZE, ly * MAP_CELL_SIZE,
                         MAP_CELL_SIZE - 1, MAP_CELL_SIZE - 1)
        end
    end

    Lg.pop()

    Lg.setFont(old_font)
end

---Add attack sphere
---@param attack Game.Attack
function Game:add_attack(attack)
    if attack.mask == nil then
        attack.mask = consts.COLGROUP_ALL
    end
    if attack.dx == nil then
        attack.dx = 0.0
    end
    if attack.dy == nil then
        attack.dy = 0.0
    end
    if attack.knockback == nil then
        attack.knockback = 0.0
    end
    if attack.ground_only == nil then
        attack.ground_only = true
    end

    assert(attack.x, "attack does not have required field 'x'")
    assert(attack.y, "attack does not have required field 'y'")
    assert(attack.radius, "attack does not have required field 'radius'")
    assert(attack.damage, "attack does not have required field 'damage'")

    local attack_system = self.ecs_world:getSystem(ecsconfig.systems.attack)
    table.insert(attack_system.attacks, attack)
end

---@param ent any
---@param out_list any[]?
function Game:get_entities_touching(ent, out_list)
    out_list = out_list or {}

    local my_pos = ent.position
    local my_col = ent.collision
    if my_pos and my_col then
        for _, e in ipairs(self.ecs_world:getEntities()) do
            local other_pos = e.position
            local other_col = e.collision

            local col = Collision.rect_rect_intersection(
                my_pos.x, my_pos.y, my_col.w, my_col.h,
                other_pos.x, other_pos.y, other_col.w, other_col.h)
            
            if col then
                table.insert(out_list, e)
            end
        end
    end

    return out_list
end

---comment
---@param transport_dir "right"|"up"|"left"|"down"
function Game:initiate_room_transport(transport_dir)
    self._transport_triggered = true

    if self._transport_trans_state ~= 0 or self._transport_debounce then
        return
    end

    assert(self._transport_trans_state == 0)
    print("initiate room transport!", transport_dir)

    if transport_dir == "right" then
        self._transport_dx = 1.0
        self._transport_dy = 0.0
    elseif transport_dir == "left" then
        self._transport_dx = -1.0
        self._transport_dy = 0.0
    elseif transport_dir == "up" then
        self._transport_dx = 0.0
        self._transport_dy = -1.0
    elseif transport_dir == "down" then
        self._transport_dx = 0.0
        self._transport_dy = 1.0
    else
        error("invalid room transport direction")
    end

    self._transport_trans_state = 1
    self._transport_timer = 0.0
end

---@return boolean is_active, number? dx, number? dy
function Game:room_transport_info()
    if self._transport_trans_state > 0 then
        return true, self._transport_dx, self._transport_dy
    else
        return false
    end
end

---@private
function Game:_load_room_at_current()
    if self.layout_x < 0 or self.layout_y < 0 or
       self.layout_x >= self.layout_width or self.layout_y >= self.layout_height
    then
        error("outside of layout")
    end

    local room = self.layout[self.layout_y+1][self.layout_x+1]

    self.room = Room(self, "res/maps/units/"..room..".lua", {
        left  = self.layout_x == 0,
        up    = self.layout_y == 0,
        right = self.layout_x == self.layout_width - 1,
        down  = self.layout_y == self.layout_height - 1
    })
end

---@private
---@param dx number
---@param dy number
function Game:_complete_room_transport(dx, dy)
    print("its done. Stop.")
    self._transport_timer = 1.0
    self._transport_trans_state = 2
    self._transport_debounce = true

    self.room:release()
    -- self.player:destroy()

    self.layout_visited[self.layout_y+1][self.layout_x+1] = true

    self.layout_x = self.layout_x + dx
    self.layout_y = self.layout_y + dy
    
    self:_load_room_at_current()
    collectgarbage("collect")
    collectgarbage("collect")

    -- place player at opposite room transport object
    for _, obj in ipairs(self.ecs_world:getEntities()) do
        if not obj.room_transport then
            goto continue
        end

        local transport = obj.room_transport.dir
        local obj_pos = assert(obj.position, "room_transport does not have position")
        local obj_col = assert(obj.collision, "room transport does not have collision")

        local obj_dx, obj_dy
        if transport == "right" then
            obj_dx, obj_dy = 1, 0
        elseif transport == "left" then
            obj_dx, obj_dy = -1, 0
        elseif transport == "up" then
            obj_dx, obj_dy = 0, -1
        elseif transport == "down" then
            obj_dx, obj_dy = 0, 1
        else
            error("invalid room_transport direction")
        end

        if obj_dx == -dx and obj_dy == -dy then
            self.player.position.x = obj_pos.x + dx * obj_col.w / 2.0
            self.player.position.y = obj_pos.y + dy * obj_col.h / 2.0
            break
        end

        ::continue::
    end
end

return Game