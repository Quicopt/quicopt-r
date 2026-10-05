# The largest, the smallest and a quantile over the scenarios

The value a quantity takes in one particular scenario:

## Usage

``` r
scenario_max(x)

scenario_min(x)

scenario_quantile(x, prob)
```

## Arguments

- x:

  A random expression (see
  [`is_random()`](https://quicopt.github.io/quicopt-r/reference/is_random.md)).

- prob:

  A number above 0 and at most 1. It cannot depend on a decision.

## Value

An expression of the same length as `x`, no longer random.

## Details

- `scenario_max(x)` is the largest value of `x` among the scenarios.
  Minimizing it makes the worst scenario as good as possible.

- `scenario_min(x)` is the smallest. Maximizing it does the same for a
  quantity where large is good, such as a profit.

- `scenario_quantile(x, prob)` is the value that the share `prob` of the
  scenarios stays at or below. With `n` scenarios it is the
  `ceiling(prob * n)`-th smallest value, which is what
  `quantile(x, prob, type = 1)` returns for a sample.
  `scenario_quantile(x, 1)` is `scenario_max(x)`. For a cost it is also
  known as the *value at risk*;
  [`cvar()`](https://quicopt.github.io/quicopt-r/reference/cvar.md) at
  the same level is the average of the values above it.

These are different from
[`max()`](https://rdrr.io/r/base/Extremes.html),
[`min()`](https://rdrr.io/r/base/Extremes.html) and
[`quantile()`](https://rdrr.io/r/stats/quantile.html). `max(a, b)`
compares two expressions *within* each scenario, and the result is still
random. `scenario_max(x)` compares the values of one expression *across*
the scenarios, and the result is a single number.

A single scenario decides the largest or smallest value, so it changes
more from one sample of scenarios to the next than an average does, and
a larger sample usually contains a more extreme scenario. Check a
solution found with these on new scenarios, with
[`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md).

## Examples

``` r
m <- model()
stock  <- num_var(m, "stock", lower = 0, upper = 200)
demand <- rand_var(m, "demand", normal(100, 15))
set_scenarios(m, 512, seed = 42)
cost <- 3 * stock + 10 * max(demand - stock, 0)
minimize(m, scenario_max(cost))                  # the cost of the worst scenario
add(m, scenario_quantile(cost, 0.95) <= 500)     # at most 500 in 95% of scenarios
```
