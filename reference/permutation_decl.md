# A permutation declaration

`size` items in `size` slots, one each. `start[i]` is the slot item `i`
starts in (a permutation of `1:size`; empty for the default, item `i` in
slot `i`). `fixed` pins the permutation at `start`, which must then be
given: how a solution is re-evaluated. Each entry of `precede` is a pair
`c(before, after)` of items, requiring `before` in an earlier slot than
`after`.

## Usage

``` r
permutation_decl(size, start = integer(), fixed = FALSE, precede = list())
```

## Arguments

- size:

  How many items, at least 2.

- start:

  The starting slot of each item, or
  [`integer()`](https://rdrr.io/r/base/integer.html).

- fixed:

  Whether the permutation is pinned at `start`.

- precede:

  A list of `c(before, after)` pairs.

## Value

A plain list, with no class attribute, with the fields
`kind = "permutation"`, `size`, `start`, `fixed` and `precede`. It
declares one permutation, and is an entry of the named list a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md)
takes as `structures`; the entry's name is the name
[`ir_struct_ref()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
refers to.
