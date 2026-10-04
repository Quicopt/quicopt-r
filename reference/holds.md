# A comparison as a 0/1 expression

`holds(a <= b)` is 1 where the comparison is true and 0 where it is not,
as a model expression: a count, a penalty, or an event can be built from
it with ordinary arithmetic. All six comparisons are allowed, since here
they are values rather than constraints: `holds(x != y)` is 1 where the
two differ.

## Usage

``` r
holds(rel, tol = 0)
```

## Arguments

- rel:

  A comparison of model expressions.

- tol:

  A non-negative tolerance, default 0.

## Value

An expression with one 0/1 element per compared element.

## Details

Across scenarios, `holds()` evaluates in each scenario separately, so
`expectation(holds(demand <= x))` is the share of scenarios in which
demand is met, the same number
[`prob()`](https://quicopt.github.io/quicopt-r/reference/prob.md) gives.
The difference is what can be done before aggregating:
`expectation(price * holds(demand <= x))` prices the event in each
scenario first.

`tol` widens the comparison: `holds(a == b, tol = 0.01)` is 1 where the
two are within 0.01 of each other, `holds(a <= b, tol = 0.01)` where `a`
is at most `b + 0.01`. Without it, `==` and `!=` compare exactly.

In a model with no random variable, a 0/1 expression makes the problem
combinatorial, and the service then expects integer variables with
finite bounds (the same holds for
[`max()`](https://rdrr.io/r/base/Extremes.html) and
[`min()`](https://rdrr.io/r/base/Extremes.html)). With a random variable
anywhere in the model there is no such restriction.

## Examples

``` r
m <- model()
x <- num_var(m, "x", 0, 200)
demand <- rand_var(m, "demand", normal(100, 15))
set_scenarios(m, 512, seed = 42)
met <- holds(demand <= x)                    # 1 in the scenarios where demand is met
add(m, expectation(met) >= 0.9)              # the same constraint as prob(demand <= x) >= 0.9
```
