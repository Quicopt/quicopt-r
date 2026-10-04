# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

# Both functions here send a model whose every decision variable is pinned to
# a given value. The service then has one point to look at, and what it
# reports about that point (objective, feasibility, the chance levels) is the
# evaluation. The wire has carried pins since its first version (`fix`), so no
# new vocabulary is involved; the cost is one request per evaluation.

# The model lowered with every decision variable pinned at the solution.
# Integer and binary values are rounded first: a pin is lower = upper = value,
# and an integer variable pinned between two integers has no feasible value.
# A permutation is pinned by declaring it fixed at the order the result
# reports, so a model with one takes a solve() result, not a bare vector.
.pinned_program <- function(m, solution, caller) {
  slots <- .result_slots(m, solution, caller)
  values <- .solution_values(m, solution, complete = TRUE, caller = caller)
  prog <- as_program(m)
  prog$fix <- lapply(prog$vars, function(vd) {
    v <- as.numeric(values[[vd$name]])
    if (vd$domain != CONTINUOUS) v <- round(v)
    if (v < vd$lower || v > vd$upper)
      stop(caller, ": the value ", v, " for '", vd$name, "' lies outside its bounds [",
           vd$lower, ", ", vd$upper, "]")
    list(var = vd$name, index = list(), value = v)
  })
  for (name in names(slots)) {
    prog$structures[[name]]$start <- slots[[name]]
    prog$structures[[name]]$fixed <- TRUE
  }
  prog
}

# The request metadata for a program sent on a model's behalf: the front-end
# tag the model itself would carry, unless the caller's config set one.
.tagged <- function(config) {
  if (is.null(config)) config <- list()
  if (is.null(config$source_language)) config$source_language <- .SOURCE_LANGUAGE
  config
}

#' The value of an expression at a solution
#'
#' A solve returns the values of the variables and of the objective. For any
#' other quantity of the model, the shortfall the solution leaves, a
#' probability it reaches, a cost it incurs, `evaluate()` computes the value
#' at that solution on the model's own scenarios.
#'
#' The expression cannot be random: close it over the scenarios first, as for
#' an objective. With a `seed`, the value is computed on fresh scenarios
#' instead of the model's own, which is how a probability or an expected cost
#' is checked out of sample (see [resample()] for the rules on fresh
#' scenarios). Each call is one request to the service.
#'
#' @param m A [model()].
#' @param solution A result from [solve()], or a named numeric vector giving
#'   every decision variable's value (`"x"`, or `"x[1]"`, `"x[2]"`, ... for a
#'   vector variable). A model with a permutation ([perm_var()]) takes a
#'   result, which carries the order found.
#' @param expr A single non-random model expression.
#' @param seed Left `NULL`, the model's own scenarios; given, a seed for fresh
#'   ones.
#' @param scenarios With `seed`: how many fresh scenarios to draw (default: as
#'   many as the model has).
#' @param ... Connection settings, passed on to [solve_model()]: `base_url`,
#'   `api_key`, `project`, `config`, `gzip`, `timeout`, `transport`.
#' @return The expression's value, a number.
#' @examples
#' \dontrun{
#' res <- solve(m)
#' evaluate(m, res, prob(demand - x <= 0))              # the service level reached
#' evaluate(m, res, prob(demand - x <= 0), seed = 2)    # and on fresh scenarios
#' evaluate(m, res, expectation(max(demand - x, 0)))    # the expected shortfall
#' }
#' @export
evaluate <- function(m, solution, expr, seed = NULL, scenarios = NULL, ...) {
  .check_model(m, "evaluate")
  node <- .need_closed(.scalar_node(expr, "expression"), "expression")
  prog <- .pinned_program(m, solution, "evaluate")
  if (!is.null(seed)) prog <- .fresh_scenarios(m, prog, seed, scenarios)
  else if (!is.null(scenarios)) stop("scenarios goes with a seed for fresh draws")
  prog$objective <- node
  prog$sense <- "min"
  prog$constraints <- list()
  .solve_tagged(prog, ...)$objective
}

#' Check a solution on scenarios it was not optimized for
#'
#' The objective and the chance levels a solve reports are measured on the
#' scenarios the solve saw, the ones that shaped the solution. On fresh
#' scenarios a solution does worse, and a chance constraint that was just
#' satisfied is missed about half the time. `resample()` draws fresh scenarios
#' from a new seed, holds the solution fixed, and evaluates the model's
#' objective and constraints on them: the out-of-sample check.
#'
#' Only the random variables with a distribution are redrawn. An
#' [empirical()] column is data and stays as it is, so a model whose
#' uncertainty is entirely empirical has nothing to resample, and the scenario
#' count cannot change while any such column is present. Each call is one
#' request to the service.
#'
#' @param m A [model()].
#' @param solution A result from [solve()], or a named numeric vector giving
#'   every decision variable's value.
#' @param seed The seed for the fresh scenarios, different from the model's.
#' @param scenarios How many to draw; left `NULL`, as many as the model has.
#'   More scenarios give a sharper out-of-sample estimate.
#' @param ... Connection settings, passed on to [solve_model()].
#' @return A `quicopt_result` for the pinned solution on the fresh scenarios:
#'   `objective` is the out-of-sample objective, `feasible` says whether every
#'   constraint still holds, and `solver_data$max_violation` is the largest
#'   amount by which one is missed (for a chance constraint, in units of
#'   probability).
#' @examples
#' \dontrun{
#' res <- solve(m)                    # in sample: objective, feasible = TRUE
#' chk <- resample(m, res, seed = 7)  # out of sample, same solution
#' chk$objective
#' chk$feasible                       # does the chance constraint still hold?
#' chk$solver_data$max_violation      # if not, by how much
#' }
#' @export
resample <- function(m, solution, seed, scenarios = NULL, ...) {
  .check_model(m, "resample")
  prog <- .fresh_scenarios(m, .pinned_program(m, solution, "resample"), seed, scenarios)
  .solve_tagged(prog, ...)
}

# A pinned program on fresh scenarios: a new seed, and optionally a new count.
# Only distributions are redrawn, so a model without one has nothing fresh to
# offer, and an empirical column fixes the count.
.fresh_scenarios <- function(m, prog, seed, scenarios) {
  if (!is.numeric(seed) || length(seed) != 1L || is.na(seed) || seed < 1 || seed != trunc(seed))
    stop("the seed is a whole number of at least 1")
  specs <- .m_get(m, "sources")
  parametric <- vapply(specs, inherits, NA, "quicopt_distribution")
  if (!any(parametric))
    stop("nothing to redraw: ",
         if (length(specs)) "every random variable is an empirical column, which is data, not draws"
         else "the model has no random variable")
  if (!is.null(scenarios)) {
    if (!is.numeric(scenarios) || length(scenarios) != 1L || is.na(scenarios) ||
        scenarios < 1 || scenarios != trunc(scenarios))
      stop("a model is solved over a whole number of scenarios, at least 1")
    if (!all(parametric))
      stop("the scenario count is fixed by the model's empirical columns and cannot change")
    prog$scenarios <- as.numeric(scenarios)
  }
  if (seed == prog$scenario_seed && is.null(scenarios))
    stop("the seed ", seed, " is the model's own; fresh scenarios need a different one")
  prog$scenario_seed <- as.numeric(seed)
  prog
}

# solve_model on a program, carrying the model's front-end tag.
.solve_tagged <- function(prog, ..., config = NULL)
  solve_model(prog, ..., config = .tagged(config))
