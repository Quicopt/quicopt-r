# Lower a model to a program

The program is the model as plain data — what
[`encode()`](https://quicopt.github.io/quicopt-r/reference/encode.md)
serializes and the service reads.
[`solve()`](https://rdrr.io/r/base/solve.html) does this on the way out;
call it directly to inspect what will be sent.

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
