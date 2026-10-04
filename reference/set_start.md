# Start the search from a known solution

Sets the start value of every variable named in `values`, so the next
solve begins there. The usual source is a previous result: solve,
tighten a constraint or add a scenario, and solve again from where the
last search ended rather than from scratch. Variables not named keep
their start.

## Usage

``` r
set_start(m, values)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).

- values:

  A result from [`solve()`](https://rdrr.io/r/base/solve.html), or a
  named numeric vector keyed the way a solution is: `"x"` for a scalar,
  `"x[1]"`, `"x[2]"`, ... for a vector variable.

## Value

The model, invisibly.

## Details

An integer or binary variable's start is rounded by the service, and any
start is clamped into the variable's bounds. A result also carries the
order found for every permutation
([`perm_var()`](https://quicopt.github.io/quicopt-r/reference/perm_var.md)),
which becomes that permutation's start.

## Examples

``` r
if (FALSE) { # \dontrun{
res <- solve(m)
add(m, x <= 100)              # a new restriction
set_start(m, res)             # begin where the last search ended
solve(m)
} # }
```
