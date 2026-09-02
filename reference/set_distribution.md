# Give a random variable its distribution

Give a random variable its distribution

## Usage

``` r
set_distribution(m, v, dist)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- v:

  The random variable's handle, from
  [`rand_var()`](https://quicopt.github.io/quicopt-r/reference/rand_var.md).

- dist:

  A
  [`distribution()`](https://quicopt.github.io/quicopt-r/reference/distribution.md)
  or an
  [`empirical()`](https://quicopt.github.io/quicopt-r/reference/empirical.md)
  column.

## Value

The model, invisibly.
