# Declare decision variables

`num_var` declares a continuous variable, `int_var` an integer one, and
`bin_var` a binary one. With `n` greater than 1 the declaration is a
vector variable: `x[3]` indexes it, `sum(x)` folds it, arithmetic is
elementwise, and per-element bounds are given as vectors of length `n`.
Solutions come back keyed `"x"` for a scalar and `"x[1]"`, `"x[2]"`, ...
for a vector.

## Usage

``` r
num_var(m, name, lower = -Inf, upper = Inf, n = 1, start = 0)

int_var(m, name, lower = -Inf, upper = Inf, n = 1, start = 0)

bin_var(m, name, n = 1)

add_var(
  m,
  name,
  lower = -Inf,
  upper = Inf,
  n = 1,
  start = 0,
  domain = c("num", "int", "bin")
)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- name:

  The variable's name, unique within the model.

- lower, upper:

  Bounds; `-Inf` / `Inf` leave a direction unbounded. A vector of length
  `n` sets per-element bounds.

- n:

  How many elements the variable has.

- start:

  The initial point handed to the solver.

- domain:

  For `add_var`: `"num"`, `"int"` or `"bin"`.

## Value

The variable handle (an expression of length `n`).

`add_var` returns the model, invisibly.

## Details

The handle is returned and is also retrievable from the model as `m$x`;
the `add_var` variant returns the model instead, for pipes.
