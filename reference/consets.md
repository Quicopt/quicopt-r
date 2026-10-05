# Constraint sets, for building a program by hand

In a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md),
a constraint states that an expression lies in a set:

## Usage

``` r
zero()

nonneg()

indicator(bin, inner)
```

## Arguments

- bin:

  The binary variable that switches the constraint on, as an
  [`ir_var()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  node.

- inner:

  The set the expression must lie in when `bin` is 1: `zero()` or
  `nonneg()`.

## Value

A plain list without a class, to be passed as the `set` of a
[`constraint()`](https://quicopt.github.io/quicopt-r/reference/constraint.md):
`list(kind = "zero")`, `list(kind = "nonneg")`, or for `indicator()` a
list with `kind = "indicator"` and the fields `bin` and `inner`.

## Details

- `zero()`: the expression equals 0;

- `nonneg()`: the expression is at least 0;

- `indicator(bin, inner)`: the expression lies in the set `inner`
  whenever the binary variable `bin` is 1, and is unrestricted when it
  is 0.

So `x + 2 * y <= 5` is written as `5 - (x + 2 * y)` in `nonneg()`, and
`x == 3` as `x - 3` in `zero()`.
[`add()`](https://quicopt.github.io/quicopt-r/reference/add.md) makes
this conversion for you.

## Examples

``` r
# x + 2 * y <= 5
constraint(ir_apply("-", list(ir_const(5),
                              ir_apply("+", list(ir_var("x"),
                                                 ir_apply("*", list(ir_const(2), ir_var("y"))))))),
           nonneg())
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
#> [1] 5
#> 
#> 
#> $f$args[[2]]
#> $f$args[[2]]$kind
#> [1] "apply"
#> 
#> $f$args[[2]]$op
#> [1] "+"
#> 
#> $f$args[[2]]$args
#> $f$args[[2]]$args[[1]]
#> $f$args[[2]]$args[[1]]$kind
#> [1] "var"
#> 
#> $f$args[[2]]$args[[1]]$name
#> [1] "x"
#> 
#> $f$args[[2]]$args[[1]]$index
#> list()
#> 
#> 
#> $f$args[[2]]$args[[2]]
#> $f$args[[2]]$args[[2]]$kind
#> [1] "apply"
#> 
#> $f$args[[2]]$args[[2]]$op
#> [1] "*"
#> 
#> $f$args[[2]]$args[[2]]$args
#> $f$args[[2]]$args[[2]]$args[[1]]
#> $f$args[[2]]$args[[2]]$args[[1]]$kind
#> [1] "const"
#> 
#> $f$args[[2]]$args[[2]]$args[[1]]$value
#> [1] 2
#> 
#> 
#> $f$args[[2]]$args[[2]]$args[[2]]
#> $f$args[[2]]$args[[2]]$args[[2]]$kind
#> [1] "var"
#> 
#> $f$args[[2]]$args[[2]]$args[[2]]$name
#> [1] "y"
#> 
#> $f$args[[2]]$args[[2]]$args[[2]]$index
#> list()
#> 
#> 
#> 
#> 
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
