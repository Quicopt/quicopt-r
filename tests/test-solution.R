# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

# Evaluating a solution: the pinned program behind evaluate() and resample(),
# and the requests they send, through a fake transport.
#
#     Rscript tests/test-solution.R

source(if (file.exists("tests/helper.R")) "tests/helper.R" else "helper.R")

internal <- function(name) {
  if (exists(name, envir = globalenv(), inherits = FALSE))
    get(name, envir = globalenv())
  else get(name, envir = asNamespace("quicopt"))
}

recorder <- function(json) {
  e <- new.env(); e$requests <- list()
  e$fn <- function(req) {
    e$requests[[length(e$requests) + 1L]] <- req
    list(status = 200L, headers = list(), body = charToRaw(json))
  }
  e
}

newsvendor <- function() {
  m <- model()
  x <- num_var(m, "x", 0, 200)
  k <- int_var(m, "k", 0, 5)
  d <- rand_var(m, "demand", normal(100, 15))
  set_scenarios(m, 512, seed = 42)
  minimize(m, 3 * x + 10 * expectation(max(d - x, 0)) + k)
  add(m, prob(d - x <= 0) >= 0.9)
  m
}

# ── the pinned program ──────────────────────────────────────────────────────

m <- newsvendor()
pinned <- internal(".pinned_program")
p <- pinned(m, c(x = 118.7, k = 2.4), "test")
check("one pin per decision variable", length(p$fix) == 2 && p$fix[[1]]$var == "x")
check("a continuous value is pinned as given", p$fix[[1]]$value == 118.7)
check("an integer value is rounded", p$fix[[2]]$value == 2)
check("the rest of the program is untouched",
      p$scenarios == 512 && p$scenario_seed == 42 && length(p$constraints) == 1)
expect_error_like("every variable needs a value", pinned(m, c(x = 1), "test"), "'k'")
expect_error_like("a value outside the bounds is refused", pinned(m, c(x = 500, k = 1), "test"), "outside")
expect_error_like("an unknown name is refused", pinned(m, c(x = 1, k = 1, q = 1), "test"), "'q'")

# ── evaluate ────────────────────────────────────────────────────────────────

rec <- recorder('{"status":"heuristic","objective":0.8984375,"feasible":true,"solution":{"x":118.7,"k":2}}')
v <- evaluate(m, c(x = 118.7, k = 2), prob(m$demand - m$x <= 0), transport = rec$fn)
check("evaluate returns the objective of the pinned solve", v == 0.8984375)
req <- rec$requests[[1]]
want <- p; want$fix[[2]]$value <- 2
want$objective <- prob(m$demand - m$x <= 0)$nodes[[1]]; want$sense <- "min"; want$constraints <- list()
check("it sends the pinned program with the expression as objective and no constraints",
      identical(req$body, encode(want)))
check("it carries the front-end tag", grepl("source_language=quicopt-r", req$url, fixed = TRUE))
v <- evaluate(m, c(x = 118.7, k = 2), prob(m$demand - m$x <= 0), seed = 2, scenarios = 1000, transport = rec$fn)
want$scenario_seed <- 2; want$scenarios <- 1000
check("with a seed it evaluates on fresh scenarios", identical(rec$requests[[2]]$body, encode(want)))
expect_error_like("scenarios needs a seed", evaluate(m, c(x = 1, k = 1), m$x, scenarios = 10), "seed")
expect_error_like("a random expression cannot be evaluated",
                  evaluate(m, c(x = 1, k = 1), m$demand - m$x, transport = rec$fn), "still random")
expect_error_like("a vector expression cannot be evaluated",
                  evaluate(m, c(x = 1, k = 1), c(m$x, m$x), transport = rec$fn), "single expression")

# ── resample ────────────────────────────────────────────────────────────────

rec <- recorder('{"status":"heuristic","objective":364.3,"feasible":false,"solution":{"x":118.7,"k":2},"solver_data":{"max_violation":0.004}}')
res <- resample(m, c(x = 118.7, k = 2), seed = 7, transport = rec$fn)
check("resample returns the full result", inherits(res, "quicopt_result") && !res$feasible &&
                                           res$solver_data$max_violation == 0.004)
want <- p; want$fix[[2]]$value <- 2; want$scenario_seed <- 7
check("it sends the pinned program under the new seed, constraints kept",
      identical(rec$requests[[1]]$body, encode(want)))
res <- resample(m, c(x = 118.7, k = 2), seed = 7, scenarios = 1000, transport = rec$fn)
want$scenarios <- 1000
check("a larger sample can be asked for", identical(rec$requests[[2]]$body, encode(want)))

expect_error_like("the model's own seed is refused", resample(m, c(x = 1, k = 1), seed = 42), "model's own")
m2 <- model(); x2 <- num_var(m2, "x", 0, 10); minimize(m2, x2)
expect_error_like("a deterministic model has nothing to resample",
                  resample(m2, c(x = 1), seed = 2), "no random variable")
m3 <- model(); x3 <- num_var(m3, "x", 0, 10)
set_empirical(m3, data.frame(d = c(1, 2, 3)))
minimize(m3, expectation(m3$d * x3))
expect_error_like("an all-empirical model has nothing to resample",
                  resample(m3, c(x = 1), seed = 2), "data, not draws")
m4 <- model(); x4 <- num_var(m4, "x", 0, 10)
set_empirical(m4, data.frame(d = c(1, 2, 3)))
r4 <- rand_var(m4, "r", normal(0, 1))
minimize(m4, expectation(m4$d * x4 + r4))
expect_error_like("the count is fixed by an empirical column",
                  resample(m4, c(x = 1), seed = 2, scenarios = 10), "empirical")

cat("solution: all green\n")
