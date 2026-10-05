# Check a solution on new scenarios

A solution is chosen to do well on the model's scenarios, so the
objective and the probabilities reported for it are measured on the very
scenarios that shaped it. On new scenarios it usually does a little
worse, and a chance constraint that was only just met is missed about
half the time. `resample()` draws new scenarios from `seed`, keeps the
solution fixed, and computes the model's objective and constraints on
them.

## Usage

``` r
resample(m, solution, seed, scenarios = NULL, ...)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- solution:

  A result from [`solve()`](https://rdrr.io/r/base/solve.html), or a
  named numeric vector with a value for every decision variable (see
  [`evaluate()`](https://quicopt.github.io/quicopt-r/reference/evaluate.md)).

- seed:

  The seed for the new scenarios, different from the model's own.

- scenarios:

  How many new scenarios to draw. Left `NULL`, as many as the model has.
  More scenarios give a more precise check.

- ...:

  Settings for the request, as for
  [`solve_model()`](https://quicopt.github.io/quicopt-r/reference/solve_model.md).

## Value

A result in the same form as from
[`solve()`](https://rdrr.io/r/base/solve.html), for the fixed solution
on the new scenarios. `objective` is the objective on them, `feasible`
says whether every constraint still holds, and
`solver_data$max_violation` is by how much the worst constraint is
missed; for a chance constraint, as a probability.

## Details

Only random variables with a distribution are drawn again. A random
variable made from an
[`empirical()`](https://quicopt.github.io/quicopt-r/reference/empirical.md)
sample or by
[`set_empirical()`](https://quicopt.github.io/quicopt-r/reference/set_empirical.md)
is data and stays as it is. A model whose random variables are all of
that kind has nothing to draw again, which is an error, and while a
model has any of them, the number of scenarios cannot change. Each call
is one request to the service.

## Examples

``` r
if (FALSE) { # \dontrun{
res <- solve(m)                                        # m as in ?evaluate
chk <- resample(m, res, seed = 7, scenarios = 1000)
chk$feasible                                           # does every constraint still hold?
chk$solver_data$max_violation                          # if not, by how much
chk$objective                                          # the objective on the new scenarios
} # }
```
