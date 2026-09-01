# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

# The DSL against the goldens: the same models authored through model()/num_var/
# minimize/add must encode to the exact golden bytes the direct IR fixtures
# reproduce — carrying the goldens' authority across the authoring surface.
# Plus the surface semantics: vectors, broadcasting, catalog policing.
#
#     Rscript tests/test-dsl.R

source(if (file.exists("tests/helper.R")) "tests/helper.R" else "helper.R")

# ── goldens through the DSL ─────────────────────────────────────────────────

m <- model()
x <- num_var(m, "x1", 0.1, 10, start = 0.1)
minimize(m, x^2 + 1 / x)
check("DSL reproduces the scalar_nlp golden",
      identical(encode(m), read_golden("scalar_nlp")),
      sprintf("   got  %s\n   want %s\n", as_hex(encode(m)), as_hex(read_golden("scalar_nlp"))))

m <- model()
x <- num_var(m, "x", 0, 200)
demand <- rand_var(m, "demand", normal(100, 15))
set_scenarios(m, 512, seed = 42)
minimize(m, 3 * x + expectation(abs(x - demand)))
add(m, prob(demand - x <= 0) >= 0.9)
check("DSL reproduces the stoch_parametric golden (the newsvendor)",
      identical(encode(m), read_golden("stoch_parametric")),
      sprintf("   got  %s\n   want %s\n", as_hex(encode(m)), as_hex(read_golden("stoch_parametric"))))

# ── operator surface ────────────────────────────────────────────────────────

m <- model()
v <- num_var(m, "v")
w <- num_var(m, "w")

e <- 3 * v            ; check("numeric on the left", e$nodes[[1]]$op == "*")
e <- v / 2            ; check("division", e$nodes[[1]]$op == "/")
e <- -v               ; check("unary minus", e$nodes[[1]]$op == "-" && length(e$nodes[[1]]$args) == 1)
e <- sqrt(exp(v))     ; check("Math composes", e$nodes[[1]]$op == "sqrt")
e <- max(v - w, 0)    ; check("max is the catalog head", e$nodes[[1]]$op == "max")
e <- max(v, w, 0)     ; check("n-ary max nests binary",
                              e$nodes[[1]]$op == "max" && e$nodes[[1]]$args[[1]]$op == "max")
e <- min(v, 3)        ; check("min", e$nodes[[1]]$op == "min")

expect_error_like("round is outside the catalog", round(v), "not in the operator catalog")
expect_error_like("range is outside the catalog", range(v), "not in the operator catalog")
expect_error_like("%% is outside the catalog", v %% 2, "not in the operator catalog")
expect_error_like("log with a base is refused", log(v, 10), "no base")
expect_error_like("strict < is refused", v < 3, "<=")
expect_error_like("!= is refused", v != 3, "big-M")

# == builds a relation and if() on it fails loudly rather than deciding
rel <- v == 3
check("== builds an equality relation", inherits(rel, "quicopt_relation") && rel$op == "==")
expect_error_like("if (v == 3) errors", if (v == 3) TRUE, ".")

# ── vector variables ────────────────────────────────────────────────────────

m <- model()
xs <- num_var(m, "xs", 0, 10, n = 3)
cost <- c(2, 3, 5)

check("a vector variable has length n", length(xs) == 3)
check("indexing picks the flat element", xs[2]$nodes[[1]]$name == "xs[2]")
e <- sum(cost * xs)
check("sum(cost * x) is one n-ary + node",
      length(e) == 1 && e$nodes[[1]]$op == "+" && length(e$nodes[[1]]$args) == 3)
check("the coefficient landed elementwise",
      e$nodes[[1]]$args[[2]]$args[[1]]$value == 3)
expect_error_like("partial recycling is refused", c(1, 2) * xs, "length mismatch")

minimize(m, sum(cost * xs))
add(m, xs <= c(5, 6, 7))            # one row per element
add(m, sum(xs) >= 4)
p <- as_program(m)
check("a family lowers to flat scalar declarations",
      length(p$vars) == 3 && p$vars[[2]]$name == "xs[2]")
check("an elementwise relation lands as n rows", length(p$constraints) == 4)

# per-element bounds
m <- model()
y <- num_var(m, "y", lower = c(0, 1), upper = 5, n = 2)
p <- as_program(m)
check("per-element bounds", p$vars[[1]]$lower == 0 && p$vars[[2]]$lower == 1)
expect_error_like("bounds of the wrong length are refused",
                  num_var(m, "z", lower = c(0, 1, 2), n = 2), "length 3")

# ── model surface ───────────────────────────────────────────────────────────

m <- model()
a <- num_var(m, "a", 0, 4)
b <- bin_var(m, "b")
maximize(m, 3 * a + 5 * b)
add(m, a + 2 * b <= 5)
p <- as_program(m)
check("sense max", p$sense == "max")
check("a <= b lands as Nonneg(b - a)",
      p$constraints[[1]]$set$kind == "nonneg" && p$constraints[[1]]$f$op == "-")

check("m$a retrieves the handle", identical(m$a$name, "a"))
expect_error_like("m$nothere names the declared variables", m$nothere, "declared: a, b")
expect_error_like("assignment into the model is refused", m$c <- 1, "num_var")
expect_error_like("duplicate names are refused", num_var(m, "a"), "already declared")
expect_error_like("bracketed names are reserved", num_var(m, "q[1]"), "reserved")
expect_error_like("a vector objective is refused", minimize(m, 1 * num_var(m, "vv", n = 2)),
                  "single expression")

# the pipe and the imperative style are the same functions
m2 <- model() |> add_var("x", 0, 4) |> add_var("y", domain = "bin")
maximize(m2, 3 * m2$x + 5 * m2$y)
add(m2, m2$x + 2 * m2$y <= 5)
m3 <- model(); x3 <- num_var(m3, "x", 0, 4); y3 <- bin_var(m3, "y")
maximize(m3, 3 * x3 + 5 * y3)
add(m3, x3 + 2 * y3 <= 5)
check("pipe and handle styles encode identically", identical(encode(m2), encode(m3)))

# a feasibility problem: no objective encodes as Const(0)
m <- model(); f <- num_var(m, "f", 0, 1); add(m, f >= 0.5)
check("no objective is a feasibility problem", as_program(m)$objective$kind == "const")

cat("dsl: all green\n")
