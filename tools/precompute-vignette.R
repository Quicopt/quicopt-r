# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: (c) 2026 Tim Bode, PGI-12, Forschungszentrum Jülich

# Re-knit the pre-computed vignette: executes vignettes/stochastic.Rmd.orig —
# including its live solves against the service — and writes the fully baked
# vignettes/stochastic.Rmd that the package ships. Run from the package root
# before a release; the shipped .Rmd executes nothing, so checks need no
# network.
knitr::knit("vignettes/stochastic.Rmd.orig", output = "vignettes/stochastic.Rmd")
