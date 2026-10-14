# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

#' Declare an ordering as a decision
#'
#' Some decisions are an arrangement: an ordering, such as the stops of a
#' courier's route or the jobs on a machine, or a one-to-one assignment, such
#' as which department moves into which office. `perm_var()` declares such a
#' decision, a *permutation*.
#'
#' @section Items and slots:
#' A permutation arranges `n` things, called *items*, in as many numbered
#' places, called *slots*, with exactly one item in each slot. Items and slots
#' are both numbered from 1 to `n`. What they stand for depends on the problem:
#'
#' * for a route, the items are the stops and the slots are the visits: slot
#'   1 is the first stop visited, slot 2 the second, and so on;
#' * for a machine, the items are the jobs and the slots are the positions in
#'   the queue;
#' * for an office plan, the items are the departments and the slots are the
#'   offices.
#'
#' [item_at()] gives the item in a slot, and [slot_of()] the slot of an item.
#' Both are expressions whose values the service chooses, like the value of a
#' decision variable. Data that depends on the arrangement, such as the
#' distance between consecutive stops, is read from a [lookup_table()]:
#' `dist[item_at(1:4, route), item_at(2:5, route)]` is the length of each of
#' the four legs of a five-stop route.
#'
#' [precede()] requires one item to be in an earlier slot than another, such
#' as a pickup before its delivery.
#'
#' @section The answer:
#' For each permutation, the result of [solve()] holds both directions under
#' `res$structures$<name>`: `item_at`, the item in each slot (for a route, the
#' stops in the order they are visited), and `slot_of`, the slot of each item.
#' [set_start()], [evaluate()] and [resample()] take the arrangement from a
#' result too.
#'
#' A model with a permutation is solved by a search, so its status is
#' `"heuristic"`. Permutations can be combined with random variables, for
#' example a route whose travel times are uncertain, minimized in
#' [expectation()]. `vignette("permutations", package = "quicopt")` works
#' through two examples.
#'
#' `add_perm_var()` declares the permutation in the same way but returns the
#' model, for use in a pipe; `m$name` then retrieves the permutation.
#'
#' @param m A [model()].
#' @param name The permutation's name, unique within the model.
#' @param n How many items, and so how many slots; at least 2.
#' @param start The arrangement the service's search starts from: `start[i]`
#'   is the slot of item `i`, so `start` contains each of the numbers 1 to `n`
#'   once. Left `NULL`, item `i` starts in slot `i`.
#' @return The permutation, for use with [item_at()], [slot_of()] and
#'   [precede()].
#' @examples
#' # Five stops along a road. Find the shortest route through all of them
#' # that visits stop 4 before stop 1.
#' position <- c(0, 3, 1, 4, 2)                      # km along the road, stops 1 to 5
#' m <- model()
#' dist  <- lookup_table(m, "dist", abs(outer(position, position, "-")))
#' route <- perm_var(m, "route", 5)
#' precede(route, 4, 1)                              # stop 4 is visited before stop 1
#' minimize(m, sum(dist[item_at(1:4, route), item_at(2:5, route)]))
#' \dontrun{
#' res <- solve(m)
#' res$structures$route$item_at                      # the stops in the order visited
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
  structs[[name]] <- list(kind = "permutation", n = n, start = start, precede = list())
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
#' @return `add_perm_var()` returns the model, invisibly.
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

#' The item in a slot, and the slot of an item
#'
#' For a permutation `P` from [perm_var()], `item_at(slot, P)` is the item in
#' a slot, and `slot_of(item, P)` is the slot that an item is in. For a route
#' whose items are stops and whose slots are the visits, `item_at(1, route)`
#' is the first stop visited, and `slot_of(3, route)` is when stop 3 is
#' visited.
#'
#' The result is an expression whose value the service chooses, like the
#' value of a decision variable. To use it to read data, such as the distance
#' between two stops, index a [lookup_table()] with it.
#'
#' The first argument is a plain number, or a vector of numbers, and both
#' functions return one element per number: `item_at(1:4, P)` is the items in
#' the first four slots, an expression of length 4.
#'
#' @param slot,item Whole numbers from 1 to the size of the permutation.
#' @param P A permutation from [perm_var()].
#' @return An expression with one element per element of the first argument,
#'   each a whole number from 1 to the size of the permutation.
#' @examples
#' m <- model()
#' route <- perm_var(m, "route", 5)
#' item_at(1, route)                   # the first stop visited
#' slot_of(3, route)                   # when stop 3 is visited
#' item_at(1:4, route)                 # the first four stops visited
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

#' Require one item to come before another
#'
#' `precede(P, before, after)` requires item `before` to be in an earlier
#' slot of the permutation `P` than item `after`: a pickup before its
#' delivery, or a job before the job that needs its output. The service only
#' considers arrangements that meet the requirement, so every solution meets
#' it.
#'
#' `precede()` may be called several times for one permutation. Requirements
#' that contradict each other, such as 1 before 2 and 2 before 1, are an
#' error.
#'
#' @param P A permutation from [perm_var()].
#' @param before,after Items: whole numbers from 1 to the size of the
#'   permutation.
#' @return The permutation, invisibly.
#' @examples
#' m <- model()
#' route <- perm_var(m, "route", 5)
#' precede(route, 4, 1)                # stop 4 is visited before stop 1
#' precede(route, 2, 5)                # and stop 2 before stop 5
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

#' A table of data indexed by decisions
#'
#' Sometimes a model needs a number from a table at a position that is not
#' known yet: the distance between the first and the second stop of a route
#' whose ordering the service is still choosing, or the price of an option that
#' an integer variable picks. An ordinary R vector or matrix cannot be indexed
#' this way. `lookup_table()` adds the data to the model under a name, and
#' indexing the result with expressions, such as [item_at()] or an integer
#' variable, builds an expression whose value is the entry at the positions
#' the service chooses.
#'
#' A table made from a vector takes one index, and a table made from a matrix
#' two. Each index may be a number, a vector of numbers, or an expression.
#'
#' Unlike indexing an ordinary R matrix, the two indices are paired up
#' element by element: `km[1:4, 2:5]` is a 4 x 4 block of a matrix `km`, but
#' for a lookup table `dist`, `dist[1:4, 2:5]` has four elements, the entries
#' `[1, 2]`, `[2, 3]`, `[3, 4]` and `[4, 5]`. This is what makes
#' `dist[item_at(1:4, P), item_at(2:5, P)]` the four legs of a five-stop
#' route.
#'
#' The result is an ordinary expression: it can be multiplied by a cost,
#' added up, or averaged with [expectation()]. An index that is not a whole
#' number is rounded, and one outside the table is moved to the nearest end,
#' so a continuous variable can be used as an index too.
#'
#' A model with a lookup table is solved by a search, so its status is
#' `"heuristic"`. The whole table is sent with the model, so a very large
#' table makes the request large.
#'
#' @param m A [model()].
#' @param name The table's name, unique within the model.
#' @param values A numeric vector or matrix without `NA`.
#' @return The table, to be indexed with `[`.
#' @examples
#' # the distances between five stops along a road
#' position <- c(0, 3, 1, 4, 2)
#' m <- model()
#' dist  <- lookup_table(m, "dist", abs(outer(position, position, "-")))
#' route <- perm_var(m, "route", 5)
#' legs  <- dist[item_at(1:4, route), item_at(2:5, route)]    # the four legs of the route
#' minimize(m, sum(legs))
#'
#' # the price of one of four options, picked by an integer variable
#' price  <- lookup_table(m, "price", c(3, 1, 4, 1.5))
#' choice <- int_var(m, "choice", lower = 1, upper = 4)
#' price[choice]
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
#' @param i,j Positions in the table: numbers, or expressions such as
#'   [item_at()]. `j` only for a table made from a matrix.
#' @return `x[i]` and `x[i, j]` return an expression with one element per
#'   position.
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

# ── partitions ──────────────────────────────────────────────────────────────

#' Divide items into groups as a decision
#'
#' Some decisions put things into groups: people into teams, jobs onto
#' machines, parcels into vans. `part_var()` declares such a decision, a
#' *partition*: each of `n` items goes into exactly one of `parts` groups,
#' called *parts*. Items are numbered from 1 to `n` and parts from 1 to
#' `parts`. A part may stay empty.
#'
#' [part_of()] gives the part an item is in, and [size_of()] how many items a
#' part holds. Both are expressions whose values the service chooses, like the
#' value of a decision variable. A requirement on the sizes, such as teams of
#' two and three, is an ordinary constraint: `add(m, size_of(1, teams) == 2)`.
#' Data that depends on an item's part, such as what a person costs in each
#' team, is read from a [lookup_table()]: `cost[1:5, part_of(1:5, teams)]`.
#' Whether an item is in a given part is `holds(part_of(i, teams) == t)`.
#'
#' @section The answer:
#' For each partition, the result of [solve()] holds `res$structures$<name>`
#' with two integer vectors: `part_of`, the part of each item, and `size_of`,
#' the number of items in each part. [set_start()], [evaluate()] and
#' [resample()] take the division from a result too.
#'
#' A model with a partition is solved by a search, so its status is
#' `"heuristic"`.
#'
#' `add_part_var()` declares the partition in the same way but returns the
#' model, for use in a pipe; `m$name` then retrieves the partition.
#'
#' @param m A [model()].
#' @param name The partition's name, unique within the model.
#' @param n How many items; at least 1.
#' @param parts How many parts; at least 2.
#' @param start The division the service's search starts from: `start[i]` is
#'   the part of item `i`, a whole number from 1 to `parts`. Left `NULL`, the
#'   service chooses one.
#' @return The partition, for use with [part_of()] and [size_of()].
#' @examples
#' # Six players of strengths 7, 5, 4, 3, 2 and 1 form a team of four and a
#' # team of two, as evenly matched as possible.
#' strength <- c(7, 5, 4, 3, 2, 1)                         # of players 1 to 6
#' m <- model()
#' teams <- part_var(m, "teams", 6, 2)                     # 6 players into teams 1 and 2
#' in_team <- function(t) holds(part_of(1:6, teams) == t)  # 1 for each player in team t
#' add(m, size_of(1, teams) == 4)                          # team 1 has four players
#' minimize(m, max(sum(strength * in_team(1)), sum(strength * in_team(2))))
#' \dontrun{
#' res <- solve(m)
#' res$objective                                           # 11
#' res$structures$teams$part_of                            # 2 1 2 1 1 1: players 1 and 3 form team 2
#' res$structures$teams$size_of                            # 4 2
#' }
#' @export
part_var <- function(m, name, n, parts, start = NULL) {
  .check_model(m, "part_var")
  .check_name(m, name)
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 1 || n != trunc(n))
    stop("a partition needs a whole number of items, at least 1")
  if (!is.numeric(parts) || length(parts) != 1L || is.na(parts) || parts < 2 ||
      parts != trunc(parts))
    stop("a partition needs a whole number of parts, at least 2")
  n <- as.integer(n); parts <- as.integer(parts)
  start <- .check_part_start(start, n, parts, name)
  P <- structure(list(name = name, n = n, parts = parts, model = m),
                 class = c("quicopt_partition", "quicopt"))
  vars <- .m_get(m, "vars")
  vars[[name]] <- P
  .m_set(m, "vars", vars)
  structs <- .m_get(m, "structures")
  structs[[name]] <- list(kind = "partition", n = n, parts = parts, start = start)
  .m_set(m, "structures", structs)
  P
}

# A start for a partition of n items into parts: NULL, or one part per item.
.check_part_start <- function(start, n, parts, name) {
  if (is.null(start)) return(integer(0))
  if (!is.numeric(start) || anyNA(start) || length(start) != n ||
      any(start != trunc(start)) || any(start < 1) || any(start > parts))
    stop("'", name, "': start must give each of the ", n, " items a part from 1 to ",
         parts, " (start[i] is the part item i starts in)")
  as.integer(start)
}

#' @rdname part_var
#' @return `add_part_var()` returns the model, invisibly.
#' @export
add_part_var <- function(m, name, n, parts, start = NULL) {
  part_var(m, name, n, parts, start)
  invisible(m)
}

# A partition handle.
.check_partition <- function(P, caller) {
  if (!inherits(P, "quicopt_partition"))
    stop(caller, " takes a partition from part_var(), got ", class(P)[[1L]])
  P
}

#' The part of an item, and the size of a part
#'
#' For a partition `P` from [part_var()], `part_of(item, P)` is the part an
#' item is in, and `size_of(part, P)` is how many items a part holds. For
#' people divided into teams, `part_of(3, teams)` is the team of person 3, and
#' `size_of(1, teams)` is the number of people in team 1.
#'
#' The result is an expression whose value the service chooses, like the
#' value of a decision variable. To read data that depends on an item's part,
#' index a [lookup_table()] with `part_of()`.
#'
#' The first argument is a plain number, or a vector of numbers, and both
#' functions return one element per number: `part_of(1:5, P)` is the parts of
#' the first five items, an expression of length 5.
#'
#' @param item Items: whole numbers from 1 to the number of items.
#' @param part Parts: whole numbers from 1 to the number of parts.
#' @param P A partition from [part_var()].
#' @return An expression with one element per element of the first argument:
#'   for `part_of()` each a whole number from 1 to the number of parts, for
#'   `size_of()` each a whole number from 0 to the number of items.
#' @examples
#' m <- model()
#' teams <- part_var(m, "teams", 5, 2)
#' part_of(3, teams)                   # the team of person 3
#' size_of(1, teams)                   # how many people are in team 1
#' part_of(1:5, teams)                 # everyone's team
#' @export
part_of <- function(item, P) {
  .check_partition(P, "part_of")
  item <- .check_positions(item, P$n, "items", "part_of")
  .qexpr(lapply(item, function(i) ir_apply("part_of", list(ir_const(i), ir_struct_ref(P$name)))))
}

#' @rdname part_of
#' @export
size_of <- function(part, P) {
  .check_partition(P, "size_of")
  part <- .check_positions(part, P$parts, "parts", "size_of")
  .qexpr(lapply(part, function(b) ir_apply("size_of", list(ir_const(b), ir_struct_ref(P$name)))))
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
print.quicopt_partition <- function(x, ...) {
  cat("partition '", x$name, "': ", x$n, " item", if (x$n != 1L) "s", " in ",
      x$parts, " parts\n", sep = "")
  invisible(x)
}

#' @export
print.quicopt_table <- function(x, ...) {
  cat("lookup table '", x$name, "': ", paste(x$dim, collapse = " x "), "\n", sep = "")
  invisible(x)
}

# ── lowering ────────────────────────────────────────────────────────────────

# The model's permutations and partitions as program declarations.
.structure_decls <- function(m)
  lapply(.m_get(m, "structures"), function(s)
    if (identical(s$kind, "partition")) partition_decl(s$n, s$parts, s$start, FALSE)
    else permutation_decl(s$n, s$start, FALSE, s$precede))

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

# A result's reported structures, each as the view a start is written in (a
# permutation's slot_of, a partition's part_of), checked against the model:
# what set_start() and a pinned evaluation read.
.result_starts <- function(m, solution, caller) {
  structs <- .m_get(m, "structures")
  if (!length(structs)) return(list())
  if (!inherits(solution, "quicopt_result") || is.null(solution$structures))
    stop(caller, ": the model has a permutation or a partition, so it takes a solve() ",
         "result, which carries the arrangement found")
  out <- list()
  for (name in names(structs)) {
    s <- solution$structures[[name]]
    decl <- structs[[name]]
    if (identical(decl$kind, "partition")) {
      if (is.null(s) || is.null(s$part_of))
        stop(caller, ": the result carries no division for the partition '", name, "'")
      out[[name]] <- .check_part_start(as.integer(s$part_of), decl$n, decl$parts, name)
    } else {
      if (is.null(s) || is.null(s$slot_of))
        stop(caller, ": the result carries no ordering for the permutation '", name, "'")
      out[[name]] <- .check_perm_start(as.integer(s$slot_of), decl$n, name)
    }
  }
  out
}
