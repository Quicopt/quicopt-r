# The value of an expression at a solution

A solve returns the values of the variables and of the objective. For
any other quantity of the model, the shortfall the solution leaves, a
probability it reaches, a cost it incurs, `evaluate()` computes the
value at that solution on the model's own scenarios.

## Usage

``` r
evaluate(m, solution, expr, seed = NULL, scenarios = NULL, ...)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- solution:

  A result from [`solve()`](https://rdrr.io/r/base/solve.html), or a
  named numeric vector giving every decision variable's value (`"x"`, or
  `"x[1]"`, `"x[2]"`, ... for a vector variable). A model with a
  permutation
  ([`perm_var()`](https://quicopt.github.io/quicopt-r/reference/perm_var.md))
  takes a result, which carries the order found.

- expr:

  A single non-random model expression.

- seed:

  Left `NULL`, the model's own scenarios; given, a seed for fresh ones.

- scenarios:

  With `seed`: how many fresh scenarios to draw (default: as many as the
  model has).

- ...:

  Connection settings, passed on to
  [`solve_model()`](https://quicopt.github.io/quicopt-r/reference/solve_model.md):
  `base_url`, `api_key`, `project`, `config`, `gzip`, `timeout`,
  `transport`.

## Value

The expression's value, a number.

## Details

The expression cannot be random: close it over the scenarios first, as
for an objective. With a `seed`, the value is computed on fresh
scenarios instead of the model's own, which is how a probability or an
expected cost is checked out of sample (see
[`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md)
for the rules on fresh scenarios). Each call is one request to the
service.

## Examples

``` r
if (FALSE) { # \dontrun{
res <- solve(m)
evaluate(m, res, prob(demand - x <= 0))              # the service level reached
evaluate(m, res, prob(demand - x <= 0), seed = 2)    # and on fresh scenarios
evaluate(m, res, expectation(max(demand - x, 0)))    # the expected shortfall
} # }
```
