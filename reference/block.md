# Group the variables of a subproblem

Many models are made of small subproblems of the same kind: one per
customer to supply, per project to staff, per product to make. Each has
a few variables and constraints of its own, such as the customer's
demand, and the subproblems interact mostly through the objective, for
example through a warehouse's opening fee that several customers share.

## Usage

``` r
block(m, name, vars)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- name:

  The block's name, unique among the model's blocks.

- vars:

  The block's variables: a decision variable, elements of one
  (`x[1:3]`), or several combined with
  [`c()`](https://rdrr.io/r/base/c.html).

## Value

The model, invisibly.

## Details

`block()` declares the variables of one such subproblem. A constraint
whose variables all belong to one block, such as one customer's demand,
is then that block's own constraint, and it holds in every solution the
service returns. Declaring the blocks of a model changes nothing else
about it. A constraint that involves variables of several blocks, such
as a person's working hours over several projects, holds in a solution
that is reported feasible.

A variable can be in at most one block, and a variable in a block needs
finite bounds.

## Examples

``` r
# Three warehouses supply three customers. Each delivery is none or 10 to 25
# units and costs 5 plus a price per unit; a warehouse that delivers anything
# pays its opening fee.
demand  <- c(40, 30, 20)                                # units, customers 1 to 3
price   <- rbind(c(1, 3, 4), c(3, 1, 3), c(4, 2, 1))    # per unit, price[warehouse, customer]
opening <- c(60, 50, 40)                                # fee of warehouses 1 to 3
m <- model()
ship <- int_var(m, "ship", lower = 10, upper = 25, n = 9, semi = TRUE)   # none, or 10 to 25 units
to   <- function(c) ship[3 * (c - 1) + 1:3]             # to customer c, from warehouses 1 to 3
from <- function(w) ship[w + c(0, 3, 6)]                # from warehouse w, to customers 1 to 3
for (c in 1:3) {
  block(m, paste0("customer_", c), to(c))
  add(m, sum(to(c)) >= demand[c])
}
sent <- c(sum(from(1)), sum(from(2)), sum(from(3)))     # units leaving each warehouse
minimize(m, sum(as.vector(price) * ship)                # price per unit
            + 5 * sum(active(ship))                     # 5 per delivery
            + sum(opening * holds(sent >= 1)))          # a warehouse that ships pays its fee
if (FALSE) { # \dontrun{
res <- solve(m)
res$objective                                           # 300
res$solution                                            # warehouse 2 delivers nothing
#  ship[1] ship[2] ship[3] ship[4] ship[5] ship[6] ship[7] ship[8] ship[9]
#       25       0      15      10       0      20       0       0      20
} # }
```
