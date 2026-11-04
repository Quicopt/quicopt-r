# CRAN comments

## Version 0.2.0

A feature release. The package gains the means to check a solution on
scenarios it was not optimized for (`resample()`, `evaluate()`), a safety
margin on chance constraints, comparisons as 0/1 expressions (`holds()`),
switched constraints, warm starts and vector random variables, and fixes three
defects: `-x` and `prod()` over three or more elements encoded shapes the
service refused, and a vector compared with a scalar added one row instead
of one per element. `NEWS.md` lists everything. The arrangements below for
examples, the vignette and the tests are unchanged.

## Submission

New submission. `quicopt` is a client for a hosted optimization service: it
builds a model in R, encodes it, and sends it to the service to be solved.

## Test environments

* macOS 15, R 4.6.1 (local)
* Windows, R 4.5.3, R 4.6.1, R 4.7.0 (devel) — via r-universe
* Linux, R 4.6.1, R 4.7.0 (devel) — via r-universe
* macOS, R 4.5.3, R 4.6.1 — via r-universe
* Ubuntu, R release — GitHub Actions

## R CMD check results

0 errors | 0 warnings | 1 note

The note is the one every first-time submission gets:

    Maintainer: 'Tim Bode <t.bode@fz-juelich.de>'
    New submission

## Notes for the reviewer

The package talks to a remote service, so three things are arranged to keep
checks self-contained:

* **Examples that would contact the service are wrapped in `\dontrun{}`.** They
  cannot succeed without network access, and running them would mint and consume
  a key on the service. Examples that need no network are left runnable.

* **The vignette is pre-computed.** `vignettes/stochastic.Rmd` contains no
  executable chunk. It is generated from `stochastic.Rmd.orig` by
  `tools/precompute-vignette.R`, which runs the solves against the live service
  at release time and bakes their output in. Building the vignette therefore
  needs no network.

* **The tests are offline.** The HTTP layer sits behind a replaceable transport
  argument, and the test suite drives a recorded stand-in, so `R CMD check`
  performs no network access at all.

**Nothing is written to the user's filespace.** The package reads the user's API key from the `api_key` argument or from the environment variable `QUICOPT_API_KEY`, which the user sets, for example in `~/.Renviron`. It never writes the key, or anything else, to disk, and leaves no file, option or environment variable behind.

No solver is bundled or required on the user's machine; the package only
encodes a model and posts it.
