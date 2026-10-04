# Sequencing and assignment: a permutation as a decision variable

Some decisions are an order or a one-to-one assignment: the sequence of
stops on a round, the order of jobs on a machine, which facility goes to
which location. Written with plain variables, such a decision needs one
binary per (item, slot) pair and a row per item and per slot, and a cost
along the sequence is a product of binaries. A permutation variable says
it directly: `n` items go into `n` slots, one each, and the service
keeps that true by construction while it searches.

## Usage

``` r
perm_var(m, name, n, start = NULL)

add_perm_var(m, name, n, start = NULL)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- name:

  The permutation's name, unique within the model.

- n:

  How many items, and so how many slots; at least 2.

- start:

  Left `NULL`, item `i` starts in slot `i`. Otherwise `start[i]` is the
  slot item `i` starts in: a permutation of `1:n`.

## Value

The permutation's handle; `m$<name>` retrieves it too.

`add_perm_var` returns the model, invisibly.

## Details

There are two fixed numberings, both from 1 to `n`:

- the **items** are the things being arranged, numbered as you listed
  them (the stops, the jobs, the facilities);

- the **slots** are the places they go, numbered in order (the steps of
  the round, the positions in the schedule, the locations).

The permutation links the two, and it is read in both directions.
[`item_at()`](https://quicopt.github.io/quicopt-r/reference/item_at.md)`(slot, P)`
is the item that sits in a slot, and
[`slot_of()`](https://quicopt.github.io/quicopt-r/reference/item_at.md)`(item, P)`
the slot an item sits in; each is an integer expression that the service
decides, usable anywhere a model expression is. Which one a model reads
depends on where its data lives: a distance between consecutive stops of
a round is `dist[item_at(k, P), item_at(k + 1, P)]`, data on the items
read along the slots; the distance between the locations of two
facilities is `dist[slot_of(f, P), slot_of(g, P)]`, data on the slots
read along the items. Both use a
[`lookup_table()`](https://quicopt.github.io/quicopt-r/reference/lookup_table.md),
a table of numbers indexed by expressions.

[`precede()`](https://quicopt.github.io/quicopt-r/reference/precede.md)`(P, a, b)`
requires item `a` to sit in an earlier slot than item `b`, which the
search never violates. A solution reports both views under
`res$structures`, and
[`set_start()`](https://quicopt.github.io/quicopt-r/reference/set_start.md),
[`evaluate()`](https://quicopt.github.io/quicopt-r/reference/evaluate.md)
and
[`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md)
carry a permutation along with the plain variables.

A model with a permutation or a lookup is solved by search, like a model
under uncertainty, and the two combine: a round whose travel times are
random is a permutation inside an
[`expectation()`](https://quicopt.github.io/quicopt-r/reference/expectation.md).

## Examples

``` r
# Five stops on a line, visited along the shortest path, stop 4 before stop 1
m <- model()
where <- c(0, 3, 1, 4, 2)                          # where each stop lies
dist <- lookup_table(m, "dist", abs(outer(where, where, "-")))
tour <- perm_var(m, "tour", 5)                     # item: a stop; slot: a step
precede(tour, 4, 1)
minimize(m, sum(dist[item_at(1:4, tour), item_at(2:5, tour)]))
if (FALSE) { # \dontrun{
res <- solve(m)
res$structures$tour$item_at                        # the stops in visiting order
} # }
```
