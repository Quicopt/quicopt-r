# The variance and the standard deviation over the scenarios

How much a quantity varies from scenario to scenario, as opposed to what
it is on average. `expectation(cost) + 2 * std_dev(cost)` is an
objective that trades a low average cost against a steady one, and
`add(m, variance(cost) <= 100)` limits the variation.

## Usage

``` r
variance(x, sample = FALSE)

std_dev(x, sample = FALSE)
```

## Arguments

- x:

  A random expression (see
  [`is_random()`](https://quicopt.github.io/quicopt-r/reference/is_random.md)).

- sample:

  `FALSE`, the default, divides by the number of scenarios; `TRUE`
  divides by one less, as [`var()`](https://rdrr.io/r/stats/cor.html)
  and [`sd()`](https://rdrr.io/r/stats/sd.html) do.

## Value

An expression of the same length as `x`, no longer random.

## Details

By default the scenarios count as the whole distribution, each with
weight `1 / n`, so `variance(x)` is
`expectation(x^2) - expectation(x)^2`. R's
[`var()`](https://rdrr.io/r/stats/cor.html) and
[`sd()`](https://rdrr.io/r/stats/sd.html) divide by `n - 1` instead,
because they estimate the variance of a population from a sample of it;
`sample = TRUE` does the same. The two differ by a factor `n / (n - 1)`,
which changes the value reported but not which decision is best.

Unlike
[`cvar()`](https://quicopt.github.io/quicopt-r/reference/cvar.md), these
measure variation in both directions: a scenario far better than average
increases them as much as one far worse.

## Examples

``` r
m <- model()
stock  <- num_var(m, "stock", lower = 0, upper = 200)
demand <- rand_var(m, "demand", normal(100, 15))
set_scenarios(m, 512, seed = 42)
cost <- 3 * stock + 10 * max(demand - stock, 0)
minimize(m, expectation(cost) + 2 * std_dev(cost))
```
