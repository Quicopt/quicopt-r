# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

# The model is an environment, deliberately: reference semantics let one set of
# setters serve both call styles — set_scenarios(m, 512) mutates in place, and
# because every setter returns the model invisibly, m |> set_scenarios(512)
# chains. The pipe therefore mutates its input (m2 <- m |> ... leaves m2 and m
# the same object); that is what Pyomo and JuMP do, and it is documented rather
# than papered over with copy-on-write, which would stale every held handle.
#
# Internal state is read with get()/assign(), which do not dispatch: `$` is
# reserved for the user and resolves variable names only, so a variable named
# "vars" can never shadow the registry.

#' Create an empty optimization model
#'
#' A model owns decision variables, an objective, constraint rows, and — for a
#' model under uncertainty — random variables and a scenario count. Declare
#' variables with [num_var()], [int_var()], [bin_var()] and [rand_var()], state
#' the goal with [minimize()] or [maximize()], add constraints with [add()],
#' and hand the model to [solve()].
#'
#' Every setter both mutates the model and returns it invisibly, so the
#' imperative style and the pipe are the same functions:
#'
#' ```r
#' m <- model()
#' x <- num_var(m, "x", 0, 4)          # handle style
#'
#' m <- model() |>                     # pipe style; m$x retrieves the handle
#'   add_var("x", 0, 4)
#' ```
#'
#' Note the pipe mutates its input — the model is one shared object, not a
#' value being copied along the chain.
#'
#' @return A model, an environment of class `quicopt_model`.
#' @export
model <- function() {
  m <- new.env(parent = emptyenv())
  assign("vars", list(), envir = m)          # name -> handle, declaration order
  assign("objective", NULL, envir = m)       # a single IR node
  assign("sense", "min", envir = m)
  assign("constraints", list(), envir = m)   # list(f = node, set = conset)
  assign("sources", list(), envir = m)       # name -> distribution / empirical / NULL
  assign("scenarios", 1, envir = m)
  assign("seed", 1, envir = m)
  assign("scen_set", FALSE, envir = m)
  class(m) <- "quicopt_model"
  m
}

.m_get <- function(m, field) get(field, envir = m, inherits = FALSE)
.m_set <- function(m, field, value) assign(field, value, envir = m)

.check_model <- function(m, caller) {
  if (!inherits(m, "quicopt_model"))
    stop(caller, " expects a quicopt model() as its first argument, got ",
         class(m)[[1L]])
  m
}

.check_name <- function(m, name) {
  if (!is.character(name) || length(name) != 1L || is.na(name) || !nzchar(name))
    stop("a variable needs a name: one non-empty string")
  if (grepl("[][]", name))
    stop("'", name, "': square brackets are reserved for the elements of a ",
         "vector variable")
  if (!is.null(.m_get(m, "vars")[[name]]))
    stop("the name '", name, "' is already declared in this model")
  name
}

# Recycle a per-element setting (bounds, start) to a family's length, refusing
# anything between scalar and exact.
.per_element <- function(x, n, what, name) {
  if (!is.numeric(x) || anyNA(x)) stop("the ", what, " of '", name, "' must be numeric")
  if (length(x) == 1L) return(rep(as.numeric(x), n))
  if (length(x) == n) return(as.numeric(x))
  stop("the ", what, " of '", name, "' has length ", length(x),
       ", but the variable has length ", n)
}

.new_var <- function(m, name, domain, lower, upper, n, start, caller) {
  .check_model(m, caller)
  .check_name(m, name)
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 1 || n != trunc(n))
    stop("n must be a whole number of at least 1")
  n <- as.integer(n)
  lower <- .per_element(lower, n, "lower bound", name)
  upper <- .per_element(upper, n, "upper bound", name)
  start <- .per_element(start, n, "start", name)
  if (any(lower > upper))
    stop("'", name, "': a lower bound exceeds its upper bound")
  # A family lowers to flat scalar variables named name[i] — the well-trodden
  # wire subset every client emits. Solutions come back under these names.
  flat <- if (n == 1L) name else sprintf("%s[%d]", name, seq_len(n))
  v <- .qexpr(lapply(flat, ir_var), class = "quicopt_var")
  v$name <- name; v$n <- n; v$flat <- flat
  v$domain <- domain; v$lower <- lower; v$upper <- upper; v$start <- start
  v$model <- m                                 # the environment, by reference
  vars <- .m_get(m, "vars")
  vars[[name]] <- v
  .m_set(m, "vars", vars)
  v
}

#' Declare decision variables
#'
#' `num_var` declares a continuous variable, `int_var` an integer one, and
#' `bin_var` a binary one. With `n` greater than 1 the declaration is a vector
#' variable: `x[3]` indexes it, `sum(x)` folds it, arithmetic is elementwise,
#' and per-element bounds are given as vectors of length `n`. Solutions come
#' back keyed `"x"` for a scalar and `"x[1]"`, `"x[2]"`, ... for a vector.
#'
#' The handle is returned and is also retrievable from the model as `m$x`; the
#' `add_var` variant returns the model instead, for pipes.
#'
#' @param m A [model()].
#' @param name The variable's name, unique within the model.
#' @param lower,upper Bounds; `-Inf` / `Inf` leave a direction unbounded. A
#'   vector of length `n` sets per-element bounds.
#' @param n How many elements the variable has.
#' @param start The initial point handed to the solver.
#' @return The variable handle (an expression of length `n`).
#' @export
num_var <- function(m, name, lower = -Inf, upper = Inf, n = 1, start = 0)
  .new_var(m, name, CONTINUOUS, lower, upper, n, start, "num_var")

#' @rdname num_var
#' @export
int_var <- function(m, name, lower = -Inf, upper = Inf, n = 1, start = 0)
  .new_var(m, name, INTEGER, lower, upper, n, start, "int_var")

#' @rdname num_var
#' @export
bin_var <- function(m, name, n = 1, start = 0)
  .new_var(m, name, BINARY, 0, 1, n, start, "bin_var")

#' @rdname num_var
#' @param domain For `add_var`: `"num"`, `"int"` or `"bin"`.
#' @return `add_var` returns the model, invisibly.
#' @export
add_var <- function(m, name, lower = -Inf, upper = Inf, n = 1, start = 0,
                    domain = c("num", "int", "bin")) {
  switch(match.arg(domain),
         num = num_var(m, name, lower, upper, n, start),
         int = int_var(m, name, lower, upper, n, start),
         bin = bin_var(m, name, n, start))
  invisible(m)
}

# ── solutions as named vectors ──────────────────────────────────────────────

# Every decision variable's flat names, each mapped to (variable, element): the
# key under which a solution comes back, and under which a start is set.
.flat_lookup <- function(m) {
  out <- list()
  for (v in .m_get(m, "vars")) {
    if (inherits(v, "quicopt_rv")) next
    for (i in seq_len(v$n)) out[[v$flat[[i]]]] <- list(var = v$name, i = i)
  }
  out
}

# A solution as a named numeric vector keyed by flat names: either a result
# from solve(), or such a vector given directly. Names must be decision
# variables of this model; `complete` demands every one of them.
.solution_values <- function(m, solution, complete, caller) {
  if (inherits(solution, "quicopt_result")) solution <- solution$solution
  if (!is.numeric(solution) || is.null(names(solution)) || any(!nzchar(names(solution))))
    stop(caller, " takes a solve() result or a named numeric vector of variable values")
  if (anyNA(solution)) stop(caller, ": a variable value cannot be NA")
  lookup <- .flat_lookup(m)
  unknown <- setdiff(names(solution), names(lookup))
  if (length(unknown))
    stop(caller, ": no decision variable named ",
         paste0("'", unknown, "'", collapse = ", "), " in this model")
  if (complete) {
    missing <- setdiff(names(lookup), names(solution))
    if (length(missing))
      stop(caller, ": the solution gives no value for ",
           paste0("'", missing, "'", collapse = ", "))
  }
  solution
}

#' Start the search from a known solution
#'
#' Sets the start value of every variable named in `values`, so the next
#' solve begins there. The usual source is a previous result: solve, tighten
#' a constraint or add a scenario, and solve again from where the last search
#' ended rather than from scratch. Variables not named keep their start.
#'
#' An integer or binary variable's start is rounded by the service, and any
#' start is clamped into the variable's bounds.
#'
#' @param m A [model()].
#' @param values A result from [solve()], or a named numeric vector keyed the
#'   way a solution is: `"x"` for a scalar, `"x[1]"`, `"x[2]"`, ... for a
#'   vector variable.
#' @return The model, invisibly.
#' @examples
#' \dontrun{
#' res <- solve(m)
#' add(m, x <= 100)              # a new restriction
#' set_start(m, res)             # begin where the last search ended
#' solve(m)
#' }
#' @export
set_start <- function(m, values) {
  .check_model(m, "set_start")
  values <- .solution_values(m, values, complete = FALSE, caller = "set_start")
  lookup <- .flat_lookup(m)
  vars <- .m_get(m, "vars")
  for (key in names(values)) {
    at <- lookup[[key]]
    vars[[at$var]]$start[[at$i]] <- as.numeric(values[[key]])
  }
  .m_set(m, "vars", vars)
  invisible(m)
}

# ── objective and constraints ───────────────────────────────────────────────

.scalar_node <- function(e, what) {
  nodes <- .nodes_of(e, what)
  if (length(nodes) != 1L)
    stop("the ", what, " must be a single expression, got length ", length(nodes),
         "; fold a vector with sum() or another aggregation first")
  nodes[[1L]]
}

.set_objective <- function(m, e, sense, caller) {
  .check_model(m, caller)
  .m_set(m, "objective", .need_closed(.scalar_node(e, "objective"), "objective"))
  .m_set(m, "sense", sense)
  invisible(m)
}

#' State what the model optimizes
#'
#' The objective is a single expression; fold a vector with `sum()` first. A
#' model given no objective is a feasibility problem. In a model under
#' uncertainty the objective cannot be random: close it over the scenarios
#' first, with [expectation()], [cvar()] or another aggregator (the
#' [stochastic] topic lists them).
#'
#' @param m A [model()].
#' @param e The objective expression.
#' @return The model, invisibly.
#' @export
minimize <- function(m, e) .set_objective(m, e, "min", "minimize")

#' @rdname minimize
#' @export
maximize <- function(m, e) .set_objective(m, e, "max", "maximize")

#' Add constraints to a model
#'
#' A comparison of model expressions is a constraint, not a logical:
#' `add(m, x + y <= 5)` requires the row to hold, and `==` states an equality.
#' A comparison of vector expressions adds one row per element, so
#' `add(m, x <= cap)` with two length-`n` vectors is `n` rows. `<`, `>` and
#' `!=` are refused: for a continuous quantity the first two mean `<=` and
#' `>=`, and the third is no constraint at all (see [holds()] for the 0/1
#' expression it does make).
#'
#' A constraint cannot be random. In a model under uncertainty, close the
#' expression with an aggregator first ([expectation()], [cvar()], [prob()]
#' and the others the [stochastic] topic lists); a chance constraint is
#' `add(m, prob(demand - x <= 0) >= 0.9)`.
#'
#' @section A safety margin on a chance constraint:
#' The probability in `prob(...) >= 0.9` is estimated from the scenarios, and
#' an estimate has a standard error: `sqrt(0.9 * 0.1 / n)` for `n` scenarios,
#' about 0.013 at 512. A solution found with the constraint just satisfied in
#' sample therefore misses the level on fresh scenarios about half the time
#' (see [resample()]). `margin = k` asks for the level tightened by `k`
#' standard errors instead, `0.9 + k * sqrt(0.9 * 0.1 / n)` here, so that the
#' true probability clears the level with confidence `pnorm(k)`: about 84% at
#' `k = 1`, 98% at `k = 2`. For an upper bound, `prob(...) <= 0.1`, the level
#' is lowered instead. The margin applies to a comparison of a [prob()] with
#' a number strictly between 0 and 1, and is resolved against the scenario
#' count when the model is sent, so it may be given before [set_scenarios()].
#'
#' @section A constraint that applies only when a switch is on:
#' `when = b`, with `b` a binary variable, imposes the row only where `b` is
#' 1: `add(m, x <= 0, when = is_closed)`. `b` is one variable, or a vector
#' variable with one element per row. In a model with no random variable a
#' switched row makes the problem combinatorial, and the service then expects
#' integer variables with finite bounds, as for [holds()].
#'
#' @param m A [model()].
#' @param rel A comparison built with `<=`, `>=` or `==`.
#' @param margin For a chance constraint: how many standard errors to tighten
#'   the level by (default none).
#' @param when A binary variable (from [bin_var()]) that switches the row on.
#' @return The model, invisibly.
#' @examples
#' m <- model()
#' x <- num_var(m, "x", 0, 200)
#' demand <- rand_var(m, "demand", normal(100, 15))
#' set_scenarios(m, 512, seed = 42)
#' add(m, prob(demand - x <= 0) >= 0.9)              # the level as stated
#' add(m, prob(demand - x <= 0) >= 0.9, margin = 2)  # the level plus 2 SE: 0.927
#' @export
add <- function(m, rel, margin = 0, when = NULL) {
  .check_model(m, "add")
  if (!inherits(rel, "quicopt_relation"))
    stop("add() takes a comparison of model expressions, as in add(m, x + y <= 5)")
  if (rel$op %in% c("<", ">"))
    stop("a constraint uses <= or >=, not strict '", rel$op,
         "' (for a continuous quantity they mean the same thing)")
  if (rel$op == "!=")
    stop("'!=' is not a constraint the service can express; ",
         "model it with a binary variable and two big-M rows")
  if (!is.numeric(margin) || length(margin) != 1L || is.na(margin) || margin < 0)
    stop("margin is one non-negative number: how many standard errors to tighten by")
  if (!is.null(when)) {
    if (!inherits(when, "quicopt_var") || when$domain != BINARY)
      stop("when= takes a binary variable from bin_var(); got ",
           if (inherits(when, "quicopt_var")) "a non-binary variable" else class(when)[[1L]])
    if (when$n != 1L && when$n != rel$n)
      stop("when= has ", when$n, " elements, but the comparison has ", rel$n, " rows")
    if (!identical(when$model, m))
      stop("the switch '", when$name, "' belongs to a different model")
  }
  cons <- .m_get(m, "constraints")
  for (i in seq_len(rel$n)) {
    lhs <- rel$lhs[[i]]; rhs <- rel$rhs[[i]]
    if (.is_random_node(lhs) || .is_random_node(rhs))
      stop("the constraint '", .render(lhs), " ", rel$op, " ", .render(rhs),
           "' is still random: it contains a random variable that no ",
           "aggregator (expectation(), cvar(), prob(), ...) has closed over the scenarios")
    row <- if (margin > 0) .chance_row(lhs, rhs, rel$op, margin) else {
      # One sign convention: a <= b lands as b - a in Nonneg, a >= b as a - b,
      # and a == b as a - b in Zero. Against a literal 0 the difference is the
      # side itself: x >= 0 lands as x in Nonneg.
      f <- switch(rel$op, "<=" = .difference(rhs, lhs), .difference(lhs, rhs))
      list(f = f, set = if (rel$op == "==") zero() else nonneg())
    }
    if (!is.null(when)) row$when <- when$flat[[if (when$n == 1L) 1L else i]]
    cons[[length(cons) + 1L]] <- row
  }
  .m_set(m, "constraints", cons)
  invisible(m)
}

# a - b, except that subtracting a literal 0 leaves a alone.
.difference <- function(a, b)
  if (b$kind == "const" && b$value == 0) a else ir_apply("-", list(a, b))

# A chance constraint with a margin, kept as its parts (the probability node,
# the level, the direction) because the tightened level depends on the
# scenario count, which may still change; .row_constraint resolves it.
.chance_row <- function(lhs, rhs, op, margin) {
  is_prob <- function(n) n$kind == "apply" && n$op %in% c("sfreq_leq", "sfreq_geq")
  if (op == "==" || !(is_prob(lhs) && rhs$kind == "const" || is_prob(rhs) && lhs$kind == "const"))
    stop("margin applies to a chance constraint: a prob() on one side of <= or >= ",
         "and a probability level on the other")
  # Normalize to prob <op> level.
  if (is_prob(rhs)) { tmp <- lhs; lhs <- rhs; rhs <- tmp; op <- if (op == "<=") ">=" else "<=" }
  level <- rhs$value
  if (level <= 0 || level >= 1)
    stop("margin needs a probability level strictly between 0 and 1, got ", level)
  list(prob = lhs, level = level, tighten_up = op == ">=", margin = margin)
}

# One stored row as a wire constraint. The margin moves a lower bound on a
# probability up, and an upper bound down, by margin standard errors of the
# scenario estimate, and clamps into [0, 1]; a switch wraps the set.
.row_constraint <- function(row, n_scen) {
  if (is.null(row$prob)) { f <- row$f; set <- row$set } else {
    se <- sqrt(row$level * (1 - row$level) / n_scen)
    level <- min(max(row$level + (if (row$tighten_up) 1 else -1) * row$margin * se, 0), 1)
    f <- if (row$tighten_up) ir_apply("-", list(row$prob, ir_const(level)))
         else ir_apply("-", list(ir_const(level), row$prob))
    set <- nonneg()
  }
  if (!is.null(row$when)) set <- indicator(ir_var(row$when), set)
  constraint(f, set)
}

# ── user access ─────────────────────────────────────────────────────────────

#' @export
`$.quicopt_model` <- function(x, name) {
  v <- get("vars", envir = x, inherits = FALSE)[[name]]
  if (is.null(v)) {
    known <- names(get("vars", envir = x, inherits = FALSE))
    stop("no variable named '", name, "' in this model",
         if (length(known)) paste0(" (declared: ", paste(known, collapse = ", "), ")")
         else " (none declared yet)")
  }
  v
}

#' @export
`$<-.quicopt_model` <- function(x, name, value)
  stop("declare variables with num_var()/int_var()/bin_var()/rand_var(), ",
       "not by assignment")

#' @export
.DollarNames.quicopt_model <- function(x, pattern = "") {
  nm <- names(get("vars", envir = x, inherits = FALSE))
  nm[grepl(pattern, nm)]
}

#' @export
print.quicopt_model <- function(x, ...) {
  vars <- get("vars", envir = x, inherits = FALSE)
  decision <- Filter(function(v) !inherits(v, "quicopt_rv"), vars)
  random <- Filter(function(v) inherits(v, "quicopt_rv"), vars)
  nflat <- sum(vapply(decision, function(v) v$n, 0L))
  obj <- get("objective", envir = x, inherits = FALSE)
  cat("quicopt model: ", nflat, " variable", if (nflat != 1L) "s", sep = "")
  if (length(random)) {
    cat(", ", length(random), " random (",
        get("scenarios", envir = x, inherits = FALSE), " scenarios)", sep = "")
  }
  cat(", ", length(get("constraints", envir = x, inherits = FALSE)),
      " constraint row(s)\n", sep = "")
  if (!is.null(obj))
    cat("  ", get("sense", envir = x, inherits = FALSE), " ", .render(obj), "\n", sep = "")
  invisible(x)
}

# ── lowering ────────────────────────────────────────────────────────────────

#' Lower a model to a program
#'
#' The program is the model as plain data — what [encode()] serializes and the
#' service reads. [solve()] does this on the way out; call it directly to
#' inspect what will be sent.
#'
#' @param m A [model()].
#' @return A [program()].
#' @export
as_program <- function(m) {
  .check_model(m, "as_program")
  vars <- .m_get(m, "vars")
  decls <- list()
  for (v in vars) {
    if (inherits(v, "quicopt_rv")) next
    for (i in seq_len(v$n))
      decls[[length(decls) + 1L]] <-
        var_decl(v$flat[[i]], character(), v$domain, v$lower[[i]], v$upper[[i]], v$start[[i]])
  }

  specs <- .m_get(m, "sources")
  scen <- .m_get(m, "scenarios")
  scen_set <- .m_get(m, "scen_set")
  # An empirical column carries its own scenario count. When set_scenarios was
  # never called, the columns' shared length is adopted; when it was, every
  # column must match it.
  emp_len <- unique(vapply(Filter(function(s) inherits(s, "quicopt_empirical"), specs),
                           function(s) length(s$data), 0L))
  if (length(emp_len) > 1L)
    stop("empirical columns disagree on the number of scenarios: ",
         paste(sort(emp_len), collapse = " vs "))
  if (length(emp_len) == 1L) {
    if (!scen_set) scen <- emp_len
    else if (scen != emp_len)
      stop("the model is set to ", scen, " scenarios, but its empirical column",
           if (sum(vapply(specs, inherits, NA, "quicopt_empirical")) > 1L) "s carry " else " carries ",
           emp_len, " values")
  }

  # One wire source per element of a random variable, each with its own
  # parameters; an empirical column is always one.
  sources <- list()
  for (name in names(specs)) {
    spec <- specs[[name]]
    if (is.null(spec))
      stop("the random variable '", name, "' has no distribution; give it one ",
           "with set_distribution(), or declare it as rand_var(m, name, dist)")
    rv <- vars[[name]]
    if (inherits(spec, "quicopt_empirical")) sources[[name]] <- spec
    else for (i in seq_len(rv$n))
      sources[[rv$flat[[i]]]] <-
        parametric(spec$head, lapply(spec$params, .param_node, i = i))
  }

  obj <- .m_get(m, "objective")
  program(vars = decls,
          objective = if (is.null(obj)) ir_const(0) else obj,
          sense = .m_get(m, "sense"),
          constraints = lapply(.m_get(m, "constraints"), .row_constraint, n_scen = scen),
          scenarios = scen,
          scenario_seed = .m_get(m, "seed"),
          sources = sources)
}
