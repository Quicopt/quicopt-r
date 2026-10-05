# Require one item to come before another

`precede(P, before, after)` requires item `before` to be in an earlier
slot of the permutation `P` than item `after`: a pickup before its
delivery, or a job before the job that needs its output. The service
only considers arrangements that meet the requirement, so every solution
meets it.

## Usage

``` r
precede(P, before, after)
```

## Arguments

- P:

  A permutation from
  [`perm_var()`](https://quicopt.github.io/quicopt-r/reference/perm_var.md).

- before, after:

  Items: whole numbers from 1 to the size of the permutation.

## Value

The permutation, invisibly.

## Details

`precede()` may be called several times for one permutation.
Requirements that contradict each other, such as 1 before 2 and 2 before
1, are an error.

## Examples

``` r
m <- model()
route <- perm_var(m, "route", 5)
precede(route, 4, 1)                # stop 4 is visited before stop 1
precede(route, 2, 5)                # and stop 2 before stop 5
```
