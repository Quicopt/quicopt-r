# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

#' Optimization under uncertainty
#'
#' Part of a model's data is often unknown when the decision has to be made:
#' demand, prices, yields, arrival times. Declare that data as random variables
#' carrying distributions, and the model is solved over a sample of scenarios
#' drawn from them.
#'
#' Two rules describe the whole surface:
#'
#' * A variable declared with [rand_var()] is a random variable, not a decision
#'   variable. Every use of it references the same sample.
#' * An expression containing a random variable is itself random, and cannot
#'   serve as an objective or a constraint until an aggregator reduces it over
#'   the scenarios: [expectation()] for the mean, [cvar()] for the tail,
#'   [prob()] for a chance constraint.
#'
#' [set_scenarios()] sets how many scenarios are drawn and from which seed.
#' Both belong to the model, so repeated solves see the same sample. The
#' drawing happens in the service, from the model's own seed — R's
#' `set.seed()` plays no role here.
#'
#' @examples
#' \dontrun{
#' # Order x units at 3 apiece against a demand learned later, pay 10 per unit
#' # of shortfall, and meet demand in at least 90% of scenarios:
#' m <- model()
#' x <- num_var(m, "x", 0, 200)
#' demand <- rand_var(m, "demand", normal(100, 15))
#' set_scenarios(m, 512, seed = 42)
#' minimize(m, 3 * x + 10 * expectation(max(demand - x, 0)))
#' add(m, prob(demand - x <= 0) >= 0.9)
#' solve(m)$solution
#' }
#' @name stochastic
NULL

# ── distributions ───────────────────────────────────────────────────────────

#' Distributions for random variables
#'
#' `normal(mean, sd)` follows `rnorm()`'s parameterization: the mean and the
#' standard deviation. `distribution(head, ...)` is the escape hatch for any
#' distribution the service supports that has no named constructor here yet.
#'
#' A parameter may be a number or a deterministic model expression. An
#' expression gives an *endogenous* distribution — one whose parameters depend
#' on the decision, such as a demand whose mean rises with the price you set. A
#' parameter may never contain a random variable: a distribution's parameters
#' are data, not draws.
#'
#' @param head The distribution's name in the service's catalog.
#' @param ... Its parameters, each a number or a deterministic expression.
#' @return A distribution, ready for [rand_var()] or [set_distribution()].
#' @export
distribution <- function(head, ...) {
  if (!is.character(head) || length(head) != 1L || !nzchar(head))
    stop("a distribution's head is one non-empty string")
  params <- list(...)
  for (p in params) .check_dist_param(p)
  structure(list(head = head, params = params), class = "quicopt_distribution")
}

#' @rdname distribution
#' @param mean,sd The mean and standard deviation, as in `rnorm()`.
#' @export
normal <- function(mean, sd) distribution("normal", mean, sd)

# One distribution parameter: a plain number, or a deterministic scalar
# expression. A random variable inside a parameter is rejected here, at the
# point of declaration, where the message can still name the construct.
.check_dist_param <- function(p) {
  if (is.numeric(p) && length(p) == 1L && !is.na(p)) return(invisible(p))
  if (inherits(p, "quicopt_expr")) {
    if (length(p$nodes) != 1L)
      stop("a distribution parameter is a single value, got length ", length(p$nodes))
    if (.has_source(p$nodes[[1L]]))
      stop("a distribution's parameters are data, not draws — ",
           "a random variable cannot appear inside one")
    return(invisible(p))
  }
  stop("a distribution parameter must be a number or a model expression, got ",
       class(p)[[1L]])
}

# Whether an IR node's tree contains a random-variable reference.
.has_source <- function(n) {
  switch(n$kind,
    source = TRUE,
    apply = any(vapply(n$args, .has_source, NA)),
    reduce = .has_source(n$body) || (!is.null(n$cond) && .has_source(n$cond)),
    FALSE)
}

# ── declaring a model's random variables ────────────────────────────────────

#' Declare a random variable
#'
#' The variable is not a decision: the solver is handed its value rather than
#' choosing it, and every use of it means the same sample within a scenario.
#' Two independent random variables are two declarations under two names.
#'
#' A random variable takes no bounds and no domain — its distribution already
#' says what values it takes.
#'
#' @param m A [model()].
#' @param name The random variable's name, unique within the model.
#' @param dist A [distribution()] such as `normal(100, 15)`, or an
#'   [empirical()] column holding one observed value per scenario. May be left
#'   `NULL` and supplied later with [set_distribution()].
#' @return The random variable's handle (an expression of length 1).
#' @export
rand_var <- function(m, name, dist = NULL) {
  .check_model(m, "rand_var")
  .check_name(m, name)
  if (!is.null(dist)) .check_dist(dist)
  v <- .qexpr(list(ir_source_ref(name)), class = "quicopt_rv")
  v$name <- name; v$n <- 1L
  vars <- .m_get(m, "vars")
  vars[[name]] <- v
  .m_set(m, "vars", vars)
  sources <- .m_get(m, "sources")
  sources[name] <- list(dist)                # list() so NULL is stored, not dropped
  .m_set(m, "sources", sources)
  v
}

# A distribution argument: a quicopt_distribution or an empirical column.
.check_dist <- function(dist) {
  if (inherits(dist, "quicopt_distribution") || inherits(dist, "quicopt_empirical"))
    return(invisible(dist))
  if (is.numeric(dist))
    stop("a plain numeric vector is ambiguous here; write empirical(x) for an ",
         "observed scenario column, or a distribution such as normal(100, 15)")
  stop("expected a distribution (e.g. normal(100, 15)) or an empirical() column, got ",
       class(dist)[[1L]])
}

#' Give a random variable its distribution
#'
#' @param m A [model()].
#' @param v The random variable's handle, from [rand_var()].
#' @param dist A [distribution()] or an [empirical()] column.
#' @return The model, invisibly.
#' @export
set_distribution <- function(m, v, dist) {
  .check_model(m, "set_distribution")
  if (inherits(v, "quicopt_var"))
    stop("'", v$name, "' is a decision variable; a random variable is declared ",
         "with rand_var(), and carries no bounds or domain")
  if (!inherits(v, "quicopt_rv"))
    stop("set_distribution attaches a distribution to a rand_var() handle, got ",
         class(v)[[1L]])
  .check_dist(dist)
  sources <- .m_get(m, "sources")
  if (!v$name %in% names(sources))
    stop("the random variable '", v$name, "' belongs to a different model")
  sources[[v$name]] <- dist
  .m_set(m, "sources", sources)
  invisible(m)
}

#' @rdname rand_var
#' @return `add_rand_var` returns the model, invisibly.
#' @export
add_rand_var <- function(m, name, dist = NULL) {
  rand_var(m, name, dist)
  invisible(m)
}

#' Set how many scenarios are drawn, and from which seed
#'
#' More scenarios estimate the true problem more closely and cost more to
#' solve. Both settings belong to the model, not to the solve, so the same
#' model always faces the same sample and two solves of it are comparable.
#' Left unset, a model is solved over one scenario — unless an [empirical()]
#' column sets the count by its own length.
#'
#' The scenarios are drawn by the service from this seed; R's `set.seed()`
#' plays no role. `n` and `seed` are both at least 1.
#'
#' @param m A [model()].
#' @param n How many scenarios to draw.
#' @param seed The draw seed; left `NULL`, the current one is kept.
#' @return The model, invisibly.
#' @export
set_scenarios <- function(m, n, seed = NULL) {
  .check_model(m, "set_scenarios")
  # 1 is the floor rather than 0 because the wire cannot carry a 0: protobuf
  # conflates it with an absent field, which the service reads as its default.
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 1 || n != trunc(n))
    stop("a model is solved over a whole number of scenarios, at least 1")
  .m_set(m, "scenarios", as.numeric(n))
  .m_set(m, "scen_set", TRUE)
  if (!is.null(seed)) {
    if (!is.numeric(seed) || length(seed) != 1L || is.na(seed) || seed < 1 || seed != trunc(seed))
      stop("the scenario seed is a whole number of at least 1")
    .m_set(m, "seed", as.numeric(seed))
  }
  invisible(m)
}

#' Turn observed history into a model's uncertainty
#'
#' Every chosen column of a data frame becomes an [empirical()] random
#' variable named after the column, and the number of rows becomes the model's
#' scenario count. All columns are read at the same scenario index, so rows
#' observed jointly stay jointly distributed — correlation in the data survives
#' into the model.
#'
#' A non-numeric column is an error, not a skip: a silently dropped column
#' would leave a model that solves fine and answers the wrong question. Select
#' with `cols` when the frame carries more than its uncertainty.
#'
#' @param m A [model()].
#' @param data A data frame of jointly observed rows.
#' @param cols Which columns to use (default: all of them).
#' @return The model, invisibly. The handles are retrievable as `m$<column>`.
#' @export
set_empirical <- function(m, data, cols = NULL) {
  .check_model(m, "set_empirical")
  if (!is.data.frame(data))
    stop("set_empirical takes a data.frame of observed rows")
  if (nrow(data) < 1L) stop("the data has no rows, so there are no scenarios")
  cols <- if (is.null(cols)) names(data) else {
    missing <- setdiff(cols, names(data))
    if (length(missing))
      stop("no such column: ", paste(missing, collapse = ", "))
    cols
  }
  if (length(cols) == 0L) stop("no columns selected")
  for (col in cols)
    if (!is.numeric(data[[col]]))
      stop("the column '", col, "' is ", class(data[[col]])[[1L]], ", not numeric; ",
           "a random variable is a number per scenario (select with cols= if ",
           "this column is not part of the uncertainty)")
  if (.m_get(m, "scen_set") && .m_get(m, "scenarios") != nrow(data))
    stop("the model is set to ", .m_get(m, "scenarios"), " scenarios, but the ",
         "data has ", nrow(data), " rows")
  for (col in cols) rand_var(m, col, empirical(data[[col]]))
  set_scenarios(m, nrow(data))
  invisible(m)
}

# ── aggregators: where a random quantity becomes a number ───────────────────

#' The expected value over the scenarios
#'
#' Minimizing an expectation optimizes the average case and says nothing about
#' the bad ones; use [cvar()] when the bad ones are what matter.
#'
#' `x` is any expression containing a random variable. The result is
#' deterministic, and can be used anywhere a number can. Applied to a vector
#' expression, it aggregates each element.
#'
#' @param x A model expression.
#' @return An expression of the same length.
#' @export
expectation <- function(x)
  .qexpr(lapply(.nodes_of(x), function(n) ir_apply("smean", list(n))))

#' The conditional value at risk at level `alpha`
#'
#' The mean of `x` over its worst `1 - alpha` fraction of scenarios — at
#' `alpha = 0.95`, the average of the worst 5%. Minimizing it optimizes the
#' tail instead of the average, and is the usual way to ask for a solution
#' that holds up in bad scenarios rather than merely on average.
#'
#' @param x A model expression.
#' @param alpha The tail level, a plain number strictly between 0 and 1; it
#'   cannot depend on a decision.
#' @return An expression of the same length.
#' @export
cvar <- function(x, alpha) {
  if (!is.numeric(alpha) || length(alpha) != 1L || is.na(alpha))
    stop("the tail level must be a plain number")
  if (alpha <= 0 || alpha >= 1)
    stop("the tail level must lie strictly between 0 and 1, got ", alpha)
  .qexpr(lapply(.nodes_of(x),
                function(n) ir_apply("scvar", list(n, ir_const(alpha)))))
}

#' The probability that a comparison holds
#'
#' The fraction of scenarios in which it does. This is what a chance
#' constraint is built from:
#'
#' ```r
#' add(m, prob(demand - x <= 0) >= 0.9)
#' ```
#'
#' which reads as *demand is met in at least 90% of scenarios*. The line holds
#' two comparisons, both meaningful: the one inside `prob` is the event being
#' measured, the outer one is the service level demanded of it.
#'
#' `rel` is a comparison, `a <= b` or `a >= b`, with at least one side
#' containing a random variable. An equality is refused: for a continuous
#' quantity its probability is zero. Elementwise over vector comparisons.
#'
#' @param rel A comparison built with `<=` or `>=`.
#' @return An expression: a probability between 0 and 1 per compared element.
#' @export
prob <- function(rel) {
  if (!inherits(rel, "quicopt_relation"))
    stop("prob takes a comparison, as in prob(demand - x <= 0)")
  if (rel$op == "==")
    stop("prob of an equality is zero for a continuous quantity; ",
         "measure an event with <= or >=")
  .qexpr(mapply(.prob_node, rel$lhs, rel$rhs,
                MoreArgs = list(op = rel$op), SIMPLIFY = FALSE))
}

# One chance-probability node for the event `lhs op rhs`. A >= event is read as
# its mirrored <= (a >= b is b <= a), then a numeric side becomes the
# frequency threshold directly and a general pair lands as lhs - rhs <= 0 —
# the same normalization the sibling clients apply.
.prob_node <- function(lhs, rhs, op) {
  if (op == ">=") { tmp <- lhs; lhs <- rhs; rhs <- tmp }   # now the event is lhs <= rhs
  if (rhs$kind == "const") return(ir_apply("sfreq_leq", list(lhs, rhs)))
  if (lhs$kind == "const") return(ir_apply("sfreq_geq", list(rhs, lhs)))
  ir_apply("sfreq_leq", list(ir_apply("-", list(lhs, rhs)), ir_const(0)))
}
