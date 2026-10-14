# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

# Variables that are 0 or between their bounds, active(), blocks and
# partitions: declarations, guardrails, what the program carries, and how a
# result's partition comes back and is pinned again.
#
#     Rscript tests/test-blocks.R

source(if (file.exists("tests/helper.R")) "tests/helper.R" else "helper.R")

internal <- function(name) {
  if (exists(name, envir = globalenv(), inherits = FALSE))
    get(name, envir = globalenv())
  else get(name, envir = asNamespace("quicopt"))
}

# ── a variable that is 0 or between its bounds ──────────────────────────────

m <- model()
d <- int_var(m, "d", lower = 10, upper = 25, length = 2, semi = TRUE)
r <- num_var(m, "r", lower = 2.5, upper = 8, semi = TRUE)
z <- num_var(m, "z", lower = -1, upper = 3, semi = TRUE)        # 0 lies between: no hole
minimize(m, sum(d) + r + z)
domains <- vapply(as_program(m)$vars, `[[`, 0L, "domain")
check("semi declares the two domains with a hole",
      identical(domains, c(SEMIINTEGER, SEMIINTEGER, SEMICONTINUOUS, SEMICONTINUOUS)))
check("the domain codes are the service's", SEMICONTINUOUS == 4L && SEMIINTEGER == 5L)
expect_error_like("a hole needs finite bounds", num_var(m, "u", lower = 1, semi = TRUE),
                  "finite bounds")
expect_error_like("semi is one TRUE or FALSE", num_var(m, "u", 0, 1, semi = NA), "TRUE or FALSE")
add_var(m, "w", lower = 5, upper = 9, domain = "int", semi = TRUE)
check("add_var passes semi on", m$w$domain == SEMIINTEGER)

# ── active() ────────────────────────────────────────────────────────────────

a <- active(d)
check("active() is one indicator per element",
      length(a) == 2L && identical(a$nodes[[2L]], ir_apply("indicator", list(ir_var("d[2]")))))
check("active() takes elements of a variable", length(active(d[1])) == 1L)
expect_error_like("active() takes variables only", active(d + 1), "decision variable")
expect_error_like("active() refuses a number", active(3), "decision variable")

# ── holds(), min() and max() write what the service reads ───────────────────

x <- num_var(m, "x", 0, 9); y <- num_var(m, "y", 0, 9)
node <- function(e) e$nodes[[1L]]
minus <- function(a, b) ir_apply("-", list(a, b))
step <- function(inner) ir_apply("step", list(inner))
not <- function(inner) ir_apply("-", list(ir_const(1), inner))
X <- ir_var("x"); Y <- ir_var("y")
check("holds(>=) is step(lhs - rhs)", identical(node(holds(x >= y)), step(minus(X, Y))))
check("holds(<=) is step(rhs - lhs)", identical(node(holds(x <= y)), step(minus(Y, X))))
check("holds(>) is 1 - step(rhs - lhs)", identical(node(holds(x > y)), not(step(minus(Y, X)))))
check("holds(<) is 1 - step(lhs - rhs)", identical(node(holds(x < y)), not(step(minus(X, Y)))))
check("holds(==) is 1 - indicator(lhs - rhs)",
      identical(node(holds(x == y)), not(ir_apply("indicator", list(minus(X, Y))))))
check("a tolerance folds into the argument",
      identical(node(holds(x >= 60, tol = 1e-6)),
                step(ir_apply("+", list(minus(X, ir_const(60)), ir_const(1e-6))))))
check("min() is the catalog's binary min",
      identical(node(min(sum(active(d)), 1)),
                ir_apply("min", list(ir_apply("+", list(ir_apply("indicator", list(ir_var("d[1]"))),
                                                        ir_apply("indicator", list(ir_var("d[2]"))))),
                                     ir_const(1)))))

# ── blocks ──────────────────────────────────────────────────────────────────

m <- model()
ship <- int_var(m, "ship", lower = 10, upper = 25, length = 4, semi = TRUE)
open <- bin_var(m, "open")
free <- num_var(m, "free", lower = 0)
block(m, "south", c(ship[3:4], open))
block(m, "north", ship[1:2])
prog <- as_program(m)
check("blocks are lowered as variable references, in the order given",
      identical(prog$blocks$south, list(ir_var("ship[3]"), ir_var("ship[4]"), ir_var("open"))) &&
      identical(prog$blocks$north, list(ir_var("ship[1]"), ir_var("ship[2]"))))
bytes <- encode(m)
check("blocks are emitted sorted by name (field 13)", {
  hex <- as_hex(bytes)
  north <- as_hex(charToRaw("north")); south <- as_hex(charToRaw("south"))
  regexpr(north, hex) < regexpr(south, hex)
})
expect_error_like("a block name is used once", block(m, "north", ship[1]), "already has a block")
expect_error_like("a variable is in one block only", block(m, "east", ship[2]), "one block only")
expect_error_like("a member needs finite bounds", block(m, "east", free), "finite bounds")
expect_error_like("a member is listed once", block(m, "east", c(free, free)), "twice")
other <- model(); stranger <- num_var(other, "stranger", 0, 1)
expect_error_like("a member is from this model", block(m, "east", stranger), "different model")
expect_error_like("a block holds variables", block(m, "east", ship[1] + 1), "decision variables")
check("printing counts the blocks", any(grepl("2 blocks", capture.output(print(m)))))

# ── partitions ──────────────────────────────────────────────────────────────

m <- model()
teams <- part_var(m, "teams", 5, 2, start = c(1, 2, 1, 2, 1))
check("a partition handle knows its sizes", teams$n_items == 5L && teams$n_parts == 2L)
check("the handle is retrievable from the model", identical(m$teams$name, "teams"))
expect_error_like("a partition needs an item", part_var(m, "p", 0, 2), "at least 1")
expect_error_like("a partition needs two parts", part_var(m, "p", 3, 1), "at least 2")
expect_error_like("a start gives each item a part", part_var(m, "p", 3, 2, start = c(1, 3, 1)),
                  "a part from 1 to 2")
expect_error_like("a start has one part per item", part_var(m, "p", 3, 2, start = c(1, 2)),
                  "a part from 1 to 2")
expect_error_like("the name is shared with variables", num_var(m, "teams"), "already declared")
check("part_of reads an item's part",
      identical(part_of(3, teams)$nodes[[1L]],
                ir_apply("part_of", list(ir_const(3), ir_struct_ref("teams")))))
check("size_of reads a part's size and is vectorized",
      length(size_of(1:2, teams)) == 2L &&
      identical(size_of(2, teams)$nodes[[1L]],
                ir_apply("size_of", list(ir_const(2), ir_struct_ref("teams")))))
expect_error_like("an item is within the partition", part_of(6, teams), "from 1 to 5")
expect_error_like("a part is within the partition", size_of(3, teams), "from 1 to 2")
expect_error_like("part_of takes a partition", part_of(1, perm_var(m, "order", 3)), "partition from part_var")
expect_error_like("item_at takes a permutation", item_at(1, teams), "permutation from perm_var")
expect_error_like("a bare partition is not a number", teams + 1, "part_of")
cost <- lookup_table(m, "cost", rbind(c(4, 1), c(2, 3), c(1, 5), c(3, 2), c(2, 2.5)))
add(m, size_of(1, teams) == 2)
minimize(m, sum(cost[1:5, part_of(1:5, teams)]))
prog <- as_program(m)
check("the program declares the partition",
      identical(prog$structures$teams, partition_decl(5, 2, c(1L, 2L, 1L, 2L, 1L), FALSE)))
check("printing counts the partitions", any(grepl("1 partition", capture.output(print(m)))))
check("printing a partition", identical(capture.output(print(teams)), "partition 'teams': 5 items in 2 parts"))

# ── a result's partition, its start and its pin ─────────────────────────────

parse <- internal(".parse_result")
json <- '{"status":"heuristic","objective":8.5,"feasible":true,"solution":{},
          "solver_data":{"model_class":"structured"},
          "structures":{"teams":{"part_of":[2,1,1,2,2],"size_of":[2,3]},
                        "order":{"item_at":[3,1,2],"slot_of":[2,3,1]}}}'
res <- parse(charToRaw(json), m)
check("a result carries the partition's two views",
      identical(res$structures$teams, list(part_of = c(2L, 1L, 1L, 2L, 2L), size_of = c(2L, 3L))))
check("and a permutation's", identical(res$structures$order$item_at, c(3L, 1L, 2L)))
set_start(m, res)
check("set_start takes the division as the partition's start",
      identical(internal(".m_get")(m, "structures")$teams$start, c(2L, 1L, 1L, 2L, 2L)) &&
      identical(internal(".m_get")(m, "structures")$order$start, c(2L, 3L, 1L)))
pinned <- internal(".pinned_program")(m, res, "evaluate")
check("a pinned evaluation fixes the partition at the result",
      isTRUE(pinned$structures$teams$fixed) &&
      identical(pinned$structures$teams$start, c(2L, 1L, 1L, 2L, 2L)))
bad <- res; bad$structures$teams$part_of <- c(1L, 1L, 3L, 2L, 2L)
expect_error_like("a reported part outside the partition is refused",
                  set_start(m, bad), "a part from 1 to 2")

# a variable that may be 0 is pinned at 0 without complaint
m <- model()
d <- num_var(m, "d", lower = 10, upper = 25, semi = TRUE)
minimize(m, d)
p0 <- internal(".pinned_program")(m, c(d = 0), "evaluate")
check("a hole's 0 is a value it can be pinned at", identical(p0$fix[[1L]]$value, 0))
p1 <- internal(".pinned_program")(m, c(d = 12.5), "evaluate")
check("a semicontinuous value is not rounded", identical(p1$fix[[1L]]$value, 12.5))
expect_error_like("a value in the hole is refused", internal(".pinned_program")(m, c(d = 5), "evaluate"),
                  "outside its bounds")

cat("blocks and partitions: all green\n")
