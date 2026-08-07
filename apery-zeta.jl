# Apery's ζ(3) accelerated series
#
# ζ(3) = 2½ ⋅ ∞∑ₙ₌₁ (-1)ⁿ⁻¹ / n³⋅(²ⁿₙ)
#
# Linear convergence, roughly 1.5–3 correct digits per term
# (the central binomial in the denominator kills terms exponentially)

function zeta3_apery(digits::Int = 100)
    setprecision(ceil(Int, digits * log2(10)) + 32)

    S = BigFloat(0)
    ζ = BigFloat(0)
    ζ_prev = BigFloat(-1)
    n = 0

    while ζ != ζ_prev
        n += 1
        sign = iseven(n - 1) ? 1 : -1
        term = BigFloat(sign) / (BigFloat(n)^3 * binomial(big(2n), big(n)))
        S += term
        ζ_prev = ζ
        ζ = BigFloat(5) / 2 * S
        println("iter $n: $ζ")
    end

    println("converged in $n iterations")
    return ζ
end

if abspath(PROGRAM_FILE) == @__FILE__
    zeta3_apery(50)
end
