# Distributions for random variables

`normal(mean, sd)` follows
[`rnorm()`](https://rdrr.io/r/stats/Normal.html)'s parameterization: the
mean and the standard deviation. `distribution(head, ...)` is the escape
hatch for any distribution the service supports that has no named
constructor here yet.

## Usage

``` r
distribution(head, ...)

normal(mean, sd)
```

## Arguments

- head:

  The distribution's name in the service's catalog.

- ...:

  Its parameters, each a number or a deterministic expression.

- mean, sd:

  The mean and standard deviation, as in
  [`rnorm()`](https://rdrr.io/r/stats/Normal.html).

## Value

A distribution, ready for
[`rand_var()`](https://quicopt.github.io/quicopt-r/reference/rand_var.md)
or
[`set_distribution()`](https://quicopt.github.io/quicopt-r/reference/set_distribution.md).

## Details

A parameter may be a number or a deterministic model expression. An
expression gives an *endogenous* distribution — one whose parameters
depend on the decision, such as a demand whose mean rises with the price
you set. A parameter may never contain a random variable: a
distribution's parameters are data, not draws.
