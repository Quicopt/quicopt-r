# quicopt

[![r-universe](https://quicopt.r-universe.dev/quicopt/badges/version)](https://quicopt.r-universe.dev/quicopt)
[![r-universe checks](https://quicopt.r-universe.dev/quicopt/badges/checks)](https://quicopt.r-universe.dev/quicopt)
[![Docs](https://img.shields.io/badge/docs-latest-blue.svg)](https://quicopt.github.io/quicopt-r/)
[![check](https://github.com/Quicopt/quicopt-r/actions/workflows/check.yml/badge.svg?branch=main)](https://github.com/Quicopt/quicopt-r/actions/workflows/check.yml)
[![R 4.1+](https://img.shields.io/badge/r-4.1%2B-276DC3.svg)](https://www.r-project.org)
[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://github.com/Quicopt/quicopt-r/blob/main/LICENSE)

The R client for the [Quicopt](https://quicopt.com) optimization service.

You describe a decision: what you get to choose, what has to hold, and what you
want as much (or as little) of as possible. Quicopt finds the best choice there is.

Part of that decision is often taken before the data is known — demand, prices,
yields. Declare that data as random variables, and the model is solved over
scenarios drawn from their distributions: minimize an expectation or a
conditional value at risk, and require constraints to hold with a given
probability. Observed history in a `data.frame` becomes a stochastic program in
one call.

There is no solver on your machine; the service does the solving.

## Install

```r
install.packages("quicopt", repos = c("https://quicopt.r-universe.dev",
                                      "https://cloud.r-project.org"))
```

Or straight from the source repository — the package is pure R, so this needs no
compiler either:

```r
pak::pak("Quicopt/quicopt-r")
```

## Toy Model

```r
library(quicopt)

m <- model()
x <- num_var(m, "x", 0, 4)
y <- bin_var(m, "y")
maximize(m, 3 * x + 5 * y)
add(m, x + 2 * y <= 5)

res <- solve(m)
res$status; res$objective   # "optimal" 14
res$solution
```

## Optimization under Uncertainty

Order `x` units at 3 apiece against a demand you will only learn later, pay for
the mismatch, and meet demand in at least 90% of scenarios:

```r
m <- model()
x <- num_var(m, "x", 0, 200)                     # decide now
demand <- rand_var(m, "demand", normal(100, 15)) # learn later
set_scenarios(m, 512, seed = 42)

minimize(m, 3 * x + 10 * expectation(max(demand - x, 0)))
add(m, prob(demand - x <= 0) >= 0.9)

res <- solve(m)
res$solution[["x"]]                              # 118.7: the 90% service
                                                 # level binds at the sample q90
```

`max(demand - x, 0)` is the shortfall — and it is plain R: arithmetic, `max`,
`sum` and friends build the model's expressions directly. Note that scenarios
are drawn by the service from the model's own seed (`set_scenarios`), so
`set.seed()` plays no role here.

Have the uncertainty as data instead of a distribution? Every column of a data
frame becomes a random variable, jointly, with correlation preserved:

```r
history <- read.csv("demand_price.csv")   # observed rows
m <- model()
set_empirical(m, history)                 # columns -> sources, nrow -> scenarios
```

## License

Apache License 2.0 — see [`LICENSE`](https://github.com/Quicopt/quicopt-r/blob/main/LICENSE). (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich.
