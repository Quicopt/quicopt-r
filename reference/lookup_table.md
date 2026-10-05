# A table of data indexed by decisions

Sometimes a model needs a number from a table at a position that is not
known yet: the distance between the first and the second stop of a route
whose order the service is still choosing, or the price of an option
that an integer variable picks. An ordinary R vector or matrix cannot be
indexed this way. `lookup_table()` adds the data to the model under a
name, and indexing the result with expressions, such as
[`item_at()`](https://quicopt.github.io/quicopt-r/reference/item_at.md)
or an integer variable, builds an expression whose value is the entry at
the positions the service chooses.

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

  A numeric vector or matrix without `NA`.

- x:

  A lookup table.

- i, j:

  Positions in the table: numbers, or expressions such as
  [`item_at()`](https://quicopt.github.io/quicopt-r/reference/item_at.md).
  `j` only for a table made from a matrix.

## Value

The table, to be indexed with `[`.

`x[i]` and `x[i, j]` return an expression with one element per position.

## Details

A table made from a vector takes one index, and a table made from a
matrix two. Each index may be a number, a vector of numbers, or an
expression.

Unlike indexing an ordinary R matrix, the two indices are paired up
element by element: `km[1:4, 2:5]` is a 4 x 4 block of a matrix `km`,
but for a lookup table `dist`, `dist[1:4, 2:5]` has four elements, the
entries `[1, 2]`, `[2, 3]`, `[3, 4]` and `[4, 5]`. This is what makes
`dist[item_at(1:4, P), item_at(2:5, P)]` the four legs of a five-stop
route.

The result is an ordinary expression: it can be multiplied by a cost,
added up, or averaged with
[`expectation()`](https://quicopt.github.io/quicopt-r/reference/expectation.md).
An index that is not a whole number is rounded, and one outside the
table is moved to the nearest end, so a continuous variable can be used
as an index too.

A model with a lookup table is solved by a search, so its status is
`"heuristic"`. The whole table is sent with the model, so a very large
table makes the request large.

## Examples

``` r
# the distances between five stops along a road
position <- c(0, 3, 1, 4, 2)
m <- model()
dist  <- lookup_table(m, "dist", abs(outer(position, position, "-")))
route <- perm_var(m, "route", 5)
legs  <- dist[item_at(1:4, route), item_at(2:5, route)]    # the four legs of the route
minimize(m, sum(legs))

# the price of one of four options, picked by an integer variable
price  <- lookup_table(m, "price", c(3, 1, 4, 1.5))
choice <- int_var(m, "choice", lower = 1, upper = 4)
price[choice]
#> price[choice]
```
