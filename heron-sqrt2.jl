# √2 via Heron/Newton/Babylonian method
#
# x_{k+1} = (x_k + 2 / x_k) / 2
#
# Quadratic convergence: number of correct digits roughly doubles each step

function sqrt2_newton(digits::Int = 100)
    setprecision(ceil(Int, digits * log2(10)) + 32)

    x = BigFloat(1.5)
    x_prev = BigFloat(0)
    k = 0

    while x != x_prev
        x_prev = x
        x = (x + BigFloat(2) / x) / 2
        k += 1
        println("iter $k: $x")
    end

    println("converged in $k iterations")
    return x
end

if abspath(PROGRAM_FILE) == @__FILE__
    sqrt2_newton(100)
end
