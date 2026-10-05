# Declare decision variables

A decision variable is a quantity the service chooses. `num_var()`
declares one that can take any value between its bounds, `int_var()` one
that must be a whole number, and `bin_var()` a yes-or-no decision, which
is either 0 or 1.

## Usage

``` r
num_var(m, name, lower = -Inf, upper = Inf, n = 1, start = 0)

int_var(m, name, lower = -Inf, upper = Inf, n = 1, start = 0)

bin_var(m, name, n = 1, start = 0)

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

  The variable's name, used for it in the answer. It must be unique
  within the model.

- lower, upper:

  The smallest and the largest value allowed. `-Inf` and `Inf`, the
  defaults, leave that side open.

- n:

  How many variables to declare under this name.

- start:

  The value the service's search starts from (see
  [`set_start()`](https://quicopt.github.io/quicopt-r/reference/set_start.md)).

- domain:

  For `add_var()`: `"num"`, `"int"` or `"bin"`, to declare the variable
  as `num_var()`, `int_var()` or `bin_var()` would.

## Value

The variable, an expression of length `n`.

`add_var()` returns the model, invisibly.

## Details

Each returns the variable, for use in expressions such as
`50 * tables + 20 * chairs`; `m$tables` retrieves it from the model too.
`add_var()` declares a variable in the same way but returns the model,
for use in a pipe (see
[`model()`](https://quicopt.github.io/quicopt-r/reference/model.md)).

With `n` greater than 1, one call declares `n` variables under one name,
and they behave like an R vector: `x[3]` is the third, arithmetic works
element by element, and `sum(x)` adds them up. `lower`, `upper` and
`start` may then be vectors of length `n`, one value per element. In the
answer the elements are named `"x[1]"`, `"x[2]"`, and so on; a single
variable is named `"x"`.

## Examples

``` r
m <- model()
tables <- int_var(m, "tables", lower = 0)
take   <- bin_var(m, "take", n = 6)                         # six yes-or-no decisions
share  <- num_var(m, "share", lower = 0, upper = 1, n = 3)
sum(share)
#> (share[1] + share[2] + share[3])
take[2]
#> take[2]
```
