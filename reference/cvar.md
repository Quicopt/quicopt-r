# The conditional value at risk at level `alpha`

The mean of `x` over its worst `1 - alpha` fraction of scenarios — at
`alpha = 0.95`, the average of the worst 5%. Minimizing it optimizes the
tail instead of the average, and is the usual way to ask for a solution
that holds up in bad scenarios rather than merely on average.

## Usage

``` r
cvar(x, alpha)
```

## Arguments

- x:

  A model expression.

- alpha:

  The tail level, a plain number strictly between 0 and 1; it cannot
  depend on a decision.

## Value

An expression of the same length.
