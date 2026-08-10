# High-level harness for the CLI entry points
#
# stream(; label) do on_iter
#     my_calc(stream = true, on_iter = on_iter)
# end
#
# Owns the value/iter/elapsed refs, wires the TUI, wraps compute in a
# graceful-interrupt handler, prints summary lines
# Assumes the calc's callback signature is (k::Int, v::BigFloat, t::Float64)

include("tui.jl")
include("interrupt.jl")

function stream(calc_fn; label::AbstractString = "value",
                         io::IO = stdout,
                         interval_s::Float64 = 1/30,
                         show_banner::Bool = true,
                         color::Bool = true)
    value_ref = Ref{BigFloat}(BigFloat(0))
    k_ref = Ref(0)
    t_ref = Ref(0.0)

    render(io = io, label = label, show_banner = show_banner,
           color = color, interval_s = interval_s) do tui_on_iter, stop_tui!

        on_iter = (k, v, t) -> begin
            value_ref[] = v
            k_ref[] = k
            t_ref[] = t
            tui_on_iter(k, v, t)
        end

        summary = () -> string("iter = ", k_ref[],
                               "  t = ", round(t_ref[], digits = 2), "s",
                               "  digits = ", digits_of(value_ref[]))

        handler = () -> begin
            stop_tui!()
            prompt_show(() -> value_ref[], label = label, summary = summary)()
        end

        with_graceful_interrupt(on_interrupt = handler) do
            calc_fn(on_iter)
        end
    end
end
