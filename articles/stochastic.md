# Deciding before the data arrives

Part of most decisions is data you will only learn afterwards: how much
is demanded, at what price, with what yield. A model under uncertainty
is ordinary R arithmetic over decision variables and random quantities.
The service solves it over a sample of scenarios, and this vignette
shows the whole loop: build, solve, and then check the answer on
scenarios the search never saw, which is the step that separates a
solution from a lucky one.

## A session, end to end

Six items with known profits and uncertain weights, to be packed into a
capacity of 12. Each weight is roughly normal around its mean, and the
packing must fit in at least 90% of scenarios:

``` r

profit      <- c(9, 7, 6, 5, 4, 3)                 # of each item
mean_weight <- c(6, 5, 4, 3, 3, 2)
capacity    <- 12

m <- model()
packed <- bin_var(m, "packed", n = 6)                      # packed[item]: 1 if the item goes in
weight <- rand_var(m, "weight", normal(mean_weight, 1))    # the uncertain weights, one per item
set_scenarios(m, 500, seed = 1)

load   <- sum(packed * weight)                             # one value per scenario
p_fits <- prob(load <= capacity)                           # P(load <= capacity), one number
add(m, p_fits >= 0.9)
maximize(m, sum(profit * packed))

res <- solve(m)
which(res$solution == 1)                                   # the items packed
#> packed[1] packed[3] 
#>         1         3
res$objective                                              # their profit
#> [1] 15
```

Everything here is plain R. `packed * weight` is elementwise,
[`sum()`](https://rdrr.io/r/base/sum.html) folds the six products into
one load, and that load is a different number in every scenario: it is
*random*, in the package’s vocabulary.
[`prob()`](https://quicopt.github.io/quicopt-r/reference/prob.md) closes
it over the scenarios into one number, the share of scenarios in which
the load fits, and that number is what the constraint is placed on.

The packing was chosen on 500 scenarios and is judged on the same 500. A
solution found that way leans on the sample that shaped it, so the first
thing to do with it is to look at it on fresh scenarios.
[`evaluate()`](https://quicopt.github.io/quicopt-r/reference/evaluate.md)
gives the value of any closed expression at a solution, on the model’s
own scenarios or, with a seed, on new ones:

``` r

evaluate(m, res, p_fits)                 # in sample: at least 0.9, by construction
#> [1] 0.904
evaluate(m, res, p_fits, seed = 2)       # out of sample: fresh draws, same packing
#> [1] 0.922
```

[`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md)
does the same for the model as a whole, holding the solution fixed and
reporting whether every constraint still holds:

``` r

chk <- resample(m, res, seed = 2)
chk$feasible
#> [1] TRUE
chk$solver_data$max_violation            # if not: by how much, in units of probability
#> [1] 0
```

With six binary decisions the feasible packings are few and far apart,
so the chosen one has slack: it fits more often than the constraint
demanded, in sample and out. A continuous decision has no such luck. It
lands exactly on the level, and then misses it on fresh draws about half
the time, which the newsvendor below shows, together with the remedy.

## The newsvendor

Order `x` units at 3 apiece. Demand turns out to be roughly normal
around 100. Every unit short costs 10 in expectation, and the service
level requires demand to be met in at least 90% of scenarios. The model
is wrapped in a function here, because the next section builds it twice:

``` r

newsvendor <- function(margin = 0) {
  m <- model()
  x <- num_var(m, "x", 0, 200)                     # decide now
  demand <- rand_var(m, "demand", normal(100, 15)) # learn later
  set_scenarios(m, 512, seed = 42)
  minimize(m, 3 * x + 10 * expectation(max(demand - x, 0)))
  add(m, prob(demand - x <= 0) >= 0.9, margin = margin)
  m
}
m <- newsvendor()
m
#> quicopt model: 1 variable, 1 random (512 scenarios), 1 constraint row(s)
#>   min ((3 * x) + (10 * smean(max((~demand - x), 0))))
```

`max(demand - x, 0)` is the shortfall, the kinked expression that prices
recourse, and
[`expectation()`](https://quicopt.github.io/quicopt-r/reference/expectation.md)
closes it over the scenarios.
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
90th percentile of demand (the population value is
`qnorm(0.9, 100, 15)`, about 119.2). Without the chance constraint the
order quantity would fall to the critical fractile
`(10 - 3) / 10 = 0.7`, about `qnorm(0.7, 100, 15)` or 107.9. The
constraint is what pushes the order up.

## A safety margin

The probability in `prob(demand - x <= 0) >= 0.9` is an estimate from
512 scenarios, and an estimate has a standard error:
`sqrt(0.9 * 0.1 / 512)`, about 0.013. The search stops as soon as the
estimate reaches 0.9, so the true probability is as likely to lie below
0.9 as above it. A check on fresh scenarios says which. The check is an
estimate too, so it gets a larger sample than the search had:

``` r

p_met <- prob(m$demand - m$x <= 0)
evaluate(m, res, p_met)                                # in sample: on the level
#> [1] 0.9003906
evaluate(m, res, p_met, seed = 7, scenarios = 1000)    # out of sample
#> [1] 0.896
```

This model is simple enough that the truth is known as well. Demand is
normal, so the probability of meeting it with an order of `x` is
`pnorm(x, 100, 15)`:

``` r

pnorm(res$solution[["x"]], 100, 15)
#> [1] 0.8940854
```

The order quantity falls short of the level it was optimized to meet.
Nothing went wrong in the search: it met the constraint it was given, on
the sample it was given.

`margin = k` asks for the level tightened by `k` standard errors, here
`0.9 + 2 * 0.013`, so that the true probability clears 0.9 with about
98% confidence. The price is a larger order:

``` r

m2 <- newsvendor(margin = 2)
res2 <- solve(m2)
c(as_stated = res$solution[["x"]], with_margin = res2$solution[["x"]])
#>   as_stated with_margin 
#>    118.7283    121.0360
```

The check is the same as before, against the level as originally stated.
The margin solution is evaluated on the plain model, since the question
is whether it meets 0.9, not 0.927:

``` r

evaluate(m, res2, p_met, seed = 7, scenarios = 1000)
#> [1] 0.924
resample(m, res2, seed = 7, scenarios = 1000)$feasible
#> [1] TRUE
pnorm(res2$solution[["x"]], 100, 15)
#> [1] 0.9196016
```

## Optimizing the tail instead of the average

An expectation optimizes the average case and says nothing about the bad
ones. `cvar(cost, 0.95)` is the mean of the worst 5% of scenarios, and
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

The limit of that idea is the single worst scenario.
`scenario_max(cost)` is the largest cost over the scenarios, and
minimizing it orders up to the largest demand the sample holds:

``` r

m3w <- model()
x3w <- num_var(m3w, "x", 0, 200)
d3w <- rand_var(m3w, "demand", normal(100, 15))
set_scenarios(m3w, 512, seed = 42)
minimize(m3w, scenario_max(3 * x3w + 10 * max(d3w - x3w, 0)))
solve(m3w)$solution[["x"]]
#> [1] 143.4227
```

An extreme is set by one scenario, so it depends on the sample far more
than a tail mean does: a larger sample will hold a larger demand, and
the order grows with it. The other statistics over the scenarios sit
between the two. `scenario_quantile(cost, 0.95)` is the cost that 95% of
scenarios stay at or below,
[`variance()`](https://quicopt.github.io/quicopt-r/reference/variance.md)
and
[`std_dev()`](https://quicopt.github.io/quicopt-r/reference/variance.md)
measure the spread in both directions, and each can be an objective term
or the left side of a constraint.

## Events as numbers

[`prob()`](https://quicopt.github.io/quicopt-r/reference/prob.md)
measures an event.
[`holds()`](https://quicopt.github.io/quicopt-r/reference/holds.md) is
the event itself, as a 0/1 value in each scenario, for arithmetic
*before* the aggregation. Suppose a stockout costs 200 whenever it
happens, on top of the 10 per unit short: a lost customer, an emergency
order. That is `200 * holds(demand > x)` in each scenario, and its
expected value joins the objective:

``` r

m4 <- model()
x4 <- num_var(m4, "x", 0, 200)
d4 <- rand_var(m4, "demand", normal(100, 15))
set_scenarios(m4, 512, seed = 42)
minimize(m4, 3 * x4 + 10 * expectation(max(d4 - x4, 0)) + 200 * expectation(holds(d4 > x4)))
solve(m4)$solution[["x"]]
#> [1] 121.0856
```

The fixed cost does what the chance constraint did, but by price rather
than by decree: the order rises until a stockout is rare enough to be
worth its cost. `expectation(holds(rel))` and `prob(rel)` are the same
number; the difference is what
[`holds()`](https://quicopt.github.io/quicopt-r/reference/holds.md) lets
you multiply it by first.

## From observed history

Usually the uncertainty is not an assumed distribution but rows you have
already observed.
[`set_empirical()`](https://quicopt.github.io/quicopt-r/reference/set_empirical.md)
turns a data frame into the model’s uncertainty in one call: every
column becomes a random variable named after it, the number of rows
becomes the scenario count, and because all columns are read at the same
scenario index, the correlation in your data survives into the model.

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

m5 <- model()
stock <- num_var(m5, "stock", 0, 200)
set_empirical(m5, history)
maximize(m5, expectation(m5$price * min(m5$demand, stock)) - 3 * stock)

res5 <- solve(m5)
res5$solution[["stock"]]
#> [1] 109
```

No distribution was fitted and none had to be: the 200 rows *are* the
scenarios. That is the shortest path from data to decision this package
has.

## Other distributions

The service draws from four distributions, each parameterized like R’s
own sampler: `normal(mean, sd)`, `uniform(min, max)`,
`exponential(rate)` and `bernoulli(prob)`. The newsvendor against a
demand that is exponential with mean 100 rather than normal:

``` r

m6 <- model()
x6 <- num_var(m6, "x", 0, 600)
d6 <- rand_var(m6, "demand", exponential(1 / 100))
set_scenarios(m6, 512, seed = 42)
minimize(m6, 3 * x6 + 10 * expectation(max(d6 - x6, 0)))
solve(m6)$solution[["x"]]
#> [1] 120.7402
```

With no chance constraint the best order for the true distribution is
its 70% quantile (ordering one unit more costs 3 and saves 10 whenever
demand exceeds the order), which is `qexp(0.7, 1 / 100)`, about 120.4.
The answer on 512 scenarios lands near it.

As with
[`normal()`](https://quicopt.github.io/quicopt-r/reference/distribution.md),
a parameter may be an expression, which is how a decision changes the
odds it is judged by: `bernoulli(0.2 - 0.015 * spend)` is a breakdown
that money spent on maintenance makes less likely.

Every other distribution is one line away, because a column you draw in
R is a random variable too. A demand that is lognormal:

``` r

set.seed(2)
m7 <- model()
x7 <- num_var(m7, "x", 0, 400)
d7 <- rand_var(m7, "demand", empirical(rlnorm(512, log(100), 0.3)))
minimize(m7, 3 * x7 + 10 * expectation(max(d7 - x7, 0)))
solve(m7)$solution[["x"]]
#> [1] 121.5136
```

Three things change with a sampled column. R’s seed governs it, not the
model’s. It is data, so
[`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md)
has nothing to redraw for it: an out-of-sample check of such a model is
a second column, drawn with another seed. And its parameters are fixed
when it is drawn, so a distribution whose parameters depend on a
decision needs one of the four named ones.

## Starting from a previous solution

A model is often solved more than once: a constraint tightened, a cost
updated, a scenario count raised.
[`set_start()`](https://quicopt.github.io/quicopt-r/reference/set_start.md)
hands the previous solution to the next search as its starting point, so
it begins where the last one ended rather than from scratch:

``` r

m8 <- newsvendor()
res8 <- solve(m8)                       # 512 scenarios
set_scenarios(m8, 1000, seed = 42)      # the same model on a larger sample
set_start(m8, res8)                     # start from where the first solve ended
solve(m8)$solution[["x"]]
#> [1] 117.6807
```

## An order to decide: a delivery round

Some decisions are not amounts but orders: the sequence of stops on a
round, of jobs on a machine.
[`perm_var()`](https://quicopt.github.io/quicopt-r/reference/perm_var.md)
declares such a decision as a permutation, `n` items in `n` slots, one
each, and the search keeps it that way. The items here are five stops on
a line and the slots are the steps of the round; the distance between
two stops is read from a
[`lookup_table()`](https://quicopt.github.io/quicopt-r/reference/lookup_table.md)
at the stops the round visits, which only the solver knows. The travel
time of each step is uncertain, so the objective is the expected length
of the round, and stop 4 must come before stop 1:

``` r

m9 <- model()
stop_x <- c(0, 3, 1, 4, 2)                                    # where each stop lies
dist <- lookup_table(m9, "dist", abs(outer(stop_x, stop_x, "-")))
tour <- perm_var(m9, "tour", 5)                               # item: a stop; slot: a step
precede(tour, 4, 1)                                           # stop 4 before stop 1
delay <- rand_var(m9, "delay", uniform(1, 1.5), n = 4)        # one factor per step
set_scenarios(m9, 256, seed = 3)
minimize(m9, expectation(sum(dist[item_at(1:4, tour), item_at(2:5, tour)] * delay)))
res9 <- solve(m9)
res9$structures$tour$item_at                                  # the stops, in visiting order
#> [1] 4 2 5 3 1
res9$objective
#> [1] 5.000605
```

`item_at(k, tour)` is the stop visited at step `k` and
`slot_of(i, tour)` the step at which stop `i` is visited; both come back
under `res9$structures`. The shortest round over these stops is 4 long,
so the expected length is 4 times the mean delay.
`resample(m9, res9, seed = 4)` checks it on fresh delays, with the round
held fixed.

## What comes back

[`solve()`](https://rdrr.io/r/base/solve.html) returns the parsed
answer: `status`, `objective`, a named `solution` vector, and the
service’s own ready-to-print summary:

``` r

res5$status
#> [1] "heuristic"
res5$objective
#> [1] 840.211
```

The objective of a model under uncertainty is an in-sample figure,
measured on the scenarios the solution was found on.
[`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md)
is how to read it on others. For a long-running model,
[`submit()`](https://quicopt.github.io/quicopt-r/reference/submit.md)
queues the same request and returns a handle immediately;
[`job_result()`](https://quicopt.github.io/quicopt-r/reference/job_status.md)
collects the answer when it is ready.
