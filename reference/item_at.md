# The item in a slot, and the slot of an item

For a permutation `P` from
[`perm_var()`](https://quicopt.github.io/quicopt-r/reference/perm_var.md),
`item_at(slot, P)` is the item in a slot, and `slot_of(item, P)` is the
slot that an item is in. For a route whose items are stops and whose
slots are the visits, `item_at(1, route)` is the first stop visited, and
`slot_of(3, route)` is when stop 3 is visited.

## Usage

``` r
item_at(slot, P)

slot_of(item, P)
```

## Arguments

- slot, item:

  Whole numbers from 1 to the size of the permutation.

- P:

  A permutation from
  [`perm_var()`](https://quicopt.github.io/quicopt-r/reference/perm_var.md).

## Value

An expression with one element per element of the first argument, each a
whole number from 1 to the size of the permutation.

## Details

The result is an expression whose value the service chooses, like the
value of a decision variable. To use it to read data, such as the
distance between two stops, index a
[`lookup_table()`](https://quicopt.github.io/quicopt-r/reference/lookup_table.md)
with it.

The first argument is a plain number, or a vector of numbers, and both
functions return one element per number: `item_at(1:4, P)` is the items
in the first four slots, an expression of length 4.

## Examples

``` r
m <- model()
route <- perm_var(m, "route", 5)
item_at(1, route)                   # the first stop visited
#> item_at(1, route)
slot_of(3, route)                   # when stop 3 is visited
#> slot_of(3, route)
item_at(1:4, route)                 # the first four stops visited
#> [1] item_at(1, route)
#> [2] item_at(2, route)
#> [3] item_at(3, route)
#> [4] item_at(4, route)
```
