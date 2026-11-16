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
v <- evaluate(m, c(x = 118.7, k = 2), prob(m$demand - m$x <= 0), seed = 2, n_scenarios = 1000, transport = rec$fn)
want$scenario_seed <- 2; want$scenarios <- 1000
check("with a seed it evaluates on fresh scenarios", identical(rec$requests[[2]]$body, encode(want)))
expect_error_like("n_scenarios needs a seed", evaluate(m, c(x = 1, k = 1), m$x, n_scenarios = 10), "seed")
warned <- NULL
v <- withCallingHandlers(
  evaluate(m, c(x = 118.7, k = 2), prob(m$demand - m$x <= 0), seed = 2, scenarios = 1000, transport = rec$fn),
  warning = function(w) { warned <<- conditionMessage(w); invokeRestart("muffleWarning") })
check("the former name scenarios still sets the count, with a warning",
      identical(rec$requests[[3]]$body, encode(want)) &&
        grepl("`scenarios` is now called `n_scenarios`", warned))
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
res <- resample(m, c(x = 118.7, k = 2), seed = 7, n_scenarios = 1000, transport = rec$fn)
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
                  resample(m4, c(x = 1), seed = 2, n_scenarios = 10), "empirical")

# ── a solution of a few thousand values ─────────────────────────────────────

m <- model()
x <- num_var(m, "x", 0, 100, length = 2000)
k <- int_var(m, "k", 0, 10, length = 1000)
s <- num_var(m, "s", -5, 5)
minimize(m, sum(x) + sum(k) + s)
flat <- c(sprintf("x[%d]", 1:2000), sprintf("k[%d]", 1:1000), "s")
values <- c((1:2000) / 20, (1:1000) %% 11 + 0.4, -2.5)
arrival <- rev(seq_along(flat))                                    # the service's order is its own
json <- paste0('{"status":"optimal","objective":1,"feasible":true,"solution":{',
               paste0('"', flat[arrival], '":', values[arrival], collapse = ","), "}}")
res <- internal(".parse_result")(charToRaw(json), internal(".declared")(m))
check("3001 values come back in declaration order",
      identical(names(res$solution), flat) && identical(unname(res$solution), values))
starts <- function(m) vapply(as_program(m)$vars, function(vd) vd$start, 0)
set_start(m, res)
check("set_start takes every value of the result as a start", identical(starts(m), values))
some <- c("k[999]" = 3, "x[7]" = 70, s = 1, "x[1999]" = 19.5, "k[1]" = 0)
set_start(m, some)
want <- setNames(values, flat); want[names(some)] <- some
check("a few values in any order set those starts and keep the rest",
      identical(starts(m), unname(want)))
set_start(m, c("x[5]" = 1, "k[2]" = 4, "x[5]" = 2))
check("a name given twice keeps its first value",
      starts(m)[[5]] == 1 && starts(m)[[2002]] == 4)
expect_error_like("an unknown name among thousands is named",
                  set_start(m, c(res$solution, "x[2001]" = 1)), "named 'x\\[2001\\]' in")
fixed <- function(p) vapply(p$fix, function(f) f$value, 0)
p <- pinned(m, res, "evaluate")
check("every variable is pinned at its value, in declaration order, integers rounded",
      identical(vapply(p$fix, function(f) f$var, ""), flat) &&
      identical(fixed(p), c(values[1:2000], round(values[2001:3000]), -2.5)))
check("a vector in any order is pinned the same way",
      identical(fixed(pinned(m, rev(res$solution), "evaluate")), fixed(p)))
expect_error_like("the values missing are named, in declaration order",
                  pinned(m, res$solution[-c(2500, 17)], "evaluate"),
                  "no value for 'x\\[17\\]', 'k\\[500\\]'$")
expect_error_like("the first value outside its bounds is named",
                  pinned(m, replace(res$solution, c("k[3]", "x[9]"), c(12, -1)), "evaluate"),
                  "value -1 for 'x\\[9\\]'")

cat("solution: all green\n")
