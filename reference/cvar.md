# The average over the worst scenarios

`cvar(x, alpha)` is the average of `x` over the worst `1 - alpha` share
of the scenarios, the ones in which `x` is largest. With `alpha = 0.95`,
it is the average over the worst 5%. The measure is known as the
*conditional value at risk*. Minimizing it asks for a decision that
keeps the bad scenarios as good as possible, rather than the average
one.

## Usage

``` r
cvar(x, alpha)
```

## Arguments

- x:

  A random expression (see
  [`is_random()`](https://quicopt.github.io/quicopt-r/reference/is_random.md)).

- alpha:

  A number strictly between 0 and 1. It cannot depend on a decision.

## Value

An expression of the same length as `x`, no longer random.

## Details

`x` is read as a cost: large values are bad. For a profit, use the
negative, `cvar(-profit, 0.95)`.

## Examples

``` r
m <- model()
stock  <- num_var(m, "stock", lower = 0, upper = 200)
demand <- rand_var(m, "demand", normal(100, 15))
set_scenarios(m, 512, seed = 42)
cost <- 3 * stock + 10 * max(demand - stock, 0)
minimize(m, cvar(cost, 0.95))              # the average cost of the worst 5% of scenarios
```
