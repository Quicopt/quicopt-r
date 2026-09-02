# quicopt expressions — model arithmetic in plain R

Arithmetic on a model's variables builds an expression rather than
computing a number, and comparing two expressions builds a constraint
rather than answering a logical. The operators are R's own —
`+ - * / ^`, `sqrt`, `exp`, `log`, `sin`, `cos`, `abs`, `max`, `min`,
`sum`, `prod` — dispatched through the `Ops`, `Math` and `Summary` group
generics, so a model reads as ordinary R code.

## Details

Expressions are vectors, like everything in R: a variable declared with
`n = 10` has length 10, arithmetic is elementwise, `x[3]` indexes, and
`sum(x)` folds. Lengths must match exactly or be 1 (a scalar
broadcasts); anything else is an error — a model is no place for silent
recycling.

An operator the service does not support raises at the point of use. So
do the comparisons that have no constraint counterpart: `<` and `>` (use
`<=` or `>=`, which for continuous quantities mean the same thing) and
`!=`.

One caveat comes with `==` building a constraint:
[`unique()`](https://rdrr.io/r/base/unique.html) still works on these
objects, but `%in%` and [`match()`](https://rdrr.io/r/base/match.html)
silently answer as if no two were equal — compare identity with
[`identical()`](https://rdrr.io/r/base/identical.html) instead.
