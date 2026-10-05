# A random variable given by a sample

`empirical(x)` describes a random variable by a sample of its values,
one per scenario, instead of by a distribution. Pass it to
[`rand_var()`](https://quicopt.github.io/quicopt-r/reference/rand_var.md),
as in `rand_var(m, "demand", empirical(x))`. The length of the sample
sets the number of scenarios.

## Usage

``` r
empirical(data)
```

## Arguments

- data:

  The sample: a numeric vector without `NA`, one value per scenario.

## Value

An object of class `quicopt_empirical`, for
[`rand_var()`](https://quicopt.github.io/quicopt-r/reference/rand_var.md)
or
[`set_distribution()`](https://quicopt.github.io/quicopt-r/reference/set_distribution.md).
It can also be an element of the `sources` of a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md).

## Details

This is how to use a distribution the package has no function for: draw
a sample in R, for example with
[`rlnorm()`](https://rdrr.io/r/stats/Lognormal.html), and pass it to
`empirical()`.

The samples of a model are read side by side, the `i`-th value of each
in scenario `i`, so values observed together stay together.
[`set_empirical()`](https://quicopt.github.io/quicopt-r/reference/set_empirical.md)
does this for every column of a data frame.

A sample is fixed data. If it was drawn in R, R's
[`set.seed()`](https://rdrr.io/r/base/Random.html) determines it, not
the model's seed, and
[`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md)
does not draw it again.

## Examples

``` r
set.seed(1)
m <- model()
demand <- rand_var(m, "demand", empirical(rlnorm(500, log(100), 0.3)))   # lognormal
```
