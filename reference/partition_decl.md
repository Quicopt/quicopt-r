# A partition, for building a program by hand

Declares one partition of a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md):
`size` items, each in one of `parts` parts (see
[`part_var()`](https://quicopt.github.io/quicopt-r/reference/part_var.md)).
[`part_var()`](https://quicopt.github.io/quicopt-r/reference/part_var.md)
builds these for you.

## Usage

``` r
partition_decl(size, parts, start = integer(), fixed = FALSE)
```

## Arguments

- size:

  How many items, at least 1.

- parts:

  How many parts, at least 2.

- start:

  The assignment the search starts from: `start[i]` is the part of item
  `i`, a whole number from 1 to `parts`.
  [`integer()`](https://rdrr.io/r/base/integer.html) leaves the start to
  the service.

- fixed:

  Whether the partition is fixed at `start`, which must then be given.
  This is how
  [`evaluate()`](https://quicopt.github.io/quicopt-r/reference/evaluate.md)
  and
  [`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md)
  keep the assignment of a solution.

## Value

A plain list without a class, with the fields `kind = "partition"`,
`size`, `parts`, `start` and `fixed`. It is an element of the named list
a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md)
takes as `structures`, and the element's name is the name
[`ir_struct_ref()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
refers to.

## Examples

``` r
# five people in two teams, people 1 to 3 starting in team 1
structures <- list(teams = partition_decl(5, 2, start = c(1, 1, 1, 2, 2)))
```
