# Optimization under uncertainty

Part of a model's data is often unknown when the decision has to be
made: demand, prices, yields, arrival times. Declare that data as random
variables carrying distributions, and the model is solved over a sample
of scenarios drawn from them.

## Details

Two rules describe the whole surface:

- A variable declared with
  [`rand_var()`](https://quicopt.github.io/quicopt-r/reference/rand_var.md)
  is a random variable, not a decision variable. Every use of it
  references the same sample.

- An expression containing a random variable is itself random, and
  cannot serve as an objective or a constraint until an aggregator
  reduces it over the scenarios:
  [`expectation()`](https://quicopt.github.io/quicopt-r/reference/expectation.md)
  for the mean,
  [`cvar()`](https://quicopt.github.io/quicopt-r/reference/cvar.md) for
  the tail,
  [`prob()`](https://quicopt.github.io/quicopt-r/reference/prob.md) for
  a chance constraint.

[`set_scenarios()`](https://quicopt.github.io/quicopt-r/reference/set_scenarios.md)
sets how many scenarios are drawn and from which seed. Both belong to
the model, so repeated solves see the same sample. The drawing happens
in the service, from the model's own seed — R's
[`set.seed()`](https://rdrr.io/r/base/Random.html) plays no role here.

## Examples

``` r
if (FALSE) { # \dontrun{
# Order x units at 3 apiece against a demand learned later, pay 10 per unit
# of shortfall, and meet demand in at least 90% of scenarios:
m <- model()
x <- num_var(m, "x", 0, 200)
demand <- rand_var(m, "demand", normal(100, 15))
set_scenarios(m, 512, seed = 42)
minimize(m, 3 * x + 10 * expectation(max(demand - x, 0)))
add(m, prob(demand - x <= 0) >= 0.9)
solve(m)$solution
} # }
```
