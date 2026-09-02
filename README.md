# quicopt

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
# install.packages("quicopt")   # once released
pak::pak("Quicopt/quicopt-r")   # from GitHub; pure R, no toolchain needed
```

## Use

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

## Under uncertainty

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

Apache-2.0.
