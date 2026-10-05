# Follow up a submitted job

- `job_status()` returns the job's state, `"queued"`, `"running"`,
  `"done"` or `"failed"`, together with the last lines of its log.

- `job_result()` returns the answer of the job, in the same form as
  [`solve()`](https://rdrr.io/r/base/solve.html). By default it waits
  for the job to finish, checking every `poll` seconds for up to
  `timeout` seconds.

- `job_log()` returns the job's log as text.

- `job_delete()` deletes the job and its stored answer from the service.

## Usage

``` r
job_status(job)

job_result(job, wait = TRUE, timeout = 120, poll = 0.5)

job_log(job)

job_delete(job)
```

## Arguments

- job:

  A job, as returned by
  [`submit()`](https://quicopt.github.io/quicopt-r/reference/submit.md).

- wait:

  `TRUE` waits until the job is finished. `FALSE` asks once, and is an
  error if the job is not finished yet.

- timeout:

  How many seconds to wait at most.

- poll:

  How many seconds to wait between two checks.

## Value

`job_status()` returns the job's state as a list.

`job_result()` returns the answer, a list of class `quicopt_result` (see
[`solve()`](https://rdrr.io/r/base/solve.html)).

`job_log()` returns the log as a single character string.

`job_delete()` returns `NULL`, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
job <- submit(m)
job_status(job)
res <- job_result(job)
job_delete(job)
} # }
```
