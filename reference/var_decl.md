# A decision variable, for building a program by hand

Declares one decision variable of a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md).
[`num_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md),
[`int_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)
and
[`bin_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)
build these for you.

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

  The variable's name, used for it in the answer.

- axes:

  The names of the index sets the variable is indexed over;
  [`character()`](https://rdrr.io/r/base/character.html) for a single
  variable.

- domain:

  `CONTINUOUS`, `INTEGER` or `BINARY`.

- lower, upper:

  A number (`-Inf` or `Inf` for no bound), or the name of a parameter
  table, for a bound that differs from index to index.

- start:

  The value the search starts from.

## Value

`var_decl()` returns a plain list without a class, with the fields
`name`, `axes`, `domain`, `lower`, `upper` and `start`. It is an element
of the list a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md)
takes as `vars`.

`CONTINUOUS`, `INTEGER` and `BINARY` are not functions but constants:
the whole numbers 1, 2 and 3, which stand for the three kinds of
variable in `domain`.

## Examples

``` r
var_decl("tables", domain = INTEGER, lower = 0)
#> $name
#> [1] "tables"
#> 
#> $axes
#> character(0)
#> 
#> $domain
#> [1] 2
#> 
#> $lower
#> [1] 0
#> 
#> $upper
#> [1] Inf
#> 
#> $start
#> [1] 0
#> 
```
