# A model as plain data

A program holds a complete model as plain R lists, in the form the
service reads:
[`encode()`](https://quicopt.github.io/quicopt-r/reference/encode.md)
turns it into bytes, and [`solve()`](https://rdrr.io/r/base/solve.html)
and
[`submit()`](https://quicopt.github.io/quicopt-r/reference/submit.md)
accept it directly.
[`as_program()`](https://quicopt.github.io/quicopt-r/reference/as_program.md)
converts a
[`model()`](https://quicopt.github.io/quicopt-r/reference/model.md) into
a program. Building one by hand, with this function and the ones it
links to, is for parts of the format that a
[`model()`](https://quicopt.github.io/quicopt-r/reference/model.md) does
not offer, such as index sets and parameter tables.

## Usage

``` r
program(
  sets = list(),
  indexed_sets = list(),
  params = list(),
  vars = list(),
  objective = NULL,
  sense = "min",
  constraints = list(),
  fix = list(),
  scenarios = 1,
  scenario_seed = 1,
  sources = list(),
  structures = list()
)
```

## Arguments

- sets:

  A list of
  [`index_set()`](https://quicopt.github.io/quicopt-r/reference/index_set.md)s.

- indexed_sets:

  Sets that differ from position to position (see above).

- params:

  Parameter tables (see above).

- vars:

  A list of
  [`var_decl()`](https://quicopt.github.io/quicopt-r/reference/var_decl.md)s.

- objective:

  The objective, an expression node (see
  [ir](https://quicopt.github.io/quicopt-r/reference/ir.md)).

- sense:

  `"min"` or `"max"`.

- constraints:

  A list of
  [`constraint()`](https://quicopt.github.io/quicopt-r/reference/constraint.md)s.

- fix:

  Variables fixed at a value (see above).

- scenarios:

  How many scenarios to draw, at least 1.

- scenario_seed:

  The seed to draw them from, at least 1.

- sources:

  The random variables: a named list of
  [`parametric()`](https://quicopt.github.io/quicopt-r/reference/parametric.md)
  and
  [`empirical()`](https://quicopt.github.io/quicopt-r/reference/empirical.md)
  declarations.

- structures:

  The permutations: a named list of
  [`permutation_decl()`](https://quicopt.github.io/quicopt-r/reference/permutation_decl.md)
  declarations.

## Value

An object of class `quicopt_program`: a list with one element per
argument, under the argument's name.

## Details

Data indexed by positions is given as lists of entries, because a
position (a list of numbers and strings) cannot be a name:

- `params` maps the name of a parameter table to a list of entries
  `list(key = <position>, value = <number>)`;

- `indexed_sets` maps a name to a list of entries
  `list(key = <position>, value = <list of elements>)`, a set that
  differs from position to position;

- `fix` is a list of entries `list(var = , index = , value = )`, each
  fixing one variable at a value.

The order of the entries does not matter.

A model with random variables also needs `sources`, which declares them,
and `scenarios` and `scenario_seed`, which say how many scenarios are
drawn and from which seed. A model with permutations needs `structures`.
