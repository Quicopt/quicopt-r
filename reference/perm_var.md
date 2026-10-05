# Declare an order as a decision

Some decisions are an arrangement: the order in which a courier visits
its stops, the order of jobs on a machine, which department moves into
which office. `perm_var()` declares such a decision, a *permutation*.

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

  The arrangement the service's search starts from: `start[i]` is the
  slot of item `i`, so `start` contains each of the numbers 1 to `n`
  once. Left `NULL`, item `i` starts in slot `i`.

## Value

The permutation, for use with
[`item_at()`](https://quicopt.github.io/quicopt-r/reference/item_at.md),
[`slot_of()`](https://quicopt.github.io/quicopt-r/reference/item_at.md)
and
[`precede()`](https://quicopt.github.io/quicopt-r/reference/precede.md).

`add_perm_var()` returns the model, invisibly.

## Items and slots

A permutation of size `n` arranges `n` things, called *items*, in `n`
numbered places, called *slots*, with exactly one item in each slot.
Items and slots are both numbered from 1 to `n`. What they stand for
depends on the problem:

- for a route, the items are the stops and the slots are the visits:
  slot 1 is the first stop visited, slot 2 the second, and so on;

- for a machine, the items are the jobs and the slots are the positions
  in the queue;

- for an office plan, the items are the departments and the slots are
  the offices.

[`item_at()`](https://quicopt.github.io/quicopt-r/reference/item_at.md)
gives the item in a slot, and
[`slot_of()`](https://quicopt.github.io/quicopt-r/reference/item_at.md)
the slot of an item. Both are expressions whose values the service
chooses, like the value of a decision variable. Data that depends on the
arrangement, such as the distance between consecutive stops, is read
from a
[`lookup_table()`](https://quicopt.github.io/quicopt-r/reference/lookup_table.md):
`dist[item_at(1:4, route), item_at(2:5, route)]` is the length of each
of the four legs of a five-stop route.

[`precede()`](https://quicopt.github.io/quicopt-r/reference/precede.md)
requires one item to be in an earlier slot than another, such as a
pickup before its delivery.

## The answer

For each permutation, the result of
[`solve()`](https://rdrr.io/r/base/solve.html) holds both directions
under `res$structures$<name>`: `item_at`, the item in each slot (for a
route, the stops in the order they are visited), and `slot_of`, the slot
of each item.
[`set_start()`](https://quicopt.github.io/quicopt-r/reference/set_start.md),
[`evaluate()`](https://quicopt.github.io/quicopt-r/reference/evaluate.md)
and
[`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md)
take the arrangement from a result too.

A model with a permutation is solved by a search, so its status is
`"heuristic"`. Permutations can be combined with random variables, for
example a route whose travel times are uncertain, minimized in
[`expectation()`](https://quicopt.github.io/quicopt-r/reference/expectation.md).
[`vignette("permutations", package = "quicopt")`](https://quicopt.github.io/quicopt-r/articles/permutations.md)
works through two examples.

`add_perm_var()` declares the permutation in the same way but returns
the model, for use in a pipe; `m$name` then retrieves the permutation.

## Examples

``` r
# Five stops along a road. Find the shortest route through all of them
# that visits stop 4 before stop 1.
position <- c(0, 3, 1, 4, 2)                      # km along the road, stops 1 to 5
m <- model()
dist  <- lookup_table(m, "dist", abs(outer(position, position, "-")))
route <- perm_var(m, "route", 5)
precede(route, 4, 1)                              # stop 4 is visited before stop 1
minimize(m, sum(dist[item_at(1:4, route), item_at(2:5, route)]))
if (FALSE) { # \dontrun{
res <- solve(m)
res$structures$route$item_at                      # the stops in the order visited
} # }
```
