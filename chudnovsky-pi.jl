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

function π_chud(n::Int, digits::Int = 100)
    setprecision(ceil(Int, digits * log2(10)) + 16) do
        C = BigFloat(426880) * sqrt(BigFloat(10005))
        S = BigFloat(0)

        for k in 0:n
            # Mₖ = (6k)! / ((3k)! (k!)³)
            M = factorial(big(6k)) ÷ (factorial(big(3k)) * factorial(big(k))^3)

            # Lₖ = 13591409 + 545140134k
            L = big(13591409) + big(545140134) * k

            # Xₖ = (-640320)^(3k)
            X = big(-640320)^(3k)

            # Sₙ = ∑ₖ₌₀ⁿ MₖLₖ/Xₖ
            S += BigFloat(M * L) / BigFloat(X)
        end

        # πₙ = C / Sₙ
        return C / S
    end
end

println(π_chud(5, 100))
