# The largest, the smallest and a quantile over the scenarios

The value a quantity takes in one particular scenario: the one where it
is largest, the one where it is smallest, or the one that a given share
of the scenarios does not exceed.

## Usage

``` r
scenario_max(x)

scenario_min(x)

scenario_quantile(x, prob)
```

## Arguments

- x:

  A random model expression (see
  [`is_random()`](https://quicopt.github.io/quicopt-r/reference/is_random.md)).

- prob:

  The level, a plain number above 0 and at most 1; it cannot depend on a
  decision.

## Value

An expression of the same length, no longer random.

## Details

- `scenario_max(x)` is the largest value of `x` over the scenarios.
  Minimizing it is the robust reading of a cost: do as well as possible
  in the worst scenario of the sample.

- `scenario_min(x)` is the smallest. Maximizing it is the same for a
  profit.

- `scenario_quantile(x, prob)` is the smallest scenario value that at
  least the share `prob` of the scenarios is at or below; with `n`
  scenarios, the `ceiling(prob * n)`-th smallest, which is what
  `quantile(x, prob, type = 1)` returns for a sample. For a cost this is
  the value at risk at level `prob`;
  [`cvar()`](https://quicopt.github.io/quicopt-r/reference/cvar.md) at
  the same level is the mean of what lies beyond it.
  `scenario_quantile(x, 1)` is `scenario_max(x)`.

These are not [`max()`](https://rdrr.io/r/base/Extremes.html),
[`min()`](https://rdrr.io/r/base/Extremes.html) and
[`quantile()`](https://rdrr.io/r/stats/quantile.html). `max(a, b)` is
the larger of two expressions *within* each scenario and stays random;
`scenario_max(x)` compares one expression *across* the scenarios and is
a number.

An extreme is set by a single scenario, so it moves more from one sample
to the next than a mean or a tail mean does, and a larger sample will
usually hold a more extreme scenario. Check a solution built on one with
[`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md).

## Examples

``` r
m <- model()
x <- num_var(m, "x", 0, 200)
demand <- rand_var(m, "demand", normal(100, 15))
set_scenarios(m, 512, seed = 42)
cost <- 3 * x + 10 * max(demand - x, 0)
minimize(m, scenario_max(cost))                   # the worst scenario
add(m, scenario_quantile(cost, 0.95) <= 500)      # 95% of scenarios cost at most 500
```
