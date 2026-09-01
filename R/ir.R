# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

#' quicopt IR — a model as plain data
#'
#' The form a model takes between the interface that wrote it and the service
#' that solves it: variables, expressions and constraints, with no trace of how
#' they were authored. [model()] and friends build one of these on the way out;
#' [encode()] turns it into the bytes the service reads. The shape is the
#' service's published contract — these constructors track it, they never fork it.
#'
#' Nodes are plain lists tagged by a `kind` field. An index tuple is a plain
#' list whose entries are integers (concrete coordinates) or strings (bound
#' index names).
#'
#' The constructors carry an `ir_` prefix rather than mirroring the Python
#' client's bare names: `Reduce` is a base R function, and this package extends
#' base names, it does not mask them.
#'
#' @name ir
NULL

# ── expression nodes ────────────────────────────────────────────────────────

#' @rdname ir
#' @param value A numeric constant.
#' @export
ir_const <- function(value) list(kind = "const", value = as.numeric(value))

#' @rdname ir
#' @param name The referenced name.
#' @param index An index tuple (a list of integers and strings; `list()` for a scalar).
#' @export
ir_param <- function(name, index = list()) list(kind = "param", name = name, index = index)

#' @rdname ir
#' @export
ir_var <- function(name, index = list()) list(kind = "var", name = name, index = index)

#' @rdname ir
#' @param op A catalog operator key, e.g. `"+"`.
#' @param args A list of argument nodes.
#' @export
ir_apply <- function(op, args) list(kind = "apply", op = op, args = args)

#' @rdname ir
#' @param idx The bound dummy index name.
#' @param over An [ir_set_ref()] the fold ranges across.
#' @param body The folded expression.
#' @param cond Keep a term only where `cond` is non-zero; `NULL` keeps every term.
#' @export
ir_reduce <- function(op, idx, over, body, cond = NULL)
  list(kind = "reduce", op = op, idx = idx, over = over, body = body, cond = cond)

#' @rdname ir
#' @export
ir_source_ref <- function(name) list(kind = "source", name = name)

#' @rdname ir
#' @param args Enclosing bound indices the set is applied to (`list()` for a flat set).
#' @export
ir_set_ref <- function(name, args = list()) list(name = name, args = args)

# ── constraint sets ─────────────────────────────────────────────────────────

#' Constraint sets
#'
#' A constraint is a set membership: the expression `f` must land in the set,
#' so `x + 2*y <= 5` is written as `5 - (x + 2*y)` in [nonneg()] — one sign
#' convention rather than two.
#'
#' @name consets
NULL

#' @rdname consets
#' @export
zero <- function() list(kind = "zero")

#' @rdname consets
#' @export
nonneg <- function() list(kind = "nonneg")

#' @rdname consets
#' @param bin The binary [ir_var()] whose activity implies the inner set.
#' @param inner The constraint set that holds when `bin` is active.
#' @export
indicator <- function(bin, inner) list(kind = "indicator", bin = bin, inner = inner)

# ── stochastic sources ──────────────────────────────────────────────────────

#' A random variable drawn from a distribution
#'
#' `head` is a catalog operator (`"normal"`, ...) and each parameter is an
#' ordinary deterministic expression node — so a distribution whose mean is
#' itself a decision needs nothing the grammar does not already have.
#'
#' @param head The distribution's catalog name.
#' @param params A list of parameter nodes.
#' @export
parametric <- function(head, params) list(kind = "parametric", head = head, params = params)

#' A random variable given as a fixed scenario column
#'
#' Exactly `scenarios` values, one per scenario. Several empirical columns are
#' read at the same scenario index, so columns observed jointly stay correlated —
#' which is how a joint distribution is expressed.
#'
#' @param data A numeric vector, one value per scenario.
#' @export
empirical <- function(data) {
  data <- as.numeric(data)
  if (anyNA(data)) stop("an empirical column cannot contain NA")
  structure(list(kind = "empirical", data = data), class = "quicopt_empirical")
}

# ── declarations and the container ──────────────────────────────────────────

# Domain codes are the service's own; see the vendored schema.

#' @rdname var_decl
#' @export
CONTINUOUS <- 1L

#' @rdname var_decl
#' @export
INTEGER <- 2L

#' @rdname var_decl
#' @export
BINARY <- 3L

#' A variable declaration
#'
#' @param name The variable's name; solutions come back keyed by it.
#' @param axes Index-set names the variable ranges over (`character()` for a scalar).
#' @param domain [CONTINUOUS], [INTEGER] or [BINARY].
#' @param lower,upper A number (`-Inf`/`Inf` for an open direction), or the
#'   name of a parameter table when the bound varies by index.
#' @param start The initial point handed to the solver.
#' @export
var_decl <- function(name, axes = character(), domain = CONTINUOUS,
                     lower = -Inf, upper = Inf, start = 0)
  list(name = name, axes = axes, domain = as.integer(domain),
       lower = lower, upper = upper, start = as.numeric(start))

#' A named index set with concrete elements
#'
#' @param name The set's name.
#' @param elements A list of integers and strings.
#' @export
index_set <- function(name, elements) list(name = name, elements = elements)

#' A constraint row
#'
#' @param f The constrained expression node.
#' @param set The constraint set `f` must lie in ([zero()], [nonneg()], [indicator()]).
#' @param over Quantifier bindings, a list of `list(idx, set_ref)` pairs
#'   (`list()` for a single scalar row).
#' @export
constraint <- function(f, set, over = list()) list(f = f, set = set, over = over)

#' A complete optimization model as plain data
#'
#' The tables keyed by index tuples are lists of entries rather than named
#' lists, because an index tuple is not a string: `params` maps a table name to
#' a list of `list(key = <index tuple>, value = <number>)` entries,
#' `indexed_sets` maps a name to `list(key = ..., value = <element list>)`
#' fibres, and `fix` is a list of `list(var = , index = , value = )` pins.
#' Entry order does not matter; encoding sorts them canonically.
#'
#' A model under uncertainty adds three more: the random variables it draws
#' (`sources`, a named list of [parametric()] / [empirical()] declarations), how
#' many scenarios are drawn and the seed they are drawn from. The last two are
#' model data — they pin the sampled instance, so the same program always sees
#' the same draws. Left at their defaults they say nothing, and the encoded
#' bytes are those of a deterministic model.
#'
#' @param sets A list of [index_set()]s.
#' @param indexed_sets Dependent sets carried as data (see above).
#' @param params Named parameter tables (see above).
#' @param vars A list of [var_decl()]s.
#' @param objective The objective expression node.
#' @param sense `"min"` or `"max"`.
#' @param constraints A list of [constraint()]s.
#' @param fix Per-index variable pins (see above).
#' @param scenarios How many scenarios are drawn (at least 1).
#' @param scenario_seed The seed they are drawn from (at least 1).
#' @param sources Named [parametric()] / [empirical()] declarations.
#' @export
program <- function(sets = list(), indexed_sets = list(), params = list(),
                    vars = list(), objective = NULL, sense = "min",
                    constraints = list(), fix = list(),
                    scenarios = 1, scenario_seed = 1, sources = list()) {
  structure(list(sets = sets, indexed_sets = indexed_sets, params = params,
                 vars = vars, objective = objective, sense = sense,
                 constraints = constraints, fix = fix,
                 scenarios = as.numeric(scenarios),
                 scenario_seed = as.numeric(scenario_seed),
                 sources = sources),
            class = "quicopt_program")
}
