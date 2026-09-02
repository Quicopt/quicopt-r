# Constraint sets

A constraint is a set membership: the expression `f` must land in the
set, so `x + 2*y <= 5` is written as `5 - (x + 2*y)` in `nonneg()` — one
sign convention rather than two.

## Usage

``` r
zero()

nonneg()

indicator(bin, inner)
```

## Arguments

- bin:

  The binary
  [`ir_var()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  whose activity implies the inner set.

- inner:

  The constraint set that holds when `bin` is active.
