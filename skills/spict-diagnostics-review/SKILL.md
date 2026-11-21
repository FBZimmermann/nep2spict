---
name: spict-diagnostics-review
description: Judge whether a SPiCT fit is acceptable — the ICES/spict 7-point checklist (convergence, finite variances, OSA residuals, retro/Mohn's rho, BMSY/K, CI order of magnitude, check.ini) plus hindcast MASE, process residuals, prior-vs-posterior and sensitivity — and write the verdict with one sentence per check. Use when reviewing a stock document, deciding acceptance, or explaining why a fit fails.
---

# Review SPiCT diagnostics

Adapted from spict-wise (`spict-model`, `knowledge/diagnostics.md`) and the spict guidelines.
The criteria and thresholds used in this project, with their sources, are in
`knowledge/acceptance_criteria.md`. Read it before judging.

## Procedure

For each check, give the number, the threshold, the verdict, and one sentence. A diagnostics
section with plots and no verdicts has not done its job.

1. **Convergence / finite variances.** Non-zero convergence: stop. Nothing downstream is
   meaningful. Non-finite SDs usually mean an unidentified parameter (often q with sdi, or K with r).
2. **OSA residuals.** Name the series (C = catch, I1 = index) and the test that fails.
   - Autocorrelation in index residuals: check for a survey change (month, area, method) before
     blaming the model. FU 9 moved from August to June, FU 23-24 changed season 2014–2016.
   - Catch-residual autocorrelation often reflects imputed discards (blocks of years with a
     constant discard ratio).
   - Normality failures from one outlier year: identify the year.
3. **Retrospective.** Report Mohn's rho for B/BMSY and F/FMSY against both bars, and look at the
   plot: are peels inside the base-run CI? Does a single peel drive the pattern (e.g. the
   assessment-year survey point)?
4. **BMSY/K.** With n fixed at 2 this is exactly 0.5 and passes by construction. Say so rather
   than treating it as evidence.
5. **CI width.** log10(upper/lower) of the 95 % CI. Wide CIs with short UWTV series are expected.
   Note which of B/BMSY or F/FMSY drives it.
6. **check.ini.** Any converged trial with distance > 0.01 means multiple optima. Report how many.
7. **Hindcast MASE** (supplementary): above 1 means no predictive skill relative to persistence.
8. **Prior vs posterior.** sd_ratio > 0.9: the data are uninformative about that parameter, so
   say the estimate is the prior. |shift| > 2: the data pull against the prior.
9. **Process residuals.** Runs of same-signed B innovations mean the production function cannot
   follow the index (often r constrained too tightly).
10. **Sensitivity.** Does terminal status (B vs 0.5 BMSY, F vs FMSY) change across defensible
    alternatives? If yes, the assessment cannot carry advice even if the seven checks pass.

## Verdict wording

- "Accepted by the checklist" requires all seven checks to pass. Never round a near-miss up.
- If a check fails and the analysis continues, state which, by how much, and what it means for
  the weight of the results.
- Distinguish a failure of the model from a failure of the data (e.g. short index, abundance not
  biomass). They lead to different remedies (benchmark vs not suitable for SPiCT).
