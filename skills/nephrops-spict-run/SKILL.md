---
name: nephrops-spict-run
description: Run, rerun or update the SPiCT assessment of one or all Nephrops FUs in this project — configure priors and settings, render stock/<stock>/<stock>_spict.qmd (fit, OSA/process residuals, retro, hindcast, check.ini, sensitivity, forecast), manage caches, and verify the outputs. Use for "run FU 7", "rerun everything", "change the r prior", or a new assessment year.
---

# Run a Nephrops SPiCT assessment

Read first: `knowledge/spict_conventions.md` (configuration and why) and
`knowledge/acceptance_criteria.md`. For the SPiCT API, check the installed source
(`args(spict::manage)`, `vignette("spict_guidelines", "spict")`) rather than memory.

## Layout

- `R/setup.R`: global settings and priors. `data/config/stocks.csv`: per-stock settings.
- `R/spict_functions.R`: `make_spict_inp()`, `fit_spict_safe()`, `acceptance_checks()`,
  `run_management()`, `run_sensitivity()`, `make_stock_summary()`.
- `stock/_template/_spict_body.qmd`: the shared document body. `stock/<stock>/<stock>_spict.qmd`:
  params and stock notes, which include the body. Generate missing stock documents with
  `Rscript R/create_stock_docs.R` (it never overwrites).
- Caches: `data/spict/<stock>/{fit,retro,hindcast,checkini,sensitivity,management,fit_generic}.rds`, each stored
  with the `inp_key()` hash of its input. A stale cache is recomputed automatically.
- Output for the summary: `data/summary/<stock>_summary.rds`.
- **The cache key covers the inputs (data, priors, settings, spict version), not the code** (except `sensitivity.rds`, whose key also hashes `run_sensitivity()` and `sens_row()`).
  After editing a function that changes how a cached object is computed (e.g. `run_sensitivity()`,
  `fit_spict_safe()`), delete the affected `data/spict/<stock>/*.rds` or set the matching
  `run_*` parameter to `true`. Functions that only post-process cached objects
  (`acceptance_checks()`, `make_stock_summary()`) need only a re-render.
- Cached fits have the full joint covariance (`$cov`) removed (`slim_fit()`), which cuts about
  80 MB per fit. `get.cov()` and `calc.process.resid()` therefore do not work on cached
  objects. Process residuals are computed before caching.

## Run

```bash
export PATH="/c/Program Files/R/R-4.5.3/bin/x64:/c/Program Files/Quarto/bin:$PATH"
Rscript R/get_data.R                       # inputs (cached)
quarto render stock/nep.fu.7/nep.fu.7_spict.qmd   # one stock (~10-15 min cold, ~1 min cached)
Rscript R/render_all.R                      # all stocks in parallel, then summary.qmd
```

Renders are slow cold: about 55 fits per stock, because process residuals, retro (5), hindcast
(5), check.ini (30) and 14 sensitivity runs each refit the model. Run them in the background with a
log and tell the user where the log is (`data/spict/<stock>/render.log`).

## Changing the configuration

- Generic priors go in `settings` in `R/setup.R`. Stock overrides go in `stocks.csv`
  (`bkfrac_median`, `bkfrac_sd`, `catch_start`). Record every change and its reason in
  `knowledge/decisions.md`, with the date.
- **Do not tune priors until the diagnostics pass.** A model that passes because `logr` was
  adjusted until it did is not evidence about the stock (spict-wise). Change a prior only for a
  reason external to the fit (life history, fishery history), then report the before/after
  difference.
- The production shape stays fixed at Schaefer; estimating `n` is a sensitivity run only.
- Changing `stdevfac`: keep the mean at 1 (`make_spict_inp()` renormalises).

## Verify (rendering is not verification)

After a render:

1. The HTML exists and the log has no error.
2. Read `data/summary/<stock>_summary.rds`: convergence, the acceptance table, no NA in
   `status`, plausible `params` (r 0.1–2, BMSY/K = 0.5 with n fixed), `advice$ices_advice`
   present.
3. Cross-check one number independently, e.g. refit `make_spict_inp(input)` in a fresh R session
   and compare `get.par("logBBmsy", fit)` at the last index time with the summary.
4. Report to the user: convergence, which criteria failed and by how much, Mohn's rho, MASE,
   status, the SPiCT vs ICES advice ratio, and anything surprising, such as a status flip across
   sensitivity runs.
