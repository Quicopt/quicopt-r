# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

#' Whether a variable is in use
#'
#' `active(x)` is 1 when the variable `x` is not 0, and 0 when it is. It is
#' meant for a variable declared with `semi = TRUE` (see [num_var()]), which is
#' either 0 or between its bounds: a delivery of either nothing or 10 to 25
#' units, say. A fee charged for every delivery that takes place is then
#' `fee * active(delivery)`, and a limit on how many deliveries take place is
#' a constraint on `sum(active(delivery))`.
#'
#' For such a variable, a model that is otherwise linear is still solved to a
#' proven optimum. On any other
#' variable, `active(x)` means the same, 1 when `x` is not 0, but the model is
#' then solved by a search.
#'
#' @param x A decision variable, or elements of one, such as `x[2:3]`.
#' @return An expression with one 0/1 element per element of `x`.
#' @examples
#' m <- model()
#' delivery <- int_var(m, "delivery", lower = 10, upper = 25, length = 3, semi = TRUE)
#' fee <- c(30, 10, 5)
#' minimize(m, sum(c(1, 2, 3) * delivery) + sum(fee * active(delivery)))
#' add(m, sum(delivery) >= 40)                     # the customer needs 40 units
#' add(m, sum(active(delivery)) <= 2)              # at most two deliveries
#' @export
active <- function(x) {
  nodes <- .nodes_of(x, "active()")
  if (!all(vapply(nodes, function(n) identical(n$kind, "var"), NA)))
    stop("active() takes a decision variable, or elements of one, such as x or x[2]")
  .qexpr(lapply(nodes, function(n) ir_apply("indicator", list(n))))
}

#' Group the variables of a subproblem
#'
#' Many models are made of small subproblems of the same kind: one per
#' customer to supply, per project to staff, per product to make. Each has a
#' few variables and constraints of its own, such as the customer's demand,
#' and the subproblems interact mostly through the objective, for example
#' through a warehouse's opening fee that several customers share.
#'
#' `block()` declares the variables of one such subproblem. A constraint
#' whose variables all belong to one block, such as one customer's demand, is
#' then that block's own constraint, and it holds in every solution the
#' service returns. Declaring the blocks of a model changes nothing else about
#' it. A constraint that involves variables of several blocks, such as a
#' person's working hours over several projects, holds in a solution that is
#' reported feasible.
#'
#' A variable can be in at most one block, and a variable in a block needs
#' finite bounds.
#'
#' @param m A [model()].
#' @param name The block's name, unique among the model's blocks.
#' @param vars The block's variables: a decision variable, elements of one
#'   (`x[1:3]`), or several combined with `c()`.
#' @return The model, invisibly.
#' @examples
#' # Three warehouses supply three customers. Each delivery is none or 10 to 25
#' # units and costs 5 plus a price per unit; a warehouse that delivers anything
#' # pays its opening fee.
#' demand  <- c(40, 30, 20)                                # units, customers 1 to 3
#' price   <- rbind(c(1, 3, 4), c(3, 1, 3), c(4, 2, 1))    # per unit, price[warehouse, customer]
#' opening <- c(60, 50, 40)                                # fee of warehouses 1 to 3
#' m <- model()
#' ship <- int_var(m, "ship", lower = 10, upper = 25, length = 9, semi = TRUE)  # none, or 10 to 25
#' to   <- function(c) ship[3 * (c - 1) + 1:3]             # to customer c, from warehouses 1 to 3
#' from <- function(w) ship[w + c(0, 3, 6)]                # from warehouse w, to customers 1 to 3
#' for (c in 1:3) {
#'   block(m, paste0("customer_", c), to(c))
#'   add(m, sum(to(c)) >= demand[c])
#' }
#' sent <- c(sum(from(1)), sum(from(2)), sum(from(3)))     # units leaving each warehouse
#' minimize(m, sum(as.vector(price) * ship)                # price per unit
#'             + 5 * sum(active(ship))                     # 5 per delivery
#'             + sum(opening * holds(sent >= 1)))          # a warehouse that ships pays its fee
#' \dontrun{
#' res <- solve(m)
#' res$objective                                           # 300
#' res$solution                                            # warehouse 2 delivers nothing
#' #  ship[1] ship[2] ship[3] ship[4] ship[5] ship[6] ship[7] ship[8] ship[9]
#' #       25       0      15      10       0      20       0       0      20
#' }
#' @export
block <- function(m, name, vars) {
  .check_model(m, "block")
  if (!is.character(name) || length(name) != 1L || is.na(name) || !nzchar(name))
    stop("a block needs a name: one non-empty string")
  blocks <- .m_get(m, "blocks")
  if (!is.null(blocks[[name]]))
    stop("the model already has a block named '", name, "'")
  if (inherits(vars, "quicopt_var") && !identical(vars$model, m))
    stop("the variable '", vars$name, "' belongs to a different model")
  nodes <- .nodes_of(vars, "block")
  if (!all(vapply(nodes, function(n) identical(n$kind, "var"), NA)))
    stop("block() takes decision variables, or elements of them, such as x or x[1:3]")
  flat <- vapply(nodes, function(n) n$name, "")
  lookup <- .flat_lookup(m)
  unknown <- setdiff(flat, names(lookup))
  if (length(unknown))
    stop("no decision variable named ", paste0("'", unknown, "'", collapse = ", "),
         " in this model")
  if (anyDuplicated(flat))
    stop("block '", name, "' lists '", flat[anyDuplicated(flat)], "' twice")
  owner <- rep(names(blocks), vapply(blocks, length, 0L))   # the block of each member so far
  names(owner) <- unlist(blocks, use.names = FALSE)
  taken <- intersect(flat, names(owner))
  if (length(taken))
    stop("'", taken[[1L]], "' is already in the block '", owner[[taken[[1L]]]],
         "'; a variable can be in one block only")
  vars_reg <- .m_get(m, "vars")
  for (key in flat) {
    at <- lookup[[key]]
    v <- vars_reg[[at$var]]
    if (!is.finite(v$lower[[at$i]]) || !is.finite(v$upper[[at$i]]))
      stop("'", key, "' has an infinite bound; a variable in a block needs finite bounds")
  }
  blocks[[name]] <- flat
  .m_set(m, "blocks", blocks)
  invisible(m)
}
