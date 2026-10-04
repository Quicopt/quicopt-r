# Declare a random variable

The variable is not a decision: the solver is handed its value rather
than choosing it, and every use of it means the same sample within a
scenario. Two independent random variables are two declarations under
two names.

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

  A
  [`distribution()`](https://quicopt.github.io/quicopt-r/reference/distribution.md)
  such as `normal(100, 15)`, or an
  [`empirical()`](https://quicopt.github.io/quicopt-r/reference/empirical.md)
  column holding one observed value per scenario. May be left `NULL` and
  supplied later with
  [`set_distribution()`](https://quicopt.github.io/quicopt-r/reference/set_distribution.md).

- n:

  How many elements the random variable has; left `NULL`, as many as the
  distribution's parameters say (1 for an empirical column).

## Value

The random variable's handle (an expression of length `n`).

`add_rand_var` returns the model, invisibly.

## Details

A random variable takes no bounds and no domain; its distribution
already says what values it takes.

A distribution with vector parameters declares a vector random variable,
`weight[1]`, ..., `weight[n]`, one independent draw per element:
`rand_var(m, "weight", normal(c(6, 5, 4), 1))`. With `n` given and
scalar parameters, the elements are `n` independent copies of one
distribution. Elements of a vector random variable are independent of
each other; correlated uncertainty is declared from data with
[`set_empirical()`](https://quicopt.github.io/quicopt-r/reference/set_empirical.md).
