# Optimization under uncertainty

Some decisions have to be made before all the data is known: how much
stock to order before demand is known, which jobs to accept before
knowing how long they will take. quicopt models such a decision by
describing each uncertain quantity as a *random variable*. The service
draws many possible outcomes of the random variables, called
*scenarios*, and finds the decision that does best across them.

## Building blocks

- [`rand_var()`](https://quicopt.github.io/quicopt-r/reference/rand_var.md)
  declares a random variable with a distribution such as
  [`normal()`](https://quicopt.github.io/quicopt-r/reference/distribution.md);
  [`set_empirical()`](https://quicopt.github.io/quicopt-r/reference/set_empirical.md)
  declares random variables from the columns of a data frame instead,
  one row per scenario.

- [`set_scenarios()`](https://quicopt.github.io/quicopt-r/reference/set_scenarios.md)
  sets how many scenarios the service draws, and the seed it draws them
  from.

- Any expression that contains a random variable has one value per
  scenario; it is called *random* (see
  [`is_random()`](https://quicopt.github.io/quicopt-r/reference/is_random.md)).
  The objective and the constraints must each be one number, so a random
  expression is summarized across the scenarios before it is used there.

## Summaries across the scenarios

- [`expectation()`](https://quicopt.github.io/quicopt-r/reference/expectation.md):
  the average.

- [`prob()`](https://quicopt.github.io/quicopt-r/reference/prob.md): the
  share of scenarios in which a comparison holds, for a requirement such
  as "demand is met on 90% of days".

- [`cvar()`](https://quicopt.github.io/quicopt-r/reference/cvar.md): the
  average over the worst scenarios.

- [`scenario_max()`](https://quicopt.github.io/quicopt-r/reference/scenario_max.md),
  [`scenario_min()`](https://quicopt.github.io/quicopt-r/reference/scenario_max.md),
  [`scenario_quantile()`](https://quicopt.github.io/quicopt-r/reference/scenario_max.md):
  the largest value, the smallest, and a quantile.

- [`variance()`](https://quicopt.github.io/quicopt-r/reference/variance.md)
  and
  [`std_dev()`](https://quicopt.github.io/quicopt-r/reference/variance.md):
  how much the value varies.

[`holds()`](https://quicopt.github.io/quicopt-r/reference/holds.md)
turns a comparison into a 0/1 value in each scenario, which can be
combined with other quantities before it is summarized.

## Checking a solution

A solution is chosen to do well on the model's scenarios, so it tends to
do a little worse on others, and the objective the service reports is
optimistic.
[`evaluate()`](https://quicopt.github.io/quicopt-r/reference/evaluate.md)
and
[`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md)
compute the figures on new scenarios, and the `margin` argument of
[`add()`](https://quicopt.github.io/quicopt-r/reference/add.md) raises
the target of a requirement on a probability to allow for this.

[`vignette("stochastic", package = "quicopt")`](https://quicopt.github.io/quicopt-r/articles/stochastic.md)
introduces all of this with a worked example.

## Examples

``` r
if (FALSE) { # \dontrun{
# Order stock at 3 per unit before demand is known, pay 10 for each unit
# of demand that cannot be met, and meet demand in at least 90% of scenarios.
m <- model()
stock  <- num_var(m, "stock", lower = 0, upper = 200)
demand <- rand_var(m, "demand", normal(100, 15))
set_scenarios(m, 512, seed = 42)
minimize(m, 3 * stock + 10 * expectation(max(demand - stock, 0)))
add(m, prob(demand <= stock) >= 0.9)
res <- solve(m)
res$solution

# Does the requirement still hold on 1000 new scenarios?
resample(m, res, seed = 7, scenarios = 1000)$feasible
} # }
```
