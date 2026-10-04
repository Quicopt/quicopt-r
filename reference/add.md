# Add constraints to a model

A comparison of model expressions is a constraint, not a logical:
`add(m, x + y <= 5)` requires the row to hold, and `==` states an
equality. A comparison of vector expressions adds one row per element,
so `add(m, x <= cap)` with two length-`n` vectors is `n` rows. `<`, `>`
and `!=` are refused: for a continuous quantity the first two mean `<=`
and `>=`, and the third is no constraint at all (see
[`holds()`](https://quicopt.github.io/quicopt-r/reference/holds.md) for
the 0/1 expression it does make).

## Usage

``` r
add(m, rel, margin = 0, when = NULL)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- rel:

  A comparison built with `<=`, `>=` or `==`.

- margin:

  For a chance constraint: how many standard errors to tighten the level
  by (default none).

- when:

  A binary variable (from
  [`bin_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md))
  that switches the row on.

## Value

The model, invisibly.

## Details

A constraint cannot be random. In a model under uncertainty, close the
expression with an aggregator first
([`expectation()`](https://quicopt.github.io/quicopt-r/reference/expectation.md),
[`cvar()`](https://quicopt.github.io/quicopt-r/reference/cvar.md),
[`prob()`](https://quicopt.github.io/quicopt-r/reference/prob.md) and
the others the
[stochastic](https://quicopt.github.io/quicopt-r/reference/stochastic.md)
topic lists); a chance constraint is
`add(m, prob(demand - x <= 0) >= 0.9)`.

## A safety margin on a chance constraint

The probability in `prob(...) >= 0.9` is estimated from the scenarios,
and an estimate has a standard error: `sqrt(0.9 * 0.1 / n)` for `n`
scenarios, about 0.013 at 512. A solution found with the constraint just
satisfied in sample therefore misses the level on fresh scenarios about
half the time (see
[`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md)).
`margin = k` asks for the level tightened by `k` standard errors
instead, `0.9 + k * sqrt(0.9 * 0.1 / n)` here, so that the true
probability clears the level with confidence `pnorm(k)`: about 84% at
`k = 1`, 98% at `k = 2`. For an upper bound, `prob(...) <= 0.1`, the
level is lowered instead. The margin applies to a comparison of a
[`prob()`](https://quicopt.github.io/quicopt-r/reference/prob.md) with a
number strictly between 0 and 1, and is resolved against the scenario
count when the model is sent, so it may be given before
[`set_scenarios()`](https://quicopt.github.io/quicopt-r/reference/set_scenarios.md).

## A constraint that applies only when a switch is on

`when = b`, with `b` a binary variable, imposes the row only where `b`
is 1: `add(m, x <= 0, when = is_closed)`. `b` is one variable, or a
vector variable with one element per row. In a model with no random
variable a switched row makes the problem combinatorial, and the service
then expects integer variables with finite bounds, as for
[`holds()`](https://quicopt.github.io/quicopt-r/reference/holds.md).

## Examples

``` r
m <- model()
x <- num_var(m, "x", 0, 200)
demand <- rand_var(m, "demand", normal(100, 15))
set_scenarios(m, 512, seed = 42)
add(m, prob(demand - x <= 0) >= 0.9)              # the level as stated
add(m, prob(demand - x <= 0) >= 0.9, margin = 2)  # the level plus 2 SE: 0.927
```
