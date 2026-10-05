# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

#' Optimization under uncertainty
#'
#' Some decisions have to be made before all the data is known: how much
#' stock to order before demand is known, which jobs to accept before knowing
#' how long they will take. quicopt models such a decision by describing each
#' uncertain quantity as a *random variable*. The service draws many possible
#' outcomes of the random variables, called *scenarios*, and finds the
#' decision that does best across them.
#'
#' @section Building blocks:
#' * [rand_var()] declares a random variable with a distribution such as
#'   [normal()]; [set_empirical()] declares random variables from the columns
#'   of a data frame instead, one row per scenario.
#' * [set_scenarios()] sets how many scenarios the service draws, and the
#'   seed it draws them from.
#' * Any expression that contains a random variable has one value per
#'   scenario; it is called *random* (see [is_random()]). The objective and
#'   the constraints must each be one number, so a random expression is
#'   summarized across the scenarios before it is used there.
#'
#' @section Summaries across the scenarios:
#' * [expectation()]: the average.
#' * [prob()]: the share of scenarios in which a comparison holds, for a
#'   requirement such as "demand is met on 90% of days".
#' * [cvar()]: the average over the worst scenarios.
#' * [scenario_max()], [scenario_min()], [scenario_quantile()]: the largest
#'   value, the smallest, and a quantile.
#' * [variance()] and [std_dev()]: how much the value varies.
#'
#' [holds()] turns a comparison into a 0/1 value in each scenario, which can
#' be combined with other quantities before it is summarized.
#'
#' @section Checking a solution:
#' A solution is chosen to do well on the model's scenarios, so it tends to do
#' a little worse on others, and the objective the service reports is
#' optimistic. [evaluate()] and [resample()] compute the figures on new
#' scenarios, and the `margin` argument of [add()] raises the target of a
#' requirement on a probability to allow for this.
#'
#' `vignette("stochastic", package = "quicopt")` introduces all of this with
#' a worked example.
#'
#' @examples
#' \dontrun{
#' # Order stock at 3 per unit before demand is known, pay 10 for each unit
#' # of demand that cannot be met, and meet demand in at least 90% of scenarios.
#' m <- model()
#' stock  <- num_var(m, "stock", lower = 0, upper = 200)
#' demand <- rand_var(m, "demand", normal(100, 15))
#' set_scenarios(m, 512, seed = 42)
#' minimize(m, 3 * stock + 10 * expectation(max(demand - stock, 0)))
#' add(m, prob(demand <= stock) >= 0.9)
#' res <- solve(m)
#' res$solution
#'
#' # Does the requirement still hold on 1000 new scenarios?
#' resample(m, res, seed = 7, scenarios = 1000)$feasible
#' }
#' @name stochastic
NULL

# ── distributions ───────────────────────────────────────────────────────────

#' Distributions for random variables
#'
#' These functions describe how a random variable is distributed, for use in
#' [rand_var()]. Each takes the same parameters, in the same order, as R's
#' corresponding random number function:
#'
#' * `normal(mean, sd)`, like `rnorm()`: the mean and the standard deviation.
#' * `uniform(min, max)`, like `runif()`: the smallest and the largest value.
#' * `exponential(rate)`, like `rexp()`: the rate, so that the mean is
#'   `1 / rate`.
#' * `bernoulli(prob)`, like `rbinom(n, 1, prob)`: 1 with probability `prob`,
#'   and 0 otherwise.
#'
#' For any other distribution, draw a sample in R and pass it to
#' [empirical()]. `distribution(head, ...)` names a distribution that the
#' service offers but this package has no function for yet; the service
#' refuses a name it does not know.
#'
#' @section Parameters that depend on a decision:
#' A parameter may be an expression of decision variables rather than a
#' number. The distribution then depends on the decision: a demand whose mean
#' falls as the price rises, or a breakdown that becomes less likely the more
#' is spent on maintenance. A parameter cannot contain a random variable.
#'
#' A parameter given as a number is checked right away: a rate that is not
#' positive, a probability outside 0 to 1, or a `min` above `max` is an error.
#' A parameter given as an expression cannot be checked in advance, so give
#' the decision variables in it bounds that keep it in range.
#'
#' @section Vector parameters:
#' A parameter may be a vector. The distribution then describes that many
#' random variables, drawn independently: `normal(c(6, 5, 4), 1)` is three
#' normal variables with means 6, 5 and 4 and standard deviation 1. Each
#' parameter has length 1 or the common length.
#'
#' @param head The name under which the service knows the distribution.
#' @param ... The distribution's parameters, each a number, a numeric vector,
#'   or an expression without random variables.
#' @return A distribution, to be passed to [rand_var()] or
#'   [set_distribution()].
#' @examples
#' m <- model()
#' lead_time <- rand_var(m, "lead_time", uniform(2, 5))      # between 2 and 5 days
#' gap       <- rand_var(m, "gap", exponential(1 / 30))      # 30 minutes on average
#' fails     <- rand_var(m, "fails", bernoulli(0.02))        # 1 with probability 0.02
#'
#' # the more is spent on maintenance, the less likely a breakdown
#' spend  <- num_var(m, "spend", lower = 0, upper = 10)
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
#' @param mean,sd The mean and the standard deviation, as in `rnorm()`.
#' @export
normal <- function(mean, sd) distribution("normal", mean, sd)

#' @rdname distribution
#' @param min,max The smallest and the largest value, as in `runif()`.
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
#' An expression that contains a random variable has a different value in
#' each scenario, and is called *random*. Summarizing it across the scenarios,
#' for example with [expectation()], gives a single number again:
#' `demand - stock` is random, `expectation(demand - stock)` is not, and
#' neither is `3 * stock`.
#'
#' An objective or a constraint must not be random, and a summary such as
#' [expectation()] needs a random expression to summarize. quicopt checks
#' both rules itself and stops with an error when one is broken, so you need
#' `is_random()` only in your own code, for example in a function that
#' accepts both kinds of expression.
#'
#' @param x An expression, or a numeric vector (which is never random).
#' @return A logical vector with one element per element of `x`.
#' @examples
#' m <- model()
#' stock  <- num_var(m, "stock", lower = 0, upper = 200)
#' demand <- rand_var(m, "demand", normal(100, 15))
#' is_random(demand - stock)                  # TRUE
#' is_random(expectation(demand - stock))     # FALSE
#' is_random(c(stock, stock^2))               # FALSE FALSE
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
#' A random variable stands for a quantity that is not known when the
#' decision is made, such as tomorrow's demand. It can be used in expressions
#' like a decision variable, but the service does not choose its value: in
#' each scenario, the value is drawn from the variable's distribution. Within
#' one scenario, every use of the variable has the same value. Two random
#' variables declared separately are drawn independently.
#'
#' A random variable has no bounds; its distribution says which values it
#' can take.
#'
#' A distribution with vector parameters declares several random variables
#' under one name, which behave like an R vector: `rand_var(m, "hours",
#' normal(c(6, 5, 4), 1))` declares `hours[1]`, `hours[2]` and `hours[3]`.
#' With scalar parameters and `n` given, it declares `n` variables with the
#' same distribution. Either way, the elements are drawn independently of each
#' other. Random variables that move together, such as demand and price, are
#' best declared from observed data with [set_empirical()].
#'
#' `add_rand_var()` declares the variable in the same way but returns the
#' model, for use in a pipe; `m$name` then retrieves the variable.
#'
#' @param m A [model()].
#' @param name The random variable's name, unique within the model.
#' @param dist A distribution such as `normal(100, 15)` (see [distribution()]),
#'   or an [empirical()] sample with one value per scenario. It may be left out
#'   and given later with [set_distribution()].
#' @param n How many random variables to declare under this name. Left `NULL`,
#'   the number follows from the length of the distribution's parameters.
#' @return The random variable, an expression of length `n`.
#' @examples
#' m <- model()
#' demand <- rand_var(m, "demand", normal(100, 15))
#' hours  <- rand_var(m, "hours", normal(c(6, 5, 4), 1))    # three, one per job
#' delay  <- rand_var(m, "delay", uniform(1, 1.5), n = 4)   # four with the same distribution
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
#' Sets or replaces the distribution of a random variable declared with
#' [rand_var()], for example one declared without a distribution.
#'
#' @param m A [model()].
#' @param v The random variable, as returned by [rand_var()].
#' @param dist A distribution such as `normal(100, 15)`, or an [empirical()]
#'   sample, of the same length as `v`.
#' @return The model, invisibly.
#' @examples
#' m <- model()
#' demand <- rand_var(m, "demand")
#' set_distribution(m, demand, normal(100, 15))
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
#' @return `add_rand_var()` returns the model, invisibly.
#' @export
add_rand_var <- function(m, name, dist = NULL, n = NULL) {
  rand_var(m, name, dist, n)
  invisible(m)
}

#' Set how many scenarios are drawn, and from which seed
#'
#' The service draws `n` scenarios: `n` possible outcomes of the model's
#' random variables. More scenarios describe the uncertainty more accurately,
#' and take longer to solve. A model whose scenarios are never set is solved
#' over a single scenario, unless an [empirical()] sample sets the number by
#' its length.
#'
#' The number of scenarios and the seed belong to the model, so solving the
#' same model again uses the same scenarios, and two solves of it can be
#' compared. The scenarios are drawn by the service, so R's `set.seed()` has
#' no effect on them.
#'
#' The service limits the number of scenarios. A model above the limit is
#' refused when it is solved, with a message that states the limit.
#'
#' @param m A [model()].
#' @param n How many scenarios to draw, at least 1.
#' @param seed The seed for the draws, at least 1. Left `NULL`, the model
#'   keeps its current seed.
#' @return The model, invisibly.
#' @examples
#' m <- model()
#' demand <- rand_var(m, "demand", normal(100, 15))
#' set_scenarios(m, 512, seed = 42)
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

#' Use observed data as a model's uncertainty
#'
#' Turns the columns of a data frame into random variables: each column
#' becomes one, named after the column, and each row becomes one scenario.
#' The columns are read row by row, so values observed together stay
#' together, and any correlation between the columns carries over into the
#' model. No distribution has to be chosen or fitted.
#'
#' The random variables are not returned; retrieve them by name, as
#' `m$demand`. The number of scenarios is set to the number of rows.
#'
#' Every column used must be numeric; a column that is not is an error rather
#' than being skipped. Use `cols` to select the columns that describe the
#' uncertainty when the data frame holds others too.
#'
#' @param m A [model()].
#' @param data A data frame with one row per observation.
#' @param cols The names of the columns to use. Left `NULL`, all of them.
#' @return The model, invisibly.
#' @examples
#' history <- data.frame(demand = c(96, 104, 121, 88, 110),
#'                       price  = c(12.1, 11.8, 11.2, 12.5, 11.6))
#' m <- model()
#' stock <- num_var(m, "stock", lower = 0, upper = 200)
#' set_empirical(m, history)
#' maximize(m, expectation(m$price * min(m$demand, stock)) - 3 * stock)
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

#' The average over the scenarios
#'
#' `expectation(x)` is the average of `x` over the model's scenarios: an
#' estimate of its expected value. It turns a random expression into a single
#' number, which can be used in the objective or in a constraint.
#'
#' Minimizing an average makes the typical scenario good, and says little
#' about the bad ones; [cvar()] looks at those instead. For a vector `x`, each
#' element is averaged separately.
#'
#' @param x A random expression (see [is_random()]).
#' @return An expression of the same length as `x`, no longer random.
#' @examples
#' m <- model()
#' stock  <- num_var(m, "stock", lower = 0, upper = 200)
#' demand <- rand_var(m, "demand", normal(100, 15))
#' set_scenarios(m, 512, seed = 42)
#' shortfall <- max(demand - stock, 0)        # units short, in each scenario
#' minimize(m, 3 * stock + 10 * expectation(shortfall))
#' @export
expectation <- function(x)
  .qexpr(lapply(.need_random(x, "expectation()"), function(n) ir_apply("smean", list(n))))

#' The average over the worst scenarios
#'
#' `cvar(x, alpha)` is the average of `x` over the worst `1 - alpha` share of
#' the scenarios, the ones in which `x` is largest. With `alpha = 0.95`, it is
#' the average over the worst 5%. The measure is known as the *conditional
#' value at risk*. Minimizing it asks for a decision that keeps the bad
#' scenarios as good as possible, rather than the average one.
#'
#' `x` is read as a cost: large values are bad. For a profit, use the
#' negative, `cvar(-profit, 0.95)`.
#'
#' @param x A random expression (see [is_random()]).
#' @param alpha A number strictly between 0 and 1. It cannot depend on a
#'   decision.
#' @return An expression of the same length as `x`, no longer random.
#' @examples
#' m <- model()
#' stock  <- num_var(m, "stock", lower = 0, upper = 200)
#' demand <- rand_var(m, "demand", normal(100, 15))
#' set_scenarios(m, 512, seed = 42)
#' cost <- 3 * stock + 10 * max(demand - stock, 0)
#' minimize(m, cvar(cost, 0.95))              # the average cost of the worst 5% of scenarios
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
#' How much a quantity varies from scenario to scenario, as opposed to what
#' it is on average. `expectation(cost) + 2 * std_dev(cost)` is an objective
#' that trades a low average cost against a steady one, and
#' `add(m, variance(cost) <= 100)` limits the variation.
#'
#' By default the scenarios count as the whole distribution, each with weight
#' `1 / n`, so `variance(x)` is `expectation(x^2) - expectation(x)^2`. R's
#' `var()` and `sd()` divide by `n - 1` instead, because they estimate the
#' variance of a population from a sample of it; `sample = TRUE` does the
#' same. The two differ by a factor `n / (n - 1)`, which changes the value
#' reported but not which decision is best.
#'
#' Unlike [cvar()], these measure variation in both directions: a scenario
#' far better than average increases them as much as one far worse.
#'
#' @param x A random expression (see [is_random()]).
#' @param sample `FALSE`, the default, divides by the number of scenarios;
#'   `TRUE` divides by one less, as `var()` and `sd()` do.
#' @return An expression of the same length as `x`, no longer random.
#' @examples
#' m <- model()
#' stock  <- num_var(m, "stock", lower = 0, upper = 200)
#' demand <- rand_var(m, "demand", normal(100, 15))
#' set_scenarios(m, 512, seed = 42)
#' cost <- 3 * stock + 10 * max(demand - stock, 0)
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
#' The value a quantity takes in one particular scenario:
#'
#' * `scenario_max(x)` is the largest value of `x` among the scenarios.
#'   Minimizing it makes the worst scenario as good as possible.
#' * `scenario_min(x)` is the smallest. Maximizing it does the same for a
#'   quantity where large is good, such as a profit.
#' * `scenario_quantile(x, prob)` is the value that the share `prob` of the
#'   scenarios stays at or below. With `n` scenarios it is the
#'   `ceiling(prob * n)`-th smallest value, which is what
#'   `quantile(x, prob, type = 1)` returns for a sample.
#'   `scenario_quantile(x, 1)` is `scenario_max(x)`. For a cost it is also
#'   known as the *value at risk*; [cvar()] at the same level is the average
#'   of the values above it.
#'
#' These are different from `max()`, `min()` and `quantile()`. `max(a, b)`
#' compares two expressions *within* each scenario, and the result is still
#' random. `scenario_max(x)` compares the values of one expression *across*
#' the scenarios, and the result is a single number.
#'
#' A single scenario decides the largest or smallest value, so it changes
#' more from one sample of scenarios to the next than an average does, and a
#' larger sample usually contains a more extreme scenario. Check a solution
#' found with these on new scenarios, with [resample()].
#'
#' @param x A random expression (see [is_random()]).
#' @param prob A number above 0 and at most 1. It cannot depend on a decision.
#' @return An expression of the same length as `x`, no longer random.
#' @examples
#' m <- model()
#' stock  <- num_var(m, "stock", lower = 0, upper = 200)
#' demand <- rand_var(m, "demand", normal(100, 15))
#' set_scenarios(m, 512, seed = 42)
#' cost <- 3 * stock + 10 * max(demand - stock, 0)
#' minimize(m, scenario_max(cost))                  # the cost of the worst scenario
#' add(m, scenario_quantile(cost, 0.95) <= 500)     # at most 500 in 95% of scenarios
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
#' `prob(a <= b)` is the share of the scenarios in which `a <= b` holds: an
#' estimate of its probability. It is a single number, so it can be used in a
#' constraint. A requirement on a probability is called a *chance
#' constraint*:
#'
#' ```r
#' add(m, prob(demand <= stock) >= 0.9)
#' ```
#'
#' reads as "demand is met in at least 90% of the scenarios". The line holds
#' two comparisons, which do different jobs: the inner one, `demand <= stock`,
#' is the event checked in each scenario, and the outer one, `>= 0.9`, is the
#' requirement on how often it happens. The `margin` argument of [add()]
#' allows for the sampling error of the estimate.
#'
#' The comparison is written with `<=` or `>=`, and at least one side must
#' contain a random variable. `==` is not accepted, since the probability
#' that a quantity which can take any value equals one particular value is 0.
#' `<` and `>` are not accepted either, since for such a quantity they mean
#' the same as `<=` and `>=`. For vector expressions, each element gets its
#' own probability.
#'
#' [holds()] turns the same comparison into a 0/1 value in each scenario, and
#' `expectation(holds(a <= b))` is the same number as `prob(a <= b)`.
#'
#' @param rel A comparison of expressions, written with `<=` or `>=`.
#' @return An expression with one probability, between 0 and 1, per element
#'   of the comparison.
#' @examples
#' m <- model()
#' stock  <- num_var(m, "stock", lower = 0, upper = 200)
#' demand <- rand_var(m, "demand", normal(100, 15))
#' set_scenarios(m, 512, seed = 42)
#' add(m, prob(demand <= stock) >= 0.9)       # demand met in at least 90% of scenarios
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
