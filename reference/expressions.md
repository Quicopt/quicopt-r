# quicopt expressions — model arithmetic in plain R

Arithmetic on a model's variables builds an expression rather than
computing a number, and comparing two expressions builds a comparison
rather than answering a logical. The operators are R's own —
`+ - * / ^`, `sqrt`, `exp`, `log`, `sin`, `cos`, `abs`, `max`, `min`,
`sum`, `prod`, `mean` — dispatched through the `Ops`, `Math` and
`Summary` group generics, so a model reads as ordinary R code.

## Details

Expressions are vectors, like everything in R: a variable declared with
`n = 10` has length 10, arithmetic is elementwise, `x[3]` indexes,
[`c()`](https://rdrr.io/r/base/c.html) concatenates, and `sum(x)` folds.
So do [`prod()`](https://rdrr.io/r/base/prod.html),
[`max()`](https://rdrr.io/r/base/Extremes.html),
[`min()`](https://rdrr.io/r/base/Extremes.html) and
[`mean()`](https://rdrr.io/r/base/mean.html): they fold every element of
every argument into one, as they do on numeric vectors (`max(x, 0)` is
the largest of all elements of `x` and 0; there is no elementwise
`pmax`). [`mean()`](https://rdrr.io/r/base/mean.html) is the mean over
the elements; the mean over the scenarios is
[`expectation()`](https://quicopt.github.io/quicopt-r/reference/expectation.md).
Lengths must match exactly or be 1 (a scalar broadcasts); anything else
is an error — a model is no place for silent recycling.

A comparison goes one of three ways:
[`add()`](https://quicopt.github.io/quicopt-r/reference/add.md) makes it
a constraint,
[`prob()`](https://quicopt.github.io/quicopt-r/reference/prob.md)
measures how often it holds across scenarios, and
[`holds()`](https://quicopt.github.io/quicopt-r/reference/holds.md)
makes it a 0/1 expression.
[`add()`](https://quicopt.github.io/quicopt-r/reference/add.md) and
[`prob()`](https://quicopt.github.io/quicopt-r/reference/prob.md) take
`<=`, `>=` and
([`add()`](https://quicopt.github.io/quicopt-r/reference/add.md) only)
`==`;
[`holds()`](https://quicopt.github.io/quicopt-r/reference/holds.md)
takes all six.

An operator the service does not support raises at the point of use
(`round`, `%%`, `log` with a base). In a model with no random variable,
[`max()`](https://rdrr.io/r/base/Extremes.html),
[`min()`](https://rdrr.io/r/base/Extremes.html) and
[`holds()`](https://quicopt.github.io/quicopt-r/reference/holds.md) make
the problem combinatorial, and the service then expects integer
variables with finite bounds; with a random variable anywhere in the
model there is no such restriction.

One caveat comes with `==` building a comparison:
[`unique()`](https://rdrr.io/r/base/unique.html) still works on these
objects, but `%in%` and [`match()`](https://rdrr.io/r/base/match.html)
silently answer as if no two were equal — compare identity with
[`identical()`](https://rdrr.io/r/base/identical.html) instead.
