# Poll a submitted job

`job_status` fetches the job's state (`queued`, `running`, `done`,
`failed`) and its log tail. `job_result` fetches the finished solve,
polling past the service's `not_done` answer until the worker finishes.
`job_log` fetches the plain-text log, and `job_delete` removes the job
and its stored result from the service.

## Usage

``` r
job_status(job)

job_result(job, wait = TRUE, timeout = 120, poll = 0.5)

job_log(job)

job_delete(job)
```

## Arguments

- job:

  A `quicopt_job` from
  [`submit()`](https://quicopt.github.io/quicopt-r/reference/submit.md).

- wait:

  Poll until the job is done (`TRUE`), or fetch exactly once.

- timeout:

  Maximum seconds to keep polling before giving up.

- poll:

  Seconds between polls.

## Value

`job_status` returns the service's job state as a list.

`job_result` returns the finished solve as a `quicopt_result`.

`job_log` returns the log as a single string.

`job_delete` returns `NULL`, invisibly.
