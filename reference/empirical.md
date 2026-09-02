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
