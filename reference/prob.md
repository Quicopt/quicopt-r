# The probability that a comparison holds

The fraction of scenarios in which it does. This is what a chance
constraint is built from:

## Usage

``` r
prob(rel)
```

## Arguments

- rel:

  A comparison built with `<=` or `>=`.

## Value

An expression: a probability between 0 and 1 per compared element.

## Details

    add(m, prob(demand - x <= 0) >= 0.9)

which reads as *demand is met in at least 90% of scenarios*. The line
holds two comparisons, both meaningful: the one inside `prob` is the
event being measured, the outer one is the service level demanded of it.

`rel` is a comparison, `a <= b` or `a >= b`, with at least one side
containing a random variable. An equality is refused: for a continuous
quantity its probability is zero. Elementwise over vector comparisons.
