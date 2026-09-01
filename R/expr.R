# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

#' quicopt expressions — model arithmetic in plain R
#'
#' Arithmetic on a model's variables builds an expression rather than computing
#' a number, and comparing two expressions builds a constraint rather than
#' answering a logical. The operators are R's own — `+ - * / ^`, `sqrt`, `exp`,
#' `log`, `sin`, `cos`, `abs`, `max`, `min`, `sum`, `prod` — dispatched through
#' the `Ops`, `Math` and `Summary` group generics, so a model reads as ordinary
#' R code.
#'
#' Expressions are vectors, like everything in R: a variable declared with
#' `n = 10` has length 10, arithmetic is elementwise, `x[3]` indexes, and
#' `sum(x)` folds. Lengths must match exactly or be 1 (a scalar broadcasts);
#' anything else is an error — a model is no place for silent recycling.
#'
#' An operator the service does not support raises at the point of use. So do
#' the comparisons that have no constraint counterpart: `<` and `>` (use `<=`
#' or `>=`, which for continuous quantities mean the same thing) and `!=`.
#'
#' One caveat comes with `==` building a constraint: `unique()` still works on
#' these objects, but `%in%` and `match()` silently answer as if no two were
#' equal — compare identity with `identical()` instead.
#'
#' @name expressions
NULL

# The operator catalog this client emits — mirrors the service's published
# catalog; the server's decoded catalog is the final arbiter. A head outside it
# is a coverage gap to register service-side, never papered over here. The
# stochastic aggregator heads (smean, scvar, sfreq_*) are emitted only by
# expectation()/cvar()/prob(), which is the deliberate naming split: the public
# surface speaks probability, the wire speaks the catalog.
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
  if (nb == 1L) return(list(a, rep(b, na), nb))
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
    if (op == "-") return(.qexpr(lapply(nodes, function(n) ir_apply("-", list(n)))))
    stop("unary '", op, "' is not part of a model expression")
  }
  if (op %in% c("<=", ">=", "==")) return(.relation(e1, e2, op))
  if (op %in% c("<", ">"))
    stop("a constraint uses <= or >=, not strict '", op,
         "' (for a continuous quantity they mean the same thing)")
  if (op == "!=")
    stop("'!=' is not a constraint the service can express; ",
         "model it with a binary variable and two big-M rows")
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
    # semantics on numeric vectors; the catalog's + is n-ary, so this is one node.
    "sum" = .qexpr(list(if (length(nodes) == 0L) ir_const(0)
                        else if (length(nodes) == 1L) nodes[[1L]]
                        else ir_apply("+", nodes))),
    "prod" = .qexpr(list(if (length(nodes) == 0L) ir_const(1)
                         else if (length(nodes) == 1L) nodes[[1L]]
                         else ir_apply("*", nodes))),
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
    apply = {
      args <- vapply(n$args, .render, "")
      if (n$op %in% c("+", "-", "*", "/", "^") && length(args) >= 2L)
        paste0("(", paste(args, collapse = paste0(" ", n$op, " ")), ")")
      else if (n$op == "-" && length(args) == 1L) paste0("-", args)
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
