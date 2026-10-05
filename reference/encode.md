# Encode a model as the bytes the service reads

Turns a model or a program into the bytes that
[`solve()`](https://rdrr.io/r/base/solve.html) sends. The same program
always gives the same bytes, in whatever order its parts were built.
[`solve()`](https://rdrr.io/r/base/solve.html) also accepts the bytes
directly.

## Usage

``` r
encode(prog)
```

## Arguments

- prog:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md)
  or a
  [`program()`](https://quicopt.github.io/quicopt-r/reference/program.md).

## Value

A raw vector.

## Examples

``` r
m <- model()
x <- num_var(m, "x", lower = 0, upper = 4)
maximize(m, 3 * x)
bytes <- encode(m)
length(bytes)
#> [1] 70
identical(bytes, encode(as_program(m)))   # TRUE
#> [1] TRUE
```
