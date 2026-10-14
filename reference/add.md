# Add constraints to a model

A comparison of expressions, written with `<=`, `>=` or `==`, becomes a
requirement that every solution must meet:
`add(m, tables + chairs <= 18)`. Here the comparison is not a test that
returns `TRUE` or `FALSE`. A comparison of two vectors adds one
constraint per element: with `x` and `cap` of length 3,
`add(m, x <= cap)` adds 3 constraints.

## Usage

``` r
add(m, rel, margin = 0, when = NULL)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- rel:

  A comparison of expressions, written with `<=`, `>=` or `==`.

- margin:

  For a chance constraint: by how many standard errors to tighten the
  target. The default, 0, leaves it as written.

- when:

  A binary variable that switches the constraint on.

## Value

The model, invisibly.

## Details

`<` and `>` are not accepted, because for a quantity that can take any
value they mean the same as `<=` and `>=`. `!=` is not accepted either;
[`holds()`](https://quicopt.github.io/quicopt-r/reference/holds.md)
turns it into a 0/1 expression, which can be used instead.

In a model with random variables, each side of a constraint has to be
one number, not one per scenario: summarize it first, for example with
[`expectation()`](https://quicopt.github.io/quicopt-r/reference/expectation.md)
or [`prob()`](https://quicopt.github.io/quicopt-r/reference/prob.md). A
requirement on a probability, such as
`add(m, prob(demand <= stock) >= 0.9)`, is called a *chance constraint*.

## A safety margin on a chance constraint

The probability in a chance constraint is estimated from the scenarios,
so it carries sampling error. For a target `p` and `n_scenarios`
scenarios, its standard error is `sqrt(p * (1 - p) / n_scenarios)`,
about 0.013 for `p = 0.9` and `n_scenarios = 512`. A solution chosen to
just meet the target on its own scenarios therefore misses the target on
new scenarios about half the time (see
[`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md)).

`margin = k` raises the target by `k` standard errors, so that the true
probability meets the original target with a confidence of about
`pnorm(k)`: 84% for `k = 1`, 98% for `k = 2`. For an upper limit, such
as `prob(...) <= 0.1`, the target is lowered instead. A margin applies
only when one side of the constraint is a
[`prob()`](https://quicopt.github.io/quicopt-r/reference/prob.md) and
the other a number strictly between 0 and 1. The standard error is
computed from the number of scenarios when the model is solved, so the
margin can be given before
[`set_scenarios()`](https://quicopt.github.io/quicopt-r/reference/set_scenarios.md)
is called.

## A constraint with an on-off switch

`when = b`, with `b` a binary variable from
[`bin_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md),
makes the constraint apply only in solutions in which `b` is 1. For
example, `add(m, output <= 0, when = closed)` forces the output to 0
only if the plant is closed. `b` is a single variable, or a vector
variable with one element per constraint.

A model with a switch is solved by a search, so its status is
`"heuristic"`. The same holds for
[`holds()`](https://quicopt.github.io/quicopt-r/reference/holds.md),
[`max()`](https://quicopt.github.io/quicopt-r/reference/summaries.md)
and
[`min()`](https://quicopt.github.io/quicopt-r/reference/summaries.md).
When every variable of such a model is an integer or a binary variable,
each needs finite bounds; a model with a continuous variable or with
random variables has no such limit.

## Examples

``` r
m <- model()
tables <- num_var(m, "tables", lower = 0)
chairs <- num_var(m, "chairs", lower = 0)
add(m, 3 * tables + chairs <= 41)                      # hours of carpentry
add(m, tables + chairs <= 18)                          # wood

# a chance constraint, without and with a safety margin
shop   <- model()
stock  <- num_var(shop, "stock", lower = 0, upper = 200)
demand <- rand_var(shop, "demand", normal(100, 15))
set_scenarios(shop, 512, seed = 42)
add(shop, prob(demand <= stock) >= 0.9)                # demand met on 90% of scenarios
add(shop, prob(demand <= stock) >= 0.9, margin = 2)    # the target raised to about 0.927
```
