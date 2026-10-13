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

A model with `holds()` is solved by a search, so its status is
`"heuristic"`. The same holds for
[`max()`](https://rdrr.io/r/base/Extremes.html) and
[`min()`](https://rdrr.io/r/base/Extremes.html). When every variable of
such a model is an integer or a binary variable, each needs finite
bounds; a model with a continuous variable or with random variables has
no such limit.

## A fee due from a level

`holds()` writes a cost that is due once a total reaches a level, and a
discount that is earned there. With deliveries `ship` from one warehouse
to several customers, `60 * holds(sum(ship) >= 1)` is a fee of 60 that
the warehouse costs once it ships anything, and
`-30 * holds(sum(ship) >= 60)` a discount of 30 from 60 units on.
`min(sum(active(ship)), 1)` is the same "anything shipped" written with
[`active()`](https://quicopt.github.io/quicopt-r/reference/active.md): 1
once any delivery takes place.
([`min()`](https://rdrr.io/r/base/Extremes.html) and
[`max()`](https://rdrr.io/r/base/Extremes.html) read the model
expression from their first argument, so it comes before the number.)

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
