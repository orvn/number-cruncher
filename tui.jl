# Streaming TUI for π_chud
#
# tui_callback(...) returns a closure suitable to pass as `on_iter` to π_chud
# Rendering is throttled to every N iterations and fits the terminal width:
#
#   iter = 1770  t = 3.5s <leading 64> … {aggregate: N digits} … <trailing 256>

function humanize_digits(n::Integer)
    n < 1_000     && return string(n)
    n < 1_000_000 && return string(round(n / 1_000, digits = 1), "K")
                     return string(round(n / 1_000_000, digits = 2), "M")
end

# decimal digits held by a BigFloat at its current precision
digits_of(x::BigFloat) = floor(Int, precision(x) * log10(BigFloat(2)))

function format_π(π::BigFloat, cols::Int)
    s = string(π)
    total = digits_of(π)
    aggregate = string("{", humanize_digits(total), " digits}")

    # try leading … aggregate … trailing at descending widths
    for (leading_n, trailing_n) in [(32, 256), (32, 128), (24, 96), (16, 64), (12, 32), (8, 16)]
        wanted = (leading_n + 2) + 3 + length(aggregate) + 3 + trailing_n
        if wanted <= cols
            leading = first(s, leading_n + 2)   # "3." + leading_n digits
            trailing = last(s, trailing_n)
            return string(leading, " … ", aggregate, " … ", trailing)
        end
    end

    # too narrow, drop aggregate chunk
    room = max(cols - 3, 10)
    half = div(room, 2)
    return string(first(s, half), "…", last(s, room - half))
end

function tui_callback(; every::Int = 1, io::IO = stdout, show_banner::Bool = true)
    first_call = Ref(true)
    return function(k::Int, π_current::BigFloat, elapsed::Float64)
        if first_call[]
            show_banner && println(io, "streaming, use ctrl-c to interrupt")
            first_call[] = false
        end
        (k != 0 && k % every != 0) && return

        cols = displaysize(io)[2]
        prefix = string("iter = ", k, "  t = ", round(elapsed, digits = 1), "s  ")
        body = format_π(π_current, max(cols - length(prefix) - 1, 20))
        line = string(prefix, body)

        # pad to full width so leftovers from a longer previous line get erased
        line = rpad(line, cols - 1)
        print(io, "\r", line)
    end
end
