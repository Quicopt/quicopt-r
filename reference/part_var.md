# Divide items into groups as a decision

Some decisions put things into groups: people into teams, jobs onto
machines, parcels into vans. `part_var()` declares such a decision, a
*partition*: each of `n_items` items goes into exactly one of `n_parts`
groups, called *parts*. Items are numbered from 1 to `n_items` and parts
from 1 to `n_parts`. A part may stay empty.

## Usage

``` r
part_var(m, name, n_items, n_parts, start = NULL)

add_part_var(m, name, n_items, n_parts, start = NULL)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- name:

  The partition's name, unique within the model.

- n_items:

  How many items; at least 1.

- n_parts:

  How many parts; at least 2.

- start:

  The division the service's search starts from: `start[i]` is the part
  of item `i`, a whole number from 1 to `n_parts`. Left `NULL`, the
  service chooses one.

## Value

The partition, for use with
[`part_of()`](https://quicopt.github.io/quicopt-r/reference/part_of.md)
and
[`size_of()`](https://quicopt.github.io/quicopt-r/reference/part_of.md).

`add_part_var()` returns the model, invisibly.

## Details

[`part_of()`](https://quicopt.github.io/quicopt-r/reference/part_of.md)
gives the part an item is in, and
[`size_of()`](https://quicopt.github.io/quicopt-r/reference/part_of.md)
how many items a part holds. Both are expressions whose values the
service chooses, like the value of a decision variable. A requirement on
the sizes, such as teams of two and three, is an ordinary constraint:
`add(m, size_of(1, teams) == 2)`. Data that depends on an item's part,
such as what a person costs in each team, is read from a
[`lookup_table()`](https://quicopt.github.io/quicopt-r/reference/lookup_table.md):
`cost[1:5, part_of(1:5, teams)]`. Whether an item is in a given part is
`holds(part_of(i, teams) == t)`.

## The answer

For each partition, the result of
[`solve()`](https://rdrr.io/r/base/solve.html) holds
`res$structures$<name>` with two integer vectors: `part_of`, the part of
each item, and `size_of`, the number of items in each part.
[`set_start()`](https://quicopt.github.io/quicopt-r/reference/set_start.md),
[`evaluate()`](https://quicopt.github.io/quicopt-r/reference/evaluate.md)
and
[`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md)
take the division from a result too.

A model with a partition is solved by a search, so its status is
`"heuristic"`.

`add_part_var()` declares the partition in the same way but returns the
model, for use in a pipe; `m$name` then retrieves the partition.

## Examples

``` r
# Six players of strengths 7, 5, 4, 3, 2 and 1 form a team of four and a
# team of two, as evenly matched as possible.
strength <- c(7, 5, 4, 3, 2, 1)                         # of players 1 to 6
m <- model()
teams <- part_var(m, "teams", 6, 2)                     # 6 players into teams 1 and 2
in_team <- function(t) holds(part_of(1:6, teams) == t)  # 1 for each player in team t
add(m, size_of(1, teams) == 4)                          # team 1 has four players
minimize(m, max(sum(strength * in_team(1)), sum(strength * in_team(2))))
if (FALSE) { # \dontrun{
res <- solve(m)
res$objective                                           # 11
res$structures$teams$part_of                            # 2 1 2 1 1 1: players 1 and 3 form team 2
res$structures$teams$size_of                            # 4 2
} # }
```
