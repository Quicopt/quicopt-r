# Sums, products, maxima and minima

`sum()`, `prod()`, `max()` and `min()` work on model expressions as they
do on numbers: each combines all the elements of all its arguments into
one value, so `max(x, 0)` is the largest of all the elements of `x` and
0. The arguments can be expressions, numbers or both, in any order:
`max(0, demand - stock)` and `max(demand - stock, 0)` mean the same.

## Usage

``` r
sum(..., na.rm = FALSE)

prod(..., na.rm = FALSE)

max(..., na.rm = FALSE)

min(..., na.rm = FALSE)
```

## Arguments

- ...:

  Expressions, numbers, or both.

- na.rm:

  Passed to base R when no argument is an expression, and ignored
  otherwise, since an expression has no missing values.

## Value

An expression with one element when any argument is an expression;
otherwise what base R returns.

## Details

quicopt provides its own versions of these four functions, because base
R would read `max(0, x)` with its numeric `max()` and stop with an
error. Called without any expression, they are base R's functions, so
loading the package changes nothing about how they work on numbers. R
reports this when the package is attached, as these functions being
masked from `base`.

The status of a model with `max()` or `min()` is `"heuristic"`: a good
answer, not a proven optimum.

## Examples

``` r
m <- model()
stock <- num_var(m, "stock", lower = 0, upper = 100)
demand <- c(60, 80, 120)
max(0, demand - stock)          # the largest shortfall of the three
#> max(max(max(0, (60 - stock)), (80 - stock)), (120 - stock))
sum(2, stock)                   # 2 + stock
#> (2 + stock)
max(3, 7)                       # 7, as in base R
#> [1] 7
```
