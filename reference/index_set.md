# A named index set with concrete elements

A named index set with concrete elements

## Usage

``` r
index_set(name, elements)
```

## Arguments

- name:

  The set's name.

- elements:

  A list of integers and strings.

## Value

A plain list, with no class attribute, with the fields `name` and
`elements` as given. It defines one index set of the model, and is an
entry of the list a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md)
takes as `sets`.
