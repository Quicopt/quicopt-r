# Check a solution on scenarios it was not optimized for

The objective and the chance levels a solve reports are measured on the
scenarios the solve saw, the ones that shaped the solution. On fresh
scenarios a solution does worse, and a chance constraint that was just
satisfied is missed about half the time. `resample()` draws fresh
scenarios from a new seed, holds the solution fixed, and evaluates the
model's objective and constraints on them: the out-of-sample check.

## Usage

``` r
resample(m, solution, seed, scenarios = NULL, ...)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- solution:

  A result from [`solve()`](https://rdrr.io/r/base/solve.html), or a
  named numeric vector giving every decision variable's value.

- seed:

  The seed for the fresh scenarios, different from the model's.

- scenarios:

  How many to draw; left `NULL`, as many as the model has. More
  scenarios give a sharper out-of-sample estimate.

- ...:

  Connection settings, passed on to
  [`solve_model()`](https://quicopt.github.io/quicopt-r/reference/solve_model.md).

## Value

A `quicopt_result` for the pinned solution on the fresh scenarios:
`objective` is the out-of-sample objective, `feasible` says whether
every constraint still holds, and `solver_data$max_violation` is the
largest amount by which one is missed (for a chance constraint, in units
of probability).

## Details

Only the random variables with a distribution are redrawn. An
[`empirical()`](https://quicopt.github.io/quicopt-r/reference/empirical.md)
column is data and stays as it is, so a model whose uncertainty is
entirely empirical has nothing to resample, and the scenario count
cannot change while any such column is present. Each call is one request
to the service.

## Examples

``` r
if (FALSE) { # \dontrun{
res <- solve(m)                    # in sample: objective, feasible = TRUE
chk <- resample(m, res, seed = 7)  # out of sample, same solution
chk$objective
chk$feasible                       # does the chance constraint still hold?
chk$solver_data$max_violation      # if not, by how much
} # }
```
