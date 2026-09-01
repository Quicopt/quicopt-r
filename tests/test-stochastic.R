# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

# The stochastic surface: declarations, guardrails, the data.frame idiom, and
# the aggregators' emitted heads.
#
#     Rscript tests/test-stochastic.R

source(if (file.exists("tests/helper.R")) "tests/helper.R" else "helper.R")

# ── declarations and guardrails ─────────────────────────────────────────────

m <- model()
x <- num_var(m, "x", 0, 200)
d <- rand_var(m, "demand", normal(100, 15))

expect_error_like("one name is one random variable", rand_var(m, "demand"), "already declared")
expect_error_like("a decision variable takes no distribution",
                  set_distribution(m, x, normal(0, 1)), "rand_var")
expect_error_like("a bare numeric is ambiguous as a distribution",
                  rand_var(m, "e", c(1, 2, 3)), "empirical")
expect_error_like("scenarios below 1 are refused", set_scenarios(m, 0), "at least 1")
expect_error_like("a fractional count is refused", set_scenarios(m, 2.5), "whole number")
expect_error_like("seed below 1 is refused", set_scenarios(m, 4, seed = 0), "at least 1")

# an undistributed random variable is caught at lowering, by name
m2 <- model(); .r <- rand_var(m2, "later"); minimize(m2, 1 * num_var(m2, "u"))
expect_error_like("no distribution is an error at lowering", as_program(m2), "'later'")

# ...and set_distribution completes it
m2 <- model(); u <- num_var(m2, "u"); lat <- rand_var(m2, "later")
set_distribution(m2, lat, normal(1, 2))
minimize(m2, u + expectation(lat))
check("set_distribution completes a bare rand_var",
      as_program(m2)$sources$later$head == "normal")

# a random variable cannot parameterize a distribution
m3 <- model(); r <- rand_var(m3, "r", normal(0, 1))
expect_error_like("a distribution parameter cannot be random",
                  normal(r, 1), "data, not draws")

# ...but a decision can: an endogenous distribution
m4 <- model(); price <- num_var(m4, "price", 1, 10)
dem <- rand_var(m4, "dem", normal(100 - 5 * price, 10))
minimize(m4, -price * expectation(dem))
p4 <- as_program(m4)
check("an endogenous mean lowers to an expression parameter",
      p4$sources$dem$params[[1]]$kind == "apply")

# ── aggregator heads (the public/wire naming split) ─────────────────────────

e <- expectation(d);        check("expectation emits smean", e$nodes[[1]]$op == "smean")
e <- cvar(d - x, 0.95);     check("cvar emits scvar with its level",
                                  e$nodes[[1]]$op == "scvar" &&
                                  e$nodes[[1]]$args[[2]]$value == 0.95)
e <- prob(d - x <= 0);      check("prob(a <= const) emits sfreq_leq", e$nodes[[1]]$op == "sfreq_leq")
e <- prob(d - x >= 5);      check("prob(a >= const) emits sfreq_geq", e$nodes[[1]]$op == "sfreq_geq")
e <- prob(50 <= d);         check("a numeric left side mirrors", e$nodes[[1]]$op == "sfreq_geq")
e <- prob(d <= x)
check("a general pair lands as a difference against 0",
      e$nodes[[1]]$op == "sfreq_leq" && e$nodes[[1]]$args[[1]]$op == "-" &&
      e$nodes[[1]]$args[[2]]$value == 0)

expect_error_like("prob of an equality is refused", prob(d == x), "zero")
expect_error_like("prob of a strict comparison is refused", prob(d < x), "<=")
expect_error_like("cvar's level must sit strictly inside (0,1)", cvar(d, 1), "strictly between")
expect_error_like("cvar's level is a plain number", cvar(d, x), "plain number")

# ── the data.frame idiom ────────────────────────────────────────────────────

history <- data.frame(demand = c(90, 100, 110, 120), price = c(9, 10, 11, 14))
m5 <- model()
stock <- num_var(m5, "stock", 0, 200)
set_empirical(m5, history)
maximize(m5, expectation(m5$price * min(m5$demand, stock)))
p5 <- as_program(m5)

check("columns became named sources",
      identical(sort(names(p5$sources)), c("demand", "price")))
check("nrow became the scenario count", p5$scenarios == 4)
check("the columns' values survive verbatim",
      identical(p5$sources$demand$data, c(90, 100, 110, 120)) &&
      identical(p5$sources$price$data, c(9, 10, 11, 14)))
check("the model encodes", length(encode(m5)) > 0)

# a non-numeric column errors, naming the column — never a silent skip
mixed <- data.frame(demand = c(1, 2), site = c("a", "b"), stringsAsFactors = FALSE)
m6 <- model()
expect_error_like("a non-numeric column is an error, by name",
                  set_empirical(m6, mixed), "'site'")
m6 <- model()
set_empirical(m6, mixed, cols = "demand")
check("cols= selects around it", identical(names(as_program(m6)$sources), "demand"))

# scenario-count consistency, both directions
m7 <- model(); set_scenarios(m7, 8)
expect_error_like("rows must match a count already set",
                  set_empirical(m7, history), "8 scenarios.*4 rows")
m8 <- model()
.r <- rand_var(m8, "a", empirical(c(1, 2, 3)))
.r <- rand_var(m8, "b", empirical(c(1, 2)))
expect_error_like("disagreeing columns are refused at lowering",
                  as_program(m8), "disagree")
m9 <- model()
.r <- rand_var(m9, "a", empirical(c(1, 2, 3)))
minimize(m9, expectation(m9$a))
check("a lone empirical column sets the count", as_program(m9)$scenarios == 3)

cat("stochastic: all green\n")
