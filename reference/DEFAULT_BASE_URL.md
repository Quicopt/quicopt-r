# The address of the public Quicopt service

[`solve()`](https://rdrr.io/r/base/solve.html) and
[`submit()`](https://quicopt.github.io/quicopt-r/reference/submit.md)
send models to this address unless they are given another `base_url`.

## Usage

``` r
DEFAULT_BASE_URL
```

## Value

Not a function but a constant: a character string, the address of the
public service.

## Examples

``` r
DEFAULT_BASE_URL
#> [1] "https://try.quicoptapi.pgi.fz-juelich.de"
```
