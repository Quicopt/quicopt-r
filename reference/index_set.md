# An index set, for building a program by hand

A named set of elements, for indexing variables (the `axes` of
[`var_decl()`](https://quicopt.github.io/quicopt-r/reference/var_decl.md)),
for reductions such as sums
([`ir_reduce()`](https://quicopt.github.io/quicopt-r/reference/ir.md)),
and for repeating a constraint over its elements (the `over` of
[`constraint()`](https://quicopt.github.io/quicopt-r/reference/constraint.md)).

## Usage

``` r
index_set(name, elements)
```

## Arguments

- name:

  The set's name.

- elements:

  A list of whole numbers and strings.

## Value

A plain list without a class, with the fields `name` and `elements`. It
is an element of the list a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md)
takes as `sets`.

## Examples

``` r
index_set("items", list(1L, 2L, 3L))
#> $name
#> [1] "items"
#> 
#> $elements
#> $elements[[1]]
#> [1] 1
#> 
#> $elements[[2]]
#> [1] 2
#> 
#> $elements[[3]]
#> [1] 3
#> 
#> 
```
