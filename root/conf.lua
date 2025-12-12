print("Lua version:", _VERSION)

-- this is to make a lua debugger extension work
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()

    -- for some reason, assertion errors points to a lldebugger internal file
    -- so i'm redefining assert so that doesn't happen 
    function assert(a, b)
        return a or error(b or "assertion failed!", 2)
    end

    function love.errorhandler(msg)
        error(msg, 3)
    end
end

if not package.loaded["bit"] then
	local bit32 = package.loaded["bit32"]
	assert(bit32, "lua environment does not have bit/bit32 library!")
	package.loaded["bit"] = bit32
end

if not unpack then
    unpack = table.unpack
end

if setfenv == nil then
    ---@param f integer|fun(any...):...unknown
    ---@param table table
    ---@return function
    function setfenv(f, table)
        if type(f) == "number" then
            f = debug.getinfo(f, "f").func
        end
        ---@cast f function

        local nm = debug.getupvalue(f, 1)
        if nm ~= "_ENV" then
           error("could not set function env") 
        end

        debug.setupvalue(f, 1, table)
        return f
    end
end

DISPLAY_WIDTH = 240
DISPLAY_HEIGHT = 180

function love.conf(t)
    t.identity = "pkhead_SystemShutdownImminent"
    t.window.width = DISPLAY_WIDTH * 3
    t.window.height = DISPLAY_HEIGHT * 3
    t.window.resizable = true
    t.window.vsync = 1
    t.window.highdpi = true
    t.window.title = "SYSTEM SHUTDOWN IMMINENT"
    
    t.modules.thread = false
    t.modules.video = false
    t.modules.physics = false
end