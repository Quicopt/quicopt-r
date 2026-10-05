# Expressions: arithmetic on variables

The values of decision variables and random variables are not known when
you write a model, so arithmetic on them cannot compute a number.
Instead it builds an *expression*: a description of a quantity, which
the service evaluates for every solution it considers. Expressions are
written as ordinary R code, with these operators and functions:

## Details

- `+`, `-`, `*`, `/` and `^`;

- [`abs()`](https://rdrr.io/r/base/MathFun.html),
  [`sqrt()`](https://rdrr.io/r/base/MathFun.html),
  [`exp()`](https://rdrr.io/r/base/Log.html),
  [`log()`](https://rdrr.io/r/base/Log.html),
  [`sin()`](https://rdrr.io/r/base/Trig.html) and
  [`cos()`](https://rdrr.io/r/base/Trig.html);

- [`sum()`](https://rdrr.io/r/base/sum.html),
  [`prod()`](https://rdrr.io/r/base/prod.html),
  [`max()`](https://rdrr.io/r/base/Extremes.html),
  [`min()`](https://rdrr.io/r/base/Extremes.html) and
  [`mean()`](https://rdrr.io/r/base/mean.html).

Expressions need not be linear. Printing an expression shows what was
built.

## Expressions are vectors

A variable declared with `n = 10` is an expression of length 10, and
expressions behave like numeric vectors in most ways: arithmetic works
element by element, `x[3]` picks one element,
[`c()`](https://rdrr.io/r/base/c.html) combines expressions and numbers
into a longer expression, and
[`length()`](https://rdrr.io/r/base/length.html) counts the elements.

There are two differences. First, the two sides of an arithmetic
operation must have the same length, or one of them length 1. R would
recycle the shorter vector, which in a model is almost always a mistake,
so here it is an error. Second,
[`sum()`](https://rdrr.io/r/base/sum.html),
[`prod()`](https://rdrr.io/r/base/prod.html),
[`max()`](https://rdrr.io/r/base/Extremes.html),
[`min()`](https://rdrr.io/r/base/Extremes.html) and
[`mean()`](https://rdrr.io/r/base/mean.html) combine all the elements of
all their arguments into one, as they do for numbers: `max(x, 0)` is the
largest of all the elements of `x` and 0, not an element-by-element
maximum, and there is no
[`pmax()`](https://rdrr.io/r/base/Extremes.html). `mean(x)` is the mean
over the elements of `x`; the mean over the scenarios is
[`expectation()`](https://quicopt.github.io/quicopt-r/reference/expectation.md).

## Comparisons

Comparing two expressions, as in `x <= y`, builds a comparison rather
than returning `TRUE` or `FALSE`. What the comparison means depends on
the function it is given to:
[`add()`](https://quicopt.github.io/quicopt-r/reference/add.md) makes it
a constraint,
[`prob()`](https://quicopt.github.io/quicopt-r/reference/prob.md)
measures how often it holds across the scenarios, and
[`holds()`](https://quicopt.github.io/quicopt-r/reference/holds.md)
turns it into an expression that is 1 where it holds and 0 where it does
not. [`add()`](https://quicopt.github.io/quicopt-r/reference/add.md) and
[`prob()`](https://quicopt.github.io/quicopt-r/reference/prob.md) accept
`<=` and `>=`, and
[`add()`](https://quicopt.github.io/quicopt-r/reference/add.md) also
`==`;
[`holds()`](https://quicopt.github.io/quicopt-r/reference/holds.md)
accepts all six comparisons.

## What does not work

Functions not listed above, such as
[`round()`](https://rdrr.io/r/base/Round.html), `%%` and
[`log()`](https://rdrr.io/r/base/Log.html) with a base, stop with an
error. Base R functions that are not written for expressions do not work
on them either: use
[`variance()`](https://quicopt.github.io/quicopt-r/reference/variance.md)
instead of [`var()`](https://rdrr.io/r/stats/cor.html),
[`holds()`](https://quicopt.github.io/quicopt-r/reference/holds.md)
instead of [`ifelse()`](https://rdrr.io/r/base/ifelse.html), and
[`identical()`](https://rdrr.io/r/base/identical.html) instead of `%in%`
or [`match()`](https://rdrr.io/r/base/match.html) to check whether two
expressions are the same.

In a model without random variables,
[`max()`](https://rdrr.io/r/base/Extremes.html),
[`min()`](https://rdrr.io/r/base/Extremes.html) and
[`holds()`](https://quicopt.github.io/quicopt-r/reference/holds.md)
limit the kind of model the service accepts: every variable must then be
an integer or a binary variable, with finite bounds. In a model with
random variables there is no such limit.

## Examples

``` r
m <- model()
tables <- num_var(m, "tables", lower = 0)
chairs <- num_var(m, "chairs", lower = 0)
50 * tables + 20 * chairs                 # an expression, not a number
#> ((50 * tables) + (20 * chairs))
tables + chairs <= 18                     # a comparison, not TRUE or FALSE
#> (tables + chairs) <= 18 

x <- num_var(m, "x", lower = 0, upper = 1, n = 3)
2 * x                                     # element by element
#> [1] (2 * x[1])
#> [2] (2 * x[2])
#> [3] (2 * x[3])
sum(x)                                    # one expression
#> (x[1] + x[2] + x[3])
max(x, 0.5)                               # the largest of all four
#> max(max(max(x[1], x[2]), x[3]), 0.5)
```
