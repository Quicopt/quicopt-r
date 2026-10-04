# Read a permutation: the item in a slot, the slot of an item

`item_at(slot, P)` is the item that sits in `slot`, and
`slot_of(item, P)` the slot that `item` sits in, for a permutation `P`
from
[`perm_var()`](https://quicopt.github.io/quicopt-r/reference/perm_var.md).
Each is an integer expression the service decides, and the two always
agree. Both are vectorized over their first argument: `item_at(1:4, P)`
is the items in the first four slots, as an expression of length 4.

## Usage

``` r
item_at(slot, P)

slot_of(item, P)
```

## Arguments

- slot, item:

  Positions, whole numbers from 1 to the permutation's size.

- P:

  A permutation from
  [`perm_var()`](https://quicopt.github.io/quicopt-r/reference/perm_var.md).

## Value

An integer-valued expression, one element per position.

## Details

The first argument is a plain number, not a decision: it names a
position in one of the two fixed numberings. Data that depends on the
result is read through a
[`lookup_table()`](https://quicopt.github.io/quicopt-r/reference/lookup_table.md):
`dist[item_at(k, P), item_at(k + 1, P)]`.

## Examples

``` r
m <- model()
tour <- perm_var(m, "tour", 5)
item_at(1, tour)                    # the first stop of the tour
#> item_at(1, tour)
slot_of(3, tour)                    # when stop 3 is visited
#> slot_of(3, tour)
item_at(1:4, tour)                  # the first four stops, as a vector
#> [1] item_at(1, tour)
#> [2] item_at(2, tour)
#> [3] item_at(3, tour)
#> [4] item_at(4, tour)
```
