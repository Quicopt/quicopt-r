# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

#' Expression nodes, for building a program by hand
#'
#' These functions build the pieces of a [program()]'s expressions directly,
#' as plain lists. A [model()] builds them for you from ordinary R
#' arithmetic, so you need them only to build a program by hand. Each node is
#' a list whose `kind` field says what it is:
#'
#' * `ir_const(value)`: a number.
#' * `ir_var(name, index)`: a decision variable.
#' * `ir_param(name, index)`: an entry of one of the program's parameter
#'   tables.
#' * `ir_source_ref(name)`: a random variable declared in the program's
#'   `sources`.
#' * `ir_apply(op, args)`: an operator, such as `"+"` or `"sqrt"`, applied to
#'   a list of argument nodes.
#' * `ir_reduce(op, idx, over, body, cond)`: `body` combined over the elements
#'   of an index set, for example the sum of `body` over all `i` in a set
#'   `S`.
#' * `ir_set_ref(name, args)`: the index set a reduction runs over.
#' * `ir_struct_ref(name)`: a permutation declared in the program's
#'   `structures`. It may appear only as the second argument of the operators
#'   `"item_at"` and `"slot_of"`, which is what [item_at()] and [slot_of()]
#'   build.
#' * `ir_table_ref(param, index)`: an entry of a parameter table at positions
#'   given by expression nodes, which is what indexing a [lookup_table()]
#'   builds.
#'
#' An `index` is a list of whole numbers, for fixed positions, and strings,
#' for the names of indices bound by an enclosing reduction or constraint; it
#' is `list()` for a variable or entry without an index.
#'
#' @return A plain list without a class. Every function except `ir_set_ref()`
#'   returns an expression node, which can stand wherever a program expects an
#'   expression: in another node's `args`, as the program's objective, or as
#'   the `f` of a [constraint()]. `ir_set_ref()` returns a reference to an
#'   index set instead, a list with the fields `name` and `args` and no
#'   `kind`, which is what `ir_reduce()` takes as `over`.
#' @examples
#' # 3 * x + 1
#' ir_apply("+", list(ir_apply("*", list(ir_const(3), ir_var("x"))), ir_const(1)))
#'
#' # the sum of cost[i] * y[i] over the elements i of the set "items"
#' ir_reduce("+", "i", ir_set_ref("items"),
#'           ir_apply("*", list(ir_param("cost", list("i")), ir_var("y", list("i")))))
#' @name ir
NULL

# ── expression nodes ────────────────────────────────────────────────────────

#' @rdname ir
#' @param value A number.
#' @export
ir_const <- function(value) list(kind = "const", value = as.numeric(value))

#' @rdname ir
#' @param name The name of the variable, table, random variable, permutation
#'   or index set referred to.
#' @param index A position: a list of whole numbers and index names, `list()`
#'   for none. For `ir_table_ref()`, a list of one or two expression nodes.
#' @export
ir_param <- function(name, index = list()) list(kind = "param", name = name, index = index)

#' @rdname ir
#' @export
ir_var <- function(name, index = list()) list(kind = "var", name = name, index = index)

#' @rdname ir
#' @param op The name of an operator the service knows, such as `"+"`, `"*"`
#'   or `"sqrt"`. For `ir_reduce()`, the operator that combines the terms,
#'   such as `"+"` for a sum.
#' @param args For `ir_apply()`, a list of argument nodes. For `ir_set_ref()`,
#'   the indices the set depends on, `list()` for a set that depends on none.
#' @export
ir_apply <- function(op, args) list(kind = "apply", op = op, args = args)

#' @rdname ir
#' @param idx The name of the index that runs over the set, as used in `body`.
#' @param over The index set to run over, from `ir_set_ref()`.
#' @param body The expression to combine over the set.
#' @param cond An expression node: only the terms in which it is not 0 are
#'   included. `NULL` includes every term.
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
#' @param param The name of the parameter table.
#' @export
ir_table_ref <- function(param, index) list(kind = "table", param = param, index = index)

#' @rdname ir
#' @export
ir_set_ref <- function(name, args = list()) list(name = name, args = args)

# ── constraint sets ─────────────────────────────────────────────────────────

#' Constraint sets, for building a program by hand
#'
#' In a [program()], a constraint states that an expression lies in a set:
#'
#' * `zero()`: the expression equals 0;
#' * `nonneg()`: the expression is at least 0;
#' * `indicator(bin, inner)`: the expression lies in the set `inner` whenever
#'   the binary variable `bin` is 1, and is unrestricted when it is 0.
#'
#' So `x + 2 * y <= 5` is written as `5 - (x + 2 * y)` in `nonneg()`, and
#' `x == 3` as `x - 3` in `zero()`. [add()] makes this conversion for you.
#'
#' @return A plain list without a class, to be passed as the `set` of a
#'   [constraint()]: `list(kind = "zero")`, `list(kind = "nonneg")`, or for
#'   `indicator()` a list with `kind = "indicator"` and the fields `bin` and
#'   `inner`.
#' @examples
#' # x + 2 * y <= 5
#' constraint(ir_apply("-", list(ir_const(5),
#'                               ir_apply("+", list(ir_var("x"),
#'                                                  ir_apply("*", list(ir_const(2), ir_var("y"))))))),
#'            nonneg())
#' @name consets
NULL

#' @rdname consets
#' @export
zero <- function() list(kind = "zero")

#' @rdname consets
#' @export
nonneg <- function() list(kind = "nonneg")

#' @rdname consets
#' @param bin The binary variable that switches the constraint on, as an
#'   [ir_var()] node.
#' @param inner The set the expression must lie in when `bin` is 1: `zero()`
#'   or `nonneg()`.
#' @export
indicator <- function(bin, inner) list(kind = "indicator", bin = bin, inner = inner)

# ── stochastic sources ──────────────────────────────────────────────────────

#' A random variable with a distribution, for building a program by hand
#'
#' Declares one random variable of a [program()] by its distribution. `head`
#' names the distribution, such as `"normal"`, and `params` holds its
#' parameters as expression nodes, in the same order as for [normal()] and the
#' other distribution functions. A parameter may contain decision variables,
#' but no random variable. [rand_var()] builds these for you.
#'
#' @param head The name under which the service knows the distribution.
#' @param params A list of expression nodes, one per parameter.
#' @return A plain list without a class, with the fields
#'   `kind = "parametric"`, `head` and `params`. It is an element of the named
#'   list a [program()] takes as `sources`, and the element's name is the name
#'   [ir_source_ref()] refers to.
#' @examples
#' # demand ~ normal(100, 15)
#' sources <- list(demand = parametric("normal", list(ir_const(100), ir_const(15))))
#' @export
parametric <- function(head, params) list(kind = "parametric", head = head, params = params)

#' A random variable given by a sample
#'
#' `empirical(x)` describes a random variable by a sample of its values, one
#' per scenario, instead of by a distribution. Pass it to [rand_var()], as in
#' `rand_var(m, "demand", empirical(x))`. The length of the sample sets the
#' number of scenarios.
#'
#' This is how to use a distribution the package has no function for: draw a
#' sample in R, for example with `rlnorm()`, and pass it to `empirical()`.
#'
#' The samples of a model are read side by side, the `i`-th value of each in
#' scenario `i`, so values observed together stay together. [set_empirical()]
#' does this for every column of a data frame.
#'
#' A sample is fixed data. If it was drawn in R, R's `set.seed()` determines
#' it, not the model's seed, and [resample()] does not draw it again.
#'
#' @param data The sample: a numeric vector without `NA`, one value per
#'   scenario.
#' @return An object of class `quicopt_empirical`, for [rand_var()] or
#'   [set_distribution()]. It can also be an element of the `sources` of a
#'   [program()].
#' @examples
#' set.seed(1)
#' m <- model()
#' demand <- rand_var(m, "demand", empirical(rlnorm(500, log(100), 0.3)))   # lognormal
#' @export
empirical <- function(data) {
  data <- as.numeric(data)
  if (anyNA(data)) stop("an empirical column cannot contain NA")
  structure(list(kind = "empirical", data = data), class = "quicopt_empirical")
}

# ── structured variables ────────────────────────────────────────────────────

#' A permutation, for building a program by hand
#'
#' Declares one permutation of a [program()]: `size` items in `size` slots,
#' one item per slot (see [perm_var()]). [perm_var()] builds these for you.
#'
#' @param size How many items, at least 2.
#' @param start The arrangement the search starts from: `start[i]` is the
#'   slot of item `i`, so `start` contains each of the numbers 1 to `size`
#'   once. `integer()` starts with item `i` in slot `i`.
#' @param fixed Whether the permutation is fixed at `start`, which must then
#'   be given. This is how [evaluate()] and [resample()] keep the arrangement
#'   of a solution.
#' @param precede A list of pairs `c(before, after)`, each requiring item
#'   `before` to be in an earlier slot than item `after`.
#' @return A plain list without a class, with the fields
#'   `kind = "permutation"`, `size`, `start`, `fixed` and `precede`. It is an
#'   element of the named list a [program()] takes as `structures`, and the
#'   element's name is the name [ir_struct_ref()] refers to.
#' @examples
#' # five stops, stop 4 before stop 1
#' structures <- list(route = permutation_decl(5, precede = list(c(4, 1))))
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

#' A decision variable, for building a program by hand
#'
#' Declares one decision variable of a [program()]. [num_var()], [int_var()]
#' and [bin_var()] build these for you.
#'
#' @param name The variable's name, used for it in the answer.
#' @param axes The names of the index sets the variable is indexed over;
#'   `character()` for a single variable.
#' @param domain `CONTINUOUS`, `INTEGER` or `BINARY`.
#' @param lower,upper A number (`-Inf` or `Inf` for no bound), or the name of
#'   a parameter table, for a bound that differs from index to index.
#' @param start The value the search starts from.
#' @return `var_decl()` returns a plain list without a class, with the fields
#'   `name`, `axes`, `domain`, `lower`, `upper` and `start`. It is an element
#'   of the list a [program()] takes as `vars`.
#'
#'   `CONTINUOUS`, `INTEGER` and `BINARY` are not functions but constants: the
#'   whole numbers 1, 2 and 3, which stand for the three kinds of variable in
#'   `domain`.
#' @examples
#' var_decl("tables", domain = INTEGER, lower = 0)
#' @export
var_decl <- function(name, axes = character(), domain = CONTINUOUS,
                     lower = -Inf, upper = Inf, start = 0)
  list(name = name, axes = axes, domain = as.integer(domain),
       lower = lower, upper = upper, start = as.numeric(start))

#' An index set, for building a program by hand
#'
#' A named set of elements, for indexing variables (the `axes` of
#' [var_decl()]), for reductions such as sums ([ir_reduce()]), and for
#' repeating a constraint over its elements (the `over` of [constraint()]).
#'
#' @param name The set's name.
#' @param elements A list of whole numbers and strings.
#' @return A plain list without a class, with the fields `name` and
#'   `elements`. It is an element of the list a [program()] takes as `sets`.
#' @examples
#' index_set("items", list(1L, 2L, 3L))
#' @export
index_set <- function(name, elements) list(name = name, elements = elements)

#' A constraint, for building a program by hand
#'
#' States that the expression `f` lies in `set` (see [zero()] and the other
#' constraint sets). With `over`, the constraint is repeated for every element
#' of one or more index sets, like a constraint written "for all `i` in `S`".
#' [add()] builds these for you.
#'
#' @param f The expression node.
#' @param set The set `f` must lie in: [zero()], [nonneg()] or [indicator()].
#' @param over A list of `list(idx, set_ref)` pairs, each repeating the
#'   constraint for every element of the set `set_ref` (from [ir_set_ref()]),
#'   with the index named `idx` standing for the element in `f`. `list()` for a
#'   single constraint.
#' @return A plain list without a class, with the fields `f`, `set` and
#'   `over`. It is an element of the list a [program()] takes as
#'   `constraints`.
#' @examples
#' # x <= 4, written as 4 - x >= 0
#' constraint(ir_apply("-", list(ir_const(4), ir_var("x"))), nonneg())
#' @export
constraint <- function(f, set, over = list()) list(f = f, set = set, over = over)

#' A model as plain data
#'
#' A program holds a complete model as plain R lists, in the form the service
#' reads: [encode()] turns it into bytes, and [solve()] and [submit()] accept
#' it directly. [as_program()] converts a [model()] into a program. Building
#' one by hand, with this function and the ones it links to, is for parts of
#' the format that a [model()] does not offer, such as index sets and
#' parameter tables.
#'
#' Data indexed by positions is given as lists of entries, because a position
#' (a list of numbers and strings) cannot be a name:
#'
#' * `params` maps the name of a parameter table to a list of entries
#'   `list(key = <position>, value = <number>)`;
#' * `indexed_sets` maps a name to a list of entries
#'   `list(key = <position>, value = <list of elements>)`, a set that differs
#'   from position to position;
#' * `fix` is a list of entries `list(var = , index = , value = )`, each fixing
#'   one variable at a value.
#'
#' The order of the entries does not matter.
#'
#' A model with random variables also needs `sources`, which declares them,
#' and `scenarios` and `scenario_seed`, which say how many scenarios are drawn
#' and from which seed. A model with permutations needs `structures`.
#'
#' @param sets A list of [index_set()]s.
#' @param indexed_sets Sets that differ from position to position (see
#'   above).
#' @param params Parameter tables (see above).
#' @param vars A list of [var_decl()]s.
#' @param objective The objective, an expression node (see [ir]).
#' @param sense `"min"` or `"max"`.
#' @param constraints A list of [constraint()]s.
#' @param fix Variables fixed at a value (see above).
#' @param scenarios How many scenarios to draw, at least 1.
#' @param scenario_seed The seed to draw them from, at least 1.
#' @param sources The random variables: a named list of [parametric()] and
#'   [empirical()] declarations.
#' @param structures The permutations: a named list of [permutation_decl()]
#'   declarations.
#' @return An object of class `quicopt_program`: a list with one element per
#'   argument, under the argument's name.
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
