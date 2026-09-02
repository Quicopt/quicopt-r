# The expected value over the scenarios

Minimizing an expectation optimizes the average case and says nothing
about the bad ones; use
[`cvar()`](https://quicopt.github.io/quicopt-r/reference/cvar.md) when
the bad ones are what matter.

## Usage

``` r
expectation(x)
```

## Arguments

- x:

  A model expression.

## Value

An expression of the same length.

## Details

`x` is any expression containing a random variable. The result is
deterministic, and can be used anywhere a number can. Applied to a
vector expression, it aggregates each element.
