# State what the model optimizes

The objective is a single expression; fold a vector with
[`sum()`](https://rdrr.io/r/base/sum.html) first. A model given no
objective is a feasibility problem.

## Usage

``` r
minimize(m, e)

maximize(m, e)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- e:

  The objective expression.

## Value

The model, invisibly.
