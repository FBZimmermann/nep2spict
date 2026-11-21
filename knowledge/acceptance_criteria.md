# SPiCT acceptance criteria used in this project

Primary source: the SPiCT guidelines shipped with the package
(`vignette("spict_guidelines", package = "spict")`, spict 1.3.9; also
<https://github.com/DTUAqua/spict/blob/master/spict/vignettes/spict_guidelines.Rmd>), section
"Checklist for the acceptance of a SPiCT assessment". WKBMSYSPiCT3 (ICES 2024) applied the same
seven points, e.g. "credible interval width for relative status less than 1 order of magnitude".

| # | Criterion | Implementation (`acceptance_checks()` in `R/spict_functions.R`) | Pass if |
|---|---|---|---|
| 1 | Convergence | `fit$opt$convergence` | `== 0` |
| 2 | Finite variance parameters | `all(is.finite(fit$sd))` | TRUE |
| 3 | No violation of model assumptions (OSA residuals) | `calc.osa.resid()`; bias (t-test), autocorrelation (Ljung–Box), normality (Shapiro–Wilk) for catch and index, from `fit$diagn` | all p > 0.05 |
| 4 | Consistent retrospective pattern | `retro(fit, 5)`, `mohns_rho()` for B/BMSY and F/FMSY | inside [−0.22, 0.30]; [−0.15, 0.20] reported as well |
| 5 | Realistic production curve | `calc.bmsyk()` | 0.1 < BMSY/K < 0.9 |
| 6 | Assessment uncertainty | 95 % CI of terminal B/BMSY and F/FMSY from `calc.om()`, width as `log10(upper/lower)` | < 1 order of magnitude |
| 7 | Initial values do not influence estimates | `check.ini(fit, 30)`, maximum relative deviation of converged trials' estimates from the base | all < 1 % |
| (8) | Predictive skill (supplementary) | `hindcast()`, `calc.mase()` | MASE < 1 |

## Choices and their reasons

- **Mohn's rho bar.** The guidelines ask for "no tendency of consistent under- or
  overestimation" and peels inside the base-run CI, with no numeric bar. The usual numeric bars come
  from Hurtado-Ferro et al. (2015), <https://doi.org/10.1093/icesjms/fsu198>: [−0.15, 0.20] for
  longer-lived and [−0.22, 0.30] for shorter-lived species. *Nephrops* has moderate longevity (about
  10 years or more). The verdict column uses the shorter-lived bar and a second column reports the
  longer-lived one. This is a judgement call; review it with the working group.
- **Order of magnitude.** spict's `calc.om()` reports `|floor(log10(upper)) - floor(log10(lower))|`,
  which depends on where the bounds fall relative to powers of ten (0.95–1.05 counts as 1 order).
  The verdict uses `log10(upper/lower) < 1` instead, and the summary also reports `calc.om()`.
  This differs from the FU32 template, which tested `CI range / estimate < 10`.
- **check.ini threshold.** The guidelines say the estimates "should be the same". spict's
  `resmat` column `Distance` is the Euclidean distance between trial and base estimates on the
  **natural** scale, so K and MSY in tonnes dominate it. An absolute threshold (spict-wise uses
  0.01; the FU32 template used > 1 and > 1000) is scale-dependent. In FU 7, 24 of 30 trials had
  distance 0.02–0.21, which is 0.23 t on K = 59 400 t (relative 4 × 10⁻⁶): the same optimum. The
  criterion here is the maximum relative deviation of any estimated parameter from the base run,
  below 1 % (`ini_relative_deviation()`, `settings$ini_rel_tol`).
- **OSA residuals.** The guidelines note that "slight violations ... do not necessarily invalidate
  model results". The table reports the count of failed tests and the minimum p, and the stock
  document comments on which series and test failed. Lag-1 autocorrelation in the index
  residuals can come from survey-design changes (e.g. survey month) rather than the model.

## Beyond the checklist

- **Prior vs posterior** (`prior_posterior()`): the posterior/prior SD ratio and the shift of the
  posterior median in prior SDs. A ratio above about 0.9 means the data are uninformative about that
  parameter.
- **Process residuals**: a run of same-signed biomass innovations means the production function
  cannot follow the index.
- **Sensitivity** (`run_sensitivity()`): r prior, B0/K prior, sdi prior, production shape, biomass
  vs abundance index, catch definition and length of the catch series. A conclusion on status
  (above/below BMSY, F above/below FMSY) that flips across defensible alternatives is a reason not
  to accept the assessment, even when the seven checks pass.

## Precedent within WGNEPH

FU 31 was downgraded from Category 2 (SPiCT) to Category 3 in 2025: Mohn's rho for both B/BMSY and
F/FMSY outside the accepted range and wide CIs (WGNEPH 2025, section 1.2).
