# Solve a model with the Quicopt service

Encodes the model, sends it, and returns the parsed result. The first
keyless call mints an API key, remembered for the rest of the R session;
pass `api_key` to authenticate with a key you already hold (used as-is,
never remembered).

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

  A [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md),
  a
  [`program()`](https://quicopt.github.io/quicopt-r/reference/program.md),
  or already-encoded bytes.

- base_url:

  The service to talk to; defaults to
  [DEFAULT_BASE_URL](https://quicopt.github.io/quicopt-r/reference/DEFAULT_BASE_URL.md).

- api_key:

  A key you hold, or `NULL` to mint and reuse a free-tier key.

- project:

  A project tag for per-project invoicing, or `NULL`.

- config:

  Named list of extra query parameters; a `source_language` here
  overrides the automatic tag.

- gzip:

  Compress the request body.

- timeout:

  Seconds to wait for the service.

- transport:

  The HTTP layer, replaceable for testing: a `function(req)` taking
  `list(method, url, headers, body, timeout)` and returning
  `list(status, headers, body)`.

- a:

  The model (the argument is named `a` to match the `solve` generic).

- b:

  Unused; supplying it is an error.

- ...:

  Passed on to `solve_model()`.

## Value

The service's answer as a `quicopt_result`: a list with `status`,
`objective`, `feasible`, `solution` (a named numeric vector),
`model_class` (the class the service read the model as, e.g. `"milp"`),
and the ready-to-print `display`. Printing the result prints `display`.

## Details

`solve(m)` and `solve_model(m)` are the same function — the former
extends the [`base::solve`](https://rdrr.io/r/base/solve.html) generic
(as `solve.qr` does), the latter is the unambiguous name for pipes and
for reading. For a long-running model, or a first call against a cold
worker,
[`submit()`](https://quicopt.github.io/quicopt-r/reference/submit.md)
queues the same request asynchronously instead of blocking.
