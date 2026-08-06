# Number Cruncher

<img src="/assets/images/number-cruncher.png" alt="number cruncher logo" width="500">

A collection of calculations and proofs on series, especially those that converge.

## Usage

Assuming Julia is installed, simply call a file like:

```zsh
julia chudnovsky-pi.jl   # π via Chudnovsky
julia euler-e.jl         # e via Taylor series
```

### Use as a library

```julia
include("chudnovsky-pi.jl")

π_chud(digits = 200)
π_chud(digits = 500, on_iter = tui_callback(every = 1))
π_chud(stream = true, on_iter = tui_callback(every = 10))
π_chud(stream = true, max_iters = 500)
```

```julia
include("euler-e.jl")

e_taylor(digits = 200)                                                   
e_taylor(digits = 500, on_iter = tui_callback(every = 1, label = "e"))   
e_taylor(stream = true, on_iter = tui_callback(every = 5, label = "e"))
```

Both share the same kwarg shape:

- `digits::Int` — target decimal digits (default `100`)
- `stream::Bool` — keep refining past target (default `false`)
- `max_iters::Union{Int,Nothing}` — hard cap (default `nothing`)
- `on_iter::Function` — optional callback `(k, value, elapsed_seconds)`

### Files

- `runtime/tui.jl` width-aware terminal interface design file. `tui_callback` takes an optional `label` kwarg (default `"π"`) so the second output line renders `<label> = ...`
- `runtime/interrupt.jl` — interruption handler

Example invocation for other calculations
```julia
val_ref = Ref{BigFloat}(BigFloat(0))
tui = tui_callback(every = 5, label = "x")
with_graceful_interrupt(on_interrupt = prompt_show(() -> val_ref[], label = "x")) do
    my_calc(on_iter = (k, v, t) -> (val_ref[] = v; tui(k, v, t)))
end
```
