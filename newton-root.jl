# kth root via Newton's method (generalization of heron-root.jl)
#
# For the kth root of n:
#   x_{i+1} = ((k-1)·x + n / x^(k-1)) / k
#
# k=2 reduces to Heron: (x + n/x) / 2. Quadratic convergence: correct digits
# roughly double each step, regardless of k

function newton_root(n, k::Int = 2; digits::Union{Int,Nothing} = 100,
                                     stream::Bool = false,
                                     max_iters::Union{Int,Nothing} = nothing,
                                     on_iter::Union{Function,Nothing} = nothing)

    # n: value to take kth root of
    # k: root degree (default 2 = square root)
    # digits: target decimal length (also caps precision in non-stream mode)
    # stream true: keep doubling precision past the target
    # max_iters: hard cap on iterations, empty = unbounded
    # on_iter: optional callback (i, x_current, elapsed_seconds)

    k >= 1 || error("k must be ≥ 1")

    prec_digits = digits === nothing ? 32 : digits
    setprecision(ceil(Int, prec_digits * log2(10)) + 32)

    n_big = BigFloat(n)
    x = BigFloat(Float64(n)^(1/k))  # good Float64-precision seed
    x_prev = BigFloat(0)
    i = 0
    t0 = time()
    k_bf = BigFloat(k)
    km1 = BigFloat(k - 1)

    while true
        on_iter !== nothing && on_iter(i, x, time() - t0)

        i += 1

        # break on fixed point (perfect kth powers converge exactly)
        if i > 1 && x == x_prev
            break
        end
        if max_iters !== nothing && i > max_iters
            break
        end

        x_prev = x
        x = (km1 * x + n_big / x^(k-1)) / k_bf

        if stream
            prec_digits *= 2
            setprecision(ceil(Int, prec_digits * log2(10)) + 32)
        end
    end

    return x
end

# Backward-compat alias
sqrt_newton(n; kwargs...) = newton_root(n, 2; kwargs...)

include("runtime/stream.jl")

# usage e.g.
#  newton_root(3, 2, digits = 200)                                                     # √3
#  newton_root(8, 3, digits = 200)                                                     # ∛8
#  render(label = "√7") do on_iter, _ ; newton_root(7, 2, digits = 500, on_iter = on_iter) ; end
#  stream(label = "∛5") do on_iter ; newton_root(5, 3, stream = true, on_iter = on_iter) ; end

function root_label(n::Real, k::Int)
    n_str = isinteger(n) ? string(Int(n)) : string(n)
    k == 2 && return "√$n_str"
    k == 3 && return "∛$n_str"
    k == 4 && return "∜$n_str"
    return "$n_str^(1/$k)"
end

if abspath(PROGRAM_FILE) == @__FILE__
    print("n = ")
    n = parse(Float64, readline())
    print("k = (default 2) ")
    kline = strip(readline())
    k = isempty(kline) ? 2 : parse(Int, kline)

    stream(label = root_label(n, k)) do on_iter
        newton_root(n, k, stream = true, on_iter = on_iter)
    end
end
