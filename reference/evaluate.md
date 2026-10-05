# Compute a quantity at a given solution

A solve reports the values of the decision variables and of the
objective. `evaluate()` computes any other quantity of the model at a
given solution: the share of scenarios in which demand is met, the
average shortfall, the cost of a plan written out by hand. It sends the
model to the service with every decision variable fixed at the
solution's value, so each call is one request.

## Usage

``` r
evaluate(m, solution, expr, seed = NULL, scenarios = NULL, ...)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- solution:

  A result from [`solve()`](https://rdrr.io/r/base/solve.html), or a
  named numeric vector with a value for every decision variable, named
  as in a solution: `"x"`, or `"x[1]"`, `"x[2]"`, ... for a vector
  variable. A model with a permutation needs a result, because only a
  result holds the arrangement.

- expr:

  The quantity to compute: one expression that is not random.

- seed:

  Left `NULL`, the model's own scenarios are used. Otherwise, the seed
  for new scenarios, different from the model's own.

- scenarios:

  With `seed`: how many new scenarios to draw. Left `NULL`, as many as
  the model has. More scenarios give a more precise value.

- ...:

  Settings for the request, as for
  [`solve_model()`](https://quicopt.github.io/quicopt-r/reference/solve_model.md):
  `base_url`, `api_key`, `project`, `config`, `gzip`, `timeout` and
  `transport`.

## Value

The value of `expr`, a number.

## Details

The quantity must be a single number, so a random expression is
summarized first, for example with
[`prob()`](https://quicopt.github.io/quicopt-r/reference/prob.md) or
[`expectation()`](https://quicopt.github.io/quicopt-r/reference/expectation.md),
as for an objective.

Without a `seed`, the value is computed on the model's own scenarios.
With a `seed`, it is computed on new scenarios drawn from that seed,
which shows how the solution does on scenarios it was not chosen for.
[`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md)
explains which random variables are drawn again.

## Examples

``` r
if (FALSE) { # \dontrun{
m <- model()
stock  <- num_var(m, "stock", lower = 0, upper = 200)
demand <- rand_var(m, "demand", normal(100, 15))
set_scenarios(m, 512, seed = 42)
minimize(m, 3 * stock + 10 * expectation(max(demand - stock, 0)))
add(m, prob(demand <= stock) >= 0.9)
res <- solve(m)

met <- prob(demand <= stock)
evaluate(m, res, met)                                  # on the model's scenarios
evaluate(m, res, met, seed = 7, scenarios = 1000)      # on 1000 new ones
evaluate(m, c(stock = 110), met)                       # for a stock of 110
} # }
```
