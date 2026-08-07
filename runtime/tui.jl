# Streaming TUI for π_chud
#
# tui_callback(...) returns a closure suitable to pass as `on_iter` to π_chud
# Rendering is throttled to every N iterations and fits the terminal width.
# Two-line output, redrawn in place:
#
#   iter = 1770  t = 3.5s
#   π = <leading 32> … {aggregate: N digits} … <trailing 256>

const ANSI_RESET   = "\e[0m"
const ANSI_DIM     = "\e[2m"
const ANSI_CYAN    = "\e[36m"     # aggregate (softer)
const ANSI_BCYAN   = "\e[96m"     # leading + trailing (bright)
const ANSI_GRAY    = "\e[90m"
const ANSI_UP_HOME = "\r\e[1A"    # cursor to start of previous line

wrap(s, code) = string(code, s, ANSI_RESET)

function humanize_digits(n::Integer)
    n < 1_000     && return string(n)
    n < 1_000_000 && return string(round(n / 1_000, digits = 1), "K")
                     return string(round(n / 1_000_000, digits = 2), "M")
end

# decimal digits held by a BigFloat at its current precision
digits_of(x::BigFloat) = floor(Int, precision(x) * log10(2))

# returns (plain, colored) — plain used for width math, colored for output
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

function tui_callback(; every::Int = 1, io::IO = stdout, show_banner::Bool = true, color::Bool = true, label::AbstractString = "π")
    first_render = Ref(true)
    return function(k::Int, π_current::BigFloat, elapsed::Float64)
        if first_render[] && show_banner
            println(io, "streaming, use ctrl-c to interrupt")
            println(io)
        end
        (k != 0 && k % every != 0) && return

        cols = displaysize(io)[2]
        elapsed_s = string(round(elapsed, digits = 1), "s")

        # line 1: iter + t
        line1_plain = string("iter = ", k, "  t = ", elapsed_s)
        line1 = color ?
            string(wrap("iter = ", ANSI_DIM), k, "  ",
                   wrap("t = ", ANSI_DIM), elapsed_s) :
            line1_plain

        # line 2: <label> = <leading> … {aggregate} … <trailing>
        prefix_plain = string(label, " = ")
        prefix = color ? wrap(prefix_plain, ANSI_DIM) : prefix_plain
        plain_body, colored_body = format_π(π_current, max(cols - length(prefix_plain) - 1, 20))
        body = color ? colored_body : plain_body

        pad1 = max(0, cols - 1 - length(line1_plain))
        pad2 = max(0, cols - 1 - length(prefix_plain) - length(plain_body))

        # move cursor back to line 1 on subsequent renders
        first_render[] || print(io, ANSI_UP_HOME)
        print(io, line1, " " ^ pad1, "\n", prefix, body, " " ^ pad2)
        first_render[] = false
    end
end
