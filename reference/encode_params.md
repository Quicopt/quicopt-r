# Encode parameter tables on their own

Encodes the parameter tables of a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md)
without the rest of it. The format has this message so that a program
can be given new data without sending the whole program again; no
function in this package sends it. Tables are written in a fixed order,
so the same data always gives the same bytes.

## Usage

``` r
encode_params(params)
```

## Arguments

- params:

  Parameter tables, as for
  [`program()`](https://quicopt.github.io/quicopt-r/reference/program.md).

## Value

A raw vector.

## Examples

``` r
cost <- list(list(key = list(1L), value = 3), list(key = list(2L), value = 1.5))
encode_params(list(cost = cost))
#>  [1] 0a 28 0a 04 63 6f 73 74 12 0f 0a 04 0a 02 08 01 11 00 00 00 00 00 00 08 40
#> [26] 12 0f 0a 04 0a 02 08 02 11 00 00 00 00 00 00 f8 3f
```
