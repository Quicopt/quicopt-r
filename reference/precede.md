# Require one item before another

`precede(P, before, after)` requires item `before` to sit in an earlier
slot than item `after`, in every solution: a pickup before its delivery,
a job before the one that needs its output. The requirement is held by
the search itself, not by a penalty, so it is never violated. The
requirements of a permutation must be consistent: a cycle among them is
refused.

## Usage

``` r
precede(P, before, after)
```

## Arguments

- P:

  A permutation from
  [`perm_var()`](https://quicopt.github.io/quicopt-r/reference/perm_var.md).

- before, after:

  Items, whole numbers from 1 to the permutation's size.

## Value

The permutation, invisibly.

## Examples

``` r
m <- model()
tour <- perm_var(m, "tour", 5)
precede(tour, 4, 1)                 # stop 4 before stop 1
```
