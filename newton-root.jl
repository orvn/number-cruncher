# √n via Newton's method (generalization of heron-root.jl)
#
# x_{k+1} = (x_k + n / x_k) / 2
#
# Quadratic convergence: correct digits roughly double each step

function sqrt_newton(n; digits::Int = 100)
    setprecision(ceil(Int, digits * log2(10)) + 32)

    n = BigFloat(n)
    x = BigFloat(sqrt(Float64(n)))  # good Float64-precision seed
    x_prev = BigFloat(0)
    k = 0

    while x != x_prev
        x_prev = x
        x = (x + n / x) / 2
        k += 1
        println("iter $k: $x")
    end

    println("converged in $k iterations")
    return x
end

if abspath(PROGRAM_FILE) == @__FILE__
    print("n = ")
    n = parse(Float64, readline())
    sqrt_newton(n)
end
