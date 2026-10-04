# A table of numbers read at positions the solver decides

Data that depends on a decision cannot be indexed with it in plain R:
`dist[item_at(1, tour), item_at(2, tour)]` has to be looked up after the
solver has chosen the order. A lookup table is such data, declared in
the model under a name, and indexing it with model expressions builds
the lookup as an expression: a vector table takes one index, a matrix
table two, and either index may be a number, a vector of numbers, or an
expression such as
[`item_at()`](https://quicopt.github.io/quicopt-r/reference/item_at.md)
or an integer variable. The indexing is vectorized, so
`dist[item_at(1:4, P), item_at(2:5, P)]` is the four legs of a five-stop
round.

## Usage

``` r
lookup_table(m, name, values)

# S3 method for class 'quicopt_table'
x[i, j]
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- name:

  The table's name, unique within the model.

- values:

  A numeric vector or matrix, with no `NA`.

- x:

  A lookup table.

- i, j:

  Positions: numbers, or model expressions such as
  [`item_at()`](https://quicopt.github.io/quicopt-r/reference/item_at.md);
  `j` only for a matrix table.

## Value

The table's handle; `m$<name>` retrieves it too.

`x[i]` and `x[i, j]` return an expression, one element per position.

## Details

The lookup is an ordinary expression: multiply it by a cost, sum it, put
it under an
[`expectation()`](https://quicopt.github.io/quicopt-r/reference/expectation.md).
Its value is the table entry at the chosen positions; an index that is
not a whole number in range is rounded and clamped into the table, so a
continuous variable may index a table too.

A lookup makes the model one that is solved by search, as a permutation
or a random variable does. The table travels with the model, one entry
per cell, so a very large table makes for a large request.

## Examples

``` r
m <- model()
where <- c(0, 3, 1, 4, 2)
dist <- lookup_table(m, "dist", abs(outer(where, where, "-")))
tour <- perm_var(m, "tour", 5)
leg <- dist[item_at(1:4, tour), item_at(2:5, tour)]     # the four legs
minimize(m, sum(leg))

# a cost per option, chosen through an integer variable
cost <- lookup_table(m, "cost", c(3, 1, 4, 1.5))
choice <- int_var(m, "choice", 1, 4)
cost[choice]
#> cost[choice]
```
