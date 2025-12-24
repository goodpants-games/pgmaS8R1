local Concord = require("concord")
local r3d = require("r3d")
local Sprite = require("sprite")
local Room = require("game.room")
local Collision = require("game.collision")
local SoundManager = require("game.sound_manager")
local map_loader = require("game.map_loader")
local mat4 = require("r3d.mat4")
local fontres = require("fontres")

local ecsconfig = require("game.ecsconfig")
local consts = require("game.consts")
local userpref = require("userpref")

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
---@overload fun(progression:Game.Progression):Game
local Game = batteries.class({ name = "Game" })

---@param progression Game.Progression
function Game:new(progression)
    self._dt_accum = 0.0
    self.frame = 0

    ---@private
    self.progression = progression
    self.sound = SoundManager()
    self.resources = {}

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
        ecsconfig.systems.particle,
        ecsconfig.systems.render)

    ---@type table?
    self.player = nil
    self.player_is_dead = false
    self.player_color = progression.player_color

    -- create r3d world
    self.r3d_world = r3d.world()

    -- create shaders
    do
        local shd = r3d.shader()
        shd:prepare()
        self.resources.shader_default = shd
    end

    do
        local shd = r3d.shader()
        shd.alpha_discard = true
        shd:prepare()
        self.resources.shader_alpha_discard = shd
    end

    do
        local shd = r3d.shader()
        shd.custom_fragment = "res/shaders/r3d_alpha_influence.glsl"
        shd:prepare()
        self.resources.shader_alpha_influence = shd
    end

    do
        local shd = r3d.shader()
        shd.light_ignore_normals = true
        shd:prepare()
        self.resources.shader_ignore_normal = shd
    end

    do
        local shd = r3d.shader()
        shd.shading = "none"
        shd:prepare()
        self.resources.shader_unshaded = shd
    end

    self.r3d_sprite_batch = r3d.batch(2048)
    self.r3d_sprite_batch.opaque = false
    self.r3d_sprite_batch.double_sided = true
    self.r3d_sprite_batch.base_shader = self.resources.shader_ignore_normal

    self.r3d_batch = r3d.batch(2048)
    self.r3d_batch.opaque = true
    self.r3d_batch.double_sided = false
    self.r3d_batch.base_shader = self.resources.shader_unshaded

    self.r3d_world:add_object(self.r3d_batch)
    self.r3d_world:add_object(self.r3d_sprite_batch)

    self.r3d_world.ambient.r = 0.04
    self.r3d_world.ambient.g = 0.04
    self.r3d_world.ambient.b = 0.04

    local heart_mesh = r3d.mesh.load_obj("res/heart_model.obj")
    self.resources.heart_model = r3d.model(heart_mesh)
    self.resources.heart_model.shader = self.resources.shader_unshaded

    self.resources.tileset = Lg.newImage("res/tilesets/test_tileset.png")
    self.resources.edge_tileset, self.resources.edge_tileset_data =
        map_loader.create_edge_atlas({ "metal", "concrete", "flesh" })

    self._ui_icons_sprite = Sprite.new("res/sprites/ui_icons.json")

    self.layout_width = consts.LAYOUT_WIDTH
    self.layout_height = consts.LAYOUT_HEIGHT
    self.layout_x = 0
    self.layout_y = 0

    -- self.layout = {
    --     {"start", "units/12", "units/07", "units/03"},
    --     {"units/02", "units/03", "units/02", "units/01"},
    --     {"units/01", "units/02", "units/01", "units/02"},
    -- }

    ---@type string[][]
    self.layout = {}
    ---@type boolean[][]
    self.layout_visited = {}
    ---@type {memory:game.RoomMemory?, heart_color:integer?, heart_visible:boolean?, prog:Game.ProgressionRoom?}[][]
    self.room_data = {}

    local progi = 1
    local prog_rooms = table.shuffle(table.copy(progression.rooms))

    -- make sure start room is always first
    for i, v in ipairs(prog_rooms) do
        if v.room_id == "start" then
            table.remove(prog_rooms, i)
            table.insert(prog_rooms, 1, v)
            break
        end
    end

    for y=1, self.layout_height do
        self.layout[y] = {}
        self.layout_visited[y] = {}
        self.room_data[y] = {}
        for x=1, self.layout_width do
            local prog_room = prog_rooms[progi]

            if x == 1 and y == 1 then
                assert(prog_room.room_id == "start")
                self.layout[y][x] = "start"
            else
                self.layout[y][x] = "units/" .. prog_room.room_id
            end
            
            self.room_data[y][x] = {
                heart_color = prog_room.heart_color,
                heart_visible = prog_room.heart_visible,
                prog = prog_room
            }

            progi = progi + 1
            
            self.layout_visited[y][x] = false
        end
    end

    -- self.room = Room(self, "res/maps/units/01.lua")
    self:_load_room_at_current()

    if not self.room.player_spawn_x then
        error("uh how do i spawn the player. HELP")
    end

    local player_health = 150
    if self.progression.difficulty == 3 then
        player_health = 80
    elseif self.progression.difficulty == 4 then
        player_health = 1
    end

    self.player = self:new_entity()
        :assemble(ecsconfig.asm.entity.player,
                  self.room.player_spawn_x,
                  self.room.player_spawn_y,
                  player_health)

    if progression.difficulty == 4 then
        self.player.light.r = 1.0
        self.player.light.g = 0.6
        self.player.light.b = 0.6
    end
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

    ---@private
    self._ping_vis_timer = 0.0

    self.cam_shake = 0
    self.battery_shake = 0
    self.color_shake = 0

    ---@private
    self._battery_shake_ox = 0
    ---@private
    self._battery_shake_oy = 0

    ---@private
    self._color_shake_ox = 0
    ---@private
    self._color_shake_oy = 0

    ---@private
    self._shutdown_sequence = nil

    -- test to make sure edge autotiler doesn't crash
    if true or not Debug.enabled then
        return
    end

    ---@param room_name string
    ---@param l boolean
    ---@param u boolean
    ---@param r boolean
    ---@param d boolean
    local function room_load_test(room_name, l,u,r,d)
        local room = Room(self, "res/maps/"..room_name..".lua", {
            spawn_enemies = false,
            closed_room_sides = {
                left  = l,
                up    = u,
                right = r,
                down  = d,
            }
        })

        room:release()
    end

    local bit = require("bit")
    for _, room_name in ipairs({ "start", "units/01", "units/02", "units/03", "units/04", "units/05", "units/06", "units/07", "units/08", "units/09", "units/10", "units/11", "units/12" }) do
        for i=0, 15 do
            print(room_name, i)
            local l = bit.band(i, 1)~=0
            local r = bit.band(i, 2)~=0
            local u = bit.band(i, 4)~=0
            local d = bit.band(i, 8)~=0
            room_load_test(room_name, l, r, u, d)
        end
    end

end

function Game:release()
    self.room:release()
    self.r3d_world:release()
    self.r3d_batch:release()
    self.r3d_sprite_batch:release()
    self._ui_icons_sprite:release()
    self.sound:release()

    for _, res in pairs(self.resources) do
        if res.release then
            res:release()
        end
    end
end

function Game:new_entity()
    return Concord.entity(self.ecs_world)
end

function Game:destroy_entity(ent)
    if self.room then
        self.room:remove_entity(ent)
    end

    ent:destroy()
end

---@param snd_name string
function Game:new_sound(snd_name)
    return self.sound:new_sound(snd_name)
end

---@param snd_name string
---@param ent any
function Game:sound_quick_play(snd_name, ent)
    local snd = self.sound:new_sound(snd_name)
    if ent then
        snd:attach_to(ent)
    end
    snd.src:play()
    snd:release()
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

    if self._ping_vis_timer > 0.0 then
        self._ping_vis_timer = self._ping_vis_timer - (1.0 / 30.0)
    end

    -- if self.cam_follow then
    --     local pos = self.cam_follow.position
    --     if pos then
    --         self.cam_x = pos.x
    --         self.cam_y = pos.y
    --     end
    -- end

    if self.frame % 2 == 0 then
        if self.cam_shake > 0 then
            self.room.cam.shake_ox = love.math.random(-1, 1)
            self.room.cam.shake_oy = love.math.random(-1, 1)
            self.cam_shake = math.max(self.cam_shake - 2, 0)
        else
            self.room.cam.shake_ox = 0.0
            self.room.cam.shake_oy = 0.0
        end

        if self.battery_shake > 0 then
            self._battery_shake_ox = love.math.random(-1, 1)
            self._battery_shake_oy = love.math.random(-1, 1)
            self.battery_shake = math.max(self.battery_shake - 2, 0)
        else
            self._battery_shake_ox = 0.0
            self._battery_shake_oy = 0.0
        end

        if self.color_shake > 0 then
            self._color_shake_ox = love.math.random(-2, 2)
            self._color_shake_oy = love.math.random(-2, 2)
            self.color_shake = math.max(self.color_shake - 2, 0)
        else
            self._color_shake_ox = 0.0
            self._color_shake_oy = 0.0
        end
    end

    local shutdown = self._shutdown_sequence
    if shutdown then
        local phase_len = 1.125 -- synced with the siren
        local tsec = shutdown.frames * consts.TICK_LEN
        local t = (math.sin(tsec * phase_len * 2 * math.pi) + 1.0) / 2.0
        self.r3d_world.ambient.r = t * 0.9

        shutdown.frames = shutdown.frames + 1
        shutdown.frames_until_vo = shutdown.frames_until_vo - 1

        if shutdown.frames_until_vo == 0 then
            shutdown.frames_until_vo = 240
            shutdown.vo_source:seek(0)
            shutdown.vo_source:play()
            shutdown.vo_count = shutdown.vo_count + 1

            if shutdown.vo_count == 3 then
                shutdown.is_done = true
                shutdown.siren_sound:stop()
                self.sound:stop_all()
            end
        end

        local rot_power = shutdown.frames / 780.0
        self.room.cam.rot = math.sin(shutdown.frames * 0.3) * math.rad(25 * rot_power)
        self.cam_shake = 10
    end

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

    self.sound.listener_x = self.player.position.x
    self.sound.listener_y = self.player.position.y
    self.sound:update()
end

---@param paused boolean
function Game:draw(paused)
    local r3d_world = self.r3d_world
    local cam_x = math.round(self.room.cam.x + self.room.cam.shake_ox)
    local cam_y = math.round(self.room.cam.y + self.room.cam.shake_oy)

    r3d_world.cam.transform:identity()
    r3d_world.cam:set_position(cam_x, cam_y, 0.0)
    r3d_world.cam.transform = mat4.rotation_z(nil, self.room.cam.rot) * r3d_world.cam.transform

    if Debug.enabled and love.keyboard.isDown("e") then
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

    self.r3d_batch:clear()
    self.r3d_sprite_batch:clear()

    Lg.push()
    Lg.translate(math.round(-cam_x + DISPLAY_WIDTH / 2.0), math.round(-cam_y + DISPLAY_HEIGHT / 2.0))
    self.ecs_world:emit("draw")
    Lg.pop()

    r3d_world:draw()

    if self._ping_vis_timer > 0.0 then
        local colors = {
            {1, 0, 0},
            {0, 1, 0},
            {0, 0, 1}
        }

        local r, g, b = unpack(colors[self.player_color])
        Lg.setColor(r, g, b, self._ping_vis_timer)
        Lg.rectangle("fill", 0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT)
    end

    self:_draw_ui()

    if self._transport_trans_state > 0 then
        Lg.setColor(0, 0, 0, self._transport_timer)
        Lg.rectangle("fill", 0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT)
    end

    if not paused and userpref.control_mode == "dual" then
        Lg.setColor(1, 1, 1)
        local draw_x = math.round(MOUSE_X)
        local draw_y = math.round(MOUSE_Y)
        local draw_w = 3
        local draw_h = 3
        Lg.setLineStyle("rough")
        Lg.rectangle("line", draw_x - draw_w/2.0 + 0.5, draw_y - draw_h/2.0 + 0.5, draw_w, draw_h)
    end

    -- local tl = self._tiled_map.layers[1] --[[@as pklove.tiled.TileLayer]]
    -- tl:draw()
    -- self.ecs_world:emit("draw")

    -- Lg.pop()
end

local UI_COLOR_TABLE = {
    {
        color = { batteries.color.unpack_rgb(0xff3826) },
        display = "724.2 nm",
    },
    {
        color = { batteries.color.unpack_rgb(0x2fc45e) },
        display = "541.8 nm",
    },
    {
        color = { batteries.color.unpack_rgb(0x4266f5) },
        display = "472.3 nm",
    },
}

---@private
function Game:_draw_ui()
    local old_font = Lg.getFont()
    Lg.setFont(fontres.departure)

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

    Lg.push()
    Lg.translate(self._battery_shake_ox, self._battery_shake_oy)
    do
        local height = math.round(6.0 * battery_percentage)
        self._ui_icons_sprite:drawCel(1, sprite_ox, text_origin_y + sprite_oy)
        Lg.rectangle("fill", 4, DISPLAY_HEIGHT - 5 - height, 5, height)
    end

    Lg.print(("%.0f%%"):format(battery_percentage * 100.0), 12, text_origin_y)
    Lg.pop()

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

    -- resonant frequency (aka player color)
    Lg.push()
    Lg.translate(self._color_shake_ox, self._color_shake_oy)
        local player_color = UI_COLOR_TABLE[self.player_color]
        if self.color_shake % 4 == 0 then
            Lg.setColor(unpack(player_color.color))
        else
            Lg.setColor(1, 1, 1)
        end

        Lg.print(player_color.display, 68, text_origin_y)
    Lg.pop()

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

            if other_pos and other_col then
                local col = Collision.rect_rect_intersection(
                    my_pos.x, my_pos.y, my_col.w, my_col.h,
                    other_pos.x, other_pos.y, other_col.w, other_col.h)
                
                if col then
                    table.insert(out_list, e)
                end
            end
        end
    end

    return out_list
end

---comment
---@param transport_dir "right"|"up"|"left"|"down"
function Game:initiate_room_transport(transport_dir)
    if self._shutdown_sequence then
        return
    end

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
function Game:_can_room_connect(from_x, from_y, dx, dy)
    local x = from_x + dx
    local y = from_y + dy
    if x < 0 or y < 0 or x >= self.layout_width or y >= self.layout_height then
        return false
    end

    if x == 0 and y == 0 then
        return dx == -1 and dy == 0
    end

    return true
end

---@private
function Game:_load_room_at_current()
    local x = self.layout_x
    local y = self.layout_y

    if x < 0 or y < 0 or
       x >= self.layout_width or y >= self.layout_height
    then
        error("outside of layout")
    end

    if self.room then
        self.room:release()
    end

    local room = self.layout[y+1][x+1]
    local room_data = self.room_data[y+1][x+1]

    self.room = Room(self, "res/maps/"..room..".lua", {
        memory = room_data.memory,
        heart_color = room_data.heart_color,
        heart_visible = room_data.heart_visible,
        spawn_enemies = room ~= "start",
        closed_room_sides = {
            left  = not self:_can_room_connect(x,y, -1, 0),
            up    = not self:_can_room_connect(x,y, 0, -1),
            right = not self:_can_room_connect(x,y, 1, 0),
            down  = not self:_can_room_connect(x,y, 0, 1)
        }
    })
end

function Game:heart_destroyed()
    print("HEART WAS DESTROYED")
    local room_data = self.room_data[self.layout_y+1][self.layout_x+1]

    room_data.heart_color = nil
    room_data.heart_visible = nil

    if room_data.prog then
        room_data.prog.heart_color = nil
        room_data.prog.heart_visible = nil
        room_data.prog.heart_destroyed = true
    end

    local health = self.player.health
    if self.progression.difficulty <= 2 then
        health.value = health.value + 50.0
        if health.value > health.max then
            health.value = health.max
        end
    end

    -- if all hearts were destroyed, then initiate ending sequence
    local all_destroyed = true
    for y=1, self.layout_height do
        for x=1, self.layout_width do
            local dat = self.room_data[y][x]
            if dat.prog and dat.prog.heart_color then
                all_destroyed = false
                goto exit_check
            end
        end
    end
    ::exit_check::

    if all_destroyed then
        local siren_sound = love.audio.newSource("res/sounds/siren.ogg", "static")
        siren_sound:play()

        local vo_source = love.audio.newSource("res/sounds/voice_system_shutdown_imminent.ogg", "static")

        self._shutdown_sequence = {
            frames = 0,
            frames_until_vo = 60,
            vo_count = 0,
            is_done = false,
            siren_sound = siren_sound,
            vo_source = vo_source
        }
    end
end

---@private
---@param dx number
---@param dy number
function Game:_complete_room_transport(dx, dy)
    print("its done. Stop.")
    self._transport_timer = 1.0
    self._transport_trans_state = 2
    self._transport_debounce = true

    self.room_data[self.layout_y+1][self.layout_x+1].memory = self.room:create_memory()
    self.layout_visited[self.layout_y+1][self.layout_x+1] = true

    self.room:release()
    
    self.layout_x = self.layout_x + dx
    self.layout_y = self.layout_y + dy
    
    self:_load_room_at_current()
    collectgarbage("collect")
    collectgarbage("collect")

    -- place player at opposite room transport object
    self.ecs_world:__flush() -- Bruh.
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
            -- break
        end

        ::continue::
    end
end

---@return Game.Progression
function Game:get_new_progression()
    self.layout_visited[self.layout_y+1][self.layout_x+1] = true
    self.progression.player_color = self.player_color + 1

    for y=1, self.layout_height do
        for x=1, self.layout_width do
            local room_data = self.room_data[y][x]
            
            if self.layout_visited[y][x] and
               room_data.prog and room_data.prog.heart_visible ~= nil
            then
                room_data.prog.heart_visible = false
            end
        end
    end

    return self.progression
end

function Game:suicide()
    self.player.health.value = 0.0
end

function Game:player_ping()
    self._ping_vis_timer = 1.0
    local heart_color, already_visible = self.room:ping_for_heart()
    if not already_visible and heart_color ~= self.player_color then
        print("penalize")
        self:sound_quick_play("player_hurt")
        local health = self.player.health

        ---@type number
        local health_deduct -- as a percentage
        if self.progression.difficulty == 1 then
            health_deduct = 0.07
        elseif self.progression.difficulty == 2 then
            health_deduct = 0.17
        else
            health_deduct = 0.25
        end

        health.value = health.value - health.max * health_deduct
        self.battery_shake = self.battery_shake + 6
        if health.value < 0.0 then
            health.value = 0.0
        end
    else
        self:sound_quick_play("ping")
    end
end

function Game:get_difficulty()
    return self.progression.difficulty
end

---@return integer?
function Game:shutdown_sequence_status()
    local dat = self._shutdown_sequence
    if not dat then
        return nil
    end

    if dat.is_done then
        return 2
    else
        return 1
    end
end

return Game