# Set how many scenarios are drawn, and from which seed

More scenarios estimate the true problem more closely and cost more to
solve. Both settings belong to the model, not to the solve, so the same
model always faces the same sample and two solves of it are comparable.
Left unset, a model is solved over one scenario — unless an
[`empirical()`](https://quicopt.github.io/quicopt-r/reference/empirical.md)
column sets the count by its own length.

## Usage

``` r
set_scenarios(m, n, seed = NULL)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- n:

  How many scenarios to draw.

- seed:

  The draw seed; left `NULL`, the current one is kept.

## Value

The model, invisibly.

## Details

The scenarios are drawn by the service from this seed; R's
[`set.seed()`](https://rdrr.io/r/base/Random.html) plays no role. `n`
and `seed` are both at least 1.
