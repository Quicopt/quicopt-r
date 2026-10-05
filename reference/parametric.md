# A random variable with a distribution, for building a program by hand

Declares one random variable of a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md)
by its distribution. `head` names the distribution, such as `"normal"`,
and `params` holds its parameters as expression nodes, in the same order
as for
[`normal()`](https://quicopt.github.io/quicopt-r/reference/distribution.md)
and the other distribution functions. A parameter may contain decision
variables, but no random variable.
[`rand_var()`](https://quicopt.github.io/quicopt-r/reference/rand_var.md)
builds these for you.

## Usage

``` r
parametric(head, params)
```

## Arguments

- head:

  The name under which the service knows the distribution.

- params:

  A list of expression nodes, one per parameter.

## Value

A plain list without a class, with the fields `kind = "parametric"`,
`head` and `params`. It is an element of the named list a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md)
takes as `sources`, and the element's name is the name
[`ir_source_ref()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
refers to.

## Examples

``` r
# demand ~ normal(100, 15)
sources <- list(demand = parametric("normal", list(ir_const(100), ir_const(15))))
```
