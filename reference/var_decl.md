# A variable declaration

A variable declaration

## Usage

``` r
CONTINUOUS

INTEGER

BINARY

var_decl(
  name,
  axes = character(),
  domain = CONTINUOUS,
  lower = -Inf,
  upper = Inf,
  start = 0
)
```

## Arguments

- name:

  The variable's name; solutions come back keyed by it.

- axes:

  Index-set names the variable ranges over
  ([`character()`](https://rdrr.io/r/base/character.html) for a scalar).

- domain:

  CONTINUOUS, INTEGER or BINARY.

- lower, upper:

  A number (`-Inf`/`Inf` for an open direction), or the name of a
  parameter table when the bound varies by index.

- start:

  The initial point handed to the solver.

## Value

`var_decl()` returns a plain list, with no class attribute, with the
fields `name`, `axes`, `domain` (the integer domain code), `lower`,
`upper` and `start` (numeric). It declares one variable of the model,
and is an entry of the list a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md)
takes as `vars`.

`CONTINUOUS`, `INTEGER` and `BINARY` are not functions but integer
constants (`1L`, `2L` and `3L`): the codes the service uses for a
variable's domain, to be passed as `domain`.
