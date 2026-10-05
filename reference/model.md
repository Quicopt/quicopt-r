# Create an empty model

A model collects everything the service needs to find the best decision:
the decisions to be made, the objective, the constraints and, when some
of the data is uncertain, the random variables and the number of
scenarios. `model()` creates an empty one, and these functions fill it:

## Usage

``` r
model()
```

## Value

An empty model, an object of class `quicopt_model`.

## Details

- decisions:
  [`num_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md),
  [`int_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md),
  [`bin_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md),
  and
  [`perm_var()`](https://quicopt.github.io/quicopt-r/reference/perm_var.md)
  for an order;

- uncertain data:
  [`rand_var()`](https://quicopt.github.io/quicopt-r/reference/rand_var.md)
  and
  [`set_empirical()`](https://quicopt.github.io/quicopt-r/reference/set_empirical.md);

- the objective:
  [`minimize()`](https://quicopt.github.io/quicopt-r/reference/minimize.md)
  or
  [`maximize()`](https://quicopt.github.io/quicopt-r/reference/minimize.md);

- constraints:
  [`add()`](https://quicopt.github.io/quicopt-r/reference/add.md).

[`solve()`](https://rdrr.io/r/base/solve.html) then sends the model to
the service. `m$name` retrieves a variable declared in `m` by its name,
and printing a model shows a short summary of it.

Each of the functions above changes the model in place and returns it
invisibly, so a model can also be written as a pipe:

    m <- model() |>
      add_var("x", lower = 0, upper = 4)    # m$x retrieves the variable

Unlike most R objects, a model is not copied when it is passed to a
function. After `m2 <- m |> add(m$x <= 3)`, `m` has the constraint too,
and `m2` and `m` are the same model.

## Examples

``` r
m <- model()
tables <- num_var(m, "tables", lower = 0)
chairs <- num_var(m, "chairs", lower = 0)
maximize(m, 50 * tables + 20 * chairs)
add(m, tables + chairs <= 18)
m
#> quicopt model: 2 variables, 1 constraint row(s)
#>   max ((50 * tables) + (20 * chairs))
```
