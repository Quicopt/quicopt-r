# Expression nodes, for building a program by hand

These functions build the pieces of a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md)'s
expressions directly, as plain lists. A
[`model()`](https://quicopt.github.io/quicopt-r/reference/model.md)
builds them for you from ordinary R arithmetic, so you need them only to
build a program by hand. Each node is a list whose `kind` field says
what it is:

## Usage

``` r
ir_const(value)

ir_param(name, index = list())

ir_var(name, index = list())

ir_apply(op, args)

ir_reduce(op, idx, over, body, cond = NULL)

ir_source_ref(name)

ir_struct_ref(name)

ir_table_ref(param, index)

ir_set_ref(name, args = list())
```

## Arguments

- value:

  A number.

- name:

  The name of the variable, table, random variable, permutation or index
  set referred to.

- index:

  A position: a list of whole numbers and index names,
  [`list()`](https://rdrr.io/r/base/list.html) for none. For
  `ir_table_ref()`, a list of one or two expression nodes.

- op:

  The name of an operator the service knows, such as `"+"`, `"*"` or
  `"sqrt"`. For `ir_reduce()`, the operator that combines the terms,
  such as `"+"` for a sum.

- args:

  For `ir_apply()`, a list of argument nodes. For `ir_set_ref()`, the
  indices the set depends on,
  [`list()`](https://rdrr.io/r/base/list.html) for a set that depends on
  none.

- idx:

  The name of the index that runs over the set, as used in `body`.

- over:

  The index set to run over, from `ir_set_ref()`.

- body:

  The expression to combine over the set.

- cond:

  An expression node: only the terms in which it is not 0 are included.
  `NULL` includes every term.

- param:

  The name of the parameter table.

## Value

A plain list without a class. Every function except `ir_set_ref()`
returns an expression node, which can stand wherever a program expects
an expression: in another node's `args`, as the program's objective, or
as the `f` of a
[`constraint()`](https://quicopt.github.io/quicopt-r/reference/constraint.md).
`ir_set_ref()` returns a reference to an index set instead, a list with
the fields `name` and `args` and no `kind`, which is what `ir_reduce()`
takes as `over`.

## Details

- `ir_const(value)`: a number.

- `ir_var(name, index)`: a decision variable.

- `ir_param(name, index)`: an entry of one of the program's parameter
  tables.

- `ir_source_ref(name)`: a random variable declared in the program's
  `sources`.

- `ir_apply(op, args)`: an operator, such as `"+"` or `"sqrt"`, applied
  to a list of argument nodes.

- `ir_reduce(op, idx, over, body, cond)`: `body` combined over the
  elements of an index set, for example the sum of `body` over all `i`
  in a set `S`.

- `ir_set_ref(name, args)`: the index set a reduction runs over.

- `ir_struct_ref(name)`: a permutation declared in the program's
  `structures`. It may appear only as the second argument of the
  operators `"item_at"` and `"slot_of"`, which is what
  [`item_at()`](https://quicopt.github.io/quicopt-r/reference/item_at.md)
  and
  [`slot_of()`](https://quicopt.github.io/quicopt-r/reference/item_at.md)
  build.

- `ir_table_ref(param, index)`: an entry of a parameter table at
  positions given by expression nodes, which is what indexing a
  [`lookup_table()`](https://quicopt.github.io/quicopt-r/reference/lookup_table.md)
  builds.

An `index` is a list of whole numbers, for fixed positions, and strings,
for the names of indices bound by an enclosing reduction or constraint;
it is [`list()`](https://rdrr.io/r/base/list.html) for a variable or
entry without an index.

## Examples

``` r
# 3 * x + 1
ir_apply("+", list(ir_apply("*", list(ir_const(3), ir_var("x"))), ir_const(1)))
#> $kind
#> [1] "apply"
#> 
#> $op
#> [1] "+"
#> 
#> $args
#> $args[[1]]
#> $args[[1]]$kind
#> [1] "apply"
#> 
#> $args[[1]]$op
#> [1] "*"
#> 
#> $args[[1]]$args
#> $args[[1]]$args[[1]]
#> $args[[1]]$args[[1]]$kind
#> [1] "const"
#> 
#> $args[[1]]$args[[1]]$value
#> [1] 3
#> 
#> 
#> $args[[1]]$args[[2]]
#> $args[[1]]$args[[2]]$kind
#> [1] "var"
#> 
#> $args[[1]]$args[[2]]$name
#> [1] "x"
#> 
#> $args[[1]]$args[[2]]$index
#> list()
#> 
#> 
#> 
#> 
#> $args[[2]]
#> $args[[2]]$kind
#> [1] "const"
#> 
#> $args[[2]]$value
#> [1] 1
#> 
#> 
#> 

# the sum of cost[i] * y[i] over the elements i of the set "items"
ir_reduce("+", "i", ir_set_ref("items"),
          ir_apply("*", list(ir_param("cost", list("i")), ir_var("y", list("i")))))
#> $kind
#> [1] "reduce"
#> 
#> $op
#> [1] "+"
#> 
#> $idx
#> [1] "i"
#> 
#> $over
#> $over$name
#> [1] "items"
#> 
#> $over$args
#> list()
#> 
#> 
#> $body
#> $body$kind
#> [1] "apply"
#> 
#> $body$op
#> [1] "*"
#> 
#> $body$args
#> $body$args[[1]]
#> $body$args[[1]]$kind
#> [1] "param"
#> 
#> $body$args[[1]]$name
#> [1] "cost"
#> 
#> $body$args[[1]]$index
#> $body$args[[1]]$index[[1]]
#> [1] "i"
#> 
#> 
#> 
#> $body$args[[2]]
#> $body$args[[2]]$kind
#> [1] "var"
#> 
#> $body$args[[2]]$name
#> [1] "y"
#> 
#> $body$args[[2]]$index
#> $body$args[[2]]$index[[1]]
#> [1] "i"
#> 
#> 
#> 
#> 
#> 
#> $cond
#> NULL
#> 
```
