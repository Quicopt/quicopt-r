# The part of an item, and the size of a part

For a partition `P` from
[`part_var()`](https://quicopt.github.io/quicopt-r/reference/part_var.md),
`part_of(item, P)` is the part an item is in, and `size_of(part, P)` is
how many items a part holds. For people divided into teams,
`part_of(3, teams)` is the team of person 3, and `size_of(1, teams)` is
the number of people in team 1.

## Usage

``` r
part_of(item, P)

size_of(part, P)
```

## Arguments

- item:

  Items: whole numbers from 1 to the number of items.

- P:

  A partition from
  [`part_var()`](https://quicopt.github.io/quicopt-r/reference/part_var.md).

- part:

  Parts: whole numbers from 1 to the number of parts.

## Value

An expression with one element per element of the first argument: for
`part_of()` each a whole number from 1 to the number of parts, for
`size_of()` each a whole number from 0 to the number of items.

## Details

The result is an expression whose value the service chooses, like the
value of a decision variable. To read data that depends on an item's
part, index a
[`lookup_table()`](https://quicopt.github.io/quicopt-r/reference/lookup_table.md)
with `part_of()`.

The first argument is a plain number, or a vector of numbers, and both
functions return one element per number: `part_of(1:5, P)` is the parts
of the first five items, an expression of length 5.

## Examples

``` r
m <- model()
teams <- part_var(m, "teams", 5, 2)
part_of(3, teams)                   # the team of person 3
#> part_of(3, teams)
size_of(1, teams)                   # how many people are in team 1
#> size_of(1, teams)
part_of(1:5, teams)                 # everyone's team
#> [1] part_of(1, teams)
#> [2] part_of(2, teams)
#> [3] part_of(3, teams)
#> [4] part_of(4, teams)
#> [5] part_of(5, teams)
```
