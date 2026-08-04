# Number Cruncher

<img src="/assets/images/number-cruncher.png" alt="number cruncher logo" width="500">

A collection of calculations and proofs on series, especially those that converge.

## Usage

Assuming Julia is installed, simply call a file like:

```zsh
julia chudnovsky-pi.jl
```

### Use as a library

```julia
include("chudnovsky-pi.jl")

π_chud(digits = 200)                                       # silent, returns BigFloat
π_chud(digits = 500, on_iter = tui_callback(every = 1))    # target accuracy w/ TUI
π_chud(stream = true, on_iter = tui_callback(every = 10))  # stream forever w/ TUI
π_chud(stream = true, max_iters = 500)                     # ~7000 digits then stop
```

`π_chud` kwargs:

- `digits::Int` — target decimal digits (default `100`)
- `stream::Bool` — keep refining past target (default `false`)
- `max_iters::Union{Int,Nothing}` — hard cap (default `nothing`)
- `on_iter::Function` — optional callback `(k, π_current, elapsed_seconds)`

### Files

- `tui.jl` width-aware terminal interface design file
- `interrupt.jl` — interruption handler

Example invocation for other calculations
```julia
val_ref = Ref{BigFloat}(BigFloat(0))
with_graceful_interrupt(on_interrupt = prompt_show(() -> val_ref[], label = "result")) do
    my_calc(on_iter = (k, v, t) -> (val_ref[] = v; tui_callback(every = 5)(k, v, t)))
end
```
