# Streaming TUI
#
# Two APIs:
#   tui_callback(...)     synchronous, returns a closure suitable for `on_iter`
#                         (renders inline on the compute thread — legacy shape)
#   tui_start(...)        decoupled, returns (on_iter, stop!) — the callback
#                         only updates a snapshot; a background task renders
#                         at fixed cadence (Threads.@spawn if nthreads > 1)
#
# Rendering: two lines, redrawn in place
#   iter = 1770  t = 3.5s
#   π = <leading 32> … {aggregate: N digits} … <trailing 256>

include("render.jl")

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

# returns (plain, colored): plain used for width math, colored for output
const AGGREGATE_FLOOR = 200  # if below, skip leading/aggregate/trailing structure

function format_π(π::BigFloat, cols::Int)
    s = string(π)
    total = digits_of(π)

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
# Used by both tui_callback (synchronous) and tui_start (decoupled)
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
    plain_body, colored_body = format_π(v, max(cols - length(prefix_plain) - 1, 20))
    body = color ? colored_body : plain_body

    pad1 = max(0, cols - 1 - length(line1_plain))
    pad2 = max(0, cols - 1 - length(prefix_plain) - length(plain_body))

    first_render[] || print(io, ANSI_UP_HOME)
    print(io, line1, " " ^ pad1, "\n", prefix, body, " " ^ pad2)
    first_render[] = false
end

# Synchronous callback (renders on the compute thread)
# Preserves the pre-decoupling behavior for callers that haven't migrated
function tui_callback(; every::Int = 1, io::IO = stdout, show_banner::Bool = true,
                        color::Bool = true, label::AbstractString = "π")
    first_render = Ref(true)
    return function(k::Int, v::BigFloat, elapsed::Float64)
        (k != 0 && k % every != 0) && return
        _render_frame(io, k, v, elapsed, first_render, color, label, show_banner)
    end
end

# Decoupled two-piece API
#
# Returns (on_iter, stop!)
#   on_iter(k, v, elapsed)  cheap: just updates the shared snapshot under a lock
#   stop!()                 halts the background task, renders one final frame,
#                           emits the trailing newline (idempotent)
#
# The renderer runs on Threads.@spawn when nthreads > 1 for real parallelism,
# else @async as a cooperative fallback
#
# `every` here means minimum k-delta between rendered frames — prevents
# repainting the same snapshot when compute is slower than interval_s
function tui_start(; every::Int = 1, io::IO = stdout, show_banner::Bool = true,
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
        if !force && !first_render[] && k - last_rendered_k[] < every
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
        yield() # allow the renderer a chance to proceed
    end

    stop! = function()
        stopped[] && return
        stopped[] = true
        stop_bg()          # halt loop and wait for the in-flight render (if any)
        do_render(true)    # guarantee the last snapshot is on screen
        println(io)        # trailing newline so shell prompt lands cleanly
    end

    return on_iter, stop!
end
