# Declare a random variable

The variable is not a decision: the solver is handed its value rather
than choosing it, and every use of it means the same sample within a
scenario. Two independent random variables are two declarations under
two names.

## Usage

``` r
rand_var(m, name, dist = NULL)

add_rand_var(m, name, dist = NULL)
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

## Value

The random variable's handle (an expression of length 1).

`add_rand_var` returns the model, invisibly.

## Details

A random variable takes no bounds and no domain — its distribution
already says what values it takes.
