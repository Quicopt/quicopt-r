# A constraint, for building a program by hand

States that the expression `f` lies in `set` (see
[`zero()`](https://quicopt.github.io/quicopt-r/reference/consets.md) and
the other constraint sets). With `over`, the constraint is repeated for
every element of one or more index sets, like a constraint written "for
all `i` in `S`".
[`add()`](https://quicopt.github.io/quicopt-r/reference/add.md) builds
these for you.

## Usage

``` r
constraint(f, set, over = list())
```

## Arguments

- f:

  The expression node.

- set:

  The set `f` must lie in:
  [`zero()`](https://quicopt.github.io/quicopt-r/reference/consets.md),
  [`nonneg()`](https://quicopt.github.io/quicopt-r/reference/consets.md)
  or
  [`indicator()`](https://quicopt.github.io/quicopt-r/reference/consets.md).

- over:

  A list of `list(idx, set_ref)` pairs, each repeating the constraint
  for every element of the set `set_ref` (from
  [`ir_set_ref()`](https://quicopt.github.io/quicopt-r/reference/ir.md)),
  with the index named `idx` standing for the element in `f`.
  [`list()`](https://rdrr.io/r/base/list.html) for a single constraint.

## Value

A plain list without a class, with the fields `f`, `set` and `over`. It
is an element of the list a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md)
takes as `constraints`.

## Examples

``` r
# x <= 4, written as 4 - x >= 0
constraint(ir_apply("-", list(ir_const(4), ir_var("x"))), nonneg())
#> $f
#> $f$kind
#> [1] "apply"
#> 
#> $f$op
#> [1] "-"
#> 
#> $f$args
#> $f$args[[1]]
#> $f$args[[1]]$kind
#> [1] "const"
#> 
#> $f$args[[1]]$value
#> [1] 4
#> 
#> 
#> $f$args[[2]]
#> $f$args[[2]]$kind
#> [1] "var"
#> 
#> $f$args[[2]]$name
#> [1] "x"
#> 
#> $f$args[[2]]$index
#> list()
#> 
#> 
#> 
#> 
#> $set
#> $set$kind
#> [1] "nonneg"
#> 
#> 
#> $over
#> list()
#> 
```
