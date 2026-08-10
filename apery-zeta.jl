# Apery's ζ(3) accelerated series
#
# ζ(3) = 2½ ⋅ ∞∑ₙ₌₁ -1ⁿ⁻¹ / n³⋅(²ⁿₙ)
#
# Linear convergence: ~log₁₀(4) ≈ 0.6 digits per term
# (the central binomial gives 4ⁿ decay, the n³ is a lower-order improvement)

const DIGITS_PER_ITER = log10(4)  # ≈ 0.602

function zeta3_apery(; digits::Union{Int,Nothing} = 100,
                       stream::Bool = false,
                       max_iters::Union{Int,Nothing} = nothing,
                       on_iter::Union{Function,Nothing} = nothing)

    # digits: target decimal length
    # stream true: keep refining past target
    # max_iters: hard cap on iterations, empty = unbounded
    # on_iter: optional callback (n, ζ_current, elapsed_seconds)

    target_iters = digits === nothing ? nothing : ceil(Int, digits / DIGITS_PER_ITER) + 5

    initial_digits = digits === nothing ? 100 : digits
    setprecision(ceil(Int, initial_digits * log2(10)) + 32)

    S = BigFloat(0)
    ζ_current = BigFloat(0)
    n = 0
    t0 = time()

    while true
        on_iter !== nothing && on_iter(n, ζ_current, time() - t0)

        n += 1

        if target_iters !== nothing && n > target_iters && !stream
            break
        end
        if max_iters !== nothing && n > max_iters
            break
        end

        sign = iseven(n - 1) ? 1 : -1
        term = BigFloat(sign) / (BigFloat(n)^3 * binomial(big(2n), big(n)))
        S += term
        ζ_current = BigFloat(5) / 2 * S

        # grow precision as streamed digits pile up
        if stream && n * DIGITS_PER_ITER > initial_digits - 16
            initial_digits = ceil(Int, n * DIGITS_PER_ITER) + 32
            setprecision(ceil(Int, initial_digits * log2(10)) + 32)
        end
    end

    return ζ_current
end

include("runtime/stream.jl")

# usage e.g.
#  zeta3_apery(digits = 200)
#  render(label = "ζ(3)") do on_iter, _ ; zeta3_apery(digits = 500, on_iter = on_iter) ; end
#  stream(label = "ζ(3)") do on_iter ; zeta3_apery(stream = true, on_iter = on_iter) ; end

if abspath(PROGRAM_FILE) == @__FILE__
    stream(label = "ζ(3)") do on_iter
        zeta3_apery(stream = true, on_iter = on_iter)
    end
end
