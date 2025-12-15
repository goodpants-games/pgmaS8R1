---@diagnostic disable undefined-global

if NO_START_COMMAND then
    print("Machine is already fully active.")
    return 
end

local GameProgression = require("game.progression")
if not GameProgression.progression then
    local game_difficulty = 2
    puts
[[Choose game difficulty.
EASY:    Ping penalty is lowered.
NORMAL:  Balanced difficulty.
HARD:    Destroying cores recovers
         no HP. Enemies do more
         damage.
EVIL:    For those who are sick
         in the head.

Type, or "x" to cancel:
]]

    while true do
        -- print("Choose game difficulty.")
        -- print("EASY:   Destroying cores recovers\n        all HP.")
        -- print("NORMAL: Destroying cores recovers some HP.")
        -- print("HARD: Destroying cores recovers no HP. Enemies do more damage.")
        local input = string.lower(get_line())

        if input:sub(1, 2) == "ea" then
            game_difficulty = 1
            break
        elseif input:sub(1, 1) == "n" then
            game_difficulty = 2
            break
        elseif input:sub(1, 1) == "h" then
            game_difficulty = 3
            break
        elseif input == "evil" then
            print("Confirm EVIL mode?")
            print("Notice: We are not responsible for\nany loss of sanity, hair, familial\nreputation, academic performance, or employment security.")
            puts("(y/n): ")

            local c = string.lower(get_line())
            if c:sub(1,1) == "y" then
                game_difficulty = 4
            else
                print("No? Good.")
                return
            end

            break
        elseif input == "x" then
            return
        end

        print("Invalid input.")
    end

    GameProgression.reset_progression(game_difficulty)
end

if not Debug.enabled then
    puts("Starting kinematics processor.")
    for i=1, math.random(4, 8) do
        coroutine.yield(0.2)
        puts(".")
    end
    puts("\n")

    puts("Starting volumetric pressure sensor.")
    for i=1, math.random(4, 8) do
        coroutine.yield(0.2)
        puts(".")
    end
    puts("\n")

    puts("Starting photon receptor matrix.")
    for i=1, math.random(4, 8) do
        coroutine.yield(0.2)
        puts(".")
    end
    puts("\n")

    coroutine.yield()
    puts("Start-up completed successfully!")
    coroutine.yield()
end

require("sceneman").switchScene("game")