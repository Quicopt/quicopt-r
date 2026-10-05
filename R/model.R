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

#' Create an empty model
#'
#' A model collects everything the service needs to find the best decision:
#' the decisions to be made, the objective, the constraints and, when some of
#' the data is uncertain, the random variables and the number of scenarios.
#' `model()` creates an empty one, and these functions fill it:
#'
#' * decisions: [num_var()], [int_var()], [bin_var()], and [perm_var()] for an
#'   order;
#' * uncertain data: [rand_var()] and [set_empirical()];
#' * the objective: [minimize()] or [maximize()];
#' * constraints: [add()].
#'
#' [solve()] then sends the model to the service. `m$name` retrieves a
#' variable declared in `m` by its name, and printing a model shows a short
#' summary of it.
#'
#' Each of the functions above changes the model in place and returns it
#' invisibly, so a model can also be written as a pipe:
#'
#' ```r
#' m <- model() |>
#'   add_var("x", lower = 0, upper = 4)    # m$x retrieves the variable
#' ```
#'
#' Unlike most R objects, a model is not copied when it is passed to a
#' function. After `m2 <- m |> add(m$x <= 3)`, `m` has the constraint too,
#' and `m2` and `m` are the same model.
#'
#' @return An empty model, an object of class `quicopt_model`.
#' @examples
#' m <- model()
#' tables <- num_var(m, "tables", lower = 0)
#' chairs <- num_var(m, "chairs", lower = 0)
#' maximize(m, 50 * tables + 20 * chairs)
#' add(m, tables + chairs <= 18)
#' m
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
  assign("structures", list(), envir = m)    # name -> list(n, start, precede), see structured.R
  assign("tables", list(), envir = m)        # name -> numeric vector or matrix
  class(m) <- "quicopt_model"
  m
}

# The registry holds four kinds of handle under one namespace: decision
# variables (quicopt_var), random variables (quicopt_rv), permutations
# (quicopt_perm) and lookup tables (quicopt_table). Only the first lowers to
# wire variables, which is what the solution is keyed by.
.is_decision <- function(v) inherits(v, "quicopt_var")

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
#' A decision variable is a quantity the service chooses. `num_var()`
#' declares one that can take any value between its bounds, `int_var()` one
#' that must be a whole number, and `bin_var()` a yes-or-no decision, which is
#' either 0 or 1.
#'
#' Each returns the variable, for use in expressions such as
#' `50 * tables + 20 * chairs`; `m$tables` retrieves it from the model too.
#' `add_var()` declares a variable in the same way but returns the model, for
#' use in a pipe (see [model()]).
#'
#' With `n` greater than 1, one call declares `n` variables under one name,
#' and they behave like an R vector: `x[3]` is the third, arithmetic works
#' element by element, and `sum(x)` adds them up. `lower`, `upper` and `start`
#' may then be vectors of length `n`, one value per element. In the answer the
#' elements are named `"x[1]"`, `"x[2]"`, and so on; a single variable is
#' named `"x"`.
#'
#' @param m A [model()].
#' @param name The variable's name, used for it in the answer. It must be
#'   unique within the model.
#' @param lower,upper The smallest and the largest value allowed. `-Inf` and
#'   `Inf`, the defaults, leave that side open.
#' @param n How many variables to declare under this name.
#' @param start The value the service's search starts from (see
#'   [set_start()]).
#' @return The variable, an expression of length `n`.
#' @examples
#' m <- model()
#' tables <- int_var(m, "tables", lower = 0)
#' take   <- bin_var(m, "take", n = 6)                         # six yes-or-no decisions
#' share  <- num_var(m, "share", lower = 0, upper = 1, n = 3)
#' sum(share)
#' take[2]
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
#' @param domain For `add_var()`: `"num"`, `"int"` or `"bin"`, to declare the
#'   variable as `num_var()`, `int_var()` or `bin_var()` would.
#' @return `add_var()` returns the model, invisibly.
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
    if (!.is_decision(v)) next
    for (i in seq_len(v$n)) out[[v$flat[[i]]]] <- list(var = v$name, i = i)
  }
  out
}

# A solution as a named numeric vector keyed by flat names: either a result
# from solve(), or such a vector given directly. Names must be decision
# variables of this model; `complete` demands every one of them.
.solution_values <- function(m, solution, complete, caller) {
  if (inherits(solution, "quicopt_result")) solution <- solution$solution
  # a model whose only decisions are permutations has an empty solution
  if (is.null(solution) || (is.numeric(solution) && length(solution) == 0L)) {
    solution <- numeric(0); names(solution) <- character(0)
  }
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

#' Start the next search from a known solution
#'
#' The service's search starts from each variable's start value, which is 0
#' unless set otherwise. When a model is solved again after a small change,
#' such as a tightened constraint or more scenarios, starting from the
#' previous answer usually gets to a good solution sooner than starting from
#' scratch. `set_start()` sets the start values from a result, or from a
#' named vector of values. Variables it is not given keep their start value.
#'
#' The service rounds the start of a whole-number variable, and moves a start
#' that lies outside the variable's bounds to the nearest bound. A result also
#' holds the order found for each permutation (see [perm_var()]), and that
#' order becomes the permutation's start.
#'
#' @param m A [model()].
#' @param values A result from [solve()], or a named numeric vector, with
#'   names as in a solution: `"x"` for a single variable, `"x[1]"`, `"x[2]"`,
#'   ... for the elements of a vector variable.
#' @return The model, invisibly.
#' @examples
#' \dontrun{
#' m <- model()
#' stock  <- num_var(m, "stock", lower = 0, upper = 200)
#' demand <- rand_var(m, "demand", normal(100, 15))
#' set_scenarios(m, 512, seed = 42)
#' minimize(m, 3 * stock + 10 * expectation(max(demand - stock, 0)))
#' res <- solve(m)
#'
#' set_scenarios(m, 1000, seed = 42)    # the same model, more scenarios
#' set_start(m, res)                    # start where the last search ended
#' solve(m)
#' }
#' @export
set_start <- function(m, values) {
  .check_model(m, "set_start")
  # a result's permutations, when it carries any; a plain vector names
  # decision variables only and leaves every permutation's start alone
  slots <- if (inherits(values, "quicopt_result") && !is.null(values$structures))
    .result_slots(m, values, "set_start") else list()
  values <- .solution_values(m, values, complete = FALSE, caller = "set_start")
  lookup <- .flat_lookup(m)
  vars <- .m_get(m, "vars")
  for (key in names(values)) {
    at <- lookup[[key]]
    vars[[at$var]]$start[[at$i]] <- as.numeric(values[[key]])
  }
  .m_set(m, "vars", vars)
  structs <- .m_get(m, "structures")
  for (name in names(slots)) structs[[name]]$start <- slots[[name]]
  .m_set(m, "structures", structs)
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

#' Set the objective
#'
#' The objective is the single number that the service makes as small
#' (`minimize()`) or as large (`maximize()`) as possible. Calling either
#' function again replaces the objective. An expression with several elements
#' has to be combined into one first, for example with `sum()`. A model
#' without an objective asks for any solution that meets the constraints.
#'
#' In a model with random variables, the objective has to be one number, not
#' one per scenario: summarize it first, for example with [expectation()]
#' (the [stochastic] help page lists all the summaries).
#'
#' @param m A [model()].
#' @param e The expression to minimize or maximize.
#' @return The model, invisibly.
#' @examples
#' m <- model()
#' tables <- num_var(m, "tables", lower = 0)
#' chairs <- num_var(m, "chairs", lower = 0)
#' maximize(m, 50 * tables + 20 * chairs)    # the profit
#' @export
minimize <- function(m, e) .set_objective(m, e, "min", "minimize")

#' @rdname minimize
#' @export
maximize <- function(m, e) .set_objective(m, e, "max", "maximize")

#' Add constraints to a model
#'
#' A comparison of expressions, written with `<=`, `>=` or `==`, becomes a
#' requirement that every solution must meet: `add(m, tables + chairs <= 18)`.
#' Here the comparison is not a test that returns `TRUE` or `FALSE`. A
#' comparison of two vectors adds one constraint per element, so with `x` and
#' `cap` of length `n`, `add(m, x <= cap)` adds `n` constraints.
#'
#' `<` and `>` are not accepted, because for a quantity that can take any
#' value they mean the same as `<=` and `>=`. `!=` is not accepted either;
#' [holds()] turns it into a 0/1 expression, which can be used instead.
#'
#' In a model with random variables, each side of a constraint has to be one
#' number, not one per scenario: summarize it first, for example with
#' [expectation()] or [prob()]. A requirement on a probability, such as
#' `add(m, prob(demand <= stock) >= 0.9)`, is called a *chance constraint*.
#'
#' @section A safety margin on a chance constraint:
#' The probability in a chance constraint is estimated from the scenarios, so
#' it carries sampling error. For a target `p` and `n` scenarios, its standard
#' error is `sqrt(p * (1 - p) / n)`, about 0.013 for `p = 0.9` and
#' `n = 512`. A solution chosen to just meet the target on its own scenarios
#' therefore misses the target on new scenarios about half the time (see
#' [resample()]).
#'
#' `margin = k` raises the target by `k` standard errors, so that the true
#' probability meets the original target with a confidence of about
#' `pnorm(k)`: 84% for `k = 1`, 98% for `k = 2`. For an upper limit, such as
#' `prob(...) <= 0.1`, the target is lowered instead. A margin applies only
#' when one side of the constraint is a [prob()] and the other a number
#' strictly between 0 and 1. The standard error is computed from the number
#' of scenarios when the model is solved, so the margin can be given before
#' [set_scenarios()] is called.
#'
#' @section A constraint with an on-off switch:
#' `when = b`, with `b` a binary variable from [bin_var()], makes the
#' constraint apply only in solutions in which `b` is 1. For example,
#' `add(m, output <= 0, when = closed)` forces the output to 0 only if the
#' plant is closed. `b` is a single variable, or a vector variable with one
#' element per constraint.
#'
#' In a model without random variables, a switch limits the kind of model
#' the service accepts: every variable must then be an integer or a binary
#' variable, with finite bounds. The same holds for [holds()], `max()` and
#' `min()`.
#'
#' @param m A [model()].
#' @param rel A comparison of expressions, written with `<=`, `>=` or `==`.
#' @param margin For a chance constraint: by how many standard errors to
#'   tighten the target. The default, 0, leaves it as written.
#' @param when A binary variable that switches the constraint on.
#' @return The model, invisibly.
#' @examples
#' m <- model()
#' tables <- num_var(m, "tables", lower = 0)
#' chairs <- num_var(m, "chairs", lower = 0)
#' add(m, 3 * tables + chairs <= 41)                      # hours of carpentry
#' add(m, tables + chairs <= 18)                          # wood
#'
#' # a chance constraint, without and with a safety margin
#' shop   <- model()
#' stock  <- num_var(shop, "stock", lower = 0, upper = 200)
#' demand <- rand_var(shop, "demand", normal(100, 15))
#' set_scenarios(shop, 512, seed = 42)
#' add(shop, prob(demand <= stock) >= 0.9)                # demand met on 90% of scenarios
#' add(shop, prob(demand <= stock) >= 0.9, margin = 2)    # the target raised to about 0.927
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
  decision <- Filter(.is_decision, vars)
  random <- Filter(function(v) inherits(v, "quicopt_rv"), vars)
  perms <- Filter(function(v) inherits(v, "quicopt_perm"), vars)
  nflat <- sum(vapply(decision, function(v) v$n, 0L))
  obj <- get("objective", envir = x, inherits = FALSE)
  cat("quicopt model: ", nflat, " variable", if (nflat != 1L) "s", sep = "")
  if (length(random)) {
    cat(", ", length(random), " random (",
        get("scenarios", envir = x, inherits = FALSE), " scenarios)", sep = "")
  }
  if (length(perms))
    cat(", ", length(perms), " permutation", if (length(perms) != 1L) "s", sep = "")
  cat(", ", length(get("constraints", envir = x, inherits = FALSE)),
      " constraint row(s)\n", sep = "")
  if (!is.null(obj))
    cat("  ", get("sense", envir = x, inherits = FALSE), " ", .render(obj), "\n", sep = "")
  invisible(x)
}

# ── lowering ────────────────────────────────────────────────────────────────

#' Convert a model to a program
#'
#' A program is the model written out as plain R lists: every variable,
#' expression and constraint, in the form that [encode()] turns into the
#' bytes sent to the service. [solve()] makes this conversion itself, so you
#' only need `as_program()` to look at exactly what a model sends, or to work
#' with the [program()] functions directly.
#'
#' @param m A [model()].
#' @return A [program()].
#' @examples
#' m <- model()
#' x <- num_var(m, "x", lower = 0, upper = 4)
#' maximize(m, 3 * x)
#' str(as_program(m)$vars)
#' @export
as_program <- function(m) {
  .check_model(m, "as_program")
  vars <- .m_get(m, "vars")
  decls <- list()
  for (v in vars) {
    if (!.is_decision(v)) next
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
  program(params = .table_params(m),
          vars = decls,
          objective = if (is.null(obj)) ir_const(0) else obj,
          sense = .m_get(m, "sense"),
          constraints = lapply(.m_get(m, "constraints"), .row_constraint, n_scen = scen),
          scenarios = scen,
          scenario_seed = .m_get(m, "seed"),
          sources = sources,
          structures = .structure_decls(m))
}
