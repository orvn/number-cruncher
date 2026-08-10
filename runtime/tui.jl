# Streaming TUI
#
# Two APIs:
#   tui_start(...)      returns (on_iter, stop!) — snapshot + background renderer
#   render(...) do      block form: sets up + tears down automatically
#
# Compute callback (on_iter) is cheap, it updates a shared snapshot, a background task (Threads.@spawn if nthreads > 1, else @async) renders at fixed cadence (interval_s) 
# Rendering: two lines, redrawn in place:
#  iter = 1770  t = 3.5s
#  π = <leading 32> … {aggregate: N digits} … <trailing 256>

include("loop.jl")

const ANSI_RESET   = "\e[0m"
const ANSI_DIM     = "\e[2m"
const ANSI_CYAN    = "\e[36m"  # aggregate (softer)
const ANSI_BCYAN   = "\e[96m"  # leading + trailing (bright)
const ANSI_GRAY    = "\e[90m"
const ANSI_UP_HOME = "\r\e[1A" # cursor to start of previous line

wrap(s, code) = string(code, s, ANSI_RESET)

function humanize_digits(n::Integer)
    n < 1_000             && return string(n)
    n < 1_000_000         && return string(round(n / 1_000, digits = 1), "K")
    n < 1_000_000_000     && return string(round(n / 1_000_000, digits = 2), "M")
    n < 1_000_000_000_000 && return string(round(n / 1_000_000_000, digits = 2), "B")
                             return string(round(n / 1_000_000_000_000, digits = 2), "T")
end

# decimal digits held by a BigFloat at its current precision
digits_of(x::BigFloat) = floor(Int, precision(x) * log10(2))

# below digit floor, skip leading/aggregate/trailing structure
const AGGREGATE_FLOOR = 200

function format_value(v::BigFloat, cols::Int)
    s = string(v)
    total = digits_of(v)

    if total < AGGREGATE_FLOOR
        display = length(s) <= cols ? s : first(s, cols)
        return display, wrap(display, ANSI_BCYAN)
    end
    aggregate = string("{", humanize_digits(total), " digits}")

    for (leading_n, trailing_n) in [(32, 256), (32, 128), (24, 96), (16, 64), (12, 32), (8, 16)]
        wanted = (leading_n + 2) + 3 + length(aggregate) + 3 + trailing_n
        if wanted <= cols
            leading = first(s, leading_n + 2)
            trailing = last(s, trailing_n)
            plain = string(leading, " … ", aggregate, " … ", trailing)
            colored = string(wrap(leading, ANSI_BCYAN), " ",
                             wrap("…", ANSI_GRAY), " ",
                             wrap(aggregate, ANSI_CYAN), " ",
                             wrap("…", ANSI_GRAY), " ",
                             wrap(trailing, ANSI_BCYAN))
            return plain, colored
        end
    end

    room = max(cols - 3, 10)
    half = div(room, 2)
    plain = string(first(s, half), "…", last(s, room - half))
    colored = string(wrap(first(s, half), ANSI_BCYAN),
                     wrap("…", ANSI_GRAY),
                     wrap(last(s, room - half), ANSI_BCYAN))
    return plain, colored
end

# One frame draw
function _render_frame(io::IO, k::Int, v::BigFloat, elapsed::Float64,
                       first_render::Ref{Bool}, color::Bool,
                       label::AbstractString, show_banner::Bool)
    if first_render[] && show_banner
        println(io, "streaming, use ctrl-c to interrupt")
        println(io)
    end

    cols = displaysize(io)[2]
    elapsed_s = string(round(elapsed, digits = 1), "s")

    line1_plain = string("iter = ", k, "  t = ", elapsed_s)
    line1 = color ?
        string(wrap("iter = ", ANSI_DIM), k, "  ",
               wrap("t = ", ANSI_DIM), elapsed_s) :
        line1_plain

    prefix_plain = string(label, " = ")
    prefix = color ? wrap(prefix_plain, ANSI_DIM) : prefix_plain
    plain_body, colored_body = format_value(v, max(cols - length(prefix_plain) - 1, 20))
    body = color ? colored_body : plain_body

    pad1 = max(0, cols - 1 - length(line1_plain))
    pad2 = max(0, cols - 1 - length(prefix_plain) - length(plain_body))

    first_render[] || print(io, ANSI_UP_HOME)
    print(io, line1, " " ^ pad1, "\n", prefix, body, " " ^ pad2)
    first_render[] = false
end

# Snapshot + background renderer
# Returns (on_iter, stop!)
#   on_iter(k, v, elapsed)  cheap: updates the shared snapshot under a lock
#   stop!()                 halts renderer, draws final frame, emits trailing
#                           newline (idempotent)
#
# Threads.@spawn parallel path when nthreads > 1, else @async cooperative
# (compute's yield() inside on_iter gives the renderer a chance to run)
function tui_start(; io::IO = stdout, show_banner::Bool = true,
                     color::Bool = true, label::AbstractString = "π",
                     interval_s::Float64 = 1/30)

    snap_lock = ReentrantLock()
    snapshot = Ref{Union{Nothing, Tuple{Int, BigFloat, Float64}}}(nothing)
    first_render = Ref(true)
    last_rendered_k = Ref(-1)
    stopped = Ref(false)

    do_render = function(force::Bool)
        snap = lock(snap_lock) do
            snapshot[]
        end
        snap === nothing && return
        k, v, elapsed = snap
        if !force && k == last_rendered_k[]
            return
        end
        last_rendered_k[] = k
        _render_frame(io, k, v, elapsed, first_render, color, label, show_banner)
    end

    stop_bg = background_loop(() -> do_render(false); interval_s = interval_s)

    on_iter = function(k::Int, v::BigFloat, elapsed::Float64)
        lock(snap_lock) do
            snapshot[] = (k, v, elapsed)
        end
        yield()  # let the renderer run if ready (see module docstring)
    end

    stop! = function()
        stopped[] && return
        stopped[] = true
        stop_bg()
        do_render(true)
        println(io)
    end

    return on_iter, stop!
end

# Block form: sets up tui_start, calls the body with (on_iter, stop!), guarantees teardown even on exception
function render(body; kwargs...)
    on_iter, stop! = tui_start(; kwargs...)
    try
        return body(on_iter, stop!)
    finally
        stop!()
    end
end
