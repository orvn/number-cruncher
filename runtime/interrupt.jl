# Graceful interrupt handling
#
# with_graceful_interrupt(; on_interrupt) do
#     ...long-running work...
# end
#
# Catches InterruptException (ctrl-c) so Julias default stacktrace + signal
# dump is suppressed, then invokes the caller-supplied handler

function with_graceful_interrupt(action; on_interrupt = nothing)
    # in script mode Julia defaults to exit_on_sigint(true), which dumps a stacktrace and kills the process before we can catch 
    # flip it so ctrl-c raises InterruptException that we can handle
    prev = ccall(:jl_exit_on_sigint, Cint, (Cint,), 0)
    try
        return action()
    catch e
        e isa InterruptException || rethrow()
        on_interrupt === nothing || on_interrupt()
        return nothing
    finally
        ccall(:jl_exit_on_sigint, Cint, (Cint,), prev)
    end
end

# Prompt helper: returns a closure suitable for on_interrupt
#
# On ctrl-c asks whether to print the current value (default yes), then exits
#
# /get_value is a zero-arg thunk so the caller can pass any live reference
# 
# /summary is an optional zero-arg thunk returning a one-line stats string printed after the value dump
function prompt_show(get_value; label = "value", summary = nothing, io::IO = stdout)
    return function()
        println(io); println(io)
        print(io, "interrupted, print full $label? [Y/n] ")
        flush(io)
        line = try
            readline()
        catch
            ""
        end
        if !startswith(lowercase(strip(line)), "n")
            println(io)
            println(io, get_value())
        end
        if summary !== nothing
            println(io)
            println(io, summary())
        end
    end
end
