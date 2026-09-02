# Submit a model for asynchronous solving

Queues the model and returns immediately with a job handle; the solve
runs on the service while your session goes on. Await it with
[`job_result()`](https://quicopt.github.io/quicopt-r/reference/job_status.md),
peek with
[`job_status()`](https://quicopt.github.io/quicopt-r/reference/job_status.md)
or
[`job_log()`](https://quicopt.github.io/quicopt-r/reference/job_status.md),
and discard it with
[`job_delete()`](https://quicopt.github.io/quicopt-r/reference/job_status.md).
The arguments are those of
[`solve_model()`](https://quicopt.github.io/quicopt-r/reference/solve_model.md);
the handle keeps the connection settings, so the polling calls need none
of them repeated.

## Usage

``` r
submit(
  m,
  base_url = DEFAULT_BASE_URL,
  api_key = NULL,
  project = NULL,
  config = NULL,
  gzip = FALSE,
  timeout = 60,
  transport = NULL
)
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

## Value

A `quicopt_job` handle.
