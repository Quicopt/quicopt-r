# Convert a model to a program

A program is the model written out as plain R lists: every variable,
expression and constraint, in the form that
[`encode()`](https://quicopt.github.io/quicopt-r/reference/encode.md)
turns into the bytes sent to the service.
[`solve()`](https://rdrr.io/r/base/solve.html) makes this conversion
itself, so you only need `as_program()` to look at exactly what a model
sends, or to work with the
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md)
functions directly.

## Usage

``` r
as_program(m)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

## Value

A
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md).

## Examples

``` r
m <- model()
x <- num_var(m, "x", lower = 0, upper = 4)
maximize(m, 3 * x)
str(as_program(m)$vars)
#> List of 1
#>  $ :List of 6
#>   ..$ name  : chr "x"
#>   ..$ axes  : chr(0) 
#>   ..$ domain: int 1
#>   ..$ lower : num 0
#>   ..$ upper : num 4
#>   ..$ start : num 0
```
