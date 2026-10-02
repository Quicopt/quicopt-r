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
