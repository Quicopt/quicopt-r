# Declare a random variable

A random variable stands for a quantity that is not known when the
decision is made, such as tomorrow's demand. It can be used in
expressions like a decision variable, but the service does not choose
its value: in each scenario, the value is drawn from the variable's
distribution. Within one scenario, every use of the variable has the
same value. Two random variables declared separately are drawn
independently.

## Usage

``` r
rand_var(m, name, dist = NULL, n = NULL)

add_rand_var(m, name, dist = NULL, n = NULL)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- name:

  The random variable's name, unique within the model.

- dist:

  A distribution such as `normal(100, 15)` (see
  [`distribution()`](https://quicopt.github.io/quicopt-r/reference/distribution.md)),
  or an
  [`empirical()`](https://quicopt.github.io/quicopt-r/reference/empirical.md)
  sample with one value per scenario. It may be left out and given later
  with
  [`set_distribution()`](https://quicopt.github.io/quicopt-r/reference/set_distribution.md).

- n:

  How many random variables to declare under this name. Left `NULL`, the
  number follows from the length of the distribution's parameters.

## Value

The random variable, an expression of length `n`.

`add_rand_var()` returns the model, invisibly.

## Details

A random variable has no bounds; its distribution says which values it
can take.

A distribution with vector parameters declares several random variables
under one name, which behave like an R vector:
`rand_var(m, "hours", normal(c(6, 5, 4), 1))` declares `hours[1]`,
`hours[2]` and `hours[3]`. With scalar parameters and `n` given, it
declares `n` variables with the same distribution. Either way, the
elements are drawn independently of each other. Random variables that
move together, such as demand and price, are best declared from observed
data with
[`set_empirical()`](https://quicopt.github.io/quicopt-r/reference/set_empirical.md).

`add_rand_var()` declares the variable in the same way but returns the
model, for use in a pipe; `m$name` then retrieves the variable.

## Examples

``` r
m <- model()
demand <- rand_var(m, "demand", normal(100, 15))
hours  <- rand_var(m, "hours", normal(c(6, 5, 4), 1))    # three, one per job
delay  <- rand_var(m, "delay", uniform(1, 1.5), n = 4)   # four with the same distribution
```
