# Euler's e via Taylor series
#
# e = ∑ₖ₌₀ 1/k! = 1 + 1 + 1/2 + 1/6 + 1/24 + ...
#
# Truncation error after k terms is bounded by 1/(k+1)!, so digits obtained
# ≈ log10((k+1)!)

# log10 of k! via Stirling, accurate enough for target/precision bookkeeping
log10_factorial(k) = k < 2 ? 0.0 :
    (k + 0.5) * log10(k) - k / log(10) + 0.5 * log10(2π)

# smallest k such that log10((k+1)!) ≥ digits
function iters_for_digits(digits::Int)
    k = 1
    while log10_factorial(k + 1) < digits
        k += 1
    end
    k
end


function e_taylor(; digits::Union{Int,Nothing} = 100,
                    stream::Bool = false,
                    max_iters::Union{Int,Nothing} = nothing,
                    on_iter::Union{Function,Nothing} = nothing)

    # digits: target decimal length
    # stream true: keep refining past target
    # max_iters: hard cap on iterations, empty = unbounded
    # on_iter: optional callback (k, e_current, elapsed_seconds)

    target_iters = digits === nothing ? nothing : iters_for_digits(digits) + 1

    initial_digits = digits === nothing ? 100 : digits
    setprecision(ceil(Int, initial_digits * log2(10)) + 32)

    S = BigFloat(1) # k=0 term contributes 1
    term = BigFloat(1) # 1/0!
    e_current = S
    k = 0
    t0 = time()

    while true
        on_iter !== nothing && on_iter(k, e_current, time() - t0)

        k += 1

        if target_iters !== nothing && k > target_iters && !stream
            break
        end
        if max_iters !== nothing && k > max_iters
            break
        end

        term = term / k  # now 1/k!
        S += term
        e_current = S

        # grow precision as streamed digits pile up
        if stream && log10_factorial(k + 1) > initial_digits - 16
            initial_digits = ceil(Int, log10_factorial(k + 1)) + 32
            setprecision(ceil(Int, initial_digits * log2(10)) + 32)
        end
    end

    on_iter !== nothing && println()
    return e_current
end

include("runtime/tui.jl")
include("runtime/interrupt.jl")

# usage e.g.
#  e_taylor(digits = 200)
#  e_taylor(digits = 500, on_iter = tui_callback(every = 1, label = "e"))
#  e_taylor(stream = true, on_iter = tui_callback(every = 5, label = "e"))

if abspath(PROGRAM_FILE) == @__FILE__
    e_ref = Ref{BigFloat}(BigFloat(0))
    k_ref = Ref(0)
    t_ref = Ref(0.0)
    tui = tui_callback(every = 5, label = "e")
    on_iter = (k, v, t) -> (e_ref[] = v; k_ref[] = k; t_ref[] = t; tui(k, v, t))

    summary = () -> string("iter = ", k_ref[],
                           "  t = ", round(t_ref[], digits = 2), "s",
                           "  digits = ", digits_of(e_ref[]))

    with_graceful_interrupt(on_interrupt = prompt_show(() -> e_ref[], label = "e", summary = summary)) do
        e_taylor(stream = true, on_iter = on_iter)
    end
end
