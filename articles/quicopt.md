# Get started

An optimization problem has three parts:

- the **decisions**: quantities you get to choose, such as how much to
  produce or which jobs to accept;
- the **objective**: one number that measures how good a choice is, such
  as profit or cost, to be made as large or as small as possible;
- the **constraints**: conditions every acceptable choice has to meet,
  such as a budget or the hours in a day.

With quicopt you write these three parts in R, and the Quicopt service
finds the best choice. Nothing is solved on your machine: the model is
sent to the service, and the answer comes back as an R list.

## A first model

A workshop makes tables and chairs. A table earns a profit of 50 and
takes 3 hours of carpentry; a chair earns 20 and takes 1 hour. This week
there are 41 hours of carpentry available, and wood for 18 pieces of
furniture in total. How many tables and how many chairs should the
workshop make?

``` r

library(quicopt)

m <- model()
tables <- num_var(m, "tables", lower = 0)
chairs <- num_var(m, "chairs", lower = 0)

maximize(m, 50 * tables + 20 * chairs)    # the profit
add(m, 3 * tables + chairs <= 41)         # carpentry hours
add(m, tables + chairs <= 18)             # wood

res <- solve(m)
res$solution
#> tables chairs 
#>   11.5    6.5
res$objective
#> [1] 705
```

Line by line:

- [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md)
  creates an empty model. Everything else adds to it.
- [`num_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)
  declares a decision: a number the service will choose. Here each must
  be at least 0, since the workshop cannot make a negative number of
  tables. The name in quotes is how the variable is labelled in the
  answer; the R object it returns, `tables`, is how you refer to it in
  the rest of the model.
- [`maximize()`](https://quicopt.github.io/quicopt-r/reference/minimize.md)
  sets the objective. `50 * tables + 20 * chairs` does not compute a
  number, since the values are not known yet. It builds an expression
  that the service evaluates for every choice it considers.
- [`add()`](https://quicopt.github.io/quicopt-r/reference/add.md) adds a
  constraint. A comparison such as `tables + chairs <= 18` is a
  requirement here, not a test that returns `TRUE` or `FALSE`.
- [`solve()`](https://rdrr.io/r/base/solve.html) sends the model to the
  service and returns its answer.

The best plan is 11.5 tables and 6.5 chairs, for a profit of 705. It
uses all 41 hours (3 × 11.5 + 6.5) and all the wood (11.5 + 6.5 = 18).
Making more of either would break one of the two limits.

## Whole numbers

Half a table is not for sale. A decision that must be a whole number is
declared with
[`int_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)
instead of
[`num_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md):

``` r

m <- model()
tables <- int_var(m, "tables", lower = 0)
chairs <- int_var(m, "chairs", lower = 0)

maximize(m, 50 * tables + 20 * chairs)
add(m, 3 * tables + chairs <= 41)
add(m, tables + chairs <= 18)

res <- solve(m)
res$solution
#> tables chairs 
#>     12      5
res$objective
#> [1] 700
```

Twelve tables and five chairs, for 700. This is not what rounding the
first answer gives: rounding 11.5 and 6.5 up breaks both limits, and
rounding them down to 11 and 6 earns only 670. When a decision has to be
whole, say so in the model, and the service will find the best
whole-number plan.

## Many decisions at once

Models often have many decisions of the same kind. A contractor is
offered six jobs for tomorrow. Each pays a fee and takes a known number
of hours, and the working day has 12 hours. Which jobs should the
contractor accept?

``` r

pay   <- c(9, 6, 7, 4, 3, 2)      # what each job pays
hours <- c(6, 5, 4, 3, 3, 2)      # how long each job takes

m <- model()
take <- bin_var(m, "take", n = 6)

maximize(m, sum(pay * take))
add(m, sum(hours * take) <= 12)

res <- solve(m)
res$solution
#> take[1] take[2] take[3] take[4] take[5] take[6] 
#>       1       0       1       0       0       1
```

[`bin_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)
declares a yes-or-no decision: a variable that is either 0 or 1. With
`n = 6` it declares six of them at once, one per job, and `take` behaves
like an R vector of length 6. `pay * take` multiplies element by
element, as it would for two numeric vectors, and
[`sum()`](https://rdrr.io/r/base/sum.html) adds the six products up. So
`sum(pay * take)` is the pay of the accepted jobs, and
`sum(hours * take)` is the hours they take.

In the answer, the six decisions are labelled `take[1]` to `take[6]`. To
see which jobs were accepted:

``` r

which(res$solution == 1)
#> take[1] take[3] take[6] 
#>       1       3       6
res$objective
#> [1] 18
```

Jobs 1, 3 and 6 take 6 + 4 + 2 = 12 hours and pay 18. No other set of
jobs that fits into the day pays more.

## Reading the answer

[`solve()`](https://rdrr.io/r/base/solve.html) returns a list. Besides
`solution` and `objective`, two of its parts tell you what kind of
answer you have:

``` r

res$status
#> [1] "optimal"
res$feasible
#> [1] TRUE
```

`feasible` says whether the solution meets every constraint. `status`
says how it was found: `"optimal"` means the service has proved that no
better solution exists. Some models, those with uncertain data or with
an order to decide (the other two articles), are solved by a search that
returns the best solution it finds, without that proof. Their status is
`"heuristic"`.

Printing `res` shows a summary prepared by the service.

## What you can write in an expression

Arithmetic on decision variables builds an *expression*: a description
of a quantity that the service can evaluate for any values of the
variables. You write it as ordinary R code, with `+`, `-`, `*`, `/` and
`^`, the functions [`abs()`](https://rdrr.io/r/base/MathFun.html),
[`sqrt()`](https://rdrr.io/r/base/MathFun.html),
[`exp()`](https://rdrr.io/r/base/Log.html),
[`log()`](https://rdrr.io/r/base/Log.html),
[`sin()`](https://rdrr.io/r/base/Trig.html) and
[`cos()`](https://rdrr.io/r/base/Trig.html), and
[`sum()`](https://rdrr.io/r/base/sum.html),
[`prod()`](https://rdrr.io/r/base/prod.html),
[`max()`](https://rdrr.io/r/base/Extremes.html),
[`min()`](https://rdrr.io/r/base/Extremes.html) and
[`mean()`](https://rdrr.io/r/base/mean.html). Expressions need not be
linear: `tables^2` or `sqrt(chairs)` is allowed in an objective or a
constraint.

Printing an expression shows what was built:

``` r

50 * tables + 20 * chairs
#> ((50 * tables) + (20 * chairs))
```

A few things behave differently from arithmetic on numbers, and
[`?expressions`](https://quicopt.github.io/quicopt-r/reference/expressions.md)
lists them. The one to know from the start: `max(x, 0)` is the largest
of *all* the elements of `x` and 0, as it is for a numeric vector. There
is no elementwise [`pmax()`](https://rdrr.io/r/base/Extremes.html).

## Where the solving happens

[`solve()`](https://rdrr.io/r/base/solve.html) sends the model over the
internet to the Quicopt service. The first time you call it in an R
session without an API key, the service issues a free key, and quicopt
keeps it for the rest of the session. If you have a key of your own,
pass it as `solve(m, api_key = ...)`.

A large model can take a while to solve.
[`submit()`](https://quicopt.github.io/quicopt-r/reference/submit.md)
sends it without waiting and returns a job, and
[`job_result()`](https://quicopt.github.io/quicopt-r/reference/job_status.md)
collects the answer when it is ready.

## Writing a model as a pipe

Every function that changes a model also returns the model, so a model
can be written as a pipe. In this style, variables are declared with
[`add_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)
and retrieved by name with `$`:

``` r

m <- model() |>
  add_var("tables", lower = 0, domain = "int") |>
  add_var("chairs", lower = 0, domain = "int")

m |>
  maximize(50 * m$tables + 20 * m$chairs) |>
  add(3 * m$tables + m$chairs <= 41) |>
  add(m$tables + m$chairs <= 18)
```

One thing differs from most pipes in R: each step changes the model `m`
itself instead of returning a modified copy. After these two pipes, `m`
holds both variables, the objective and both constraints, ready for
`solve(m)`.

## Where to go next

- [`vignette("stochastic", package = "quicopt")`](https://quicopt.github.io/quicopt-r/articles/stochastic.md),
  *Deciding before the data arrives*: models in which some of the data,
  such as demand or travel times, is uncertain.
- [`vignette("permutations", package = "quicopt")`](https://quicopt.github.io/quicopt-r/articles/permutations.md),
  *Choosing an order*: decisions that are a sequence or an assignment,
  such as a delivery route.
- [`help(package = "quicopt")`](https://quicopt.github.io/quicopt-r/reference)
  lists every function.
