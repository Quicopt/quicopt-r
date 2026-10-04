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
#' @return A plain list, with no class attribute, holding one node of a model's
#'   expression tree. `ir_const()`, `ir_param()`, `ir_var()`, `ir_apply()`,
#'   `ir_reduce()`, `ir_source_ref()`, `ir_struct_ref()` and `ir_table_ref()`
#'   each return an expression node: its `kind` field (`"const"`, `"param"`,
#'   `"var"`, `"apply"`, `"reduce"`, `"source"`, `"structure"` or `"table"`)
#'   says which node it is, and the remaining fields are the
#'   arguments under their own names (`value` coerced to numeric). Such a node
#'   stands wherever an expression is expected: as an entry of another node's
#'   `args`, as the objective of a [program()], or as the `f` of a
#'   [constraint()]. `ir_set_ref()` returns a list with the fields `name` and
#'   `args`: a reference to an index set rather than an expression, so it
#'   carries no `kind`, and it is what [ir_reduce()] takes as `over`.
#'
#'   `ir_struct_ref()` refers to a declared permutation by name, and is legal
#'   only as the second argument of the catalog operators `item_at` and
#'   `slot_of` (what [item_at()] and [slot_of()] build). `ir_table_ref()` reads
#'   the parameter table `param` at one or two positions given as expression
#'   nodes (what indexing a [lookup_table()] builds).
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
#' @export
ir_struct_ref <- function(name) list(kind = "structure", name = name)

#' @rdname ir
#' @param param The name of the parameter table read.
#' @export
ir_table_ref <- function(param, index) list(kind = "table", param = param, index = index)

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
#' @return A plain list, with no class attribute, naming the set a constrained
#'   expression must lie in; it is what [constraint()] takes as `set`. `zero()`
#'   returns `list(kind = "zero")`, meaning the expression equals 0. `nonneg()`
#'   returns `list(kind = "nonneg")`, meaning the expression is at least 0.
#'   `indicator()` returns a list with `kind = "indicator"` and the fields
#'   `bin` and `inner` as given, meaning `inner` is imposed only where `bin`
#'   is active.
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
#' @return A plain list, with no class attribute, with the fields
#'   `kind = "parametric"`, `head` and `params` as given. It declares one
#'   random variable by its distribution, and is an entry of the named list a
#'   [program()] takes as `sources`; the entry's name is the name
#'   [ir_source_ref()] refers to.
#' @export
parametric <- function(head, params) list(kind = "parametric", head = head, params = params)

#' A random variable given as a fixed scenario column
#'
#' Exactly `scenarios` values, one per scenario. Several empirical columns are
#' read at the same scenario index, so columns observed jointly stay correlated —
#' which is how a joint distribution is expressed.
#'
#' @param data A numeric vector, one value per scenario.
#' @return An object of class `quicopt_empirical`: a list with the fields
#'   `kind = "empirical"` and `data`, the column as a numeric vector. It
#'   declares one random variable by its observed values, and is an entry of
#'   the named list a [program()] takes as `sources`.
#' @export
empirical <- function(data) {
  data <- as.numeric(data)
  if (anyNA(data)) stop("an empirical column cannot contain NA")
  structure(list(kind = "empirical", data = data), class = "quicopt_empirical")
}

# ── structured variables ────────────────────────────────────────────────────

#' A permutation declaration
#'
#' `size` items in `size` slots, one each. `start[i]` is the slot item `i`
#' starts in (a permutation of `1:size`; empty for the default, item `i` in
#' slot `i`). `fixed` pins the permutation at `start`, which must then be
#' given: how a solution is re-evaluated. Each entry of `precede` is a pair
#' `c(before, after)` of items, requiring `before` in an earlier slot than
#' `after`.
#'
#' @param size How many items, at least 2.
#' @param start The starting slot of each item, or `integer()`.
#' @param fixed Whether the permutation is pinned at `start`.
#' @param precede A list of `c(before, after)` pairs.
#' @return A plain list, with no class attribute, with the fields
#'   `kind = "permutation"`, `size`, `start`, `fixed` and `precede`. It
#'   declares one permutation, and is an entry of the named list a
#'   [program()] takes as `structures`; the entry's name is the name
#'   [ir_struct_ref()] refers to.
#' @export
permutation_decl <- function(size, start = integer(), fixed = FALSE, precede = list())
  list(kind = "permutation", size = as.integer(size), start = as.integer(start),
       fixed = isTRUE(fixed), precede = lapply(precede, as.integer))

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
#' @return `var_decl()` returns a plain list, with no class attribute, with the
#'   fields `name`, `axes`, `domain` (the integer domain code), `lower`,
#'   `upper` and `start` (numeric). It declares one variable of the model, and
#'   is an entry of the list a [program()] takes as `vars`.
#'
#'   `CONTINUOUS`, `INTEGER` and `BINARY` are not functions but integer
#'   constants (`1L`, `2L` and `3L`): the codes the service uses for a
#'   variable's domain, to be passed as `domain`.
#' @export
var_decl <- function(name, axes = character(), domain = CONTINUOUS,
                     lower = -Inf, upper = Inf, start = 0)
  list(name = name, axes = axes, domain = as.integer(domain),
       lower = lower, upper = upper, start = as.numeric(start))

#' A named index set with concrete elements
#'
#' @param name The set's name.
#' @param elements A list of integers and strings.
#' @return A plain list, with no class attribute, with the fields `name` and
#'   `elements` as given. It defines one index set of the model, and is an
#'   entry of the list a [program()] takes as `sets`.
#' @export
index_set <- function(name, elements) list(name = name, elements = elements)

#' A constraint row
#'
#' @param f The constrained expression node.
#' @param set The constraint set `f` must lie in ([zero()], [nonneg()], [indicator()]).
#' @param over Quantifier bindings, a list of `list(idx, set_ref)` pairs
#'   (`list()` for a single scalar row).
#' @return A plain list, with no class attribute, with the fields `f`, `set`
#'   and `over` as given. It states that `f` lies in `set`, once for every
#'   binding of the indices in `over`, and is an entry of the list a
#'   [program()] takes as `constraints`.
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
#' A model with a permutation adds `structures`, a named list of
#' [permutation_decl()] declarations that [ir_struct_ref()] nodes refer to.
#' Left empty it says nothing, as `sources` does.
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
#' @param structures Named [permutation_decl()] declarations.
#' @return An object of class `quicopt_program`: a list with one field per
#'   argument, under the argument's name (`scenarios` and `scenario_seed`
#'   coerced to numeric). It is the complete model in the form the service
#'   reads, with nothing left to resolve: [encode()] turns it into bytes, and
#'   [solve_model()] and [submit()] accept it directly.
#' @export
program <- function(sets = list(), indexed_sets = list(), params = list(),
                    vars = list(), objective = NULL, sense = "min",
                    constraints = list(), fix = list(),
                    scenarios = 1, scenario_seed = 1, sources = list(),
                    structures = list()) {
  structure(list(sets = sets, indexed_sets = indexed_sets, params = params,
                 vars = vars, objective = objective, sense = sense,
                 constraints = constraints, fix = fix,
                 scenarios = as.numeric(scenarios),
                 scenario_seed = as.numeric(scenario_seed),
                 sources = sources, structures = structures),
            class = "quicopt_program")
}
