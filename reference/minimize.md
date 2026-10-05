# Set the objective

The objective is the single number that the service makes as small
(`minimize()`) or as large (`maximize()`) as possible. Calling either
function again replaces the objective. An expression with several
elements has to be combined into one first, for example with
[`sum()`](https://rdrr.io/r/base/sum.html). A model without an objective
asks for any solution that meets the constraints.

## Usage

``` r
minimize(m, e)

maximize(m, e)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- e:

  The expression to minimize or maximize.

## Value

The model, invisibly.

## Details

In a model with random variables, the objective has to be one number,
not one per scenario: summarize it first, for example with
[`expectation()`](https://quicopt.github.io/quicopt-r/reference/expectation.md)
(the
[stochastic](https://quicopt.github.io/quicopt-r/reference/stochastic.md)
help page lists all the summaries).

## Examples

``` r
m <- model()
tables <- num_var(m, "tables", lower = 0)
chairs <- num_var(m, "chairs", lower = 0)
maximize(m, 50 * tables + 20 * chairs)    # the profit
```
