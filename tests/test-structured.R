# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

# Permutations and lookup tables: declarations, guardrails, the expressions
# they build, what the program and the bytes carry, and how a result's order
# comes back and is pinned again.
#
#     Rscript tests/test-structured.R

source(if (file.exists("tests/helper.R")) "tests/helper.R" else "helper.R")

internal <- function(name) {
  if (exists(name, envir = globalenv(), inherits = FALSE))
    get(name, envir = globalenv())
  else get(name, envir = asNamespace("quicopt"))
}

# Five stops on a line, stop 4 before stop 1: the tour of the examples.
tour_model <- function() {
  m <- model()
  where <- c(0, 3, 1, 4, 2)
  dist <- lookup_table(m, "dist", abs(outer(where, where, "-")))
  tour <- perm_var(m, "tour", 5)
  precede(tour, 4, 1)
  minimize(m, sum(dist[item_at(1:4, tour), item_at(2:5, tour)]))
  m
}

# ── declarations and guardrails ─────────────────────────────────────────────

m <- model()
tour <- perm_var(m, "tour", 5)
check("a permutation handle knows its model and size", identical(tour$model, m) && tour$n == 5L)
check("the handle is retrievable from the model", identical(m$tour$name, "tour"))
expect_error_like("a permutation needs at least two items", perm_var(m, "p", 1), "at least 2")
expect_error_like("a fractional size is refused", perm_var(m, "p", 2.5), "whole number")
expect_error_like("a name is declared once", perm_var(m, "tour", 3), "already declared")
expect_error_like("a name is shared with no variable", num_var(m, "tour"), "already declared")
expect_error_like("a start must be a permutation", perm_var(m, "p", 3, start = c(1, 1, 2)), "permutation of 1:3")
expect_error_like("a start has the right length", perm_var(m, "p", 3, start = c(2, 1)), "permutation of 1:3")
p <- perm_var(m, "p", 3, start = c(3, 1, 2))
check("a start is kept as given", identical(internal(".m_get")(m, "structures")$p$start, c(3L, 1L, 2L)))

expect_error_like("item_at needs a permutation", item_at(1, num_var(m, "x")), "perm_var")
expect_error_like("a slot is in range", item_at(6, tour), "from 1 to 5")
expect_error_like("an item is in range", slot_of(0, tour), "from 1 to 5")
expect_error_like("a position is a whole number", item_at(1.5, tour), "whole numbers")
expect_error_like("a bare permutation is not an expression", tour + 1, "item_at")

expect_error_like("an item cannot precede itself", precede(tour, 2, 2), "itself")
expect_error_like("a precedence names items in range", precede(tour, 1, 9), "from 1 to 5")
expect_error_like("one pair per call", precede(tour, 1:2, 3), "one item before one other")
precede(tour, 1, 2); precede(tour, 2, 3)
expect_error_like("a cycle is refused", precede(tour, 3, 1), "contradicts")
check("consistent requirements are kept, in order",
      identical(internal(".m_get")(m, "structures")$tour$precede, list(c(1L, 2L), c(2L, 3L))))

expect_error_like("a lookup table is numeric", lookup_table(m, "t", c("a", "b")), "numeric")
expect_error_like("a lookup table has no NA", lookup_table(m, "t", c(1, NA)), "no NA")
expect_error_like("a lookup table has at most two dimensions", lookup_table(m, "t", array(1, c(2, 2, 2))), "one or two")
cost <- lookup_table(m, "cost", c(3, 1, 4, 1.5))
dist <- lookup_table(m, "dist", matrix(1:9, 3))
check("the handles know their dimensions", identical(cost$dim, 4L) && identical(dist$dim, c(3L, 3L)))
expect_error_like("a vector table takes one index", cost[1, 2], "one index")
expect_error_like("a matrix table takes two", dist[1], "two positions")
expect_error_like("a plain index is in range", cost[5], "from 1 to 4")
expect_error_like("a plain index is whole", dist[1.5, 1], "whole numbers")
expect_error_like("a bare table is not an expression", cost + 1, "indexing")
expect_error_like("index lengths broadcast or match", dist[1:2, 1:3], "length mismatch")

# ── the expressions ─────────────────────────────────────────────────────────

e <- item_at(1:4, tour)
check("item_at is vectorized over the slots", length(e) == 4L)
n <- e$nodes[[3L]]
check("a part is the catalog operator over a constant and a structure reference",
      n$kind == "apply" && n$op == "item_at" && n$args[[1L]]$kind == "const" &&
      n$args[[1L]]$value == 3 && identical(n$args[[2L]], ir_struct_ref("tour")))
check("slot_of is the other direction", slot_of(2, tour)$nodes[[1L]]$op == "slot_of")

leg <- dist[item_at(1:2, tour), item_at(2:3, tour)]
check("a two-index lookup is one node per position", length(leg) == 2L)
check("the lookup names the table and carries both positions",
      leg$nodes[[1L]]$kind == "table" && leg$nodes[[1L]]$param == "dist" &&
      length(leg$nodes[[1L]]$index) == 2L && leg$nodes[[1L]]$index[[2L]]$op == "item_at")
check("a plain index becomes a constant", cost[2]$nodes[[1L]]$index[[1L]]$value == 2)
check("a scalar index broadcasts against a vector", length(dist[1, 1:3]) == 3L)
x <- int_var(m, "choice", 1, 4)
check("an integer variable indexes a table", cost[x]$nodes[[1L]]$index[[1L]]$kind == "var")

check("a part is not random", !is_random(item_at(1, tour)))
d <- rand_var(m, "d", normal(2, 1))
check("a lookup at a random position is random", is_random(cost[d]) && !is_random(cost[x]))
check("a lookup prints as an indexing", internal(".render")(leg$nodes[[1L]]) == "dist[item_at(1, tour), item_at(2, tour)]")
check("a lookup is closed by an aggregator", !is_random(expectation(cost[d])))
expect_error_like("a random lookup cannot be an objective", minimize(m, cost[d]), "still random")

# ── the program and its bytes ───────────────────────────────────────────────

mt <- tour_model()
prog <- as_program(mt)
check("the program declares the permutation",
      identical(prog$structures$tour, permutation_decl(5, integer(), FALSE, list(c(4L, 1L)))))
check("the program carries no decision variables for it", length(prog$vars) == 0L)
check("the table is a dense parameter table, one entry per cell",
      length(prog$params$dist) == 25L &&
      all(vapply(prog$params$dist, function(en) length(en$key) == 2L, NA)))
entry <- Filter(function(en) identical(en$key, list(2L, 4L)), prog$params$dist)[[1L]]
check("an entry is keyed by its row and column", entry$value == 1)
check("the objective sums four lookups", prog$objective$op == "+" && length(prog$objective$args) == 4L)
print_out <- capture.output(print(mt))
check("the model prints its permutation", any(grepl("1 permutation", print_out)))

bytes <- encode(mt)
has_text <- function(s) length(grepRaw(s, bytes, fixed = TRUE)) > 0L
check("the bytes carry the structure declaration (field 12, a kind of 'permutation')",
      has_text("permutation") && has_text("tour"))
check("the bytes carry the parts and the table", has_text("item_at") && has_text("dist"))
plain <- model(); y <- num_var(plain, "y", 0, 1); minimize(plain, y)
check("a model without a permutation encodes as before (no field 12)",
      identical(encode(plain), encode(program(vars = list(var_decl("y", character(), CONTINUOUS, 0, 1, 0)),
                                             objective = ir_var("y"), sense = "min"))))

# a fixed declaration and a start on the wire: the varint runs
prog$structures$tour$start <- c(2L, 1L, 4L, 5L, 3L)
prog$structures$tour$fixed <- TRUE
fixed_bytes <- encode(prog)
check("a start and a fix change the bytes", !identical(fixed_bytes, bytes) && length(fixed_bytes) > length(bytes))

# ── the result, and pinning the order again ─────────────────────────────────

recorder <- function(json) {
  e <- new.env(); e$requests <- list()
  e$fn <- function(req) {
    e$requests[[length(e$requests) + 1L]] <- req
    list(status = 200L, headers = list(), body = charToRaw(json))
  }
  e
}

answer <- '{"status":"heuristic","objective":4.0,"feasible":true,"solution":{},
            "solver_data":{"model_class":"structured"},
            "structures":{"tour":{"item_at":[4,2,5,3,1],"slot_of":[5,2,4,1,3]}}}'
rec <- recorder(answer)
res <- solve(mt, transport = rec$fn)
check("a result carries both views as integer vectors",
      identical(res$structures$tour$item_at, c(4L, 2L, 5L, 3L, 1L)) &&
      identical(res$structures$tour$slot_of, c(5L, 2L, 4L, 1L, 3L)))
check("the views agree", all(res$structures$tour$item_at[res$structures$tour$slot_of] == 1:5))
check("the class comes back", res$model_class == "structured")
res$display <- NULL
check("a result prints its order", any(grepl("item_at = \\[4, 2, 5, 3, 1\\]", capture.output(print(res)))))

plain_res <- solve(plain, transport = recorder('{"status":"optimal","objective":0,"solution":{"y":0}}')$fn)
check("a result without permutations has none", is.null(plain_res$structures))

set_start(mt, res)
check("set_start carries the order into the permutation's start",
      identical(internal(".m_get")(mt, "structures")$tour$start, c(5L, 2L, 4L, 1L, 3L)))

pinned <- internal(".pinned_program")
p <- pinned(mt, res, "test")
check("a pinned evaluation fixes the permutation at the order found",
      isTRUE(p$structures$tour$fixed) && identical(p$structures$tour$start, c(5L, 2L, 4L, 1L, 3L)))
expect_error_like("a bare vector cannot pin a permutation", pinned(mt, numeric(0), "test"), "solve\\(\\) result")
bad <- res; bad$structures$tour$slot_of <- c(1L, 1L, 2L, 3L, 4L)
expect_error_like("an inconsistent order is refused", pinned(mt, bad, "test"), "permutation of 1:5")

# evaluate() sends the pinned program with the expression as its objective
rec2 <- recorder('{"status":"heuristic","objective":1.0,"feasible":true,"solution":{}}')
v <- evaluate(mt, res, mt$dist[item_at(1, mt$tour), item_at(2, mt$tour)], transport = rec2$fn)
check("evaluate returns the pinned objective", v == 1.0)
want <- p
want$objective <- mt$dist[item_at(1, mt$tour), item_at(2, mt$tour)]$nodes[[1L]]
want$sense <- "min"; want$constraints <- list()
check("it sends the fixed permutation with the lookup as objective",
      identical(rec2$requests[[1L]]$body, encode(want)))

cat("all structured checks passed\n")
