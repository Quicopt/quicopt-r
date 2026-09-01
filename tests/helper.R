# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

# Load the package under test. Inside R CMD check the installed package is on
# the library path; during development the sources are sourced directly, so the
# tests run from a plain checkout with no install step (Rscript tests/test-*.R).
local({
  for (rdir in c("R", "../R")) {
    if (file.exists(file.path(rdir, "ir.R"))) {
      for (f in sort(list.files(rdir, pattern = "\\.R$", full.names = TRUE)))
        sys.source(f, envir = globalenv())
      return(invisible())
    }
  }
  library(quicopt)
})

golden_dir <- if (dir.exists("tests/goldens")) "tests/goldens" else "goldens"

read_golden <- function(name) {
  hex <- trimws(readLines(file.path(golden_dir, paste0(name, ".hex")), warn = FALSE))
  hex <- paste(hex, collapse = "")
  as.raw(strtoi(substring(hex, seq(1, nchar(hex), 2), seq(2, nchar(hex), 2)), 16L))
}

as_hex <- function(bytes) paste(as.character(bytes), collapse = "")

check <- function(label, ok, detail = "") {
  if (isTRUE(ok)) {
    cat(sprintf("PASS  %s\n", label))
  } else {
    cat(sprintf("FAIL  %s\n%s", label, detail))
    stop("test failed: ", label, call. = FALSE)
  }
}

expect_error_like <- function(label, expr, pattern) {
  msg <- tryCatch({ expr; NULL }, error = function(e) conditionMessage(e))
  check(label, !is.null(msg) && grepl(pattern, msg),
        sprintf("   expected an error matching %s, got: %s\n",
                pattern, if (is.null(msg)) "no error" else msg))
}
