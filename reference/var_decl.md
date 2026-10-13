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

SEMICONTINUOUS

SEMIINTEGER

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

  `CONTINUOUS`, `INTEGER`, `BINARY`, `SEMICONTINUOUS` or `SEMIINTEGER`.

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

`CONTINUOUS`, `INTEGER`, `BINARY`, `SEMICONTINUOUS` and `SEMIINTEGER`
are not functions but constants: the whole numbers 1 to 5, which stand
for the five kinds of variable in `domain`.

## Details

A variable of domain `SEMICONTINUOUS` is either 0 or a value between its
bounds, and one of domain `SEMIINTEGER` is either 0 or a whole number
between them (see the `semi` argument of
[`num_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)).
Both need finite bounds.

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
