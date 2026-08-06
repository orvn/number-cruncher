# Chudnovsky π approximation
#
# 1/π = 12 ∑ₖ₌₀ⁿ (-1)ᵏ (6k)! (13591409 + 545140134k)
#              / ((3k)! (k!)³ 640320^(3k + 3/2))
#
# π ≈ C / ∑ₖ MₖLₖ/Xₖ
#
# C = 426880√10005
# Mₖ = (6k)! / ((3k)! (k!)³)
# Lₖ = 13591409 + 545140134k
# Xₖ = (-640320)^(3k)
#
# Each iteration adds ~14.1816 digits of precision

const DIGITS_PER_ITER = log10(big"151931373056000")  # ≈ 14.1816

# π_chud(; digits, stream, max_iters, on_iter)
#
# digits    target accuracy in decimal digits (nothing → run until max_iters or forever)
# stream    true → keep refining past target
# max_iters hard cap on iterations (nothing → unbounded)
# on_iter   optional callback (k, π_current, elapsed_seconds) invoked each iteration
function π_chud(; digits::Union{Int,Nothing} = 100,
                  stream::Bool = false,
                  max_iters::Union{Int,Nothing} = nothing,
                  on_iter::Union{Function,Nothing} = nothing)

    target_iters = digits === nothing ? nothing : ceil(Int, digits / DIGITS_PER_ITER) + 1

    initial_digits = digits === nothing ? 100 : digits
    setprecision(ceil(Int, initial_digits * log2(10)) + 32)

    C = BigFloat(426880) * sqrt(BigFloat(10005))
    S = BigFloat(0)

    # incremental term state: M₀ = 1, L₀ = 13591409, X₀ = 1
    M = big(1) // big(1)
    L = big(13591409)
    X = big(1)
    k = 0
    π_current = BigFloat(NaN)
    t0 = time()

    while true
        S += BigFloat(M * L) / BigFloat(X)
        π_current = C / S

        on_iter !== nothing && on_iter(k, π_current, time() - t0)

        k += 1

        if target_iters !== nothing && k > target_iters && !stream
            break
        end
        if max_iters !== nothing && k > max_iters
            break
        end

        # M_{k+1} = M_k · (6k+1)(6k+2)(6k+3)(6k+4)(6k+5)(6k+6) / ((3k+1)(3k+2)(3k+3)(k+1)³)
        num = big(6k-5) * big(6k-4) * big(6k-3) * big(6k-2) * big(6k-1) * big(6k)
        den = big(3k-2) * big(3k-1) * big(3k) * big(k)^3
        M = M * num // den
        L += big(545140134)
        X *= big(-640320)^3

        # grow precision as streamed digits pile up
        if stream && k * DIGITS_PER_ITER > initial_digits - 16
            initial_digits = ceil(Int, k * DIGITS_PER_ITER) + 32
            setprecision(ceil(Int, initial_digits * log2(10)) + 32)
        end
    end

    on_iter !== nothing && println()
    return π_current
end

include("runtime/tui.jl")
include("runtime/interrupt.jl")

# usage
#   π_chud(digits = 200)                                          # silent, returns value
#   π_chud(digits = 500, on_iter = tui_callback(every = 1))       # target accuracy w/ TUI
#   π_chud(stream = true, on_iter = tui_callback(every = 5))      # stream forever w/ TUI
#   π_chud(stream = true, max_iters = 500,
#          on_iter = tui_callback(every = 10, show_banner = false))

if abspath(PROGRAM_FILE) == @__FILE__
    π_ref = Ref{BigFloat}(BigFloat(0))
    k_ref = Ref(0)
    t_ref = Ref(0.0)
    tui = tui_callback(every = 5)
    on_iter = (k, p, e) -> (π_ref[] = p; k_ref[] = k; t_ref[] = e; tui(k, p, e))

    summary = () -> string("iter = ", k_ref[],
                           "  t = ", round(t_ref[], digits = 2), "s",
                           "  digits = ", digits_of(π_ref[]))

    with_graceful_interrupt(on_interrupt = prompt_show(() -> π_ref[], label = "π", summary = summary)) do
        π_chud(stream = true, on_iter = on_iter)
    end
end
