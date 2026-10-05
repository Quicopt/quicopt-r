# Use observed data as a model's uncertainty

Turns the columns of a data frame into random variables: each column
becomes one, named after the column, and each row becomes one scenario.
The columns are read row by row, so values observed together stay
together, and any correlation between the columns carries over into the
model. No distribution has to be chosen or fitted.

## Usage

``` r
set_empirical(m, data, cols = NULL)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- data:

  A data frame with one row per observation.

- cols:

  The names of the columns to use. Left `NULL`, all of them.

## Value

The model, invisibly.

## Details

The random variables are not returned; retrieve them by name, as
`m$demand`. The number of scenarios is set to the number of rows.

Every column used must be numeric; a column that is not is an error
rather than being skipped. Use `cols` to select the columns that
describe the uncertainty when the data frame holds others too.

## Examples

``` r
history <- data.frame(demand = c(96, 104, 121, 88, 110),
                      price  = c(12.1, 11.8, 11.2, 12.5, 11.6))
m <- model()
stock <- num_var(m, "stock", lower = 0, upper = 200)
set_empirical(m, history)
maximize(m, expectation(m$price * min(m$demand, stock)) - 3 * stock)
```
