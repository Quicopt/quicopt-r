# Encode a program to the bytes the service reads

Two equal programs always encode to equal bytes, whichever order their
tables happened to be built in. A model that declares no uncertainty and
no permutation encodes to exactly the bytes it would have before those
layers existed, so declaring none costs an ordinary model nothing.

## Usage

``` r
encode(prog)
```

## Arguments

- prog:

  A
  [`program()`](https://quicopt.github.io/quicopt-r/reference/program.md),
  or a model built with
  [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md)
  (which is lowered first).

## Value

A raw vector: the encoded program.

## Details

Encoding is normally invisible:
[`solve_model()`](https://quicopt.github.io/quicopt-r/reference/solve_model.md)
does it for you, and what it sends is exactly these bytes. Reach for
`encode` to send them yourself, store them, or check them.
