# CRAN comments

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

**Nothing is written to the user's filespace.** The service mints an API key on
a first keyless call; the package keeps it in memory for the session only and
never writes it to disk, so no file, option or environment variable is left
behind. A fresh session mints a fresh key.

No solver is bundled or required on the user's machine; the package only
encodes a model and posts it.
