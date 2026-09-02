# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

# The transport, exercised hermetically: a fake transport stands in for the
# service, so request shaping (URL, query metadata, auth, gzip) and response
# handling (result JSON, key mint, error conditions) run with no network.
#
#     Rscript tests/test-client.R

source(if (file.exists("tests/helper.R")) "tests/helper.R" else "helper.R")

# Reach package internals whether the sources were sourced or the package loaded.
internal <- function(name) {
  if (exists(name, envir = globalenv(), inherits = FALSE))
    get(name, envir = globalenv())
  else get(name, envir = asNamespace("quicopt"))
}
forget_session_key <- function() rm(list = ls(internal(".the")), envir = internal(".the"))

# A transport double: records every request, replays scripted responses.
recorder <- function(responses) {
  e <- new.env()
  e$requests <- list()
  e$i <- 0L
  e$fn <- function(req) {
    e$requests[[length(e$requests) + 1L]] <- req
    e$i <- e$i + 1L
    responses[[min(e$i, length(responses))]]
  }
  e
}

ok_response <- function(json, headers = list())
  list(status = 200L, headers = headers, body = charToRaw(json))

small_model <- function() {
  m <- model()
  x <- num_var(m, "x", 0, 4)
  maximize(m, 3 * x)
  add(m, x <= 2)
  m
}

# ── request shaping ─────────────────────────────────────────────────────────

forget_session_key()
m <- small_model()
rec <- recorder(list(ok_response(paste0('{"status":"optimal","objective":6.0,',
                                        '"solution":{"x":2.0},',
                                        '"solver_data":{"model_class":"milp"}}'))))
res <- solve_model(m, transport = rec$fn)
req <- rec$requests[[1]]

check("POST to /v1/solve with the front-end tag",
      identical(req$url, paste0(DEFAULT_BASE_URL, "/v1/solve?source_language=quicopt-r")))
check("the body is exactly the encoded model", identical(req$body, encode(m)))
check("the body is declared octet-stream",
      identical(req$headers[["Content-Type"]], "application/octet-stream"))
check("no Authorization before any key exists", is.null(req$headers[["Authorization"]]))
check("the result parses", res$status == "optimal" && res$objective == 6.0 &&
      identical(res$solution, c(x = 2.0)))
check("the model class is surfaced from solver_data",
      identical(res$model_class, "milp"))
rec2 <- recorder(list(ok_response('{"status":"optimal"}')))
check("an answer without solver_data has no model class",
      is.null(solve_model(m, transport = rec2$fn)$model_class))

# project and config metadata ride the query string, %20-escaped, never +
forget_session_key()
rec <- recorder(list(ok_response('{"status":"optimal"}')))
. <- solve_model(m, project = "proj A/1", transport = rec$fn)
check("project_id is %20-escaped",
      grepl("project_id=proj%20A%2F1", rec$requests[[1]]$url, fixed = TRUE))

rec <- recorder(list(ok_response('{"status":"optimal"}')))
. <- solve_model(m, config = list(source_language = "custom"), transport = rec$fn)
check("a caller's source_language wins",
      grepl("source_language=custom", rec$requests[[1]]$url, fixed = TRUE) &&
      !grepl("quicopt-r", rec$requests[[1]]$url, fixed = TRUE))

# encoded bytes solve like a model, with nothing to attribute
rec <- recorder(list(ok_response('{"status":"optimal"}')))
. <- solve_model(encode(m), transport = rec$fn)
check("raw bytes carry no source_language",
      identical(rec$requests[[1]]$url, paste0(DEFAULT_BASE_URL, "/v1/solve")))

# gzip: header set, body decompresses to the wire bytes
rec <- recorder(list(ok_response('{"status":"optimal"}')))
. <- solve_model(m, gzip = TRUE, transport = rec$fn)
req <- rec$requests[[1]]
check("gzip declares itself", identical(req$headers[["Content-Encoding"]], "gzip"))
check("the gzipped body inflates to the wire bytes",
      identical(memDecompress(req$body, type = "gzip"), encode(m)))

# ── the minted key ──────────────────────────────────────────────────────────

forget_session_key()
rec <- recorder(list(
  ok_response('{"status":"optimal"}', headers = list("x-quicopt-api-key" = "minted-1")),
  ok_response('{"status":"optimal"}')))
. <- solve_model(m, transport = rec$fn)
. <- solve_model(m, transport = rec$fn)
check("the minted key replays as a Bearer token",
      identical(rec$requests[[2]]$headers[["Authorization"]], "Bearer minted-1"))

# an explicit key is used as-is and never remembered
forget_session_key()
rec <- recorder(list(
  ok_response('{"status":"optimal"}', headers = list("x-quicopt-api-key" = "should-not-stick")),
  ok_response('{"status":"optimal"}', headers = list("x-quicopt-api-key" = "minted-2")),
  ok_response('{"status":"optimal"}')))
. <- solve_model(m, api_key = "my-own", transport = rec$fn)
. <- solve_model(m, transport = rec$fn)                 # keyless: mints
. <- solve_model(m, transport = rec$fn)                 # replays the mint
check("an explicit key is sent",
      identical(rec$requests[[1]]$headers[["Authorization"]], "Bearer my-own"))
check("an explicit key is never remembered",
      is.null(rec$requests[[2]]$headers[["Authorization"]]))
check("the later mint replays",
      identical(rec$requests[[3]]$headers[["Authorization"]], "Bearer minted-2"))

# a mint arriving on an error response still counts
forget_session_key()
rec <- recorder(list(
  list(status = 503L, headers = list("x-quicopt-api-key" = "minted-3"),
       body = charToRaw('{"reason":"queue_full","display":"try again"}')),
  ok_response('{"status":"optimal"}')))
try(solve_model(m, transport = rec$fn), silent = TRUE)
. <- solve_model(m, transport = rec$fn)
check("a key minted on an error response is kept",
      identical(rec$requests[[2]]$headers[["Authorization"]], "Bearer minted-3"))

# a held key is never overwritten by a later mint
forget_session_key()
rec <- recorder(list(
  ok_response('{"status":"optimal"}', headers = list("x-quicopt-api-key" = "first")),
  ok_response('{"status":"optimal"}', headers = list("x-quicopt-api-key" = "second")),
  ok_response('{"status":"optimal"}')))
. <- solve_model(m, transport = rec$fn)
. <- solve_model(m, transport = rec$fn)
. <- solve_model(m, transport = rec$fn)
check("the first key wins",
      identical(rec$requests[[3]]$headers[["Authorization"]], "Bearer first"))

# ── errors ──────────────────────────────────────────────────────────────────

forget_session_key()
rec <- recorder(list(list(status = 422L, headers = list(),
  body = charToRaw('{"reason":"unsupported_model","display":"the model uses an operator the free tier does not solve"}'))))
cond <- tryCatch(solve_model(m, transport = rec$fn), quicopt_error = function(e) e)
check("a refusal is a quicopt_error condition", inherits(cond, "quicopt_error"))
check("it carries the stable reason code", identical(cond$reason, "unsupported_model"))
check("its message is the service's display",
      identical(conditionMessage(cond), "the model uses an operator the free tier does not solve"))
check("the status rides along", cond$status == 422L)

rec <- recorder(list(list(status = 500L, headers = list(), body = charToRaw("not json"))))
cond <- tryCatch(solve_model(m, transport = rec$fn), quicopt_error = function(e) e)
check("an opaque failure still raises cleanly", grepl("HTTP 500", conditionMessage(cond)))

# a vector variable's solution comes back under its flat names
forget_session_key()
rec <- recorder(list(ok_response(
  '{"status":"optimal","solution":{"xs[1]":1.0,"xs[2]":2.0,"xs[3]":3.0}}')))
mv <- model(); xs <- num_var(mv, "xs", 0, 5, n = 3); minimize(mv, sum(xs));
res <- solve_model(mv, transport = rec$fn)
check("family values come back keyed by flat names",
      identical(res$solution, c("xs[1]" = 1.0, "xs[2]" = 2.0, "xs[3]" = 3.0)))

# ── asynchronous jobs ───────────────────────────────────────────────────────

# submit: body, path, and the key echoed in the accepted-response JSON
forget_session_key()
rec <- recorder(list(
  list(status = 202L, headers = list(),
       body = charToRaw('{"job_id":"j-7","api_key":"minted-body"}')),
  ok_response('{"state":"running","log_tail":"..."}')))
job <- submit(m, transport = rec$fn)
st <- job_status(job)
check("submit POSTs the wire bytes to /v1/jobs",
      identical(rec$requests[[1]]$url, paste0(DEFAULT_BASE_URL, "/v1/jobs?source_language=quicopt-r")) &&
      identical(rec$requests[[1]]$body, encode(m)))
check("the handle carries the job id", inherits(job, "quicopt_job") && job$job_id == "j-7")
check("a key echoed in the job body is adopted",
      identical(rec$requests[[2]]$headers[["Authorization"]], "Bearer minted-body"))
check("job_status GETs the job, bodyless",
      identical(rec$requests[[2]]$url, paste0(DEFAULT_BASE_URL, "/v1/jobs/j-7")) &&
      is.null(rec$requests[[2]]$body) &&
      is.null(rec$requests[[2]]$headers[["Content-Type"]]))
check("job_status parses the state", st$state == "running")

# job_result polls past not_done, then parses the finished solve
not_done <- list(status = 409L, headers = list(),
                 body = charToRaw('{"reason":"not_done"}'))
forget_session_key()
rec <- recorder(list(
  list(status = 202L, headers = list(), body = charToRaw('{"job_id":"j-8"}')),
  not_done, not_done,
  ok_response('{"status":"optimal","objective":6.0,"solution":{"x":2.0}}')))
job <- submit(m, transport = rec$fn)
res <- job_result(job, poll = 0.01)
check("job_result polls past not_done",
      length(rec$requests) == 4 && res$status == "optimal" && res$objective == 6.0)
check("the polls hit the result endpoint",
      identical(rec$requests[[3]]$url, paste0(DEFAULT_BASE_URL, "/v1/jobs/j-8/result")))

# wait = FALSE surfaces not_done instead of polling
forget_session_key()
rec <- recorder(list(list(status = 202L, headers = list(), body = charToRaw('{"job_id":"j-9"}')),
                     not_done))
job <- submit(m, transport = rec$fn)
cond <- tryCatch(job_result(job, wait = FALSE), quicopt_error = function(e) e)
check("wait = FALSE raises not_done once", identical(cond$reason, "not_done") &&
      length(rec$requests) == 2)

# a real failure is never polled past
forget_session_key()
rec <- recorder(list(list(status = 202L, headers = list(), body = charToRaw('{"job_id":"j-10"}')),
                     list(status = 500L, headers = list(),
                          body = charToRaw('{"reason":"worker_crashed","display":"the job failed"}'))))
job <- submit(m, transport = rec$fn)
cond <- tryCatch(job_result(job, poll = 0.01), quicopt_error = function(e) e)
check("a non-not_done error propagates immediately",
      identical(cond$reason, "worker_crashed") && length(rec$requests) == 2)

# log and delete address their endpoints with the right methods
forget_session_key()
rec <- recorder(list(list(status = 202L, headers = list(), body = charToRaw('{"job_id":"j-11"}')),
                     list(status = 200L, headers = list(), body = charToRaw("the log text")),
                     list(status = 200L, headers = list(), body = raw(0))))
job <- submit(m, transport = rec$fn)
check("job_log returns the text", identical(job_log(job), "the log text"))
job_delete(job)
check("job_delete DELETEs the job",
      rec$requests[[3]]$method == "DELETE" &&
      identical(rec$requests[[3]]$url, paste0(DEFAULT_BASE_URL, "/v1/jobs/j-11")))

forget_session_key()
cat("client: all green\n")
