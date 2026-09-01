# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

#' quicopt wire — a program's bytes
#'
#' [encode()] turns a [program()] into the bytes the service reads. Encoding is
#' deterministic: the same model always produces the same bytes, and they are
#' the bytes the service produces for that model too — checked byte for byte
#' against committed goldens in `tests/`.
#'
#' @name wire
NULL

# Hand-rolled rather than generated: the schema is small and frozen, and the
# byte-exactness the golden test pins is easier to hold with the encoder in
# view. Mirrors the Python client's encoder rule for rule; the rules that
# exactness turns on are commented at the functions enforcing them.
#
# Protobuf crib: a field is `tag = (number*8 + wiretype)` then the payload;
# wiretype 0 = varint, 1 = fixed64 (doubles, little-endian), 2 =
# length-delimited (strings, embedded messages, packed repeated).

# ── the byte sink ───────────────────────────────────────────────────────────
# Growing a raw vector in place is quadratic in R, so a sink is a list of raw
# chunks collapsed once at the end (measured 73x faster at 20k appends).

.sink <- function() {
  e <- new.env(parent = emptyenv())
  e$chunks <- vector("list", 32L)
  e$n <- 0L
  e
}

.put <- function(io, r) {
  n <- io$n + 1L
  if (n > length(io$chunks)) io$chunks <- c(io$chunks, vector("list", length(io$chunks)))
  io$chunks[[n]] <- r
  io$n <- n
  invisible(NULL)
}

.bytes <- function(io) {
  if (io$n == 0L) return(raw(0))
  unlist(io$chunks[seq_len(io$n)], use.names = FALSE)
}

# ── low-level writers ───────────────────────────────────────────────────────

# Base-128 varint. Arithmetic runs in doubles, exact below 2^53 — every value
# emitted here (field tags, lengths, domain codes, scenario counts) sits far
# under that. Negative int64 would need 64-bit two's complement, which doubles
# cannot carry exactly; no fixture and no front-end emits one, so it is refused
# rather than approximated.
.put_varint <- function(io, x) {
  x <- as.numeric(x)
  if (x < 0) stop("wire: negative varints are not supported")
  if (x >= 2^53) stop("wire: varint too large to encode exactly")
  out <- integer(0)
  repeat {
    b <- x %% 128
    x <- (x - b) / 128
    if (x > 0) out <- c(out, b + 128) else { out <- c(out, b); break }
  }
  .put(io, as.raw(out))
}

.put_tag <- function(io, field, wt) .put_varint(io, field * 8 + wt)

.w_bytes <- function(io, field, b) {          # wiretype 2: tag, length, payload
  .put_tag(io, field, 2)
  .put_varint(io, length(b))
  if (length(b)) .put(io, b)
}

.w_str <- function(io, field, s)              # a string field, as UTF-8 bytes
  .w_bytes(io, field, charToRaw(enc2utf8(as.character(s))))

.w_msg <- function(io, field, b) .w_bytes(io, field, b)   # an embedded message

.w_double <- function(io, field, x) {         # wiretype 1: little-endian fixed64
  .put_tag(io, field, 1)
  .put(io, writeBin(as.numeric(x), raw(), size = 8, endian = "little"))
}

.w_varint <- function(io, field, x) {
  .put_tag(io, field, 0)
  .put_varint(io, x)
}

# Materialize an embedded message's bytes by running its builder on a fresh sink.
.msg <- function(build) {
  io <- .sink()
  build(io)
  .bytes(io)
}

# ── canonical ordering ──────────────────────────────────────────────────────
# Vectors (sets, vars, constraints, args) keep their order; tables keyed by
# index tuples (params, indexed_sets, fix) are sorted so two encodes of equal
# data agree: tuples by length then element-wise, ints before strings at each
# position. Names sort bytewise (radix = the C locale), which over UTF-8 is
# code-point order — the reference codec's ordering, independent of the session
# locale.

.sort_names <- function(x) sort(x, method = "radix")

.is_int_elem <- function(e) is.numeric(e) && !is.character(e)

# Order a list of index tuples canonically: build one sort column per tuple
# position (kind, number, text), pad short tuples so length is the primary key.
.idx_order <- function(keys) {
  n <- length(keys)
  if (n <= 1L) return(seq_len(n))
  lens <- vapply(keys, length, 0L)
  cols <- list(lens)
  for (p in seq_len(max(lens, 0L))) {
    kind <- integer(n); num <- numeric(n); txt <- character(n)
    for (i in seq_len(n)) {
      if (p > lens[[i]]) { kind[[i]] <- -1L; next }        # padding sorts first,
      e <- keys[[i]][[p]]                                  # consistent with the
      if (.is_int_elem(e)) {                               # length primary key
        kind[[i]] <- 0L; num[[i]] <- as.numeric(e)
      } else {
        kind[[i]] <- 1L; txt[[i]] <- as.character(e)
      }
    }
    cols <- c(cols, list(kind, num, txt))
  }
  do.call(order, c(cols, list(method = "radix")))
}

# ── message encoders (schema order, one function per message) ───────────────

.enc_index_elem <- function(io, e) {
  if (is.character(e)) .w_str(io, 2, e)                    # a bound index name
  else if (.is_int_elem(e)) .w_varint(io, 1, e)            # a concrete coordinate
  else stop("wire: index element must be a number or a string, got ", class(e)[[1]])
}

.enc_index <- function(io, idx)
  for (e in idx) .w_msg(io, 1, .msg(function(b) .enc_index_elem(b, e)))

.idx_msg <- function(idx) .msg(function(b) .enc_index(b, idx))

.enc_var_ref <- function(io, v) {
  .w_str(io, 1, v$name)
  .w_msg(io, 2, .idx_msg(v$index))
}

.enc_param_ref <- function(io, p) {
  .w_str(io, 1, p$name)
  .w_msg(io, 2, .idx_msg(p$index))
}

.enc_set_ref <- function(io, s) {
  .w_str(io, 1, s$name)
  .w_msg(io, 2, .idx_msg(s$args))
}

# The oneof case is always emitted, so Const(0.0) survives the round-trip
# rather than collapsing to an empty message.
.enc_expr <- function(io, e) {
  switch(e$kind,
    const = .w_double(io, 1, e$value),
    param = .w_msg(io, 2, .msg(function(b) .enc_param_ref(b, e))),
    var = .w_msg(io, 3, .msg(function(b) .enc_var_ref(b, e))),
    apply = .w_msg(io, 4, .msg(function(b) {
      .w_str(b, 1, e$op)
      for (a in e$args) .w_msg(b, 2, .expr_msg(a))
    })),
    reduce = .w_msg(io, 5, .msg(function(b) {
      .w_str(b, 1, e$op)
      .w_str(b, 2, e$idx)
      .w_msg(b, 3, .msg(function(cc) .enc_set_ref(cc, e$over)))
      .w_msg(b, 4, .expr_msg(e$body))
      if (!is.null(e$cond)) .w_msg(b, 5, .expr_msg(e$cond))
    })),
    source = .w_msg(io, 6, .msg(function(b) .w_str(b, 1, e$name))),
    stop("wire: not an expression node: ", e$kind)
  )
}

.expr_msg <- function(e) .msg(function(b) .enc_expr(b, e))

.enc_conset <- function(io, s) {
  switch(s$kind,
    zero = .w_msg(io, 1, raw(0)),
    nonneg = .w_msg(io, 2, raw(0)),
    indicator = .w_msg(io, 3, .msg(function(b) {
      .w_msg(b, 1, .msg(function(cc) .enc_var_ref(cc, s$bin)))
      .w_msg(b, 2, .msg(function(cc) .enc_conset(cc, s$inner)))
    })),
    stop("wire: not a constraint set: ", s$kind)
  )
}

.enc_constraint <- function(io, cn) {
  .w_msg(io, 1, .expr_msg(cn$f))
  .w_msg(io, 2, .msg(function(b) .enc_conset(b, cn$set)))
  for (q in cn$over)
    .w_msg(io, 3, .msg(function(b) {
      .w_str(b, 1, q[[1]])
      .w_msg(b, 2, .msg(function(cc) .enc_set_ref(cc, q[[2]])))
    }))
}

.enc_bound <- function(io, b) {
  if (is.character(b)) .w_str(io, 2, b)                    # a param-table name
  else .w_double(io, 1, b)
}

.enc_var_decl <- function(io, vd) {
  .w_str(io, 1, vd$name)
  for (ax in vd$axes) .w_str(io, 2, ax)
  .w_varint(io, 3, vd$domain)
  .w_msg(io, 4, .msg(function(b) .enc_bound(b, vd$lower)))
  .w_msg(io, 5, .msg(function(b) .enc_bound(b, vd$upper)))
  .w_double(io, 6, vd$start)                               # always, even at 0.0
}

.enc_index_set <- function(io, s) {
  .w_str(io, 1, s$name)
  for (el in s$elements) .w_msg(io, 2, .msg(function(b) .enc_index_elem(b, el)))
}

.enc_indexed_set <- function(io, name, fibres) {
  .w_str(io, 1, name)
  keys <- lapply(fibres, `[[`, "key")
  for (i in .idx_order(keys)) {
    fib <- fibres[[i]]
    .w_msg(io, 2, .msg(function(b) {
      .w_msg(b, 1, .idx_msg(fib$key))
      for (el in fib$value) .w_msg(b, 2, .msg(function(cc) .enc_index_elem(cc, el)))
    }))
  }
}

.enc_param_table <- function(io, name, entries) {
  .w_str(io, 1, name)
  keys <- lapply(entries, `[[`, "key")
  for (i in .idx_order(keys)) {
    en <- entries[[i]]
    .w_msg(io, 2, .msg(function(b) {
      .w_msg(b, 1, .idx_msg(en$key))
      .w_double(b, 2, en$value)                            # always, even at 0.0
    }))
  }
}

.enc_source <- function(io, name, s) {
  .w_str(io, 1, name)
  if (s$kind == "parametric") {
    .w_msg(io, 2, .msg(function(b) {
      .w_str(b, 1, s$head)
      for (p in s$params) .w_msg(b, 2, .expr_msg(p))
    }))
  } else if (s$kind == "empirical") {
    # Packed: one length-delimited field of 8*R little-endian doubles — what a
    # generated encoder emits for a proto3 repeated double. writeBin packs the
    # whole column in one vectorized call.
    column <- writeBin(as.numeric(s$data), raw(), size = 8, endian = "little")
    .w_msg(io, 3, .msg(function(b) .w_bytes(b, 1, column)))
  } else stop("wire: not a source declaration: ", s$kind)
}

# ── the program ─────────────────────────────────────────────────────────────

#' Encode a program to the bytes the service reads
#'
#' Two equal programs always encode to equal bytes, whichever order their
#' tables happened to be built in. A model that declares no uncertainty encodes
#' to exactly the bytes it would have before the stochastic layer existed, so
#' declaring none costs an ordinary model nothing.
#'
#' Encoding is normally invisible: [solve_model()] does it for you, and what it
#' sends is exactly these bytes. Reach for `encode` to send them yourself,
#' store them, or check them.
#'
#' @param prog A [program()], or a model built with [model()] (which is lowered
#'   first).
#' @return A raw vector: the encoded program.
#' @export
encode <- function(prog) {
  if (inherits(prog, "quicopt_model")) prog <- as_program(prog)
  if (!inherits(prog, "quicopt_program")) stop("encode takes a program() or a model()")
  # Fields in schema order (1-8 deterministic, 9-11 stochastic); the order-free
  # tables are emitted sorted, which is what makes equal programs equal bytes.
  # The two scenario scalars are omitted at their default of 1 — and that is
  # why the default is 1 and not 0: protobuf cannot tell a zero from an absent
  # field, so a 0 here would reach the service as "use your default".
  io <- .sink()
  for (s in prog$sets) .w_msg(io, 1, .msg(function(b) .enc_index_set(b, s)))
  for (name in .sort_names(names2(prog$indexed_sets)))
    .w_msg(io, 2, .msg(function(b) .enc_indexed_set(b, name, prog$indexed_sets[[name]])))
  for (name in .sort_names(names2(prog$params)))
    .w_msg(io, 3, .msg(function(b) .enc_param_table(b, name, prog$params[[name]])))
  for (vd in prog$vars) .w_msg(io, 4, .msg(function(b) .enc_var_decl(b, vd)))
  .w_msg(io, 5, .expr_msg(prog$objective))
  .w_str(io, 6, prog$sense)
  for (cn in prog$constraints) .w_msg(io, 7, .msg(function(b) .enc_constraint(b, cn)))
  if (length(prog$fix)) {
    vars <- vapply(prog$fix, `[[`, "", "var")
    keys <- lapply(prog$fix, `[[`, "index")
    ord <- order(vars, .idx_order_rank(keys), method = "radix")
    for (i in ord) {
      fx <- prog$fix[[i]]
      .w_msg(io, 8, .msg(function(b) {
        .w_str(b, 1, fx$var)
        .w_msg(b, 2, .idx_msg(fx$index))
        .w_double(b, 3, fx$value)                          # always, even at 0.0
      }))
    }
  }
  if (prog$scenarios != 1) .w_varint(io, 9, prog$scenarios)
  if (prog$scenario_seed != 1) .w_varint(io, 10, prog$scenario_seed)
  for (name in .sort_names(names2(prog$sources)))
    .w_msg(io, 11, .msg(function(b) .enc_source(b, name, prog$sources[[name]])))
  .bytes(io)
}

# The rank of each tuple under the canonical order, usable as a secondary sort
# column beside the variable name.
.idx_order_rank <- function(keys) {
  r <- integer(length(keys))
  r[.idx_order(keys)] <- seq_along(keys)
  r
}

names2 <- function(x) if (is.null(names(x))) character(0) else names(x)

#' Encode parameter tables alone, for rebinding data
#'
#' Send the program once, then one of these per instance to re-solve the same
#' structure on new data without re-sending the model. Tables are written in
#' sorted order, so the same data always encodes to the same bytes.
#'
#' @param params Named parameter tables, as in [program()].
#' @return A raw vector: the encoded tables.
#' @export
encode_params <- function(params) {
  io <- .sink()
  for (name in .sort_names(names2(params)))
    .w_msg(io, 1, .msg(function(b) .enc_param_table(b, name, params[[name]])))
  .bytes(io)
}
