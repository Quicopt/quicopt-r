# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

#' The public Quicopt endpoint
#'
#' [solve()] targets it unless another `base_url` is given.
#' @export
DEFAULT_BASE_URL <- "https://try.quicoptapi.pgi.fz-juelich.de"

# The source_language tag names the front-end a model was written in, and this
# package's interface is one. A caller-supplied value in `config` wins.
.SOURCE_LANGUAGE <- "quicopt-r"

# Session state: a key minted by the first keyless call, replayed for the rest
# of the session. Deliberately memory-only — nothing is written to the user's
# filespace.
.the <- new.env(parent = emptyenv())

#' Solve a model with the Quicopt service
#'
#' Encodes the model, sends it, and returns the parsed result. The first
#' keyless call mints an API key, remembered for the rest of the R session;
#' pass `api_key` to authenticate with a key you already hold (used as-is,
#' never remembered).
#'
#' `solve(m)` and `solve_model(m)` are the same function — the former extends
#' the `base::solve` generic (as `solve.qr` does), the latter is the
#' unambiguous name for pipes and for reading. For a long-running model, or a
#' first call against a cold worker, [submit()] queues the same request
#' asynchronously instead of blocking.
#'
#' @param m A [model()], a [program()], or already-encoded bytes.
#' @param base_url The service to talk to; defaults to [DEFAULT_BASE_URL].
#' @param api_key A key you hold, or `NULL` to mint and reuse a free-tier key.
#' @param project A project tag for per-project invoicing, or `NULL`.
#' @param config Named list of extra query parameters; a `source_language`
#'   here overrides the automatic tag.
#' @param gzip Compress the request body.
#' @param timeout Seconds to wait for the service.
#' @param transport The HTTP layer, replaceable for testing: a
#'   `function(req)` taking `list(method, url, headers, body, timeout)` and
#'   returning `list(status, headers, body)`.
#' @return The service's answer as a `quicopt_result`: a list with `status`,
#'   `objective`, `feasible`, `solution` (a named numeric vector), and the
#'   ready-to-print `display`. Printing the result prints `display`.
#' @export
solve_model <- function(m, base_url = DEFAULT_BASE_URL, api_key = NULL,
                        project = NULL, config = NULL, gzip = FALSE,
                        timeout = 60, transport = NULL) {
  resp <- .request(base_url, "POST", "/v1/solve",
                   body = if (is.raw(m)) m else encode(m),
                   meta = .meta_config(m, project, config), gzip = gzip,
                   api_key = api_key, timeout = timeout, transport = transport)
  .parse_result(resp$body)
}

#' @rdname solve_model
#' @param a The model (the argument is named `a` to match the `solve` generic).
#' @param b Unused; supplying it is an error.
#' @param ... Passed on to [solve_model()].
#' @export
solve.quicopt_model <- function(a, b, ...) {
  if (!missing(b))
    stop("solve() for a quicopt model takes the model alone; pass options by name")
  solve_model(a, ...)
}

# ── asynchronous jobs ───────────────────────────────────────────────────────

#' Submit a model for asynchronous solving
#'
#' Queues the model and returns immediately with a job handle; the solve runs
#' on the service while your session goes on. Await it with [job_result()],
#' peek with [job_status()] or [job_log()], and discard it with [job_delete()].
#' The arguments are those of [solve_model()]; the handle keeps the connection
#' settings, so the polling calls need none of them repeated.
#'
#' @inheritParams solve_model
#' @return A `quicopt_job` handle.
#' @export
submit <- function(m, base_url = DEFAULT_BASE_URL, api_key = NULL,
                   project = NULL, config = NULL, gzip = FALSE,
                   timeout = 60, transport = NULL) {
  resp <- .request(base_url, "POST", "/v1/jobs",
                   body = if (is.raw(m)) m else encode(m),
                   meta = .meta_config(m, project, config), gzip = gzip,
                   api_key = api_key, timeout = timeout, transport = transport)
  parsed <- jsonlite::fromJSON(rawToChar(resp$body), simplifyVector = FALSE)
  # /v1/jobs echoes a minted key in the accepted-response body as well as the
  # header; adopt it under the same rules (never over an explicit or held key).
  .adopt_key(parsed$api_key, explicit = !is.null(api_key))
  if (is.null(parsed$job_id)) stop("the service accepted the job but returned no job_id")
  structure(list(job_id = parsed$job_id, base_url = base_url,
                 api_key = api_key, timeout = timeout, transport = transport),
            class = "quicopt_job")
}

#' Poll a submitted job
#'
#' `job_status` fetches the job's state (`queued`, `running`, `done`,
#' `failed`) and its log tail. `job_result` fetches the finished solve,
#' polling past the service's `not_done` answer until the worker finishes.
#' `job_log` fetches the plain-text log, and `job_delete` removes the job and
#' its stored result from the service.
#'
#' @param job A `quicopt_job` from [submit()].
#' @return `job_status` returns the service's job state as a list.
#' @export
job_status <- function(job) .job_json(job, "GET", "")

#' @rdname job_status
#' @param wait Poll until the job is done (`TRUE`), or fetch exactly once.
#' @param timeout Maximum seconds to keep polling before giving up.
#' @param poll Seconds between polls.
#' @return `job_result` returns the finished solve as a `quicopt_result`.
#' @export
job_result <- function(job, wait = TRUE, timeout = 120, poll = 0.5) {
  deadline <- Sys.time() + timeout
  repeat {
    resp <- tryCatch(.job_request(job, "GET", "/result"),
                     quicopt_error = function(e) e)
    if (!inherits(resp, "quicopt_error")) return(.parse_result(resp$body))
    if (!wait || !identical(resp$reason, "not_done") || Sys.time() > deadline)
      stop(resp)
    Sys.sleep(poll)
  }
}

#' @rdname job_status
#' @return `job_log` returns the log as a single string.
#' @export
job_log <- function(job)
  rawToChar(.job_request(job, "GET", "/log")$body)

#' @rdname job_status
#' @return `job_delete` returns `NULL`, invisibly.
#' @export
job_delete <- function(job) {
  .job_request(job, "DELETE", "")
  invisible(NULL)
}

#' @export
print.quicopt_job <- function(x, ...) {
  cat("quicopt job ", x$job_id, " at ", x$base_url, "\n", sep = "")
  invisible(x)
}

# One bodyless request against a job's endpoint, using the handle's settings.
.job_request <- function(job, method, tail) {
  if (!inherits(job, "quicopt_job"))
    stop("expected a quicopt_job from submit(), got ", class(job)[[1L]])
  .request(job$base_url, method, paste0("/v1/jobs/", job$job_id, tail),
           api_key = job$api_key, timeout = job$timeout, transport = job$transport)
}

# A job request whose body is the service's JSON, parsed.
.job_json <- function(job, method, tail)
  jsonlite::fromJSON(rawToChar(.job_request(job, method, tail)$body),
                     simplifyVector = FALSE)

# ── the request core ────────────────────────────────────────────────────────

# One request against the service: shape it, send it through the transport,
# adopt any minted key (error responses included), and raise a structured
# condition on a non-2xx answer. Every endpoint above goes through here.
.request <- function(base_url, method, path, body = NULL, meta = list(),
                     gzip = FALSE, api_key = NULL, timeout = 60,
                     transport = NULL) {
  req <- .shape_request(paste0(base_url, path), method, meta, body, gzip,
                        api_key, timeout)
  resp <- (if (is.null(transport)) .curl_transport else transport)(req)
  .adopt_key(resp$headers[["x-quicopt-api-key"]], explicit = !is.null(api_key))
  if (resp$status < 200L || resp$status > 299L) .quicopt_stop(resp)
  resp
}

# The per-call metadata, sent as query parameters and never inside the encoded
# model: the caller's config first, then the automatic source_language unless
# the config already set one, then the project id.
.meta_config <- function(m, project, config) {
  meta <- if (is.null(config)) list() else {
    if (is.null(names(config)) || any(!nzchar(names(config))))
      stop("config must be a fully named list")
    config
  }
  if (inherits(m, "quicopt_model") && is.null(meta$source_language))
    meta$source_language <- .SOURCE_LANGUAGE
  if (!is.null(project)) meta$project_id <- project
  meta
}

# The query string, percent-escaped with %20 (never +) — the cross-client rule;
# URLencode(reserved = TRUE) does exactly that.
.query <- function(meta) {
  if (length(meta) == 0L) return("")
  esc <- function(s) utils::URLencode(as.character(s), reserved = TRUE)
  paste0("?", paste0(vapply(names(meta), esc, ""), "=",
                     vapply(meta, esc, ""), collapse = "&"))
}

# One shaped HTTP request: URL with query, headers (a named list, so an absent
# header reads as NULL), and the possibly compressed body (NULL for a bodyless
# request, which then carries no content headers). The key used is an explicit
# one, else the session's.
.shape_request <- function(url, method, meta, body, gzip, api_key, timeout) {
  headers <- list()
  if (!is.null(body)) {
    headers[["Content-Type"]] <- "application/octet-stream"
    if (gzip) {
      body <- memCompress(body, type = "gzip")
      headers[["Content-Encoding"]] <- "gzip"
    }
  }
  key <- if (!is.null(api_key)) api_key else .the$key
  if (!is.null(key)) headers[["Authorization"]] <- paste("Bearer", key)
  list(method = method, url = paste0(url, .query(meta)),
       headers = headers, body = body, timeout = timeout)
}

# Adopt a key the service minted (the response header carries it — on error
# responses too — and an accepted job echoes it in its body). A key the caller
# passed explicitly is theirs and is never remembered; a key already held is
# never overwritten.
.adopt_key <- function(minted, explicit) {
  if (!explicit && is.null(.the$key) && !is.null(minted) && nzchar(minted))
    .the$key <- minted
  invisible(NULL)
}

# ── the HTTP layer ──────────────────────────────────────────────────────────

# The real transport: one curl request, returning status, lower-cased headers
# and the raw body. Everything above it is exercised hermetically by swapping
# this function out.
.curl_transport <- function(req) {
  h <- curl::new_handle()
  curl::handle_setopt(h, customrequest = req$method, timeout = req$timeout)
  if (!is.null(req$body)) curl::handle_setopt(h, postfields = req$body)
  if (length(req$headers)) curl::handle_setheaders(h, .list = req$headers)
  resp <- curl::curl_fetch_memory(req$url, handle = h)
  list(status = resp$status_code,
       headers = curl::parse_headers_list(resp$headers),
       body = resp$content)
}

# ── the answer ──────────────────────────────────────────────────────────────

# The service's JSON, decoded leniently: absent fields stay NULL rather than
# raising, and the solution becomes a named numeric vector.
.parse_result <- function(body) {
  parsed <- jsonlite::fromJSON(rawToChar(body), simplifyVector = FALSE)
  solution <- if (is.null(parsed$solution)) NULL else unlist(parsed$solution)
  structure(list(status = parsed$status,
                 objective = parsed$objective,
                 feasible = parsed$feasible,
                 solution = solution,
                 solve_time_seconds = parsed$solve_time_seconds,
                 solver_data = parsed$solver_data,
                 display = parsed$display,
                 job_id = parsed$job_id),
            class = "quicopt_result")
}

#' @export
print.quicopt_result <- function(x, ...) {
  if (!is.null(x$display)) cat(x$display, "\n", sep = "")
  else cat("quicopt result: ", x$status,
           if (!is.null(x$objective)) paste0(", objective ", x$objective), "\n", sep = "")
  invisible(x)
}

# A non-2xx answer as a structured condition: the service's stable `reason`
# code and its ready-to-print `display`, plus the raw body for anything else.
.quicopt_stop <- function(resp) {
  parsed <- tryCatch(jsonlite::fromJSON(rawToChar(resp$body), simplifyVector = FALSE),
                     error = function(e) NULL)
  reason <- parsed$reason
  display <- parsed$display
  message <- if (!is.null(display)) display
             else if (!is.null(reason)) paste0("the service refused the request: ", reason)
             else paste0("HTTP ", resp$status)
  stop(structure(class = c("quicopt_error", "error", "condition"),
                 list(message = message, call = NULL,
                      status = resp$status, reason = reason,
                      display = display, body = resp$body)))
}
