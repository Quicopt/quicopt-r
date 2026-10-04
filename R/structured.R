# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

#' Sequencing and assignment: a permutation as a decision variable
#'
#' Some decisions are an order or a one-to-one assignment: the sequence of
#' stops on a round, the order of jobs on a machine, which facility goes to
#' which location. Written with plain variables, such a decision needs one
#' binary per (item, slot) pair and a row per item and per slot, and a cost
#' along the sequence is a product of binaries. A permutation variable says
#' it directly: `n` items go into `n` slots, one each, and the service keeps
#' that true by construction while it searches.
#'
#' There are two fixed numberings, both from 1 to `n`:
#'
#' * the **items** are the things being arranged, numbered as you listed them
#'   (the stops, the jobs, the facilities);
#' * the **slots** are the places they go, numbered in order (the steps of
#'   the round, the positions in the schedule, the locations).
#'
#' The permutation links the two, and it is read in both directions.
#' [item_at()]`(slot, P)` is the item that sits in a slot, and
#' [slot_of()]`(item, P)` the slot an item sits in; each is an integer
#' expression that the service decides, usable anywhere a model expression
#' is. Which one a model reads depends on where its data lives: a distance
#' between consecutive stops of a round is `dist[item_at(k, P), item_at(k + 1,
#' P)]`, data on the items read along the slots; the distance between the
#' locations of two facilities is `dist[slot_of(f, P), slot_of(g, P)]`, data
#' on the slots read along the items. Both use a [lookup_table()], a table of
#' numbers indexed by expressions.
#'
#' [precede()]`(P, a, b)` requires item `a` to sit in an earlier slot than
#' item `b`, which the search never violates. A solution reports both views
#' under `res$structures`, and [set_start()], [evaluate()] and [resample()]
#' carry a permutation along with the plain variables.
#'
#' A model with a permutation or a lookup is solved by search, like a model
#' under uncertainty, and the two combine: a round whose travel times are
#' random is a permutation inside an [expectation()].
#'
#' @param m A [model()].
#' @param name The permutation's name, unique within the model.
#' @param n How many items, and so how many slots; at least 2.
#' @param start Left `NULL`, item `i` starts in slot `i`. Otherwise
#'   `start[i]` is the slot item `i` starts in: a permutation of `1:n`.
#' @return The permutation's handle; `m$<name>` retrieves it too.
#' @examples
#' # Five stops on a line, visited along the shortest path, stop 4 before stop 1
#' m <- model()
#' where <- c(0, 3, 1, 4, 2)                          # where each stop lies
#' dist <- lookup_table(m, "dist", abs(outer(where, where, "-")))
#' tour <- perm_var(m, "tour", 5)                     # item: a stop; slot: a step
#' precede(tour, 4, 1)
#' minimize(m, sum(dist[item_at(1:4, tour), item_at(2:5, tour)]))
#' \dontrun{
#' res <- solve(m)
#' res$structures$tour$item_at                        # the stops in visiting order
#' }
#' @export
perm_var <- function(m, name, n, start = NULL) {
  .check_model(m, "perm_var")
  .check_name(m, name)
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 2 || n != trunc(n))
    stop("a permutation needs a whole number of items, at least 2")
  n <- as.integer(n)
  start <- .check_perm_start(start, n, name)
  # "quicopt" routes arithmetic on the bare handle into the group generics,
  # where .nodes_of names the right way to read it
  P <- structure(list(name = name, n = n, model = m), class = c("quicopt_perm", "quicopt"))
  vars <- .m_get(m, "vars")
  vars[[name]] <- P
  .m_set(m, "vars", vars)
  structs <- .m_get(m, "structures")
  structs[[name]] <- list(n = n, start = start, precede = list())
  .m_set(m, "structures", structs)
  P
}

# A start for a permutation of n items: NULL, or a permutation of 1:n.
.check_perm_start <- function(start, n, name) {
  if (is.null(start)) return(integer(0))
  if (!is.numeric(start) || anyNA(start) || length(start) != n ||
      any(start != trunc(start)) || !setequal(start, seq_len(n)))
    stop("'", name, "': start must be a permutation of 1:", n,
         " (start[i] is the slot item i starts in)")
  as.integer(start)
}

#' @rdname perm_var
#' @return `add_perm_var` returns the model, invisibly.
#' @export
add_perm_var <- function(m, name, n, start = NULL) {
  perm_var(m, name, n, start)
  invisible(m)
}

# A permutation handle, from this model.
.check_perm <- function(P, caller) {
  if (!inherits(P, "quicopt_perm"))
    stop(caller, " takes a permutation from perm_var(), got ", class(P)[[1L]])
  P
}

# Positions into a permutation of n: whole numbers in 1..n, vectorized.
.check_positions <- function(k, n, what, caller) {
  if (!is.numeric(k) || length(k) == 0L || anyNA(k) || any(k != trunc(k)) ||
      any(k < 1) || any(k > n))
    stop(caller, ": ", what, " must be whole numbers from 1 to ", n)
  as.integer(k)
}

#' Read a permutation: the item in a slot, the slot of an item
#'
#' `item_at(slot, P)` is the item that sits in `slot`, and `slot_of(item, P)`
#' the slot that `item` sits in, for a permutation `P` from [perm_var()]. Each
#' is an integer expression the service decides, and the two always agree.
#' Both are vectorized over their first argument: `item_at(1:4, P)` is the
#' items in the first four slots, as an expression of length 4.
#'
#' The first argument is a plain number, not a decision: it names a position
#' in one of the two fixed numberings. Data that depends on the result is read
#' through a [lookup_table()]: `dist[item_at(k, P), item_at(k + 1, P)]`.
#'
#' @param slot,item Positions, whole numbers from 1 to the permutation's size.
#' @param P A permutation from [perm_var()].
#' @return An integer-valued expression, one element per position.
#' @examples
#' m <- model()
#' tour <- perm_var(m, "tour", 5)
#' item_at(1, tour)                    # the first stop of the tour
#' slot_of(3, tour)                    # when stop 3 is visited
#' item_at(1:4, tour)                  # the first four stops, as a vector
#' @export
item_at <- function(slot, P) {
  .check_perm(P, "item_at")
  slot <- .check_positions(slot, P$n, "slots", "item_at")
  .qexpr(lapply(slot, function(k) ir_apply("item_at", list(ir_const(k), ir_struct_ref(P$name)))))
}

#' @rdname item_at
#' @export
slot_of <- function(item, P) {
  .check_perm(P, "slot_of")
  item <- .check_positions(item, P$n, "items", "slot_of")
  .qexpr(lapply(item, function(i) ir_apply("slot_of", list(ir_const(i), ir_struct_ref(P$name)))))
}

#' Require one item before another
#'
#' `precede(P, before, after)` requires item `before` to sit in an earlier
#' slot than item `after`, in every solution: a pickup before its delivery, a
#' job before the one that needs its output. The requirement is held by the
#' search itself, not by a penalty, so it is never violated. The requirements
#' of a permutation must be consistent: a cycle among them is refused.
#'
#' @param P A permutation from [perm_var()].
#' @param before,after Items, whole numbers from 1 to the permutation's size.
#' @return The permutation, invisibly.
#' @examples
#' m <- model()
#' tour <- perm_var(m, "tour", 5)
#' precede(tour, 4, 1)                 # stop 4 before stop 1
#' @export
precede <- function(P, before, after) {
  .check_perm(P, "precede")
  before <- .check_positions(before, P$n, "items", "precede")
  after <- .check_positions(after, P$n, "items", "precede")
  if (length(before) != 1L || length(after) != 1L)
    stop("precede takes one item before one other; call it once per requirement")
  if (before == after) stop("an item cannot precede itself")
  m <- P$model
  structs <- .m_get(m, "structures")
  edges <- c(structs[[P$name]]$precede, list(c(before, after)))
  if (.has_cycle(edges, P$n))
    stop("requiring ", before, " before ", after, " contradicts the requirements ",
         "already given for '", P$name, "'")
  structs[[P$name]]$precede <- edges
  .m_set(m, "structures", structs)
  invisible(P)
}

# Whether the edges (a list of c(before, after)) over 1..n contain a cycle:
# Kahn's algorithm leaves a node unplaced exactly when they do.
.has_cycle <- function(edges, n) {
  indeg <- integer(n)
  for (e in edges) indeg[[e[[2L]]]] <- indeg[[e[[2L]]]] + 1L
  ready <- which(indeg == 0L)
  placed <- 0L
  while (length(ready)) {
    x <- ready[[1L]]; ready <- ready[-1L]
    placed <- placed + 1L
    for (e in edges) if (e[[1L]] == x) {
      indeg[[e[[2L]]]] <- indeg[[e[[2L]]]] - 1L
      if (indeg[[e[[2L]]]] == 0L) ready <- c(ready, e[[2L]])
    }
  }
  placed < n
}

#' A table of numbers read at positions the solver decides
#'
#' Data that depends on a decision cannot be indexed with it in plain R:
#' `dist[item_at(1, tour), item_at(2, tour)]` has to be looked up after the
#' solver has chosen the order. A lookup table is such data, declared in the
#' model under a name, and indexing it with model expressions builds the
#' lookup as an expression: a vector table takes one index, a matrix table
#' two, and either index may be a number, a vector of numbers, or an
#' expression such as [item_at()] or an integer variable. The indexing is
#' vectorized, so `dist[item_at(1:4, P), item_at(2:5, P)]` is the four legs
#' of a five-stop round.
#'
#' The lookup is an ordinary expression: multiply it by a cost, sum it, put it
#' under an [expectation()]. Its value is the table entry at the chosen
#' positions; an index that is not a whole number in range is rounded and
#' clamped into the table, so a continuous variable may index a table too.
#'
#' A lookup makes the model one that is solved by search, as a permutation or
#' a random variable does. The table travels with the model, one entry per
#' cell, so a very large table makes for a large request.
#'
#' @param m A [model()].
#' @param name The table's name, unique within the model.
#' @param values A numeric vector or matrix, with no `NA`.
#' @return The table's handle; `m$<name>` retrieves it too.
#' @examples
#' m <- model()
#' where <- c(0, 3, 1, 4, 2)
#' dist <- lookup_table(m, "dist", abs(outer(where, where, "-")))
#' tour <- perm_var(m, "tour", 5)
#' leg <- dist[item_at(1:4, tour), item_at(2:5, tour)]     # the four legs
#' minimize(m, sum(leg))
#'
#' # a cost per option, chosen through an integer variable
#' cost <- lookup_table(m, "cost", c(3, 1, 4, 1.5))
#' choice <- int_var(m, "choice", 1, 4)
#' cost[choice]
#' @export
lookup_table <- function(m, name, values) {
  .check_model(m, "lookup_table")
  .check_name(m, name)
  if (!is.numeric(values) || length(values) == 0L || anyNA(values))
    stop("'", name, "': a lookup table is a numeric vector or matrix with no NA")
  if (is.matrix(values)) dim <- dim(values)
  else if (is.null(dim(values)) || length(dim(values)) == 1L) dim <- length(values)
  else stop("'", name, "': a lookup table has one or two dimensions")
  tbl <- structure(list(name = name, dim = dim, model = m), class = c("quicopt_table", "quicopt"))
  vars <- .m_get(m, "vars")
  vars[[name]] <- tbl
  .m_set(m, "vars", vars)
  tables <- .m_get(m, "tables")
  tables[[name]] <- if (is.matrix(values)) values else as.numeric(values)
  .m_set(m, "tables", tables)
  tbl
}

#' @rdname lookup_table
#' @param x A lookup table.
#' @param i,j Positions: numbers, or model expressions such as [item_at()];
#'   `j` only for a matrix table.
#' @return `x[i]` and `x[i, j]` return an expression, one element per position.
#' @export
`[.quicopt_table` <- function(x, i, j) {
  one <- length(x$dim) == 1L
  if (missing(i) || (!one && missing(j)))
    stop("'", x$name, "' is read at ", if (one) "one position: " else "two positions: ",
         x$name, if (one) "[i]" else "[i, j]")
  if (one && !missing(j))
    stop("'", x$name, "' is a vector table and takes one index")
  ni <- .index_nodes(i, x$dim[[1L]], x$name)
  if (one) return(.qexpr(lapply(ni, function(a) ir_table_ref(x$name, list(a)))))
  nj <- .index_nodes(j, x$dim[[2L]], x$name)
  bc <- .broadcast(ni, nj, paste0(x$name, "[i, j]"))
  .qexpr(mapply(function(a, b) ir_table_ref(x$name, list(a, b)), bc[[1L]], bc[[2L]], SIMPLIFY = FALSE))
}

# One index of a lookup as nodes: a plain position is checked against the
# table's extent here; an expression is the solver's to evaluate.
.index_nodes <- function(i, extent, name) {
  if (is.numeric(i)) {
    if (length(i) == 0L || anyNA(i) || any(i != trunc(i)) || any(i < 1) || any(i > extent))
      stop("'", name, "': a plain index must be whole numbers from 1 to ", extent)
    return(lapply(as.numeric(i), ir_const))
  }
  .nodes_of(i, paste0("lookup into '", name, "'"))
}

# ── printing ────────────────────────────────────────────────────────────────

#' @export
print.quicopt_perm <- function(x, ...) {
  s <- .m_get(x$model, "structures")[[x$name]]
  cat("permutation '", x$name, "': ", x$n, " items in ", x$n, " slots", sep = "")
  if (length(s$precede))
    cat(", ", length(s$precede), " precedence", if (length(s$precede) != 1L) "s", sep = "")
  cat("\n")
  invisible(x)
}

#' @export
print.quicopt_table <- function(x, ...) {
  cat("lookup table '", x$name, "': ", paste(x$dim, collapse = " x "), "\n", sep = "")
  invisible(x)
}

# ── lowering ────────────────────────────────────────────────────────────────

# The model's permutations as program declarations.
.structure_decls <- function(m)
  lapply(.m_get(m, "structures"),
         function(s) permutation_decl(s$n, s$start, FALSE, s$precede))

# The model's lookup tables as parameter tables: one entry per cell, keyed by
# its position (one or two indices).
.table_params <- function(m) {
  lapply(.m_get(m, "tables"), function(values) {
    if (is.matrix(values)) {
      idx <- which(!is.na(values), arr.ind = TRUE)
      Map(function(r, c) list(key = list(r, c), value = values[r, c]), idx[, 1L], idx[, 2L])
    } else {
      Map(function(k, v) list(key = list(k), value = v), seq_along(values), values)
    }
  })
}

# A result's reported permutations, each as its slot_of view, checked against
# the model: what set_start() and a pinned evaluation read.
.result_slots <- function(m, solution, caller) {
  structs <- .m_get(m, "structures")
  if (!length(structs)) return(list())
  if (!inherits(solution, "quicopt_result") || is.null(solution$structures))
    stop(caller, ": the model has a permutation, so it takes a solve() result, ",
         "which carries the order found")
  out <- list()
  for (name in names(structs)) {
    s <- solution$structures[[name]]
    if (is.null(s) || is.null(s$slot_of))
      stop(caller, ": the result carries no order for the permutation '", name, "'")
    out[[name]] <- .check_perm_start(as.integer(s$slot_of), structs[[name]]$n, name)
  }
  out
}
