# Turn observed history into a model's uncertainty

Every chosen column of a data frame becomes an
[`empirical()`](https://quicopt.github.io/quicopt-r/reference/empirical.md)
random variable named after the column, and the number of rows becomes
the model's scenario count. All columns are read at the same scenario
index, so rows observed jointly stay jointly distributed — correlation
in the data survives into the model.

## Usage

``` r
set_empirical(m, data, cols = NULL)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- data:

  A data frame of jointly observed rows.

- cols:

  Which columns to use (default: all of them).

## Value

The model, invisibly. The handles are retrievable as `m$<column>`.

## Details

A non-numeric column is an error, not a skip: a silently dropped column
would leave a model that solves fine and answers the wrong question.
Select with `cols` when the frame carries more than its uncertainty.
