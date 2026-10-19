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
  },

  holes_blocks = function() {                  # both hole domains, indicator, step, min, blocks
    # The blocks are given in the order opposite to their emission (pair
    # before supply), on purpose: the encoder sorts them by name.
    q <- ir_var("q"); r <- ir_var("r"); s <- ir_var("s")
    x <- function(i) ir_var("x", list(i))
    ind <- function(e) ir_apply("indicator", list(e))
    times <- function(k, e) ir_apply("*", list(ir_const(k), e))
    program(
      sets = list(index_set("I", list(1L, 2L))),
      vars = list(var_decl("q", character(), SEMIINTEGER, 10.0, 25.0, 0.0),
                  var_decl("r", character(), SEMICONTINUOUS, 2.5, 8.0, 0.0),
                  var_decl("s", character(), BINARY, 0.0, 1.0, 0.0),
                  var_decl("x", "I", INTEGER, 0.0, 4.0, 0.0)),
      objective = ir_apply("+", list(
        times(1.5, q), times(2.0, r), times(30.0, ind(q)),
        times(40.0, ir_apply("step", list(
          ir_apply("-", list(ir_apply("+", list(x(1L), x(2L))), ir_const(1.0)))))),
        times(-5.0, ir_apply("min", list(ir_const(1.0), ir_apply("+", list(ind(q), ind(r)))))))),
      sense = "min",
      constraints = list(
        constraint(ir_apply("-", list(ir_apply("+", list(q, r)), ir_const(12.0))), nonneg()),
        constraint(ir_apply("-", list(times(8.0, s), r)), nonneg()),
        constraint(ir_apply("-", list(ir_apply("+", list(x(1L), x(2L))), ir_const(3.0))), nonneg())),
      blocks = list(pair = list(x(1L), x(2L)), supply = list(q, r, s)))
  },

  partition = function() {                     # a live and a fixed partition, part reads
    teams <- ir_struct_ref("teams"); split <- ir_struct_ref("split")
    part <- function(i) ir_apply("part_of", list(ir_const(i), teams))
    size <- function(b, P) ir_apply("size_of", list(ir_const(b), P))
    program(
      params = list(cost = list(list(key = list(1L), value = 2.0),
                                list(key = list(2L), value = 0.5))),
      vars = list(var_decl("y", character(), CONTINUOUS, 0.0, 5.0, 0.0)),
      objective = ir_apply("+", list(
        ir_table_ref("cost", list(part(1))), ir_table_ref("cost", list(part(3))),
        ir_apply("^", list(ir_apply("-", list(size(1, teams), size(2, teams))), ir_const(2.0))),
        ir_var("y"))),
      sense = "min",
      constraints = list(constraint(ir_apply("-", list(ir_var("y"), size(3, split))), nonneg())),
      structures = list(teams = partition_decl(5, 2, start = c(1, 2, 1, 2, 1)),
                        split = partition_decl(4, 3, start = c(3, 1, 3, 2), fixed = TRUE)))
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

# A subexpression used in several places is one object in R, shared rather
# than copied, and encode() writes every use from the bytes of its first
# encoding. The bytes must be those of the same program with every use a
# separate copy, which a serialize round trip makes: it does not keep the
# sharing.
unshared <- function(prog) unserialize(serialize(prog, NULL))

# Every kind of node shared, in the objective, in constraints and in a
# distribution's parameter: a stock carried over ten months, each month's
# loss reading the stock the month starts with. 0 and -0 are separate
# objects with different bytes, and each is shared.
demand <- ir_source_ref("demand")
plus_zero <- ir_const(0); minus_zero <- ir_const(-0)
price <- ir_param("price", list("i"))
total <- ir_reduce("+", "i", ir_set_ref("S"),
                   ir_apply("*", list(price, ir_var("y", list("i")))), price)
fee <- ir_table_ref("fee", list(ir_var("k")))
stock <- plus_zero
losses <- list()
for (t in 1:10) {                              # loop over the months
  available <- ir_apply("+", list(stock, ir_var("ship", list(t)), fee))
  losses[[t]] <- ir_apply("max", list(ir_apply("-", list(demand, available)), plus_zero))
  stock <- ir_apply("max", list(ir_apply("-", list(available, demand)), minus_zero))
}   # end loop over the months
mean_demand <- ir_apply("+", list(total, ir_const(100)))
shared <- program(
  sets = list(index_set("S", list(1L, 2L)), index_set("M", as.list(1:10))),
  params = list(price = list(list(key = list(1L), value = 2.0),
                             list(key = list(2L), value = 3.0)),
                fee = list(list(key = list(1L), value = 0.5),
                           list(key = list(2L), value = 0.25))),
  vars = list(var_decl("y", "S", CONTINUOUS, 0, 10, 0),
              var_decl("k", character(), INTEGER, 1, 2, 1),
              var_decl("ship", "M", CONTINUOUS, 0, 50, 5)),
  objective = ir_apply("+", c(list(total, ir_apply("smean", list(ir_apply("+", losses)))),
                              losses[c(3, 7)])),
  sense = "min",
  constraints = list(constraint(ir_apply("-", list(mean_demand, stock)), nonneg()),
                     constraint(ir_apply("-", list(stock, minus_zero)), zero(),
                                list(list("i", ir_set_ref("S"))))),
  scenarios = 8,
  sources = list(demand = parametric("normal", list(mean_demand, ir_const(15)))))
check("a shared subexpression encodes as separate copies do",
      identical(encode(shared), encode(unshared(shared))))

# 0 and -0 are identical() in R, but their bytes differ in the sign bit, the
# last of the eight (80). Writing a shared node from its first encoding must
# not mistake one for the other, as a memo keyed by value would. The expected
# bytes are those of the encoder that wrote every use afresh.
signed_zeros <- program(objective = ir_apply("+", list(plus_zero, minus_zero, plus_zero, minus_zero)))
check("0 and -0 keep their own bytes when each is shared",
      identical(as_hex(encode(signed_zeros)),
                paste0("2a31222f0a012b",
                       "120909", "0000000000000000", "120909", "0000000000000080",
                       "120909", "0000000000000000", "120909", "0000000000000080",
                       "32036d696e")))

# The same through a model: a stock carried over twelve months, each month
# reading last month's stock twice, once for what is lost and once for what
# is kept.
m <- model()
ship <- num_var(m, "ship", lower = 0, upper = 50, length = 12)
need <- rand_var(m, "need", normal(20, 5))
stock <- 0
lost <- list()
for (t in 1:12) {                              # loop over the months
  available <- stock + ship[t]
  lost[[t]] <- max(need - available, 0)
  stock <- max(available - need, 0)
}   # end loop over the months
minimize(m, sum(ship) + expectation(10 * do.call(sum, lost) + stock))
check("a model's shared stock encodes as separate copies do",
      identical(encode(m), encode(unshared(as_program(m)))))

cat("wire goldens: all green\n")
