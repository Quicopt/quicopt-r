# Solve a model without waiting

`submit()` sends a model to the service like
[`solve()`](https://rdrr.io/r/base/solve.html) does, but returns at once
with a *job*, while the service solves the model in the background and
your R session can go on.
[`job_result()`](https://quicopt.github.io/quicopt-r/reference/job_status.md)
collects the answer when it is ready, and
[`job_status()`](https://quicopt.github.io/quicopt-r/reference/job_status.md)
shows how far the job has got.

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

## Value

A job, of class `quicopt_job`, for
[`job_result()`](https://quicopt.github.io/quicopt-r/reference/job_status.md),
[`job_status()`](https://quicopt.github.io/quicopt-r/reference/job_status.md),
[`job_log()`](https://quicopt.github.io/quicopt-r/reference/job_status.md)
and
[`job_delete()`](https://quicopt.github.io/quicopt-r/reference/job_status.md).

## Details

The job keeps the address, the key and the other settings it was
submitted with, so the functions that follow it up need only the job.

## Examples

``` r
if (FALSE) { # \dontrun{
job <- submit(m)
job_status(job)$status
res <- job_result(job)        # waits until the job is finished
} # }
```
