# A random variable given as a fixed scenario column

Exactly `scenarios` values, one per scenario. Several empirical columns
are read at the same scenario index, so columns observed jointly stay
correlated — which is how a joint distribution is expressed.

## Usage

``` r
empirical(data)
```

## Arguments

- data:

  A numeric vector, one value per scenario.

## Value

An object of class `quicopt_empirical`: a list with the fields
`kind = "empirical"` and `data`, the column as a numeric vector. It
declares one random variable by its observed values, and is an entry of
the named list a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md)
takes as `sources`.
