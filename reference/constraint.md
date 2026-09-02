# A constraint row

A constraint row

## Usage

``` r
constraint(f, set, over = list())
```

## Arguments

- f:

  The constrained expression node.

- set:

  The constraint set `f` must lie in
  ([`zero()`](https://quicopt.github.io/quicopt-r/reference/consets.md),
  [`nonneg()`](https://quicopt.github.io/quicopt-r/reference/consets.md),
  [`indicator()`](https://quicopt.github.io/quicopt-r/reference/consets.md)).

- over:

  Quantifier bindings, a list of `list(idx, set_ref)` pairs
  ([`list()`](https://rdrr.io/r/base/list.html) for a single scalar
  row).
