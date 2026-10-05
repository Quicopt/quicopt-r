# Give a random variable its distribution

Sets or replaces the distribution of a random variable declared with
[`rand_var()`](https://quicopt.github.io/quicopt-r/reference/rand_var.md),
for example one declared without a distribution.

## Usage

``` r
set_distribution(m, v, dist)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- v:

  The random variable, as returned by
  [`rand_var()`](https://quicopt.github.io/quicopt-r/reference/rand_var.md).

- dist:

  A distribution such as `normal(100, 15)`, or an
  [`empirical()`](https://quicopt.github.io/quicopt-r/reference/empirical.md)
  sample, of the same length as `v`.

## Value

The model, invisibly.

## Examples

``` r
m <- model()
demand <- rand_var(m, "demand")
set_distribution(m, demand, normal(100, 15))
```
