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
