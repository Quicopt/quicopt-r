# quicopt 0.6.0

* `num_var()` and `int_var()` take `semi = TRUE` for a variable that is either 0 or between its bounds, never in between: a delivery of nothing or of 10 to 25 units. Its bounds must be finite. `active(x)` is 1 when such a variable is not 0, so a fee per delivery is `fee * active(delivery)`, and a model that is otherwise linear is still solved to a proven optimum.
* `block(m, name, vars)` names the variables of one subproblem, such as one customer's deliveries. Every solution the service returns satisfies the constraints over one block's variables alone. A variable is in at most one block and needs finite bounds.
* `part_var(m, "teams", n, parts)` declares a partition: each of `n` items in one of `parts` parts. `part_of(item, P)` is an item's part and `size_of(part, P)` the number of items in a part, both vectorized over their first argument. A solution reports both under `res$structures$<name>`, and `set_start()`, `evaluate()` and `resample()` carry the division along.
* A model with `max()`, `min()`, `holds()` or a switch is solved by a search; such a model whose variables are all integer or binary needs finite bounds on each, as before, but one with a continuous variable is now accepted.
* `partition_decl()`, the constants `SEMICONTINUOUS` and `SEMIINTEGER`, and `program(blocks = )` are the data-layer forms. The service must be recent enough to know these constructs; an older one refuses the model when it is sent.

# quicopt 0.5.0

* `solve()` and `submit()` take `time_limit`, the number of seconds the solve may run, in place of the time the service would choose. A solver that proves its answer sooner still stops sooner; a search runs for all of it. The service grants at most its maximum, and a warning says so when it granted less; `res$solver_data$time_budget_s` is the time it granted. `solve()` waits for the answer at least `time_limit` plus a minute, and `job_result()` polls that long by default. The service must be recent enough to know the setting; an older one refuses the request.

# quicopt 0.4.0

* `perm_var(m, "tour", n)` declares a permutation: `n` items in `n` slots, one each. `item_at(slot, P)` is the item in a slot and `slot_of(item, P)` the slot of an item, integer expressions vectorized over their first argument; `precede(P, a, b)` requires item `a` in an earlier slot than item `b`. A solution reports both views under `res$structures$<name>`, and `set_start()`, `evaluate()` and `resample()` carry the order along with the plain variables.
* `lookup_table(m, "dist", values)` declares a numeric vector or matrix whose entries are read at positions the solver decides: `dist[item_at(1:4, tour), item_at(2:5, tour)]` is the legs of a round, `cost[choice]` a cost chosen through an integer variable. A lookup is an ordinary expression, and is random exactly when one of its positions is.
* A model with a permutation or a lookup is solved by search, as a model under uncertainty is, and the two combine. The service must be recent enough to know these constructs; an older one refuses the model when it is sent.
* `permutation_decl()`, `ir_struct_ref()` and `ir_table_ref()` are the data-layer forms, and `program()` takes `structures`.

# quicopt 0.3.0

* `uniform(min, max)`, `exponential(rate)` and `bernoulli(prob)` join `normal()` as named distributions, parameterized like `runif()`, `rexp()` and `rbinom(n, 1, prob)`. As with `normal()`, a parameter may be an expression, so a rate or a failure probability can depend on a decision. A numeric parameter outside its range is refused where the distribution is built.
* `variance(x)` and `std_dev(x)` measure how much a quantity varies over the scenarios. By default the scenarios are the whole distribution, so `variance(x)` is `expectation(x^2) - expectation(x)^2`; `sample = TRUE` divides by `n - 1` as `var()` and `sd()` do.
* `scenario_max(x)` and `scenario_min(x)` are the largest and the smallest value over the scenarios, and `scenario_quantile(x, prob)` is the value that the share `prob` of scenarios stays at or below (`quantile(type = 1)` of the scenario values). Minimizing `scenario_max(cost)` optimizes the worst scenario of the sample.

# quicopt 0.2.0

The release for checking a solution, not only finding one.

* `resample(m, res, seed)` evaluates a solution on scenarios it was not
  optimized for, and reports the out-of-sample objective and whether every
  constraint still holds. `evaluate(m, res, expr)` gives the value of any
  non-random expression at a solution, on the model's scenarios or, with
  `seed`, on fresh ones.
* `add(m, prob(...) >= level, margin = k)` tightens a chance constraint's level
  by `k` standard errors of the scenario estimate, so the level is cleared out
  of sample rather than merely in sample.
* `holds(a <= b)` is a comparison as a 0/1 expression, in each scenario; all six
  comparisons are allowed there, with an optional tolerance.
* `add(m, rel, when = b)` imposes a row only where the binary `b` is 1.
* `set_start(m, res)` warm-starts the next solve from a previous solution;
  `bin_var()` takes a `start` too.
* `rand_var(m, "weight", normal(c(6, 5, 4), 1))` declares a vector random
  variable, one independent draw per element.
* `is_random(x)` says whether an expression still varies across scenarios. An
  aggregator applied to a non-random expression, and a random objective or
  constraint, are now refused in R with the public names, before the service
  refuses them with wire names.
* `mean()` of a model expression is the mean over its elements, like `sum()`;
  `c()` concatenates expressions.

Fixed:

* `-x` and `prod()` over three or more elements encoded shapes the service
  rejected.
* `x <= 3` with a vector `x` added one row instead of one per element.
* The `solution` of a result is ordered as the variables were declared. It
  used to keep the order the answer arrived in, which is the service's own,
  so `which(res$solution == 1)` did not count items the way the model did.

# quicopt 0.1.1

Documentation: every help topic with a usage section now states its value.

# quicopt 0.1.0

First release.
