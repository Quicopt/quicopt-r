# Deciding before the data arrives

Part of most decisions is data you will only learn afterwards: how much
is demanded, at what price, with what yield. This vignette orders stock
against a demand that is not known yet — first from an assumed
distribution, then straight from observed history.

## The newsvendor

Order `x` units at 3 apiece. Demand turns out to be roughly normal
around 100. Every unit short costs 10 in expectation, and the service
level requires demand to be met in at least 90% of scenarios:

``` r

m <- model()
x <- num_var(m, "x", 0, 200)                     # decide now
demand <- rand_var(m, "demand", normal(100, 15)) # learn later
set_scenarios(m, 512, seed = 42)

minimize(m, 3 * x + 10 * expectation(max(demand - x, 0)))
add(m, prob(demand - x <= 0) >= 0.9)
m
#> quicopt model: 1 variable, 1 random (512 scenarios), 1 constraint row(s)
#>   min ((3 * x) + (10 * smean(max((~demand - x), 0))))
```

Everything here is ordinary R. `max(demand - x, 0)` is the shortfall —
the kinked expression that prices recourse — and
[`expectation()`](https://quicopt.github.io/quicopt-r/reference/expectation.md)
closes it over the scenarios;
[`prob()`](https://quicopt.github.io/quicopt-r/reference/prob.md)
measures the event `demand - x <= 0` across scenarios, and the outer
`>= 0.9` is the service level demanded of that probability.

Two things are worth saying out loud. A variable declared with
[`rand_var()`](https://quicopt.github.io/quicopt-r/reference/rand_var.md)
is a random variable, not a decision variable: the solver is handed its
value rather than choosing it, and every mention of `demand` refers to
the same sample. And the scenarios are drawn *by the service* from the
model’s own seed (`set_scenarios`), so R’s
[`set.seed()`](https://rdrr.io/r/base/Random.html) plays no role in the
solve.

``` r

res <- solve(m)
res$solution[["x"]]
#> [1] 118.7283
```

The answer is the 90% service level binding: `x` lands on the sample’s
90th percentile of demand (the population value is `qnorm(0.9, 100, 15)`
≈ 119.2). Without the chance constraint the order quantity would fall to
the critical fractile `(10 - 3) / 10 = 0.7`, about `qnorm(0.7, 100, 15)`
≈ 107.9 — the constraint is what pushes the order up:

``` r

m2 <- model()
x2 <- num_var(m2, "x", 0, 200)
d2 <- rand_var(m2, "demand", normal(100, 15))
set_scenarios(m2, 512, seed = 42)
minimize(m2, 3 * x2 + 10 * expectation(max(d2 - x2, 0)))
solve(m2)$solution[["x"]]
#> [1] 107.642
```

## Optimizing the tail instead of the average

An expectation optimizes the average case and says nothing about the bad
ones. `cvar(cost, 0.95)` is the mean of the worst 5% of scenarios —
minimizing it asks for a decision that holds up when things go badly:

``` r

m3 <- model()
x3 <- num_var(m3, "x", 0, 200)
d3 <- rand_var(m3, "demand", normal(100, 15))
set_scenarios(m3, 512, seed = 42)
minimize(m3, cvar(3 * x3 + 10 * max(d3 - x3, 0), 0.95))
solve(m3)$solution[["x"]]
#> [1] 132.5795
```

The tail-averse order is larger than the expectation-optimal one, as it
should be: the worst scenarios are the high-demand ones, and stocking
more is what protects against them.

## From observed history

Usually the uncertainty is not an assumed distribution but rows you have
already observed.
[`set_empirical()`](https://quicopt.github.io/quicopt-r/reference/set_empirical.md)
turns a data frame into the model’s uncertainty in one call: every
column becomes a random variable named after it, the number of rows
becomes the scenario count — and because all columns are read at the
same scenario index, the correlation in your data survives into the
model.

Here, 200 jointly observed days of demand and price (built with
`set.seed`, which governs this *data*, not the solve):

``` r

set.seed(1)
z <- rnorm(200)
history <- data.frame(demand = round(100 + 15 * z + 5 * rnorm(200)),
                      price  = round(12 - 0.03 * (15 * z) + rnorm(200), 2))
cor(history$demand, history$price)
#> [1] -0.2968849
```

Demand and price move against each other, and that relationship is
exactly what a stochastic program should see. Sell `min(demand, stock)`
at the scenario’s price, pay 3 per unit stocked:

``` r

m4 <- model()
stock <- num_var(m4, "stock", 0, 200)
set_empirical(m4, history)
maximize(m4, expectation(m4$price * min(m4$demand, stock)) - 3 * stock)

res4 <- solve(m4)
res4$solution[["stock"]]
#> [1] 109
```

No distribution was fitted and none had to be: the 200 rows *are* the
scenarios. That is the shortest path from data to decision this package
has.

## What comes back

[`solve()`](https://rdrr.io/r/base/solve.html) returns the parsed answer
— `status`, `objective`, a named `solution` vector — and the service’s
own ready-to-print summary:

``` r

res4$status
#> [1] "heuristic"
res4$objective
#> [1] 840.211
```

For a long-running model,
[`submit()`](https://quicopt.github.io/quicopt-r/reference/submit.md)
queues the same request and returns a handle immediately;
[`job_result()`](https://quicopt.github.io/quicopt-r/reference/job_status.md)
collects the answer when it is ready.
