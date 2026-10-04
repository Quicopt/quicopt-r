# The variance and the standard deviation over the scenarios

How much a quantity varies from scenario to scenario, as opposed to what
it averages to. `expectation(cost) + k * std_dev(cost)` is the mean-risk
objective that penalizes spread, and `add(m, variance(ret) <= v)` caps
it.

## Usage

``` r
variance(x, sample = FALSE)

std_dev(x, sample = FALSE)
```

## Arguments

- x:

  A random model expression (see
  [`is_random()`](https://quicopt.github.io/quicopt-r/reference/is_random.md)).

- sample:

  `FALSE` (the default) divides by the number of scenarios; `TRUE`
  divides by one less, as [`var()`](https://rdrr.io/r/stats/cor.html)
  and [`sd()`](https://rdrr.io/r/stats/sd.html) do.

## Value

An expression of the same length, no longer random.

## Details

By default the scenarios are taken as the whole distribution, each with
weight `1/n`, so `variance(x)` is `expectation(x^2) - expectation(x)^2`.
That is not what [`var()`](https://rdrr.io/r/stats/cor.html) and
[`sd()`](https://rdrr.io/r/stats/sd.html) compute: they divide by
`n - 1`, to estimate the variance of a population from a sample of it.
`sample = TRUE` gives that estimate. The two differ by the factor
`n / (n - 1)`, which matters to a reported number and not to which
decision minimizes it.

Unlike
[`cvar()`](https://quicopt.github.io/quicopt-r/reference/cvar.md), these
measure deviation in both directions: a scenario that turns out far
better than average raises them as much as one that turns out far worse.

## Examples

``` r
m <- model()
x <- num_var(m, "x", 0, 200)
demand <- rand_var(m, "demand", normal(100, 15))
set_scenarios(m, 512, seed = 42)
cost <- 3 * x + 10 * max(demand - x, 0)
minimize(m, expectation(cost) + 2 * std_dev(cost))
```
