# quicopt IR — a model as plain data

The form a model takes between the interface that wrote it and the
service that solves it: variables, expressions and constraints, with no
trace of how they were authored.
[`model()`](https://quicopt.github.io/quicopt-r/reference/model.md) and
friends build one of these on the way out;
[`encode()`](https://quicopt.github.io/quicopt-r/reference/encode.md)
turns it into the bytes the service reads. The shape is the service's
published contract — these constructors track it, they never fork it.

## Usage

``` r
ir_const(value)

ir_param(name, index = list())

ir_var(name, index = list())

ir_apply(op, args)

ir_reduce(op, idx, over, body, cond = NULL)

ir_source_ref(name)

ir_set_ref(name, args = list())
```

## Arguments

- value:

  A numeric constant.

- name:

  The referenced name.

- index:

  An index tuple (a list of integers and strings;
  [`list()`](https://rdrr.io/r/base/list.html) for a scalar).

- op:

  A catalog operator key, e.g. `"+"`.

- args:

  Enclosing bound indices the set is applied to
  ([`list()`](https://rdrr.io/r/base/list.html) for a flat set).

- idx:

  The bound dummy index name.

- over:

  An `ir_set_ref()` the fold ranges across.

- body:

  The folded expression.

- cond:

  Keep a term only where `cond` is non-zero; `NULL` keeps every term.

## Value

A plain list, with no class attribute, holding one node of a model's
expression tree. `ir_const()`, `ir_param()`, `ir_var()`, `ir_apply()`,
`ir_reduce()` and `ir_source_ref()` each return an expression node: its
`kind` field (`"const"`, `"param"`, `"var"`, `"apply"`, `"reduce"` or
`"source"`) says which node it is, and the remaining fields are the
arguments under their own names (`value` coerced to numeric). Such a
node stands wherever an expression is expected: as an entry of another
node's `args`, as the objective of a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md),
or as the `f` of a
[`constraint()`](https://quicopt.github.io/quicopt-r/reference/constraint.md).
`ir_set_ref()` returns a list with the fields `name` and `args`: a
reference to an index set rather than an expression, so it carries no
`kind`, and it is what `ir_reduce()` takes as `over`.

## Details

Nodes are plain lists tagged by a `kind` field. An index tuple is a
plain list whose entries are integers (concrete coordinates) or strings
(bound index names).

The constructors carry an `ir_` prefix rather than mirroring the Python
client's bare names: `Reduce` is a base R function, and this package
extends base names, it does not mask them.
