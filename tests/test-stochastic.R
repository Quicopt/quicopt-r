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

# ── the named distributions: heads, parameter order, ranges ─────────────────

m5 <- model(); spend <- num_var(m5, "spend", 0, 10)
lead  <- rand_var(m5, "lead", uniform(2, 5))
gap   <- rand_var(m5, "gap", exponential(1 / 30))
fails <- rand_var(m5, "fails", bernoulli(0.02))
wear  <- rand_var(m5, "wear", bernoulli(0.2 - 0.015 * spend))
set_scenarios(m5, 16, seed = 1)
minimize(m5, spend + expectation(lead + gap + 100 * fails + 100 * wear))
p5 <- as_program(m5)
values_of <- function(src) vapply(src$params, function(n) n$value, 0)
check("uniform emits its head with the limits in runif()'s order",
      p5$sources$lead$head == "uniform" && identical(values_of(p5$sources$lead), c(2, 5)))
check("exponential emits its head with the rate",
      p5$sources$gap$head == "exponential" && identical(values_of(p5$sources$gap), 1 / 30))
check("bernoulli emits its head with the probability",
      p5$sources$fails$head == "bernoulli" && identical(values_of(p5$sources$fails), 0.02))
check("a probability may depend on a decision",
      p5$sources$wear$params[[1]]$kind == "apply")
check("a model with every named distribution encodes", is.raw(encode(m5)) && length(encode(m5)) > 0)

# vector parameters declare a vector random variable, one source per element
m6 <- model(); u3 <- rand_var(m6, "u", uniform(c(0, 1, 2), 10))
set_scenarios(m6, 4); minimize(m6, sum(expectation(u3)))
p6 <- as_program(m6)
check("a vector uniform lowers to one source per element",
      all(c("u[1]", "u[2]", "u[3]") %in% names(p6$sources)) &&
      identical(values_of(p6$sources[["u[2]"]]), c(1, 10)))

expect_error_like("a lower limit above the upper one is refused", uniform(3, 2), "lower limit")
expect_error_like("...elementwise too", uniform(c(0, 6), 5), "lower limit")
expect_error_like("a rate of zero is refused", exponential(0), "positive")
expect_error_like("a negative rate is refused", exponential(c(1, -1)), "positive")
expect_error_like("a probability above 1 is refused", bernoulli(1.2), "between 0 and 1")
expect_error_like("a negative probability is refused", bernoulli(-0.1), "between 0 and 1")
check("the limits of the range are allowed",
      inherits(bernoulli(c(0, 1)), "quicopt_distribution") &&
      inherits(uniform(2, 2), "quicopt_distribution"))
expect_error_like("a random variable cannot be a rate", exponential(r), "data, not draws")

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

# ── the spread and the single-scenario statistics ───────────────────────────

head_of <- function(e) e$nodes[[1]]$op
check("variance emits svar", head_of(variance(d - x)) == "svar" &&
      length(variance(d - x)$nodes[[1]]$args) == 1L)
check("variance(sample = TRUE) emits svar_sample",
      head_of(variance(d - x, sample = TRUE)) == "svar_sample")
check("std_dev emits sstd", head_of(std_dev(d - x)) == "sstd")
e <- std_dev(d - x, sample = TRUE)
check("std_dev(sample = TRUE) is the root of the sample variance",
      head_of(e) == "sqrt" && e$nodes[[1]]$args[[1]]$op == "svar_sample")
check("scenario_max emits smax", head_of(scenario_max(d - x)) == "smax")
check("scenario_min emits smin", head_of(scenario_min(d - x)) == "smin")
e <- scenario_quantile(d - x, 0.95)
check("scenario_quantile emits squantile with its level",
      head_of(e) == "squantile" && e$nodes[[1]]$args[[2]]$value == 0.95)
check("the level 1 is allowed", head_of(scenario_quantile(d, 1)) == "squantile")

# each of them closes the expression: the typing rules must see a number
closed <- list(variance(d - x), variance(d - x, sample = TRUE), std_dev(d - x),
               std_dev(d - x, sample = TRUE), scenario_max(d - x), scenario_min(d - x),
               scenario_quantile(d - x, 0.5))
check("every new aggregator closes its expression", !any(vapply(closed, is_random, NA)))
ms <- model(); xs <- num_var(ms, "x", 0, 200); ds <- rand_var(ms, "demand", normal(100, 15))
set_scenarios(ms, 16, seed = 1)
cost <- 3 * xs + 10 * max(ds - xs, 0)
minimize(ms, expectation(cost) + 2 * std_dev(cost))
add(ms, scenario_quantile(cost, 0.95) <= 500)
add(ms, scenario_max(cost) - scenario_min(cost) <= 400)
add(ms, variance(cost, sample = TRUE) <= 1e4)
check("they serve as objective and constraints, and the model encodes",
      length(as_program(ms)$constraints) == 3L && is.raw(encode(ms)))
check("a vector expression aggregates per element",
      length(variance(c(d - x, d + x))$nodes) == 2L)

expect_error_like("variance of a non-random expression is refused", variance(3 * x), "no random variable")
expect_error_like("scenario_max of a non-random expression is refused", scenario_max(x), "no random variable")
expect_error_like("a quantile level of 0 is refused", scenario_quantile(d, 0), "above 0")
expect_error_like("a quantile level above 1 is refused", scenario_quantile(d, 1.5), "at most 1")
expect_error_like("a quantile level is a plain number", scenario_quantile(d, x), "plain number")
expect_error_like("sample is a flag", variance(d, sample = NA), "TRUE or FALSE")

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

# ── is_random, and the two typing rules caught early ────────────────────────

m <- model(); x <- num_var(m, "x", 0, 200); d <- rand_var(m, "demand", normal(100, 15))
check("a random variable is random", is_random(d))
check("so is arithmetic on it", is_random(d - x))
check("an aggregator closes it", !is_random(expectation(d - x)) && !is_random(prob(d <= x)))
check("a decision is not random, elementwise", identical(is_random(c(x, x^2)), c(FALSE, FALSE)))
check("a number is not random", identical(is_random(3), FALSE))
check("closed inside, random outside", is_random(d * expectation(d)))

expect_error_like("expectation of a non-random expression is refused",
                  expectation(3 * x), "no random variable")
expect_error_like("cvar of a non-random expression is refused", cvar(x, 0.9), "no random variable")
expect_error_like("prob of a non-random event is refused", prob(x <= 3), "no random variable")
expect_error_like("a random objective is refused", minimize(m, d - x), "still random")
expect_error_like("a random constraint is refused", add(m, d <= x), "still random")
check("a closed objective is accepted", !is.null(minimize(m, expectation(d - x))))

# ── a safety margin on a chance constraint ──────────────────────────────────

m <- model(); x <- num_var(m, "x", 0, 200); d <- rand_var(m, "demand", normal(100, 15))
set_scenarios(m, 512, seed = 42)
add(m, prob(d - x <= 0) >= 0.9, margin = 2)
se <- sqrt(0.9 * 0.1 / 512)
f <- as_program(m)$constraints[[1]]$f
check("a lower bound on a probability is raised by k standard errors",
      f$op == "-" && f$args[[1]]$op == "sfreq_leq" &&
      abs(f$args[[2]]$value - (0.9 + 2 * se)) < 1e-12)
check("the row is Nonneg", as_program(m)$constraints[[1]]$set$kind == "nonneg")

set_scenarios(m, 128)
f <- as_program(m)$constraints[[1]]$f
check("the margin is resolved against the scenario count at lowering",
      abs(f$args[[2]]$value - (0.9 + 2 * sqrt(0.9 * 0.1 / 128))) < 1e-12)

m <- model(); x <- num_var(m, "x", 0, 200); d <- rand_var(m, "demand", normal(100, 15))
set_scenarios(m, 512)
add(m, prob(d - x >= 150) <= 0.05, margin = 1)
f <- as_program(m)$constraints[[1]]$f
check("an upper bound on a probability is lowered",
      f$args[[1]]$kind == "const" && abs(f$args[[1]]$value - (0.05 - sqrt(0.05 * 0.95 / 512))) < 1e-12 &&
      f$args[[2]]$op == "sfreq_geq")
add(m, 0.9 <= prob(d - x <= 0), margin = 1)
f <- as_program(m)$constraints[[2]]$f
check("a mirrored chance constraint tightens the same way",
      abs(f$args[[2]]$value - (0.9 + se)) < 1e-12)
add(m, prob(d - x <= 0) >= 0.999, margin = 100)
check("the tightened level is clamped to 1", as_program(m)$constraints[[3]]$f$args[[2]]$value == 1)

expect_error_like("margin needs a chance constraint", add(m, x <= 10, margin = 1), "prob()")
expect_error_like("margin needs a level inside (0, 1)",
                  add(m, prob(d - x <= 0) >= 1, margin = 1), "strictly between")
expect_error_like("margin is non-negative", add(m, prob(d - x <= 0) >= 0.9, margin = -1), "non-negative")
m0 <- model(); x0 <- num_var(m0, "x", 0, 200); d0 <- rand_var(m0, "d", normal(100, 15))
add(m0, prob(d0 - x0 <= 0) >= 0.9)
m1 <- model(); x1 <- num_var(m1, "x", 0, 200); d1 <- rand_var(m1, "d", normal(100, 15))
add(m1, prob(d1 - x1 <= 0) >= 0.9, margin = 0)
check("margin = 0 encodes exactly as no margin", identical(encode(m0), encode(m1)))

# ── holds: a comparison as a 0/1 expression ─────────────────────────────────

m <- model(); x <- num_var(m, "x", 0, 200); d <- rand_var(m, "demand", normal(100, 15))
h <- function(rel, tol = 0) holds(rel, tol)$nodes[[1]]
n <- h(d <= x);  check("a <= b is step(b - a)", n$op == "step" && n$args[[1]]$op == "-" &&
                                                 n$args[[1]]$args[[1]]$name == "x")
n <- h(d >= x);  check("a >= b is step(a - b)", n$op == "step" && n$args[[1]]$args[[1]]$kind == "source")
n <- h(d < x);   check("a < b is 1 - step(a - b)", n$op == "-" && n$args[[1]]$value == 1 &&
                                                   n$args[[2]]$op == "step")
n <- h(d > x);   check("a > b is 1 - step(b - a)", n$op == "-" && n$args[[2]]$op == "step" &&
                                                   n$args[[2]]$args[[1]]$args[[1]]$name == "x")
n <- h(d == x);  check("a == b is 1 - indicator(a - b)", n$op == "-" && n$args[[2]]$op == "indicator")
n <- h(d != x);  check("a != b is indicator(a - b)", n$op == "indicator")
n <- h(d <= x, tol = 0.5)
check("a tolerance widens the step's argument",
      n$op == "step" && n$args[[1]]$op == "+" && n$args[[1]]$args[[2]]$value == 0.5)
n <- h(d == x, tol = 0.5)
check("an equality with tolerance is step(tol - abs(a - b))",
      n$op == "step" && n$args[[1]]$op == "-" && n$args[[1]]$args[[1]]$value == 0.5 &&
      n$args[[1]]$args[[2]]$op == "abs")
check("holds of a random comparison is random, and expectation closes it",
      is_random(holds(d <= x)) && !is_random(expectation(holds(d <= x))))
check("holds is elementwise", length(holds(num_var(m, "v", n = 3) <= 1)) == 3)
expect_error_like("holds takes a comparison", holds(x), "comparison")
expect_error_like("tol is non-negative", holds(d <= x, tol = -1), "non-negative")

cat("stochastic (continued): all green\n")

# ── vector random variables ─────────────────────────────────────────────────

m <- model()
packed <- bin_var(m, "packed", n = 3)
w <- rand_var(m, "weight", normal(c(6, 5, 4), 1))
check("vector parameters declare a vector random variable", length(w) == 3 && w$n == 3)
check("its elements are flat sources", w$nodes[[2]]$name == "weight[2]")
minimize(m, expectation(sum(packed * w)))
p <- as_program(m)
check("one wire source per element, with its own parameters",
      identical(names(p$sources), c("weight[1]", "weight[2]", "weight[3]")) &&
      p$sources[["weight[2]"]]$params[[1]]$value == 5 && p$sources[["weight[3]"]]$params[[2]]$value == 1)
w2 <- rand_var(m, "noise", normal(0, 1), n = 2)
check("n with scalar parameters gives independent copies",
      length(as_program(m)$sources) == 5 && as_program(m)$sources[["noise[2]"]]$params[[2]]$value == 1)
expect_error_like("n must agree with the parameters",
                  rand_var(m, "bad", normal(c(1, 2), 1), n = 3), "length 2")
expect_error_like("parameters must agree among themselves", normal(c(1, 2), c(1, 2, 3)), "disagree")
expect_error_like("an empirical column is one random variable",
                  rand_var(m, "e", empirical(c(1, 2, 3)), n = 2), "one random variable")
price <- num_var(m, "price", 1, 10)
dm <- rand_var(m, "dm", normal(100 - c(5, 6) * price, 10))
check("a vector expression parameter lowers elementwise",
      as_program(m)$sources[["dm[2]"]]$params[[1]]$args[[2]]$args[[1]]$value == 6)
lat <- rand_var(m, "lat", n = 2)
expect_error_like("set_distribution checks the length", set_distribution(m, lat, normal(c(1, 2, 3), 1)), "length 3")
set_distribution(m, lat, normal(c(1, 2), 1))
check("and accepts a matching one", as_program(m)$sources[["lat[2]"]]$params[[1]]$value == 2)
m2 <- model(); lat2 <- rand_var(m2, "lat")
expect_error_like("a handle from another model is refused", set_distribution(m, lat2, normal(0, 1)), "different model")

cat("stochastic (vectors): all green\n")
