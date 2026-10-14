# Changelog

## quicopt 0.7.0

- Counts are named for what they count. The number of items of a
  permutation or a partition is `n_items`
  (`perm_var(m, "tour", n_items)`,
  `part_var(m, "teams", n_items, n_parts)`), the number of parts
  `n_parts`, and the number of scenarios `n_scenarios`
  (`set_scenarios(m, n_scenarios, seed)`, and `n_scenarios =` in
  [`evaluate()`](https://quicopt.github.io/quicopt-r/reference/evaluate.md)
  and
  [`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md)).
  The handles read the counts back as `$n_items` and `$n_parts`. Calls
  that pass the counts by position work as before;
  `perm_var(m, "tour", n = 5)`, `part_var(m, "teams", 6, parts = 2)` and
  `$n` or `$parts` on a handle need the new names.
- The length of a vector variable is `length`, as in
  `numeric(length = 3)`: `bin_var(m, "take", length = 6)` declares six
  yes-or-no decisions. The same holds for
  [`num_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md),
  [`int_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md),
  [`add_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md),
  [`rand_var()`](https://quicopt.github.io/quicopt-r/reference/rand_var.md)
  and
  [`add_rand_var()`](https://quicopt.github.io/quicopt-r/reference/rand_var.md).
- The former names, `n =` for the length and `scenarios =` in
  [`evaluate()`](https://quicopt.github.io/quicopt-r/reference/evaluate.md)
  and
  [`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md),
  still work, with a warning, and will stop working in a later release.
  Giving a former name together with its new one is an error.

## quicopt 0.6.1

- [`max()`](https://quicopt.github.io/quicopt-r/reference/summaries.md),
  [`min()`](https://quicopt.github.io/quicopt-r/reference/summaries.md),
  [`sum()`](https://quicopt.github.io/quicopt-r/reference/summaries.md)
  and
  [`prod()`](https://quicopt.github.io/quicopt-r/reference/summaries.md)
  accept a plain number before an expression. `max(0, demand - stock)`
  used to stop with “invalid ‘type’ (list) of argument”, because base R
  chooses the method of these functions by their first argument only;
  only `max(demand - stock, 0)` worked. quicopt now provides its own
  versions of the four functions, which pass any call without an
  expression to base R unchanged. R notes them as masked from `base`
  when the package is attached.

## quicopt 0.6.0

- [`num_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)
  and
  [`int_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)
  take `semi = TRUE` for a variable that is either 0 or between its
  bounds, never in between: a delivery of nothing or of 10 to 25 units.
  Its bounds must be finite. `active(x)` is 1 when such a variable is
  not 0, so a fee per delivery is `fee * active(delivery)`, and a model
  that is otherwise linear is still solved to a proven optimum.
- `block(m, name, vars)` names the variables of one subproblem, such as
  one customer’s deliveries. Every solution the service returns
  satisfies the constraints over one block’s variables alone. A variable
  is in at most one block and needs finite bounds.
- `part_var(m, "teams", n, parts)` declares a partition: each of `n`
  items in one of `parts` parts. `part_of(item, P)` is an item’s part
  and `size_of(part, P)` the number of items in a part, both vectorized
  over their first argument. A solution reports both under
  `res$structures$<name>`, and
  [`set_start()`](https://quicopt.github.io/quicopt-r/reference/set_start.md),
  [`evaluate()`](https://quicopt.github.io/quicopt-r/reference/evaluate.md)
  and
  [`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md)
  carry the division along.
- A model with
  [`max()`](https://quicopt.github.io/quicopt-r/reference/summaries.md),
  [`min()`](https://quicopt.github.io/quicopt-r/reference/summaries.md),
  [`holds()`](https://quicopt.github.io/quicopt-r/reference/holds.md) or
  a switch is solved by a search; such a model whose variables are all
  integer or binary needs finite bounds on each, as before, but one with
  a continuous variable is now accepted.
- [`partition_decl()`](https://quicopt.github.io/quicopt-r/reference/partition_decl.md),
  the constants `SEMICONTINUOUS` and `SEMIINTEGER`, and
  `program(blocks = )` are the data-layer forms. The service must be
  recent enough to know these constructs; an older one refuses the model
  when it is sent.

## quicopt 0.5.0

- [`solve()`](https://rdrr.io/r/base/solve.html) and
  [`submit()`](https://quicopt.github.io/quicopt-r/reference/submit.md)
  take `time_limit`, the number of seconds the solve may run, in place
  of the time the service would choose. A solver that proves its answer
  sooner still stops sooner; a search runs for all of it. The service
  grants at most its maximum, and a warning says so when it granted
  less; `res$solver_data$time_budget_s` is the time it granted.
  [`solve()`](https://rdrr.io/r/base/solve.html) waits for the answer at
  least `time_limit` plus a minute, and
  [`job_result()`](https://quicopt.github.io/quicopt-r/reference/job_status.md)
  polls that long by default. The service must be recent enough to know
  the setting; an older one refuses the request.

## quicopt 0.4.0

- `perm_var(m, "tour", n)` declares a permutation: `n` items in `n`
  slots, one each. `item_at(slot, P)` is the item in a slot and
  `slot_of(item, P)` the slot of an item, integer expressions vectorized
  over their first argument; `precede(P, a, b)` requires item `a` in an
  earlier slot than item `b`. A solution reports both views under
  `res$structures$<name>`, and
  [`set_start()`](https://quicopt.github.io/quicopt-r/reference/set_start.md),
  [`evaluate()`](https://quicopt.github.io/quicopt-r/reference/evaluate.md)
  and
  [`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md)
  carry the order along with the plain variables.
- `lookup_table(m, "dist", values)` declares a numeric vector or matrix
  whose entries are read at positions the solver decides:
  `dist[item_at(1:4, tour), item_at(2:5, tour)]` is the legs of a round,
  `cost[choice]` a cost chosen through an integer variable. A lookup is
  an ordinary expression, and is random exactly when one of its
  positions is.
- A model with a permutation or a lookup is solved by search, as a model
  under uncertainty is, and the two combine. The service must be recent
  enough to know these constructs; an older one refuses the model when
  it is sent.
- [`permutation_decl()`](https://quicopt.github.io/quicopt-r/reference/permutation_decl.md),
  [`ir_struct_ref()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  and
  [`ir_table_ref()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  are the data-layer forms, and
  [`program()`](https://quicopt.github.io/quicopt-r/reference/program.md)
  takes `structures`.

## quicopt 0.3.0

- `uniform(min, max)`, `exponential(rate)` and `bernoulli(prob)` join
  [`normal()`](https://quicopt.github.io/quicopt-r/reference/distribution.md)
  as named distributions, parameterized like
  [`runif()`](https://rdrr.io/r/stats/Uniform.html),
  [`rexp()`](https://rdrr.io/r/stats/Exponential.html) and
  `rbinom(n, 1, prob)`. As with
  [`normal()`](https://quicopt.github.io/quicopt-r/reference/distribution.md),
  a parameter may be an expression, so a rate or a failure probability
  can depend on a decision. A numeric parameter outside its range is
  refused where the distribution is built.
- `variance(x)` and `std_dev(x)` measure how much a quantity varies over
  the scenarios. By default the scenarios are the whole distribution, so
  `variance(x)` is `expectation(x^2) - expectation(x)^2`;
  `sample = TRUE` divides by `n - 1` as
  [`var()`](https://rdrr.io/r/stats/cor.html) and
  [`sd()`](https://rdrr.io/r/stats/sd.html) do.
- `scenario_max(x)` and `scenario_min(x)` are the largest and the
  smallest value over the scenarios, and `scenario_quantile(x, prob)` is
  the value that the share `prob` of scenarios stays at or below
  (`quantile(type = 1)` of the scenario values). Minimizing
  `scenario_max(cost)` optimizes the worst scenario of the sample.

## quicopt 0.2.0

The release for checking a solution, not only finding one.

- `resample(m, res, seed)` evaluates a solution on scenarios it was not
  optimized for, and reports the out-of-sample objective and whether
  every constraint still holds. `evaluate(m, res, expr)` gives the value
  of any non-random expression at a solution, on the model’s scenarios
  or, with `seed`, on fresh ones.
- `add(m, prob(...) >= level, margin = k)` tightens a chance
  constraint’s level by `k` standard errors of the scenario estimate, so
  the level is cleared out of sample rather than merely in sample.
- `holds(a <= b)` is a comparison as a 0/1 expression, in each scenario;
  all six comparisons are allowed there, with an optional tolerance.
- `add(m, rel, when = b)` imposes a row only where the binary `b` is 1.
- `set_start(m, res)` warm-starts the next solve from a previous
  solution;
  [`bin_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)
  takes a `start` too.
- `rand_var(m, "weight", normal(c(6, 5, 4), 1))` declares a vector
  random variable, one independent draw per element.
- `is_random(x)` says whether an expression still varies across
  scenarios. An aggregator applied to a non-random expression, and a
  random objective or constraint, are now refused in R with the public
  names, before the service refuses them with wire names.
- [`mean()`](https://rdrr.io/r/base/mean.html) of a model expression is
  the mean over its elements, like
  [`sum()`](https://quicopt.github.io/quicopt-r/reference/summaries.md);
  [`c()`](https://rdrr.io/r/base/c.html) concatenates expressions.

Fixed:

- `-x` and
  [`prod()`](https://quicopt.github.io/quicopt-r/reference/summaries.md)
  over three or more elements encoded shapes the service rejected.
- `x <= 3` with a vector `x` added one row instead of one per element.
- The `solution` of a result is ordered as the variables were declared.
  It used to keep the order the answer arrived in, which is the
  service’s own, so `which(res$solution == 1)` did not count items the
  way the model did.

## quicopt 0.1.1

Documentation: every help topic with a usage section now states its
value.

## quicopt 0.1.0

First release.
