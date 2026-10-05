# Set how many scenarios are drawn, and from which seed

The service draws `n` scenarios: `n` possible outcomes of the model's
random variables. More scenarios describe the uncertainty more
accurately, and take longer to solve. A model whose scenarios are never
set is solved over a single scenario, unless an
[`empirical()`](https://quicopt.github.io/quicopt-r/reference/empirical.md)
sample sets the number by its length.

## Usage

``` r
set_scenarios(m, n, seed = NULL)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- n:

  How many scenarios to draw, at least 1.

- seed:

  The seed for the draws, at least 1. Left `NULL`, the model keeps its
  current seed.

## Value

The model, invisibly.

## Details

The number of scenarios and the seed belong to the model, so solving the
same model again uses the same scenarios, and two solves of it can be
compared. The scenarios are drawn by the service, so R's
[`set.seed()`](https://rdrr.io/r/base/Random.html) has no effect on
them.

The service limits the number of scenarios. A model above the limit is
refused when it is solved, with a message that states the limit.

## Examples

``` r
m <- model()
demand <- rand_var(m, "demand", normal(100, 15))
set_scenarios(m, 512, seed = 42)
```
