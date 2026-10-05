# Start the next search from a known solution

The service's search starts from each variable's start value, which is 0
unless set otherwise. When a model is solved again after a small change,
such as a tightened constraint or more scenarios, starting from the
previous answer usually gets to a good solution sooner than starting
from scratch. `set_start()` sets the start values from a result, or from
a named vector of values. Variables it is not given keep their start
value.

## Usage

``` r
set_start(m, values)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- values:

  A result from [`solve()`](https://rdrr.io/r/base/solve.html), or a
  named numeric vector, with names as in a solution: `"x"` for a single
  variable, `"x[1]"`, `"x[2]"`, ... for the elements of a vector
  variable.

## Value

The model, invisibly.

## Details

The service rounds the start of a whole-number variable, and moves a
start that lies outside the variable's bounds to the nearest bound. A
result also holds the order found for each permutation (see
[`perm_var()`](https://quicopt.github.io/quicopt-r/reference/perm_var.md)),
and that order becomes the permutation's start.

## Examples

``` r
if (FALSE) { # \dontrun{
m <- model()
stock  <- num_var(m, "stock", lower = 0, upper = 200)
demand <- rand_var(m, "demand", normal(100, 15))
set_scenarios(m, 512, seed = 42)
minimize(m, 3 * stock + 10 * expectation(max(demand - stock, 0)))
res <- solve(m)

set_scenarios(m, 1000, seed = 42)    # the same model, more scenarios
set_start(m, res)                    # start where the last search ended
solve(m)
} # }
```
