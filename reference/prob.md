# The probability that a comparison holds

`prob(a <= b)` is the share of the scenarios in which `a <= b` holds: an
estimate of its probability. It is a single number, so it can be used in
a constraint. A requirement on a probability is called a *chance
constraint*:

## Usage

``` r
prob(rel)
```

## Arguments

- rel:

  A comparison of expressions, written with `<=` or `>=`.

## Value

An expression with one probability, between 0 and 1, per element of the
comparison.

## Details

    add(m, prob(demand <= stock) >= 0.9)

reads as "demand is met in at least 90% of the scenarios". The line
holds two comparisons, which do different jobs: the inner one,
`demand <= stock`, is the event checked in each scenario, and the outer
one, `>= 0.9`, is the requirement on how often it happens. The `margin`
argument of
[`add()`](https://quicopt.github.io/quicopt-r/reference/add.md) allows
for the sampling error of the estimate.

The comparison is written with `<=` or `>=`, and at least one side must
contain a random variable. `==` is not accepted, since the probability
that a quantity which can take any value equals one particular value is
0. `<` and `>` are not accepted either, since for such a quantity they
mean the same as `<=` and `>=`. For vector expressions, each element
gets its own probability.

[`holds()`](https://quicopt.github.io/quicopt-r/reference/holds.md)
turns the same comparison into a 0/1 value in each scenario, and
`expectation(holds(a <= b))` is the same number as `prob(a <= b)`.

## Examples

``` r
m <- model()
stock  <- num_var(m, "stock", lower = 0, upper = 200)
demand <- rand_var(m, "demand", normal(100, 15))
set_scenarios(m, 512, seed = 42)
add(m, prob(demand <= stock) >= 0.9)       # demand met in at least 90% of scenarios
```
