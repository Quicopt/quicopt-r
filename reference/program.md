# A complete optimization model as plain data

The tables keyed by index tuples are lists of entries rather than named
lists, because an index tuple is not a string: `params` maps a table
name to a list of `list(key = <index tuple>, value = <number>)` entries,
`indexed_sets` maps a name to `list(key = ..., value = <element list>)`
fibres, and `fix` is a list of `list(var = , index = , value = )` pins.
Entry order does not matter; encoding sorts them canonically.

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

  Dependent sets carried as data (see above).

- params:

  Named parameter tables (see above).

- vars:

  A list of
  [`var_decl()`](https://quicopt.github.io/quicopt-r/reference/var_decl.md)s.

- objective:

  The objective expression node.

- sense:

  `"min"` or `"max"`.

- constraints:

  A list of
  [`constraint()`](https://quicopt.github.io/quicopt-r/reference/constraint.md)s.

- fix:

  Per-index variable pins (see above).

- scenarios:

  How many scenarios are drawn (at least 1).

- scenario_seed:

  The seed they are drawn from (at least 1).

- sources:

  Named
  [`parametric()`](https://quicopt.github.io/quicopt-r/reference/parametric.md)
  /
  [`empirical()`](https://quicopt.github.io/quicopt-r/reference/empirical.md)
  declarations.

- structures:

  Named
  [`permutation_decl()`](https://quicopt.github.io/quicopt-r/reference/permutation_decl.md)
  declarations.

## Value

An object of class `quicopt_program`: a list with one field per
argument, under the argument's name (`scenarios` and `scenario_seed`
coerced to numeric). It is the complete model in the form the service
reads, with nothing left to resolve:
[`encode()`](https://quicopt.github.io/quicopt-r/reference/encode.md)
turns it into bytes, and
[`solve_model()`](https://quicopt.github.io/quicopt-r/reference/solve_model.md)
and
[`submit()`](https://quicopt.github.io/quicopt-r/reference/submit.md)
accept it directly.

## Details

A model under uncertainty adds three more: the random variables it draws
(`sources`, a named list of
[`parametric()`](https://quicopt.github.io/quicopt-r/reference/parametric.md)
/
[`empirical()`](https://quicopt.github.io/quicopt-r/reference/empirical.md)
declarations), how many scenarios are drawn and the seed they are drawn
from. The last two are model data — they pin the sampled instance, so
the same program always sees the same draws. Left at their defaults they
say nothing, and the encoded bytes are those of a deterministic model.

A model with a permutation adds `structures`, a named list of
[`permutation_decl()`](https://quicopt.github.io/quicopt-r/reference/permutation_decl.md)
declarations that
[`ir_struct_ref()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
nodes refer to. Left empty it says nothing, as `sources` does.
