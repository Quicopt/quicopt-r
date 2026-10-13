# Whether a variable is in use

`active(x)` is 1 when the variable `x` is not 0, and 0 when it is. It is
meant for a variable declared with `semi = TRUE` (see
[`num_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)),
which is either 0 or between its bounds: a delivery of either nothing or
10 to 25 units, say. A fee charged for every delivery that takes place
is then `fee * active(delivery)`, and a limit on how many deliveries
take place is a constraint on `sum(active(delivery))`.

## Usage

``` r
active(x)
```

## Arguments

- x:

  A decision variable, or elements of one, such as `x[2:3]`.

## Value

An expression with one 0/1 element per element of `x`.

## Details

For such a variable, a model that is otherwise linear is still solved to
a proven optimum. On any other variable, `active(x)` means the same, 1
when `x` is not 0, but the model is then solved by a search.

## Examples

``` r
m <- model()
delivery <- int_var(m, "delivery", lower = 10, upper = 25, n = 3, semi = TRUE)
fee <- c(30, 10, 5)
minimize(m, sum(c(1, 2, 3) * delivery) + sum(fee * active(delivery)))
add(m, sum(delivery) >= 40)                     # the customer needs 40 units
add(m, sum(active(delivery)) <= 2)              # at most two deliveries
```
