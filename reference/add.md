# Add constraints to a model

A comparison of model expressions is a constraint, not a logical:
`add(m, x + y <= 5)` requires the row to hold, and `==` states an
equality. A comparison of vector expressions adds one row per element,
so `add(m, x <= cap)` with two length-`n` vectors is `n` rows.

## Usage

``` r
add(m, rel)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- rel:

  A comparison built with `<=`, `>=` or `==`.

## Value

The model, invisibly.
