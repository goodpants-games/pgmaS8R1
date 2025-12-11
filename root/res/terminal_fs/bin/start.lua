---@diagnostic disable undefined-global

if NO_START_COMMAND then
    print("Machine is already fully active.")
    return 
end

if not Debug.enabled then
    puts("Starting kinematics process.")
    for i=1, math.random(4, 8) do
        coroutine.yield(0.5)
        puts(".")
    end
    puts("\n")

    puts("Starting auditory process.")
    for i=1, math.random(4, 8) do
        coroutine.yield(0.5)
        puts(".")
    end
    puts("\n")

    puts("Starting optical process.")
    for i=1, math.random(4, 8) do
        coroutine.yield(0.5)
        puts(".")
    end
    puts("\n")

    coroutine.yield()
    puts("Start-up completed successfully!")
    coroutine.yield()
end

require("sceneman").switchScene("game")