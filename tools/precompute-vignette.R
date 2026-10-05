# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

# Re-knit the pre-computed vignettes: executes each vignettes/<name>.Rmd.orig —
# including its live solves against the service — and writes the fully baked
# vignettes/<name>.Rmd that the package ships. Run from the package root
# before a release; the shipped .Rmd files execute nothing, so checks need no
# network.
for (name in c("quicopt", "stochastic", "permutations"))
  knitr::knit(file.path("vignettes", paste0(name, ".Rmd.orig")),
              output = file.path("vignettes", paste0(name, ".Rmd")))
