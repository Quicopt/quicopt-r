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

## Value

A plain list, with no class attribute, naming the set a constrained
expression must lie in; it is what
[`constraint()`](https://quicopt.github.io/quicopt-r/reference/constraint.md)
takes as `set`. `zero()` returns `list(kind = "zero")`, meaning the
expression equals 0. `nonneg()` returns `list(kind = "nonneg")`, meaning
the expression is at least 0. `indicator()` returns a list with
`kind = "indicator"` and the fields `bin` and `inner` as given, meaning
`inner` is imposed only where `bin` is active.
