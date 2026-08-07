# Background loop primitive
#
# background_loop(loop_fn; interval_s = 1/30)
#   Spawns a task that calls loop_fn() at a fixed cadence
#   Returns a stop! closure that halts the loop and waits for it to drain
#   Uses Threads.@spawn when nthreads > 1 for parallelism
#   Falls back to @async when nthreads == 1 for cooperative scheduling

function background_loop(loop_fn; interval_s::Float64 = 1/30)
    running = Threads.Atomic{Bool}(true)

    loop = () -> begin
        while running[]
            loop_fn()
            sleep(interval_s)
        end
    end

    task = Threads.nthreads() > 1 ? Threads.@spawn(loop()) : @async loop()

    return () -> begin
        running[] = false
        wait(task)
        nothing
    end
end
