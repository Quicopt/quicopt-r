# Distributions for random variables

The named constructors follow the parameterizations of R's own samplers:

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

  The distribution's name in the service's catalog.

- ...:

  Its parameters, each a number, a numeric vector, or a non-random
  expression.

- mean, sd:

  The mean and standard deviation, as in
  [`rnorm()`](https://rdrr.io/r/stats/Normal.html).

- min, max:

  The lower and upper limits, as in
  [`runif()`](https://rdrr.io/r/stats/Uniform.html).

- rate:

  The rate, as in [`rexp()`](https://rdrr.io/r/stats/Exponential.html);
  the mean is `1 / rate`.

- prob:

  The probability of a 1, as in `rbinom(n, 1, prob)`.

## Value

A distribution, ready for
[`rand_var()`](https://quicopt.github.io/quicopt-r/reference/rand_var.md)
or
[`set_distribution()`](https://quicopt.github.io/quicopt-r/reference/set_distribution.md).

## Details

- `normal(mean, sd)`, as
  [`rnorm()`](https://rdrr.io/r/stats/Normal.html): the mean and the
  standard deviation.

- `uniform(min, max)`, as
  [`runif()`](https://rdrr.io/r/stats/Uniform.html): the two limits.

- `exponential(rate)`, as
  [`rexp()`](https://rdrr.io/r/stats/Exponential.html): the rate, so the
  mean is `1 / rate`.

- `bernoulli(prob)`, as `rbinom(n, 1, prob)`: 1 with probability `prob`,
  else 0.

`distribution(head, ...)` names a distribution by its catalog name, for
a distribution the service's catalog holds and no constructor here names
yet. A head the catalog does not hold is refused when the model is sent.
Every other distribution is available through
[`empirical()`](https://quicopt.github.io/quicopt-r/reference/empirical.md):
draw a column in R and declare it (see the vignette).

A parameter may be a number or a non-random model expression. An
expression gives an *endogenous* distribution, one whose parameters
depend on the decision, such as a demand whose mean falls with the price
you set or a failure whose probability falls with what you spend on
maintenance. A parameter may never contain a random variable: a
distribution's parameters are data, not draws.

A parameter may also be a vector, and the distribution then declares a
vector random variable: `normal(c(6, 5, 4), 1)` is three independent
normals with their own means and a shared standard deviation. Every
parameter has length 1 or the vector's length.

A numeric parameter outside its distribution's range is refused where
the distribution is built: a rate that is not positive, a probability
outside 0 to 1, a lower limit above its upper limit. A parameter given
as an expression cannot be checked this way, since its value is the
solver's to choose; bound the decision variables so that it stays in
range.

## Examples

``` r
m <- model()
lead_time <- rand_var(m, "lead_time", uniform(2, 5))
gap       <- rand_var(m, "gap", exponential(1 / 30))   # mean 30
fails     <- rand_var(m, "fails", bernoulli(0.02))

# an endogenous distribution: spending on maintenance lowers the failure
# probability
spend  <- num_var(m, "spend", 0, 10)
breaks <- rand_var(m, "breaks", bernoulli(0.2 - 0.015 * spend))
```
