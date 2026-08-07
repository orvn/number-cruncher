# √n via Newton's method (generalization of heron-root.jl)
#
# x_{k+1} = (x_k + n / x_k) / 2
#
# Quadratic convergence: correct digits roughly double each step

function sqrt_newton(n; digits::Union{Int,Nothing} = 100,
                       stream::Bool = false,
                       max_iters::Union{Int,Nothing} = nothing,
                       on_iter::Union{Function,Nothing} = nothing)

    # n: value to take √ of (any Real, converted to BigFloat internally)
    # digits: target decimal length (also caps precision in non-stream mode)
    # stream true: keep doubling precision past the target
    # max_iters: hard cap on iterations, empty = unbounded
    # on_iter: optional callback (k, x_current, elapsed_seconds)

    prec_digits = digits === nothing ? 32 : digits
    setprecision(ceil(Int, prec_digits * log2(10)) + 32)

    n_big = BigFloat(n)
    x = BigFloat(sqrt(Float64(n)))  # good Float64-precision seed
    x_prev = BigFloat(0)
    k = 0
    t0 = time()

    while true
        on_iter !== nothing && on_iter(k, x, time() - t0)
        k += 1

        if !stream && k > 1 && x == x_prev
            break
        end
        if max_iters !== nothing && k > max_iters
            break
        end

        x_prev = x
        x = (x + n_big / x) / 2

        if stream
            prec_digits *= 2
            setprecision(ceil(Int, prec_digits * log2(10)) + 32)
        end
    end

    on_iter !== nothing && println()
    return x
end

include("runtime/tui.jl")
include("runtime/interrupt.jl")

# usage e.g.
#  sqrt_newton(3, digits = 200)
#  sqrt_newton(7, digits = 500, on_iter = tui_callback(every = 1, label = "√7"))
#  sqrt_newton(π, stream = true, on_iter = tui_callback(every = 1, label = "√π"))

if abspath(PROGRAM_FILE) == @__FILE__
    print("n = ")
    n = parse(Float64, readline())
    label_str = isinteger(n) ? "√$(Int(n))" : "√$n"

    x_ref = Ref{BigFloat}(BigFloat(0))
    k_ref = Ref(0)
    t_ref = Ref(0.0)
    tui = tui_callback(every = 1, label = label_str)
    on_iter = (k, v, t) -> (x_ref[] = v; k_ref[] = k; t_ref[] = t; tui(k, v, t))

    summary = () -> string("iter = ", k_ref[],
                           "  t = ", round(t_ref[], digits = 2), "s",
                           "  digits = ", digits_of(x_ref[]))

    with_graceful_interrupt(on_interrupt = prompt_show(() -> x_ref[], label = label_str, summary = summary)) do
        sqrt_newton(n, stream = true, on_iter = on_iter)
    end
end
