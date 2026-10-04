# Does an expression vary across scenarios?

An expression is random while it contains a random variable that no
aggregator has closed: `demand - x` is random, `expectation(demand - x)`
is not, and neither is `3 * x`. Only a non-random expression can be an
objective or a constraint; only a random one can be aggregated. Both
rules are checked where the expression is used, so this predicate is for
your own code: a helper that accepts either kind, or a check before a
long build.

## Usage

``` r
is_random(x)
```

## Arguments

- x:

  A model expression, or a numeric vector (never random).

## Value

A logical vector, one entry per element of `x`.

## Examples

``` r
m <- model()
x <- num_var(m, "x", 0, 10)
d <- rand_var(m, "d", normal(5, 1))
is_random(d - x)                 # TRUE
#> [1] TRUE
is_random(expectation(d - x))    # FALSE
#> [1] FALSE
is_random(c(x, x^2))             # FALSE FALSE
#> [1] FALSE FALSE
```
