# Number Cruncher

<img src="/assets/images/number-cruncher.png" alt="number cruncher logo" width="500">

A collection of calculations and proofs on series, especially those that converge.

## Usage

Assuming Julia is installed, call a file like:

```zsh
julia -t 2 chudnovsky-pi.jl   # π via Chudnovsky
julia -t 2 euler-e.jl         # e via Taylor series
julia -t 2 heron-root.jl      # √2 via Heron's method
julia -t 2 newton-root.jl     # kth root of n via Newton's method
julia -t 2 apery-zeta.jl      # ζ(3) via Apery's series
```

Simply running like `julia euler-e.jl` also works, but `-t 2` allows the streaming TUI renderer to be put on a background thread so compute isn't blocked by terminal i/o.

At minimum, it is recommended to run with two threads, however _auto_ mode may also be used `julia --threads=auto euler-e.jl`, which determines thread quantity based on the local machine.

### Use as a library

A few examples of usage as a drop-in library:
```julia
include("chudnovsky-pi.jl")

π_chud(digits = 200)

render(label = "π") do on_iter, _
    π_chud(digits = 500, on_iter = on_iter)  # target 500 digits
end

stream(label = "π") do on_iter
    π_chud(stream = true, on_iter = on_iter) # stream until interrupt
end
π_chud(stream = true, max_iters = 500)
```

```julia
include("newton-root.jl")

newton_root(3, 2, digits = 200)       # √3
newton_root(27, 3, digits = 200)      # ∛27

render(label = "√7") do on_iter, _
    newton_root(7, 2, digits = 500, on_iter = on_iter)
end

stream(label = "√π") do on_iter
    newton_root(π, 2, stream = true, on_iter = on_iter)
end
```

All of these share the same kwarg shape:

- `digits::Int`: target decimal digits (default `100`)
- `stream::Bool`: keep refining past target (default `false`)
- `max_iters::Union{Int,Nothing}`: ceiling (default `nothing`)
- `on_iter::Function`: optional callback `(k, value, elapsed_seconds)`

### Files

- `runtime/loop.jl`: `background_loop` primitive, a pseudo-event-based system
- `runtime/tui.jl`: width-aware two-line rendering; `tui_start` (raw) and `render` (block)
- `runtime/interrupt.jl`: `with_graceful_interrupt` and `prompt_show`
- `runtime/stream.jl`: `stream` block that composes TUI

Reusing the harness for a new calculation example:
```julia
include("runtime/stream.jl")

stream(label = "x") do on_iter
    my_calc(stream = true, on_iter = on_iter)
end
```

The `on_iter` callback must have signature of the form `(k::Int, v::BigFloat, t::Float64)`

### Tests

Test the first 50 digits of each constant, `√n·√n ≈ n`,
perfect-square exact convergence and the two most-used TUI helpers with `test-calcs.jl`

```zsh
julia test/test-calcs.jl
```
