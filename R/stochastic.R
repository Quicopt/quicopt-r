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
#' * An expression containing a random variable is itself random (see
#'   [is_random()]), and cannot serve as an objective or a constraint until an
#'   aggregator reduces it over the scenarios: [expectation()] for the mean,
#'   [cvar()] for the tail, [prob()] for a chance constraint, [variance()] and
#'   [std_dev()] for the spread, [scenario_max()], [scenario_min()] and
#'   [scenario_quantile()] for single scenario values. [holds()] turns an
#'   event into a 0/1 value inside a scenario, for arithmetic before the
#'   aggregation.
#'
#' [set_scenarios()] sets how many scenarios are drawn and from which seed.
#' Both belong to the model, so repeated solves see the same sample. The
#' drawing happens in the service, from the model's own seed; R's
#' `set.seed()` plays no role here.
#'
#' A solution is shaped by the scenarios it was found on, so its objective and
#' its chance levels are in-sample figures. [resample()] and [evaluate()]
#' check a solution on fresh scenarios, and `margin` in [add()] builds the
#' expected shortfall of a chance constraint into the model.
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
#' res <- solve(m)
#' res$solution
#'
#' # The same order on scenarios it was not optimized for:
#' resample(m, res, seed = 7)$feasible
#' }
#' @name stochastic
NULL

# ── distributions ───────────────────────────────────────────────────────────

#' Distributions for random variables
#'
#' The named constructors follow the parameterizations of R's own samplers:
#'
#' * `normal(mean, sd)`, as `rnorm()`: the mean and the standard deviation.
#' * `uniform(min, max)`, as `runif()`: the two limits.
#' * `exponential(rate)`, as `rexp()`: the rate, so the mean is `1 / rate`.
#' * `bernoulli(prob)`, as `rbinom(n, 1, prob)`: 1 with probability `prob`,
#'   else 0.
#'
#' `distribution(head, ...)` names a distribution by its catalog name, for a
#' distribution the service's catalog holds and no constructor here names yet.
#' A head the catalog does not hold is refused when the model is sent. Every
#' other distribution is available through [empirical()]: draw a column in R
#' and declare it (see the vignette).
#'
#' A parameter may be a number or a non-random model expression. An
#' expression gives an *endogenous* distribution, one whose parameters depend
#' on the decision, such as a demand whose mean falls with the price you set
#' or a failure whose probability falls with what you spend on maintenance.
#' A parameter may never contain a random variable: a distribution's
#' parameters are data, not draws.
#'
#' A parameter may also be a vector, and the distribution then declares a
#' vector random variable: `normal(c(6, 5, 4), 1)` is three independent
#' normals with their own means and a shared standard deviation. Every
#' parameter has length 1 or the vector's length.
#'
#' A numeric parameter outside its distribution's range is refused where the
#' distribution is built: a rate that is not positive, a probability outside
#' 0 to 1, a lower limit above its upper limit. A parameter given as an
#' expression cannot be checked this way, since its value is the solver's to
#' choose; bound the decision variables so that it stays in range.
#'
#' @param head The distribution's name in the service's catalog.
#' @param ... Its parameters, each a number, a numeric vector, or a non-random
#'   expression.
#' @return A distribution, ready for [rand_var()] or [set_distribution()].
#' @examples
#' m <- model()
#' lead_time <- rand_var(m, "lead_time", uniform(2, 5))
#' gap       <- rand_var(m, "gap", exponential(1 / 30))   # mean 30
#' fails     <- rand_var(m, "fails", bernoulli(0.02))
#'
#' # an endogenous distribution: spending on maintenance lowers the failure
#' # probability
#' spend  <- num_var(m, "spend", 0, 10)
#' breaks <- rand_var(m, "breaks", bernoulli(0.2 - 0.015 * spend))
#' @export
distribution <- function(head, ...) {
  if (!is.character(head) || length(head) != 1L || !nzchar(head))
    stop("a distribution's head is one non-empty string")
  params <- list(...)
  for (p in params) .check_dist_param(p)
  .dist_length(params)
  structure(list(head = head, params = params), class = "quicopt_distribution")
}

#' @rdname distribution
#' @param mean,sd The mean and standard deviation, as in `rnorm()`.
#' @export
normal <- function(mean, sd) distribution("normal", mean, sd)

#' @rdname distribution
#' @param min,max The lower and upper limits, as in `runif()`.
#' @export
uniform <- function(min, max) {
  if (is.numeric(min) && is.numeric(max) && !anyNA(min) && !anyNA(max) && any(min > max))
    stop("a uniform distribution's lower limit cannot exceed its upper limit")
  distribution("uniform", min, max)
}

#' @rdname distribution
#' @param rate The rate, as in `rexp()`; the mean is `1 / rate`.
#' @export
exponential <- function(rate) {
  if (is.numeric(rate) && !anyNA(rate) && any(rate <= 0))
    stop("an exponential distribution's rate must be positive")
  distribution("exponential", rate)
}

#' @rdname distribution
#' @param prob The probability of a 1, as in `rbinom(n, 1, prob)`.
#' @export
bernoulli <- function(prob) {
  if (is.numeric(prob) && !anyNA(prob) && any(prob < 0 | prob > 1))
    stop("a Bernoulli distribution's probability must lie between 0 and 1")
  distribution("bernoulli", prob)
}

# One distribution parameter: numbers, or a non-random expression. A random
# variable inside a parameter is rejected here, at the point of declaration,
# where the message can still name the construct.
.check_dist_param <- function(p) {
  if (is.numeric(p) && length(p) >= 1L && !anyNA(p)) return(invisible(p))
  if (inherits(p, "quicopt_expr")) {
    for (n in p$nodes)
      if (.has_source(n))
        stop("a distribution's parameters are data, not draws: ",
             "a random variable cannot appear inside one")
    return(invisible(p))
  }
  stop("a distribution parameter must be a number or a model expression, got ",
       class(p)[[1L]])
}

# The length of the random variable a parameter list declares: the common
# length of its vector parameters, 1 when all are scalars.
.dist_length <- function(params) {
  lens <- unique(vapply(params, length, 0L))
  lens <- lens[lens != 1L]
  if (length(lens) > 1L)
    stop("a distribution's parameters disagree in length: ",
         paste(sort(lens), collapse = " vs "), " (each has length 1 or the vector's length)")
  if (length(lens)) lens else 1L
}

# Element i of a parameter as an IR node: a vector parameter's own element, a
# scalar's only one.
.param_node <- function(p, i) {
  nodes <- .nodes_of(p, "distribution parameter")
  nodes[[if (length(nodes) == 1L) 1L else i]]
}

# ── randomness: what is still a draw, and what is already a number ──────────

# Whether an IR node's tree contains a random-variable reference anywhere,
# closed or not. A distribution parameter must have none: its draws would
# depend on other draws.
.has_source <- function(n) {
  switch(n$kind,
    source = TRUE,
    apply = any(vapply(n$args, .has_source, NA)),
    reduce = .has_source(n$body) || (!is.null(n$cond) && .has_source(n$cond)),
    table = any(vapply(n$index, .has_source, NA)),     # a lookup at a random position
    FALSE)
}

# The catalog heads that close an expression over the scenarios. Below one of
# them the expression is random; the head itself is a number. Every aggregator
# this client emits must be listed here: a head missing from the list would
# leave a closed expression looking random, and the typing checks would refuse
# a valid model.
.AGGREGATORS <- c("smean", "scvar", "sfreq_leq", "sfreq_geq",
                  "svar", "svar_sample", "sstd", "smin", "smax", "squantile")

# Whether a node still varies across scenarios: it references a random
# variable that no aggregator above it has closed.
.is_random_node <- function(n) {
  switch(n$kind,
    source = TRUE,
    apply = if (n$op %in% .AGGREGATORS) FALSE else any(vapply(n$args, .is_random_node, NA)),
    reduce = .is_random_node(n$body) || (!is.null(n$cond) && .is_random_node(n$cond)),
    table = any(vapply(n$index, .is_random_node, NA)),  # random exactly when an index is
    FALSE)
}

#' Does an expression vary across scenarios?
#'
#' An expression is random while it contains a random variable that no
#' aggregator has closed: `demand - x` is random, `expectation(demand - x)`
#' is not, and neither is `3 * x`. Only a non-random expression can be an
#' objective or a constraint; only a random one can be aggregated. Both rules
#' are checked where the expression is used, so this predicate is for your own
#' code: a helper that accepts either kind, or a check before a long build.
#'
#' @param x A model expression, or a numeric vector (never random).
#' @return A logical vector, one entry per element of `x`.
#' @examples
#' m <- model()
#' x <- num_var(m, "x", 0, 10)
#' d <- rand_var(m, "d", normal(5, 1))
#' is_random(d - x)                 # TRUE
#' is_random(expectation(d - x))    # FALSE
#' is_random(c(x, x^2))             # FALSE FALSE
#' @export
is_random <- function(x) vapply(.nodes_of(x), .is_random_node, NA)

# The two typing rules, applied where the public name is still in view: the
# service enforces the same rules at decode, but its message would name wire
# operators the user never typed.
.need_random <- function(x, what) {
  nodes <- .nodes_of(x)
  for (n in nodes)
    if (!.is_random_node(n))
      stop(what, " aggregates over the scenarios, but '", .render(n),
           "' contains no random variable: it is the same number in every scenario")
  nodes
}

.need_closed <- function(n, what) {
  if (.is_random_node(n))
    stop("the ", what, " '", .render(n), "' is still random: it contains a ",
         "random variable that no aggregator (expectation(), cvar(), prob(), ...) ",
         "has closed over the scenarios")
  n
}

# ── declaring a model's random variables ────────────────────────────────────

#' Declare a random variable
#'
#' The variable is not a decision: the solver is handed its value rather than
#' choosing it, and every use of it means the same sample within a scenario.
#' Two independent random variables are two declarations under two names.
#'
#' A random variable takes no bounds and no domain; its distribution already
#' says what values it takes.
#'
#' A distribution with vector parameters declares a vector random variable,
#' `weight[1]`, ..., `weight[n]`, one independent draw per element:
#' `rand_var(m, "weight", normal(c(6, 5, 4), 1))`. With `n` given and scalar
#' parameters, the elements are `n` independent copies of one distribution.
#' Elements of a vector random variable are independent of each other;
#' correlated uncertainty is declared from data with [set_empirical()].
#'
#' @param m A [model()].
#' @param name The random variable's name, unique within the model.
#' @param dist A [distribution()] such as `normal(100, 15)`, or an
#'   [empirical()] column holding one observed value per scenario. May be left
#'   `NULL` and supplied later with [set_distribution()].
#' @param n How many elements the random variable has; left `NULL`, as many as
#'   the distribution's parameters say (1 for an empirical column).
#' @return The random variable's handle (an expression of length `n`).
#' @export
rand_var <- function(m, name, dist = NULL, n = NULL) {
  .check_model(m, "rand_var")
  .check_name(m, name)
  if (!is.null(dist)) .check_dist(dist)
  n <- .rv_length(dist, n, name)
  flat <- if (n == 1L) name else sprintf("%s[%d]", name, seq_len(n))
  v <- .qexpr(lapply(flat, ir_source_ref), class = "quicopt_rv")
  v$name <- name; v$n <- n; v$flat <- flat
  v$model <- m
  vars <- .m_get(m, "vars")
  vars[[name]] <- v
  .m_set(m, "vars", vars)
  sources <- .m_get(m, "sources")
  sources[name] <- list(dist)                # list() so NULL is stored, not dropped
  .m_set(m, "sources", sources)
  v
}

# The length a random variable gets from its distribution and an explicit n:
# they must agree, and an empirical column is one random variable.
.rv_length <- function(dist, n, name) {
  if (!is.null(n) && (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 1 || n != trunc(n)))
    stop("n must be a whole number of at least 1")
  from_dist <- if (inherits(dist, "quicopt_distribution")) .dist_length(dist$params) else 1L
  if (is.null(n)) return(as.integer(from_dist))
  n <- as.integer(n)
  if (inherits(dist, "quicopt_empirical") && n != 1L)
    stop("'", name, "': an empirical column is one random variable (declare one per column)")
  if (from_dist != 1L && from_dist != n)
    stop("'", name, "': the distribution's parameters have length ", from_dist,
         ", but n is ", n)
  n
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
#' @param dist A [distribution()] or an [empirical()] column, of the handle's
#'   length.
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
  if (!identical(v$model, m))
    stop("the random variable '", v$name, "' belongs to a different model")
  .rv_length(dist, v$n, v$name)
  sources <- .m_get(m, "sources")
  sources[[v$name]] <- dist
  .m_set(m, "sources", sources)
  invisible(m)
}

#' @rdname rand_var
#' @return `add_rand_var` returns the model, invisibly.
#' @export
add_rand_var <- function(m, name, dist = NULL, n = NULL) {
  rand_var(m, name, dist, n)
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
#' plays no role. `n` and `seed` are both at least 1. The service caps the
#' count: a model over its limit is refused when sent, with the limit named
#' in the refusal (the client does not know it in advance, since it is the
#' service's to set).
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
#' @param x A random model expression (see [is_random()]).
#' @return An expression of the same length, no longer random.
#' @export
expectation <- function(x)
  .qexpr(lapply(.need_random(x, "expectation()"), function(n) ir_apply("smean", list(n))))

#' The conditional value at risk at level `alpha`
#'
#' The mean of `x` over its worst `1 - alpha` fraction of scenarios — at
#' `alpha = 0.95`, the average of the worst 5%. Minimizing it optimizes the
#' tail instead of the average, and is the usual way to ask for a solution
#' that holds up in bad scenarios rather than merely on average.
#'
#' @param x A random model expression (see [is_random()]).
#' @param alpha The tail level, a plain number strictly between 0 and 1; it
#'   cannot depend on a decision.
#' @return An expression of the same length, no longer random.
#' @export
cvar <- function(x, alpha) {
  if (!is.numeric(alpha) || length(alpha) != 1L || is.na(alpha))
    stop("the tail level must be a plain number")
  if (alpha <= 0 || alpha >= 1)
    stop("the tail level must lie strictly between 0 and 1, got ", alpha)
  .qexpr(lapply(.need_random(x, "cvar()"),
                function(n) ir_apply("scvar", list(n, ir_const(alpha)))))
}

#' The variance and the standard deviation over the scenarios
#'
#' How much a quantity varies from scenario to scenario, as opposed to what it
#' averages to. `expectation(cost) + k * std_dev(cost)` is the mean-risk
#' objective that penalizes spread, and `add(m, variance(ret) <= v)` caps it.
#'
#' By default the scenarios are taken as the whole distribution, each with
#' weight `1/n`, so `variance(x)` is `expectation(x^2) - expectation(x)^2`.
#' That is not what `var()` and `sd()` compute: they divide by `n - 1`, to
#' estimate the variance of a population from a sample of it. `sample = TRUE`
#' gives that estimate. The two differ by the factor `n / (n - 1)`, which
#' matters to a reported number and not to which decision minimizes it.
#'
#' Unlike [cvar()], these measure deviation in both directions: a scenario
#' that turns out far better than average raises them as much as one that
#' turns out far worse.
#'
#' @param x A random model expression (see [is_random()]).
#' @param sample `FALSE` (the default) divides by the number of scenarios;
#'   `TRUE` divides by one less, as `var()` and `sd()` do.
#' @return An expression of the same length, no longer random.
#' @examples
#' m <- model()
#' x <- num_var(m, "x", 0, 200)
#' demand <- rand_var(m, "demand", normal(100, 15))
#' set_scenarios(m, 512, seed = 42)
#' cost <- 3 * x + 10 * max(demand - x, 0)
#' minimize(m, expectation(cost) + 2 * std_dev(cost))
#' @export
variance <- function(x, sample = FALSE) {
  head <- if (.flag(sample, "sample")) "svar_sample" else "svar"
  .qexpr(lapply(.need_random(x, "variance()"), function(n) ir_apply(head, list(n))))
}

#' @rdname variance
#' @export
std_dev <- function(x, sample = FALSE) {
  node <- if (.flag(sample, "sample"))
    function(n) ir_apply("sqrt", list(ir_apply("svar_sample", list(n))))
  else
    function(n) ir_apply("sstd", list(n))
  .qexpr(lapply(.need_random(x, "std_dev()"), node))
}

# A TRUE/FALSE argument, checked where a wrong value can still be named.
.flag <- function(value, name) {
  if (!is.logical(value) || length(value) != 1L || is.na(value))
    stop("'", name, "' is TRUE or FALSE")
  value
}

#' The largest, the smallest and a quantile over the scenarios
#'
#' The value a quantity takes in one particular scenario: the one where it is
#' largest, the one where it is smallest, or the one that a given share of the
#' scenarios does not exceed.
#'
#' * `scenario_max(x)` is the largest value of `x` over the scenarios.
#'   Minimizing it is the robust reading of a cost: do as well as possible in
#'   the worst scenario of the sample.
#' * `scenario_min(x)` is the smallest. Maximizing it is the same for a
#'   profit.
#' * `scenario_quantile(x, prob)` is the smallest scenario value that at least
#'   the share `prob` of the scenarios is at or below; with `n` scenarios, the
#'   `ceiling(prob * n)`-th smallest, which is what `quantile(x, prob, type =
#'   1)` returns for a sample. For a cost this is the value at risk at level
#'   `prob`; [cvar()] at the same level is the mean of what lies beyond it.
#'   `scenario_quantile(x, 1)` is `scenario_max(x)`.
#'
#' These are not `max()`, `min()` and `quantile()`. `max(a, b)` is the larger
#' of two expressions *within* each scenario and stays random;
#' `scenario_max(x)` compares one expression *across* the scenarios and is a
#' number.
#'
#' An extreme is set by a single scenario, so it moves more from one sample to
#' the next than a mean or a tail mean does, and a larger sample will usually
#' hold a more extreme scenario. Check a solution built on one with
#' [resample()].
#'
#' @param x A random model expression (see [is_random()]).
#' @param prob The level, a plain number above 0 and at most 1; it cannot
#'   depend on a decision.
#' @return An expression of the same length, no longer random.
#' @examples
#' m <- model()
#' x <- num_var(m, "x", 0, 200)
#' demand <- rand_var(m, "demand", normal(100, 15))
#' set_scenarios(m, 512, seed = 42)
#' cost <- 3 * x + 10 * max(demand - x, 0)
#' minimize(m, scenario_max(cost))                   # the worst scenario
#' add(m, scenario_quantile(cost, 0.95) <= 500)      # 95% of scenarios cost at most 500
#' @export
scenario_max <- function(x)
  .qexpr(lapply(.need_random(x, "scenario_max()"), function(n) ir_apply("smax", list(n))))

#' @rdname scenario_max
#' @export
scenario_min <- function(x)
  .qexpr(lapply(.need_random(x, "scenario_min()"), function(n) ir_apply("smin", list(n))))

#' @rdname scenario_max
#' @export
scenario_quantile <- function(x, prob) {
  if (!is.numeric(prob) || length(prob) != 1L || is.na(prob))
    stop("the quantile's level must be a plain number")
  if (prob <= 0 || prob > 1)
    stop("the quantile's level must lie above 0 and at most 1, got ", prob)
  .qexpr(lapply(.need_random(x, "scenario_quantile()"),
                function(n) ir_apply("squantile", list(n, ir_const(prob)))))
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
#' quantity its probability is zero. So are `<` and `>`, which for a
#' continuous quantity mean the same as `<=` and `>=`. Elementwise over vector
#' comparisons.
#'
#' The same event as a 0/1 expression, scenario by scenario, is
#' [holds()]: `expectation(holds(rel))` is `prob(rel)`.
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
  if (rel$op %in% c("<", ">", "!="))
    stop("prob measures an event written with <= or >= (for a continuous ",
         "quantity '", rel$op, "' means the same thing)")
  for (i in seq_len(rel$n))
    if (!.is_random_node(rel$lhs[[i]]) && !.is_random_node(rel$rhs[[i]]))
      stop("prob measures how often an event happens across the scenarios, but '",
           .render(rel$lhs[[i]]), " ", rel$op, " ", .render(rel$rhs[[i]]),
           "' contains no random variable")
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
