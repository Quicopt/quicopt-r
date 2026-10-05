# quicopt

[![r-universe](https://quicopt.r-universe.dev/quicopt/badges/version)](https://quicopt.r-universe.dev/quicopt)
[![r-universe checks](https://quicopt.r-universe.dev/quicopt/badges/checks)](https://quicopt.r-universe.dev/quicopt)
[![Docs](https://img.shields.io/badge/docs-latest-blue.svg)](https://quicopt.github.io/quicopt-r/)
[![check](https://github.com/Quicopt/quicopt-r/actions/workflows/check.yml/badge.svg?branch=main)](https://github.com/Quicopt/quicopt-r/actions/workflows/check.yml)
[![R 4.1+](https://img.shields.io/badge/r-4.1%2B-276DC3.svg)](https://www.r-project.org)
[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://github.com/Quicopt/quicopt-r/blob/main/LICENSE)

quicopt lets you write an optimization model in R and solve it with the
[Quicopt](https://quicopt.com) service. You state what you can decide, what you
want to achieve, and which conditions have to hold, and the service finds the
best decision. Nothing needs to be installed besides the package: the model is
sent to the service, and the answer comes back as an R list.

quicopt is built in particular for decisions under uncertainty. When part of
the data, such as demand, prices or travel times, is not known in advance, you
describe it by a probability distribution or by observations in a data frame,
and the service finds the decision that does best across many possible
outcomes.

## Install

```r
install.packages("quicopt", repos = c("https://quicopt.r-universe.dev",
                                      "https://cloud.r-project.org"))
```

or from the source repository, which needs no compiler either, since the
package is written in plain R:

```r
pak::pak("Quicopt/quicopt-r")
```

## A first model

A workshop makes tables and chairs. A table earns 50 and takes 3 hours of
carpentry, a chair earns 20 and takes 1 hour. There are 41 hours available and
wood for 18 pieces. How many of each should it make?

```r
library(quicopt)

m <- model()
tables <- int_var(m, "tables", lower = 0)
chairs <- int_var(m, "chairs", lower = 0)

maximize(m, 50 * tables + 20 * chairs)    # profit
add(m, 3 * tables + chairs <= 41)         # hours of carpentry
add(m, tables + chairs <= 18)             # wood

res <- solve(m)
res$solution                              # 12 tables, 5 chairs
res$objective                             # a profit of 700
```

## A decision under uncertainty

A shop orders stock at 3 per unit before it knows the day's demand, which is
roughly normal with mean 100 and standard deviation 15. Each unit of demand it
cannot meet costs 10. The shop wants the lowest expected cost, and enough stock
to meet demand on at least 90% of days:

```r
m <- model()
stock  <- num_var(m, "stock", lower = 0, upper = 200)   # decided now
demand <- rand_var(m, "demand", normal(100, 15))       # learned later
set_scenarios(m, 512, seed = 42)                       # 512 simulated days

minimize(m, 3 * stock + 10 * expectation(max(demand - stock, 0)))
add(m, prob(demand <= stock) >= 0.9)

res <- solve(m)
res$solution[["stock"]]                                # 118.7
```

The stock was chosen to work on those 512 simulated days. `resample()` checks
it on new ones, and `add(..., margin = 2)` builds in a safety margin for what
it finds. With observed history in a data frame instead of a distribution,
`set_empirical(m, history)` makes each column a random variable and each row a
scenario.

## Learn more

* [Get started](https://quicopt.github.io/quicopt-r/articles/quicopt.html):
  variables, objectives, constraints and the answer, step by step.
* [Deciding before the data arrives](https://quicopt.github.io/quicopt-r/articles/stochastic.html):
  random variables, expected costs, chance constraints, and checking a solution
  on new scenarios.
* [Choosing an order](https://quicopt.github.io/quicopt-r/articles/permutations.html):
  routes, schedules and assignments.
* [Reference](https://quicopt.github.io/quicopt-r/reference/): every function.

## License

Apache License 2.0 — see [`LICENSE`](https://github.com/Quicopt/quicopt-r/blob/main/LICENSE). (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich.
