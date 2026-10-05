# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

#' The address of the public Quicopt service
#'
#' [solve()] and [submit()] send models to this address unless they are given
#' another `base_url`.
#'
#' @return Not a function but a constant: a character string, the address of
#'   the public service.
#' @examples
#' DEFAULT_BASE_URL
#' @export
DEFAULT_BASE_URL <- "https://try.quicoptapi.pgi.fz-juelich.de"

# The source_language tag names the front-end a model was written in, and this
# package's interface is one. A caller-supplied value in `config` wins.
.SOURCE_LANGUAGE <- "quicopt-r"

# Session state: a key minted by the first keyless call, replayed for the rest
# of the session. Deliberately memory-only — nothing is written to the user's
# filespace.
.the <- new.env(parent = emptyenv())

#' Solve a model
#'
#' `solve()` sends a model to the Quicopt service, waits for the answer, and
#' returns it as a list (see the Value section). `solve_model()` is the same
#' function under a name that cannot be confused with base R's `solve()`,
#' which can read better in a pipe.
#'
#' `solve()` waits for up to `timeout` seconds. For a model that takes
#' longer, [submit()] sends it without waiting.
#'
#' @section API keys:
#' The service needs an API key. The first time a model is solved in an R
#' session without one, the service issues a free key, and quicopt keeps it
#' in memory until the session ends; it is never written to disk. To use a
#' key of your own, pass it as `api_key`. It is then used for that call only,
#' and not kept.
#'
#' @section Status:
#' `status` says what kind of answer the result holds:
#'
#' * `"optimal"`: the service has proved that no better solution exists.
#' * `"heuristic"`: the best solution a search found, without that proof.
#'   Models with random variables, permutations or lookup tables are solved
#'   this way. If such a result has `feasible = FALSE`, the search found no
#'   solution that meets every constraint, which does not prove that none
#'   exists.
#'
#' Other values say why no solution is available.
#'
#' @param m A [model()]. A [program()], or the bytes from [encode()], also
#'   work.
#' @param base_url The address of the service.
#' @param api_key Your API key, or `NULL` to use the session's free key (see
#'   the API keys section).
#' @param project A project name, for billing by project, or `NULL`.
#' @param config A named list of further settings, sent to the service as
#'   query parameters.
#' @param gzip Whether to compress the model before sending it; worth it for
#'   a large model.
#' @param timeout How many seconds to wait for the answer.
#' @param transport For tests: a function that is called instead of sending
#'   the request. It takes a list with the elements `method`, `url`,
#'   `headers`, `body` and `timeout`, and returns a list with the elements
#'   `status`, `headers` and `body`.
#' @return A list of class `quicopt_result`, with these elements:
#'
#'   * `status`: what kind of answer it is (see the Status section).
#'   * `feasible`: whether the solution meets every constraint.
#'   * `objective`: the value of the objective at the solution.
#'   * `solution`: a named numeric vector with the value of each decision
#'     variable, in the order they were declared.
#'   * `structures`: for a model with permutations, one element per
#'     permutation, holding the integer vectors `item_at` and `slot_of` (see
#'     [perm_var()]); otherwise `NULL`.
#'   * `model_class`: the kind of model the service recognized, such as
#'     `"lp"`, `"milp"` or `"stochastic"`.
#'   * `solver_data`: further details from the service, such as
#'     `max_violation`, by how much the worst constraint is missed.
#'   * `display`: a summary prepared by the service, which is what printing
#'     the result shows.
#' @examples
#' \dontrun{
#' m <- model()
#' tables <- int_var(m, "tables", lower = 0)
#' chairs <- int_var(m, "chairs", lower = 0)
#' maximize(m, 50 * tables + 20 * chairs)
#' add(m, 3 * tables + chairs <= 41)
#' add(m, tables + chairs <= 18)
#'
#' res <- solve(m)
#' res$status
#' res$solution
#' res
#' }
#' @export
solve_model <- function(m, base_url = DEFAULT_BASE_URL, api_key = NULL,
                        project = NULL, config = NULL, gzip = FALSE,
                        timeout = 60, transport = NULL) {
  resp <- .request(base_url, "POST", "/v1/solve",
                   body = if (is.raw(m)) m else encode(m),
                   meta = .meta_config(m, project, config), gzip = gzip,
                   api_key = api_key, timeout = timeout, transport = transport)
  .parse_result(resp$body, .declared(m))
}

# The decision variables' wire names in the order they were declared: the order
# a solution is handed back in. The service answers with a JSON object, whose
# order is its own, and in an R vector position means something, so that
# `which(res$solution == 1)` had better count the way the model was written.
# Raw bytes carry no order this side can read without decoding them.
.declared <- function(m) {
  if (inherits(m, "quicopt_model")) m <- as_program(m)
  if (!inherits(m, "quicopt_program")) return(NULL)
  vapply(m$vars, function(v) v$name, "")
}

#' @rdname solve_model
#' @param a The model. The argument is called `a` because base R's `solve()`
#'   calls it that.
#' @param b Not used; giving it is an error.
#' @param ... Further arguments for `solve_model()`, by name.
#' @export
solve.quicopt_model <- function(a, b, ...) {
  if (!missing(b))
    stop("solve() for a quicopt model takes the model alone; pass options by name")
  solve_model(a, ...)
}

# ── asynchronous jobs ───────────────────────────────────────────────────────

#' Solve a model without waiting
#'
#' `submit()` sends a model to the service like [solve()] does, but returns
#' at once with a *job*, while the service solves the model in the
#' background and your R session can go on. [job_result()] collects the
#' answer when it is ready, and [job_status()] shows how far the job has got.
#'
#' The job keeps the address, the key and the other settings it was submitted
#' with, so the functions that follow it up need only the job.
#'
#' @inheritParams solve_model
#' @return A job, of class `quicopt_job`, for [job_result()], [job_status()],
#'   [job_log()] and [job_delete()].
#' @examples
#' \dontrun{
#' job <- submit(m)
#' job_status(job)$status
#' res <- job_result(job)        # waits until the job is finished
#' }
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
                 api_key = api_key, timeout = timeout, transport = transport,
                 declared = .declared(m)),
            class = "quicopt_job")
}

#' Follow up a submitted job
#'
#' * `job_status()` returns the job's state, `"queued"`, `"running"`,
#'   `"done"` or `"failed"`, together with the last lines of its log.
#' * `job_result()` returns the answer of the job, in the same form as
#'   [solve()]. By default it waits for the job to finish, checking every
#'   `poll` seconds for up to `timeout` seconds.
#' * `job_log()` returns the job's log as text.
#' * `job_delete()` deletes the job and its stored answer from the service.
#'
#' @param job A job, as returned by [submit()].
#' @return `job_status()` returns the job's state as a list.
#' @examples
#' \dontrun{
#' job <- submit(m)
#' job_status(job)
#' res <- job_result(job)
#' job_delete(job)
#' }
#' @export
job_status <- function(job) .job_json(job, "GET", "")

#' @rdname job_status
#' @param wait `TRUE` waits until the job is finished. `FALSE` asks once, and
#'   is an error if the job is not finished yet.
#' @param timeout How many seconds to wait at most.
#' @param poll How many seconds to wait between two checks.
#' @return `job_result()` returns the answer, a list of class
#'   `quicopt_result` (see [solve()]).
#' @export
job_result <- function(job, wait = TRUE, timeout = 120, poll = 0.5) {
  deadline <- Sys.time() + timeout
  repeat {
    resp <- tryCatch(.job_request(job, "GET", "/result"),
                     quicopt_error = function(e) e)
    if (!inherits(resp, "quicopt_error")) return(.parse_result(resp$body, job$declared))
    if (!wait || !identical(resp$reason, "not_done") || Sys.time() > deadline)
      stop(resp)
    Sys.sleep(poll)
  }
}

#' @rdname job_status
#' @return `job_log()` returns the log as a single character string.
#' @export
job_log <- function(job)
  rawToChar(.job_request(job, "GET", "/log")$body)

#' @rdname job_status
#' @return `job_delete()` returns `NULL`, invisibly.
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
# raising, and the solution becomes a named numeric vector, the `declared`
# names first and in that order, any other name after them as it arrived.
.parse_result <- function(body, declared = NULL) {
  parsed <- jsonlite::fromJSON(rawToChar(body), simplifyVector = FALSE)
  solution <- if (is.null(parsed$solution)) NULL else unlist(parsed$solution)
  if (length(solution) && length(declared)) {
    known <- intersect(declared, names(solution))
    solution <- solution[c(known, setdiff(names(solution), known))]
  }
  structure(list(status = parsed$status,
                 objective = parsed$objective,
                 feasible = parsed$feasible,
                 solution = solution,
                 # The class the service read the model as. It travels inside
                 # solver_data; the sibling clients surface it at the top level,
                 # and so does this one.
                 model_class = parsed$solver_data$model_class,
                 # The permutations found, both views as integer vectors; the
                 # key is absent for a model that declares none.
                 structures = .parse_structures(parsed$structures),
                 solve_time_seconds = parsed$solve_time_seconds,
                 solver_data = parsed$solver_data,
                 display = parsed$display,
                 job_id = parsed$job_id),
            class = "quicopt_result")
}

.parse_structures <- function(s) {
  if (is.null(s)) return(NULL)
  lapply(s, function(p) list(item_at = as.integer(unlist(p$item_at)),
                             slot_of = as.integer(unlist(p$slot_of))))
}

#' @export
print.quicopt_result <- function(x, ...) {
  if (!is.null(x$display)) cat(x$display, "\n", sep = "")
  else {
    cat("quicopt result: ", x$status,
        if (!is.null(x$objective)) paste0(", objective ", x$objective), "\n", sep = "")
    for (name in names(x$structures))
      cat("  ", name, ": item_at = [", paste(x$structures[[name]]$item_at, collapse = ", "),
          "]\n", sep = "")
  }
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
