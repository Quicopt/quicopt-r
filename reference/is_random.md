# Does an expression vary across scenarios?

An expression that contains a random variable has a different value in
each scenario, and is called *random*. Summarizing it across the
scenarios, for example with
[`expectation()`](https://quicopt.github.io/quicopt-r/reference/expectation.md),
gives a single number again: `demand - stock` is random,
`expectation(demand - stock)` is not, and neither is `3 * stock`.

## Usage

``` r
is_random(x)
```

## Arguments

- x:

  An expression, or a numeric vector (which is never random).

## Value

A logical vector with one element per element of `x`.

## Details

An objective or a constraint must not be random, and a summary such as
[`expectation()`](https://quicopt.github.io/quicopt-r/reference/expectation.md)
needs a random expression to summarize. quicopt checks both rules itself
and stops with an error when one is broken, so you need `is_random()`
only in your own code, for example in a function that accepts both kinds
of expression.

## Examples

``` r
m <- model()
stock  <- num_var(m, "stock", lower = 0, upper = 200)
demand <- rand_var(m, "demand", normal(100, 15))
is_random(demand - stock)                  # TRUE
#> [1] TRUE
is_random(expectation(demand - stock))     # FALSE
#> [1] FALSE
is_random(c(stock, stock^2))               # FALSE FALSE
#> [1] FALSE FALSE
```
