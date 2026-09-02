# Create an empty optimization model

A model owns decision variables, an objective, constraint rows, and —
for a model under uncertainty — random variables and a scenario count.
Declare variables with
[`num_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md),
[`int_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md),
[`bin_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)
and
[`rand_var()`](https://quicopt.github.io/quicopt-r/reference/rand_var.md),
state the goal with
[`minimize()`](https://quicopt.github.io/quicopt-r/reference/minimize.md)
or
[`maximize()`](https://quicopt.github.io/quicopt-r/reference/minimize.md),
add constraints with
[`add()`](https://quicopt.github.io/quicopt-r/reference/add.md), and
hand the model to [`solve()`](https://rdrr.io/r/base/solve.html).

## Usage

``` r
model()
```

## Value

A model, an environment of class `quicopt_model`.

## Details

Every setter both mutates the model and returns it invisibly, so the
imperative style and the pipe are the same functions:

    m <- model()
    x <- num_var(m, "x", 0, 4)          # handle style

    m <- model() |>                     # pipe style; m$x retrieves the handle
      add_var("x", 0, 4)

Note the pipe mutates its input — the model is one shared object, not a
value being copied along the chain.
