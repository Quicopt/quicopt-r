# Encode parameter tables alone, for rebinding data

Send the program once, then one of these per instance to re-solve the
same structure on new data without re-sending the model. Tables are
written in sorted order, so the same data always encodes to the same
bytes.

## Usage

``` r
encode_params(params)
```

## Arguments

- params:

  Named parameter tables, as in
  [`program()`](https://quicopt.github.io/quicopt-r/reference/program.md).

## Value

A raw vector: the encoded tables.
