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

#' Compute a quantity at a given solution
#'
#' A solve reports the values of the decision variables and of the
#' objective. `evaluate()` computes any other quantity of the model at a
#' given solution: the share of scenarios in which demand is met, the average
#' shortfall, the cost of a plan written out by hand. It sends the model to
#' the service with every decision variable fixed at the solution's value, so
#' each call is one request.
#'
#' The quantity must be a single number, so a random expression is summarized
#' first, for example with [prob()] or [expectation()], as for an objective.
#'
#' Without a `seed`, the value is computed on the model's own scenarios. With
#' a `seed`, it is computed on new scenarios drawn from that seed, which shows
#' how the solution does on scenarios it was not chosen for. [resample()]
#' explains which random variables are drawn again.
#'
#' @param m A [model()].
#' @param solution A result from [solve()], or a named numeric vector with a
#'   value for every decision variable, named as in a solution: `"x"`, or
#'   `"x[1]"`, `"x[2]"`, ... for a vector variable. A model with a permutation
#'   needs a result, because only a result holds the arrangement.
#' @param expr The quantity to compute: one expression that is not random.
#' @param seed Left `NULL`, the model's own scenarios are used. Otherwise, the
#'   seed for new scenarios, different from the model's own.
#' @param scenarios With `seed`: how many new scenarios to draw. Left `NULL`,
#'   as many as the model has. More scenarios give a more precise value.
#' @param ... Settings for the request, as for [solve_model()]: `base_url`,
#'   `api_key`, `project`, `config`, `gzip`, `timeout` and `transport`.
#' @return The value of `expr`, a number.
#' @examples
#' \dontrun{
#' m <- model()
#' stock  <- num_var(m, "stock", lower = 0, upper = 200)
#' demand <- rand_var(m, "demand", normal(100, 15))
#' set_scenarios(m, 512, seed = 42)
#' minimize(m, 3 * stock + 10 * expectation(max(demand - stock, 0)))
#' add(m, prob(demand <= stock) >= 0.9)
#' res <- solve(m)
#'
#' met <- prob(demand <= stock)
#' evaluate(m, res, met)                                  # on the model's scenarios
#' evaluate(m, res, met, seed = 7, scenarios = 1000)      # on 1000 new ones
#' evaluate(m, c(stock = 110), met)                       # for a stock of 110
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

#' Check a solution on new scenarios
#'
#' A solution is chosen to do well on the model's scenarios, so the objective
#' and the probabilities reported for it are measured on the very scenarios
#' that shaped it. On new scenarios it usually does a little worse, and a
#' chance constraint that was only just met is missed about half the time.
#' `resample()` draws new scenarios from `seed`, keeps the solution fixed,
#' and computes the model's objective and constraints on them.
#'
#' Only random variables with a distribution are drawn again. A random
#' variable made from an [empirical()] sample or by [set_empirical()] is data
#' and stays as it is. A model whose random variables are all of that kind has
#' nothing to draw again, which is an error, and while a model has any of
#' them, the number of scenarios cannot change. Each call is one request to
#' the service.
#'
#' @param m A [model()].
#' @param solution A result from [solve()], or a named numeric vector with a
#'   value for every decision variable (see [evaluate()]).
#' @param seed The seed for the new scenarios, different from the model's
#'   own.
#' @param scenarios How many new scenarios to draw. Left `NULL`, as many as
#'   the model has. More scenarios give a more precise check.
#' @param ... Settings for the request, as for [solve_model()].
#' @return A result in the same form as from [solve()], for the fixed solution
#'   on the new scenarios. `objective` is the objective on them, `feasible`
#'   says whether every constraint still holds, and
#'   `solver_data$max_violation` is by how much the worst constraint is
#'   missed; for a chance constraint, as a probability.
#' @examples
#' \dontrun{
#' res <- solve(m)                                        # m as in ?evaluate
#' chk <- resample(m, res, seed = 7, scenarios = 1000)
#' chk$feasible                                           # does every constraint still hold?
#' chk$solver_data$max_violation                          # if not, by how much
#' chk$objective                                          # the objective on the new scenarios
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
