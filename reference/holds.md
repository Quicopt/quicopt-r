# A comparison as a 0/1 expression

`holds(a <= b)` is 1 when the comparison is true and 0 when it is false.
Unlike a constraint, it does not require anything: it is an expression
like any other, so it can be added up, multiplied by a cost, or used in
the objective. `sum(holds(x >= 1))`, for example, counts the elements of
`x` that are at least 1. All six comparisons are accepted, including
`<`, `>` and `!=`, which
[`add()`](https://quicopt.github.io/quicopt-r/reference/add.md) refuses.

## Usage

``` r
holds(rel, tol = 0)
```

## Arguments

- rel:

  A comparison of expressions.

- tol:

  How far the comparison may be off and still count as true; a number of
  at least 0.

## Value

An expression with one 0/1 element per element of the comparison.

## Details

With random variables, `holds()` is evaluated in each scenario
separately. `expectation(holds(demand <= stock))` is then the share of
scenarios in which demand is met, the same number as
`prob(demand <= stock)`. The difference is that `holds()` lets you
combine the event with other quantities before averaging: for example,
`expectation(200 * holds(demand > stock))` is the expected cost of a
fixed charge of 200 whenever the stock runs out.

`tol` loosens the comparison. `holds(a == b, tol = 0.01)` is 1 when `a`
and `b` are within 0.01 of each other, and `holds(a <= b, tol = 0.01)`
is 1 when `a` is at most `b + 0.01`. Without it, `==` and `!=` compare
exactly.

In a model without random variables, `holds()` limits the kind of model
the service accepts: every variable must then be an integer or a binary
variable, with finite bounds. The same holds for
[`max()`](https://rdrr.io/r/base/Extremes.html) and
[`min()`](https://rdrr.io/r/base/Extremes.html). In a model with random
variables there is no such limit.

## Examples

``` r
m <- model()
stock  <- num_var(m, "stock", lower = 0, upper = 200)
demand <- rand_var(m, "demand", normal(100, 15))
set_scenarios(m, 512, seed = 42)
stockout <- holds(demand > stock)            # 1 in the scenarios where the stock runs out
minimize(m, 3 * stock + 200 * expectation(stockout))

met <- holds(demand <= stock)
add(m, expectation(met) >= 0.9)              # the same as prob(demand <= stock) >= 0.9
```
