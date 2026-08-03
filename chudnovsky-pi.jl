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

# π_chud(; digits, stream, max_iters, refresh)
#
# digits    target accuracy in decimal digits (nothing → run until max_iters or forever)
# stream    true → keep refining past target, refreshing the printed value
# max_iters hard cap on iterations (nothing → unbounded)
# refresh   print progress in place (\r) after each iteration
function π_chud(; digits::Union{Int,Nothing} = 100,
                  stream::Bool = false,
                  max_iters::Union{Int,Nothing} = nothing,
                  refresh::Bool = true)

    # target iterations for requested accuracy (+1 safety)
    target_iters = digits === nothing ? nothing : ceil(Int, digits / DIGITS_PER_ITER) + 1

    # precision: size to whatever we're aiming for; grow later if streaming
    initial_digits = digits === nothing ? 100 : digits
    setprecision(ceil(Int, initial_digits * log2(10)) + 32)

    if refresh && stream && max_iters === nothing
        println("streaming indefinitely — ctrl-c to interrupt")
    end

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

        if refresh
            elapsed = time() - t0
            print("\riter=", lpad(k, 6),
                  "  t=", lpad(string(round(elapsed, digits=2)), 8), "s",
                  "  π ≈ ", π_current)
        end

        k += 1

        # stopping conditions
        if target_iters !== nothing && k > target_iters && !stream
            break
        end
        if max_iters !== nothing && k > max_iters
            break
        end

        # advance term ratios:
        # M_{k+1} = M_k · (6k+1)(6k+2)(6k+3)(6k+4)(6k+5)(6k+6) / ((3k+1)(3k+2)(3k+3)(k+1)³)
        num = big(6k-5) * big(6k-4) * big(6k-3) * big(6k-2) * big(6k-1) * big(6k)
        den = big(3k-2) * big(3k-1) * big(3k) * big(k)^3
        M = M * num // den
        L += big(545140134)
        X *= big(-640320)^3

        # if streaming, keep bumping precision so we don't stall at initial cap
        if stream && k * DIGITS_PER_ITER > initial_digits - 16
            initial_digits = ceil(Int, k * DIGITS_PER_ITER) + 32
            setprecision(ceil(Int, initial_digits * log2(10)) + 32)
        end
    end

    refresh && println()
    return π_current
end

# usage
#   π_chud(digits = 200)                    # stop at ~200 digits
#   π_chud(stream = true)                   # refresh forever, ctrl-c exits
#   π_chud(stream = true, max_iters = 500)  # ~7000 digits streamed then stop

π_chud(stream = true)
