# The average over the scenarios

`expectation(x)` is the average of `x` over the model's scenarios: an
estimate of its expected value. It turns a random expression into a
single number, which can be used in the objective or in a constraint.

## Usage

``` r
expectation(x)
```

## Arguments

- x:

  A random expression (see
  [`is_random()`](https://quicopt.github.io/quicopt-r/reference/is_random.md)).

## Value

An expression of the same length as `x`, no longer random.

## Details

Minimizing an average makes the typical scenario good, and says little
about the bad ones;
[`cvar()`](https://quicopt.github.io/quicopt-r/reference/cvar.md) looks
at those instead. For a vector `x`, each element is averaged separately.

## Examples

``` r
m <- model()
stock  <- num_var(m, "stock", lower = 0, upper = 200)
demand <- rand_var(m, "demand", normal(100, 15))
set_scenarios(m, 512, seed = 42)
shortfall <- max(demand - stock, 0)        # units short, in each scenario
minimize(m, 3 * stock + 10 * expectation(shortfall))
```
