# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

# The byte-equality test — the encoder's correctness property.
#
# For each fixture, encode() must reproduce, byte for byte, the committed
# golden bytes the Quicopt service expects (tests/goldens/<name>.hex).
# Byte-equality is the sharpest check: identical bytes imply an identical
# decoded program (the codec is injective), so a match proves structural
# fidelity. The goldens are shared fixtures across the Quicopt clients; the
# service's own codec is what they were captured from.
#
# Self-contained: no network, no solver, no third-party packages.
#     Rscript tests/test-wire-goldens.R

source(if (file.exists("tests/helper.R")) "tests/helper.R" else "helper.R")

# Fixtures — the same programs the service's codec encodes for the goldens.

fixtures <- list(

  scalar_nlp = function() {                    # min x1^2 + 1/x1, x1 in [0.1, 10]
    x <- ir_var("x1")
    program(
      vars = list(var_decl("x1", character(), CONTINUOUS, 0.1, 10.0, 0.1)),
      objective = ir_apply("+", list(ir_apply("^", list(x, ir_const(2.0))),
                                     ir_apply("/", list(ir_const(1.0), x)))),
      sense = "min")
  },

  bounds_zero_start = function() {             # start=0, fix=0, max, Nonneg+Zero
    y <- ir_var("y1")
    program(
      vars = list(var_decl("y1", character(), CONTINUOUS, -1.0, 1.0, 0.0)),
      objective = y, sense = "max",
      constraints = list(constraint(y, nonneg()),
                         constraint(ir_apply("-", list(y, ir_const(0.5))), zero())),
      fix = list(list(var = "y1", index = list(), value = 0.0)))
  },

  indexed = function() {                       # families, indexing, canonical sort
    # Insertion order of the tables is deliberately scrambled: the encoder's
    # canonical sort is what the golden pins.
    program(
      sets = list(index_set("S", list(1L, 2L, 3L))),
      indexed_sets = list(a = list(
        list(key = list(1L), value = list(10L, 11L)),
        list(key = list(3L), value = list(30L)),
        list(key = list(2L), value = list(20L)))),
      params = list(p = list(
        list(key = list(2L), value = 2.0),
        list(key = list(1L), value = 0.0),
        list(key = list(3L), value = 3.0))),
      vars = list(
        var_decl("α", "S", CONTINUOUS, -3.15, 3.15, 0.0),
        var_decl("y", "S", CONTINUOUS, "p", 10.0, 1.0),   # lower = a param name
        var_decl("z", "S", BINARY, 0.0, 1.0, 0.0)),
      objective = ir_reduce("+", "i", ir_set_ref("S"),
                            ir_apply("*", list(ir_param("p", list("i")),
                                               ir_var("y", list("i"))))),
      sense = "min",
      constraints = list(constraint(
        ir_reduce("+", "j", ir_set_ref("a", list("i")),
                  ir_var("y", list("j")), ir_param("p", list("i"))),
        nonneg(),
        list(list("i", ir_set_ref("S"))))),
      fix = list(list(var = "α", index = list(1L), value = 0.0)))
  },

  indicator = function() {                     # u active implies x >= 0
    x <- ir_var("x"); u <- ir_var("u")
    program(
      vars = list(var_decl("x", character(), CONTINUOUS, -5.0, 5.0, 0.0),
                  var_decl("u", character(), BINARY, 0.0, 1.0, 0.0)),
      objective = x, sense = "min",
      constraints = list(constraint(x, indicator(u, nonneg()))))
  },

  stoch_parametric = function() {              # sources, both scalars, aggregators
    x <- ir_var("x"); d <- ir_source_ref("demand")
    program(
      vars = list(var_decl("x", character(), CONTINUOUS, 0.0, 200.0, 0.0)),
      objective = ir_apply("+", list(
        ir_apply("*", list(ir_const(3.0), x)),
        ir_apply("smean", list(ir_apply("abs", list(ir_apply("-", list(x, d)))))))),
      sense = "min",
      constraints = list(constraint(
        ir_apply("-", list(
          ir_apply("sfreq_leq", list(ir_apply("-", list(d, x)), ir_const(0.0))),
          ir_const(0.9))),
        nonneg())),
      scenarios = 512, scenario_seed = 42,
      sources = list(demand = parametric("normal", list(ir_const(100.0), ir_const(15.0)))))
  },

  stoch_empirical = function() {               # both source kinds, omitted seed
    # Sorted emission (price before shock) is not the insertion order, on purpose.
    x <- ir_var("x"); price <- ir_source_ref("price"); shock <- ir_source_ref("shock")
    program(
      params = list("μ" = list(list(key = list(), value = 50.0))),
      vars = list(var_decl("x", character(), CONTINUOUS, 0.0, 100.0, 0.0)),
      objective = ir_apply("+", list(
        ir_apply("smean", list(ir_apply("*", list(shock, ir_apply("-", list(price, x)))))),
        ir_apply("scvar", list(ir_apply("-", list(price, x)), ir_const(0.95))))),
      sense = "min",
      scenarios = 4,
      sources = list(shock = empirical(c(0.9, 1.0, 1.1, 1.3)),
                     price = parametric("normal", list(ir_param("μ"), ir_const(2.0)))))
  }
)

for (name in names(fixtures)) {
  got <- encode(fixtures[[name]]())
  want <- read_golden(name)
  check(sprintf("golden %-18s %4d bytes", name, length(want)),
        identical(got, want),
        sprintf("   got  %s\n   want %s\n", as_hex(got), as_hex(want)))
}

# encode_params: deterministic bytes from an order-free table set.
pd <- encode_params(list(
  b = list(list(key = list(1L), value = 2.0)),
  a = list(list(key = list(), value = 1.0))))
pd2 <- encode_params(list(
  a = list(list(key = list(), value = 1.0)),
  b = list(list(key = list(1L), value = 2.0))))
check("encode_params is order-free", identical(pd, pd2))

cat("wire goldens: all green\n")
