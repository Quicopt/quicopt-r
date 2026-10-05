# A permutation, for building a program by hand

Declares one permutation of a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md):
`size` items in `size` slots, one item per slot (see
[`perm_var()`](https://quicopt.github.io/quicopt-r/reference/perm_var.md)).
[`perm_var()`](https://quicopt.github.io/quicopt-r/reference/perm_var.md)
builds these for you.

## Usage

``` r
permutation_decl(size, start = integer(), fixed = FALSE, precede = list())
```

## Arguments

- size:

  How many items, at least 2.

- start:

  The arrangement the search starts from: `start[i]` is the slot of item
  `i`, so `start` contains each of the numbers 1 to `size` once.
  [`integer()`](https://rdrr.io/r/base/integer.html) starts with item
  `i` in slot `i`.

- fixed:

  Whether the permutation is fixed at `start`, which must then be given.
  This is how
  [`evaluate()`](https://quicopt.github.io/quicopt-r/reference/evaluate.md)
  and
  [`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md)
  keep the arrangement of a solution.

- precede:

  A list of pairs `c(before, after)`, each requiring item `before` to be
  in an earlier slot than item `after`.

## Value

A plain list without a class, with the fields `kind = "permutation"`,
`size`, `start`, `fixed` and `precede`. It is an element of the named
list a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md)
takes as `structures`, and the element's name is the name
[`ir_struct_ref()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
refers to.

## Examples

``` r
# five stops, stop 4 before stop 1
structures <- list(route = permutation_decl(5, precede = list(c(4, 1))))
```
