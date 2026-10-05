# Distributions for random variables

These functions describe how a random variable is distributed, for use
in
[`rand_var()`](https://quicopt.github.io/quicopt-r/reference/rand_var.md).
Each takes the same parameters, in the same order, as R's corresponding
random number function:

## Usage

``` r
distribution(head, ...)

normal(mean, sd)

uniform(min, max)

exponential(rate)

bernoulli(prob)
```

## Arguments

- head:

  The name under which the service knows the distribution.

- ...:

  The distribution's parameters, each a number, a numeric vector, or an
  expression without random variables.

- mean, sd:

  The mean and the standard deviation, as in
  [`rnorm()`](https://rdrr.io/r/stats/Normal.html).

- min, max:

  The smallest and the largest value, as in
  [`runif()`](https://rdrr.io/r/stats/Uniform.html).

- rate:

  The rate, as in [`rexp()`](https://rdrr.io/r/stats/Exponential.html);
  the mean is `1 / rate`.

- prob:

  The probability of a 1, as in `rbinom(n, 1, prob)`.

## Value

A distribution, to be passed to
[`rand_var()`](https://quicopt.github.io/quicopt-r/reference/rand_var.md)
or
[`set_distribution()`](https://quicopt.github.io/quicopt-r/reference/set_distribution.md).

## Details

- `normal(mean, sd)`, like
  [`rnorm()`](https://rdrr.io/r/stats/Normal.html): the mean and the
  standard deviation.

- `uniform(min, max)`, like
  [`runif()`](https://rdrr.io/r/stats/Uniform.html): the smallest and
  the largest value.

- `exponential(rate)`, like
  [`rexp()`](https://rdrr.io/r/stats/Exponential.html): the rate, so
  that the mean is `1 / rate`.

- `bernoulli(prob)`, like `rbinom(n, 1, prob)`: 1 with probability
  `prob`, and 0 otherwise.

For any other distribution, draw a sample in R and pass it to
[`empirical()`](https://quicopt.github.io/quicopt-r/reference/empirical.md).
`distribution(head, ...)` names a distribution that the service offers
but this package has no function for yet; the service refuses a name it
does not know.

## Parameters that depend on a decision

A parameter may be an expression of decision variables rather than a
number. The distribution then depends on the decision: a demand whose
mean falls as the price rises, or a breakdown that becomes less likely
the more is spent on maintenance. A parameter cannot contain a random
variable.

A parameter given as a number is checked right away: a rate that is not
positive, a probability outside 0 to 1, or a `min` above `max` is an
error. A parameter given as an expression cannot be checked in advance,
so give the decision variables in it bounds that keep it in range.

## Vector parameters

A parameter may be a vector. The distribution then describes that many
random variables, drawn independently: `normal(c(6, 5, 4), 1)` is three
normal variables with means 6, 5 and 4 and standard deviation 1. Each
parameter has length 1 or the common length.

## Examples

``` r
m <- model()
lead_time <- rand_var(m, "lead_time", uniform(2, 5))      # between 2 and 5 days
gap       <- rand_var(m, "gap", exponential(1 / 30))      # 30 minutes on average
fails     <- rand_var(m, "fails", bernoulli(0.02))        # 1 with probability 0.02

# the more is spent on maintenance, the less likely a breakdown
spend  <- num_var(m, "spend", lower = 0, upper = 10)
breaks <- rand_var(m, "breaks", bernoulli(0.2 - 0.015 * spend))
```
