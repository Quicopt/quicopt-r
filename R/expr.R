# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

#' Expressions: arithmetic on variables
#'
#' The values of decision variables and random variables are not known when
#' you write a model, so arithmetic on them cannot compute a number. Instead
#' it builds an *expression*: a description of a quantity, which the service
#' evaluates for every solution it considers. Expressions are written as
#' ordinary R code, with these operators and functions:
#'
#' * `+`, `-`, `*`, `/` and `^`;
#' * `abs()`, `sqrt()`, `exp()`, `log()`, `sin()` and `cos()`;
#' * `sum()`, `prod()`, `max()`, `min()` and `mean()`.
#'
#' Expressions need not be linear. Printing an expression shows what was
#' built.
#'
#' @section Expressions are vectors:
#' A variable declared with `n = 10` is an expression of length 10, and
#' expressions behave like numeric vectors in most ways: arithmetic works
#' element by element, `x[3]` picks one element, `c()` combines expressions
#' and numbers into a longer expression, and `length()` counts the elements.
#'
#' There are two differences. First, the two sides of an arithmetic operation
#' must have the same length, or one of them length 1. R would recycle the
#' shorter vector, which in a model is almost always a mistake, so here it is
#' an error. Second, `sum()`, `prod()`, `max()`, `min()` and `mean()` combine
#' all the elements of all their arguments into one, as they do for numbers:
#' `max(x, 0)` is the largest of all the elements of `x` and 0, not an
#' element-by-element maximum, and there is no `pmax()`. `mean(x)` is the mean
#' over the elements of `x`; the mean over the scenarios is [expectation()].
#'
#' @section Comparisons:
#' Comparing two expressions, as in `x <= y`, builds a comparison rather than
#' returning `TRUE` or `FALSE`. What the comparison means depends on the
#' function it is given to: [add()] makes it a constraint, [prob()] measures
#' how often it holds across the scenarios, and [holds()] turns it into an
#' expression that is 1 where it holds and 0 where it does not. `add()` and
#' `prob()` accept `<=` and `>=`, and `add()` also `==`; `holds()` accepts
#' all six comparisons.
#'
#' @section What does not work:
#' Functions not listed above, such as `round()`, `%%` and `log()` with a
#' base, stop with an error. Base R functions that are not written for
#' expressions do not work on them either: use [variance()] instead of
#' `var()`, [holds()] instead of `ifelse()`, and `identical()` instead of
#' `%in%` or `match()` to check whether two expressions are the same.
#'
#' In a model without random variables, `max()`, `min()` and [holds()] limit
#' the kind of model the service accepts: every variable must then be an
#' integer or a binary variable, with finite bounds. In a model with random
#' variables there is no such limit.
#'
#' @examples
#' m <- model()
#' tables <- num_var(m, "tables", lower = 0)
#' chairs <- num_var(m, "chairs", lower = 0)
#' 50 * tables + 20 * chairs                 # an expression, not a number
#' tables + chairs <= 18                     # a comparison, not TRUE or FALSE
#'
#' x <- num_var(m, "x", lower = 0, upper = 1, n = 3)
#' 2 * x                                     # element by element
#' sum(x)                                    # one expression
#' max(x, 0.5)                               # the largest of all four
#' @name expressions
NULL

# The operator catalog this client emits — mirrors the service's published
# catalog; the server's decoded catalog is the final arbiter. A head outside it
# is a coverage gap to register service-side, never papered over here. The
# stochastic aggregator heads (smean, scvar, sfreq_*, svar, svar_sample, sstd,
# smin, smax, squantile) are emitted only by the aggregator functions of
# stochastic.R, and the 0/1 heads (step, indicator) only by holds(), which is
# the deliberate naming split: the public surface speaks probability and
# events, the wire speaks the catalog.
.CATALOG_MATH <- c("sqrt", "exp", "log", "sin", "cos", "abs")

# A quicopt expression: a vector of IR nodes. Variable handles and random
# variables are subclasses carrying their extra fields; every operator works
# through `nodes` alone, so they compose uniformly.
.qexpr <- function(nodes, class = character())
  structure(list(nodes = nodes), class = c(class, "quicopt_expr", "quicopt"))

# The nodes of anything usable in model arithmetic: an expression's own, or a
# numeric vector's constants.
.nodes_of <- function(x, what = "expression") {
  if (inherits(x, "quicopt_expr")) return(x$nodes)
  if (inherits(x, "quicopt_perm"))
    stop("a permutation is read through item_at(slot, ", x$name, ") or slot_of(item, ",
         x$name, "), not used directly in a model ", what)
  if (inherits(x, "quicopt_table"))
    stop("a lookup table is read by indexing it, ", x$name,
         if (length(x$dim) == 1L) "[i]" else "[i, j]", ", not used directly in a model ", what)
  if (is.numeric(x) && !is.matrix(x)) {
    if (length(x) == 0L) stop("cannot use an empty numeric vector in a model ", what)
    if (anyNA(x)) stop("cannot use NA in a model ", what)
    return(lapply(as.numeric(x), ir_const))
  }
  stop("cannot use a ", class(x)[[1L]], " in a model ", what,
       "; expected a model expression or a numeric vector")
}

# Broadcast two node lists to a common length: equal lengths, or 1 against n.
# R's partial recycling (2 against 10) is refused — in a model it manufactures
# wrong constraints silently.
.broadcast <- function(a, b, op) {
  na <- length(a); nb <- length(b)
  if (na == nb) return(list(a, b, na))
  if (na == 1L) return(list(rep(a, nb), b, nb))
  if (nb == 1L) return(list(a, rep(b, na), na))
  stop("length mismatch in '", op, "': ", na, " against ", nb,
       " (lengths must be equal, or one of them 1)")
}

# ── the group generics ──────────────────────────────────────────────────────

#' @export
Ops.quicopt <- function(e1, e2) {
  op <- .Generic
  if (missing(e2)) {                                       # unary + / -
    nodes <- .nodes_of(e1)
    if (op == "+") return(.qexpr(nodes))
    # The catalog's minus is binary, and the service checks arity exactly, so
    # -x is spelled 0 - x on the wire, as the sibling clients spell it.
    if (op == "-") return(.qexpr(lapply(nodes, function(n) ir_apply("-", list(ir_const(0), n)))))
    stop("unary '", op, "' is not part of a model expression")
  }
  # A comparison is a relation, not a logical. Which relations may become a
  # constraint (add) or an event (prob, holds) is decided there, where the
  # message can say what to write instead.
  if (op %in% c("<=", ">=", "==", "<", ">", "!=")) return(.relation(e1, e2, op))
  if (!(op %in% c("+", "-", "*", "/", "^")))
    stop("'", op, "' is not in the operator catalog")
  bc <- .broadcast(.nodes_of(e1), .nodes_of(e2), op)
  .qexpr(mapply(function(a, b) ir_apply(op, list(a, b)),
                bc[[1L]], bc[[2L]], SIMPLIFY = FALSE))
}

#' @export
Math.quicopt <- function(x, ...) {
  op <- .Generic
  if (!(op %in% .CATALOG_MATH))
    stop("'", op, "' is not in the operator catalog")
  if (op == "log" && length(list(...)) > 0L)
    stop("log() in a model takes no base; the catalog's log is natural: ",
         "write log(x) / log(b) for another base")
  .qexpr(lapply(.nodes_of(x), function(n) ir_apply(op, list(n))))
}

#' @export
Summary.quicopt <- function(..., na.rm = FALSE) {
  op <- .Generic
  nodes <- unlist(lapply(list(...), .nodes_of), recursive = FALSE)
  switch(op,
    # sum/prod fold ALL elements of all arguments into one scalar, exactly R's
    # semantics on numeric vectors. The catalog's + is n-ary, so a sum is one
    # node; its * is binary, so a product nests left, like max and min.
    "sum" = .qexpr(list(if (length(nodes) == 0L) ir_const(0)
                        else if (length(nodes) == 1L) nodes[[1L]]
                        else ir_apply("+", nodes))),
    "prod" = .qexpr(list(if (length(nodes) == 0L) ir_const(1)
                         else Reduce(function(a, b) ir_apply("*", list(a, b)), nodes))),
    # max/min also fold everything, again R's own semantics (max(c(1, 5), 3) is
    # 5); the catalog's max is binary, so an n-ary call nests left.
    "max" = ,
    "min" = {
      if (length(nodes) == 0L) stop(op, "() of a model expression needs at least one argument")
      .qexpr(list(Reduce(function(a, b) ir_apply(op, list(a, b)), nodes)))
    },
    stop("'", op, "' is not in the operator catalog")
  )
}

# ── relations (the constraints-to-be) ───────────────────────────────────────

.relation <- function(lhs, rhs, op) {
  bc <- .broadcast(.nodes_of(lhs, "constraint"), .nodes_of(rhs, "constraint"), op)
  structure(list(lhs = bc[[1L]], rhs = bc[[2L]], op = op, n = bc[[3L]]),
            class = "quicopt_relation")
}

#' A comparison as a 0/1 expression
#'
#' `holds(a <= b)` is 1 when the comparison is true and 0 when it is false.
#' Unlike a constraint, it does not require anything: it is an expression
#' like any other, so it can be added up, multiplied by a cost, or used in
#' the objective. `sum(holds(x >= 1))`, for example, counts the elements of
#' `x` that are at least 1. All six comparisons are accepted, including `<`,
#' `>` and `!=`, which [add()] refuses.
#'
#' With random variables, `holds()` is evaluated in each scenario
#' separately. `expectation(holds(demand <= stock))` is then the share of
#' scenarios in which demand is met, the same number as
#' `prob(demand <= stock)`. The difference is that `holds()` lets you combine
#' the event with other quantities before averaging: for example,
#' `expectation(200 * holds(demand > stock))` is the expected cost of a fixed
#' charge of 200 whenever the stock runs out.
#'
#' `tol` loosens the comparison. `holds(a == b, tol = 0.01)` is 1 when `a`
#' and `b` are within 0.01 of each other, and `holds(a <= b, tol = 0.01)` is
#' 1 when `a` is at most `b + 0.01`. Without it, `==` and `!=` compare exactly.
#'
#' In a model without random variables, `holds()` limits the kind of model
#' the service accepts: every variable must then be an integer or a binary
#' variable, with finite bounds. The same holds for `max()` and `min()`. In a
#' model with random variables there is no such limit.
#'
#' @param rel A comparison of expressions.
#' @param tol How far the comparison may be off and still count as true; a
#'   number of at least 0.
#' @return An expression with one 0/1 element per element of the comparison.
#' @examples
#' m <- model()
#' stock  <- num_var(m, "stock", lower = 0, upper = 200)
#' demand <- rand_var(m, "demand", normal(100, 15))
#' set_scenarios(m, 512, seed = 42)
#' stockout <- holds(demand > stock)            # 1 in the scenarios where the stock runs out
#' minimize(m, 3 * stock + 200 * expectation(stockout))
#'
#' met <- holds(demand <= stock)
#' add(m, expectation(met) >= 0.9)              # the same as prob(demand <= stock) >= 0.9
#' @export
holds <- function(rel, tol = 0) {
  if (!inherits(rel, "quicopt_relation"))
    stop("holds takes a comparison, as in holds(demand <= x)")
  if (!is.numeric(tol) || length(tol) != 1L || is.na(tol) || tol < 0)
    stop("tol is one non-negative number")
  .qexpr(mapply(.holds_node, rel$lhs, rel$rhs,
                MoreArgs = list(op = rel$op, tol = tol), SIMPLIFY = FALSE))
}

# One 0/1 node for `lhs op rhs`. The catalog has two 0/1 heads: step (1 where
# the argument is at least 0) and indicator (1 where it is not 0). An exact
# equality uses indicator; a tolerance folds into the argument of step.
.holds_node <- function(lhs, rhs, op, tol) {
  minus <- function(a, b) ir_apply("-", list(a, b))
  step <- function(n) ir_apply("step", list(n))
  not <- function(n) ir_apply("-", list(ir_const(1), n))
  widen <- function(n) if (tol > 0) ir_apply("+", list(n, ir_const(tol))) else n
  gap <- function(n) if (tol > 0) ir_apply("-", list(n, ir_const(tol))) else n
  switch(op,
    "<=" = step(widen(minus(rhs, lhs))),                   # rhs + tol - lhs >= 0
    ">=" = step(widen(minus(lhs, rhs))),
    "<"  = not(step(gap(minus(lhs, rhs)))),                # not (lhs - rhs - tol >= 0)
    ">"  = not(step(gap(minus(rhs, lhs)))),
    "==" = if (tol > 0) step(minus(ir_const(tol), ir_apply("abs", list(minus(lhs, rhs)))))
           else not(ir_apply("indicator", list(minus(lhs, rhs)))),
    "!=" = if (tol > 0) not(step(minus(ir_const(tol), ir_apply("abs", list(minus(lhs, rhs))))))
           else ir_apply("indicator", list(minus(lhs, rhs))))
}

# ── vector behaviour ────────────────────────────────────────────────────────

#' @export
`[.quicopt_expr` <- function(x, i) {
  if (!is.numeric(i) || length(i) == 0L || anyNA(i) || any(i < 1L) || any(i != trunc(i)))
    stop("index a model expression with positive whole numbers")
  i <- as.integer(i)
  if (any(i > length(x$nodes)))
    stop("index out of bounds: the expression has length ", length(x$nodes))
  .qexpr(x$nodes[i])
}

#' @export
length.quicopt_expr <- function(x) length(x$nodes)

# c() concatenates expressions and numbers into one longer expression, as it
# concatenates numeric vectors; dispatch is on the first argument.
#' @export
c.quicopt_expr <- function(...)
  .qexpr(unlist(lapply(list(...), .nodes_of), recursive = FALSE))

# mean() folds the elements, as sum() and max() do; the mean over scenarios
# is expectation(). The plain generic would otherwise return NA with a warning.
#' @export
mean.quicopt_expr <- function(x, ...) {
  n <- length(x$nodes)
  if (n == 1L) return(.qexpr(x$nodes))
  .qexpr(list(ir_apply("/", list(ir_apply("+", x$nodes), ir_const(n)))))
}

# ── rendering ───────────────────────────────────────────────────────────────

.fmt_num <- function(v) {
  if (is.finite(v) && v == trunc(v) && abs(v) < 1e15) return(format(trunc(v)))
  format(v)
}

.render <- function(n) {
  switch(n$kind,
    const = .fmt_num(n$value),
    var = if (length(n$index)) paste0(n$name, "[", paste(vapply(n$index, as.character, ""),
                                                         collapse = ","), "]") else n$name,
    param = n$name,
    source = paste0("~", n$name),
    structure = n$name,
    table = paste0(n$param, "[", paste(vapply(n$index, .render, ""), collapse = ", "), "]"),
    apply = {
      args <- vapply(n$args, .render, "")
      # 0 - x is how the wire spells -x; print it the way it was written.
      if (n$op == "-" && length(args) == 2L && n$args[[1L]]$kind == "const" &&
          n$args[[1L]]$value == 0)
        paste0("-", args[[2L]])
      else if (n$op %in% c("+", "-", "*", "/", "^") && length(args) >= 2L)
        paste0("(", paste(args, collapse = paste0(" ", n$op, " ")), ")")
      else paste0(n$op, "(", paste(args, collapse = ", "), ")")
    },
    reduce = paste0(n$op, "_{", n$idx, " in ", n$over$name, "} ", .render(n$body)),
    paste0("<", n$kind, ">")
  )
}

#' @export
print.quicopt_expr <- function(x, ...) {
  lines <- vapply(x$nodes, .render, "")
  if (length(lines) == 1L) cat(lines, "\n", sep = "")
  else cat(paste0("[", seq_along(lines), "] ", lines, collapse = "\n"), "\n", sep = "")
  invisible(x)
}

#' @export
print.quicopt_relation <- function(x, ...) {
  for (i in seq_len(x$n))
    cat(.render(x$lhs[[i]]), x$op, .render(x$rhs[[i]]), "\n")
  invisible(x)
}
