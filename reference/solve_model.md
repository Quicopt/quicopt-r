# Solve a model

[`solve()`](https://rdrr.io/r/base/solve.html) sends a model to the
Quicopt service, waits for the answer, and returns it as a list (see the
Value section). `solve_model()` is the same function under a name that
cannot be confused with base R's
[`solve()`](https://rdrr.io/r/base/solve.html), which can read better in
a pipe.

## Usage

``` r
solve_model(
  m,
  base_url = DEFAULT_BASE_URL,
  api_key = NULL,
  project = NULL,
  config = NULL,
  gzip = FALSE,
  timeout = 60,
  transport = NULL
)

# S3 method for class 'quicopt_model'
solve(a, b, ...)
```

## Arguments

- m:

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md).
  A
  [`program()`](https://quicopt.github.io/quicopt-r/reference/program.md),
  or the bytes from
  [`encode()`](https://quicopt.github.io/quicopt-r/reference/encode.md),
  also work.

- base_url:

  The address of the service.

- api_key:

  Your API key, or `NULL` to use the session's free key (see the API
  keys section).

- project:

  A project name, for billing by project, or `NULL`.

- config:

  A named list of further settings, sent to the service as query
  parameters.

- gzip:

  Whether to compress the model before sending it; worth it for a large
  model.

- timeout:

  How many seconds to wait for the answer.

- transport:

  For tests: a function that is called instead of sending the request.
  It takes a list with the elements `method`, `url`, `headers`, `body`
  and `timeout`, and returns a list with the elements `status`,
  `headers` and `body`.

- a:

  The model. The argument is called `a` because base R's
  [`solve()`](https://rdrr.io/r/base/solve.html) calls it that.

- b:

  Not used; giving it is an error.

- ...:

  Further arguments for `solve_model()`, by name.

## Value

A list of class `quicopt_result`, with these elements:

- `status`: what kind of answer it is (see the Status section).

- `feasible`: whether the solution meets every constraint.

- `objective`: the value of the objective at the solution.

- `solution`: a named numeric vector with the value of each decision
  variable, in the order they were declared.

- `structures`: for a model with permutations, one element per
  permutation, holding the integer vectors `item_at` and `slot_of` (see
  [`perm_var()`](https://quicopt.github.io/quicopt-r/reference/perm_var.md));
  otherwise `NULL`.

- `model_class`: the kind of model the service recognized, such as
  `"lp"`, `"milp"` or `"stochastic"`.

- `solver_data`: further details from the service, such as
  `max_violation`, by how much the worst constraint is missed.

- `display`: a summary prepared by the service, which is what printing
  the result shows.

## Details

[`solve()`](https://rdrr.io/r/base/solve.html) waits for up to `timeout`
seconds. For a model that takes longer,
[`submit()`](https://quicopt.github.io/quicopt-r/reference/submit.md)
sends it without waiting.

## API keys

The service needs an API key. The first time a model is solved in an R
session without one, the service issues a free key, and quicopt keeps it
in memory until the session ends; it is never written to disk. To use a
key of your own, pass it as `api_key`. It is then used for that call
only, and not kept.

## Status

`status` says what kind of answer the result holds:

- `"optimal"`: the service has proved that no better solution exists.

- `"heuristic"`: the best solution a search found, without that proof.
  Models with random variables, permutations or lookup tables are solved
  this way. If such a result has `feasible = FALSE`, the search found no
  solution that meets every constraint, which does not prove that none
  exists.

Other values say why no solution is available.

## Examples

``` r
if (FALSE) { # \dontrun{
m <- model()
tables <- int_var(m, "tables", lower = 0)
chairs <- int_var(m, "chairs", lower = 0)
maximize(m, 50 * tables + 20 * chairs)
add(m, 3 * tables + chairs <= 41)
add(m, tables + chairs <= 18)

res <- solve(m)
res$status
res$solution
res
} # }
```
