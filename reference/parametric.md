# A random variable drawn from a distribution

`head` is a catalog operator (`"normal"`, ...) and each parameter is an
ordinary deterministic expression node — so a distribution whose mean is
itself a decision needs nothing the grammar does not already have.

## Usage

``` r
parametric(head, params)
```

## Arguments

- head:

  The distribution's catalog name.

- params:

  A list of parameter nodes.

## Value

A plain list, with no class attribute, with the fields
`kind = "parametric"`, `head` and `params` as given. It declares one
random variable by its distribution, and is an entry of the named list a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md)
takes as `sources`; the entry's name is the name
[`ir_source_ref()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
refers to.
