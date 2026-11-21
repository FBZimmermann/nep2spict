---
name: nephrops-spict-compare
description: Build or interpret the cross-FU comparison (summary.qmd) — acceptance across stocks, parameter estimates, stock trends, agreement of SPiCT status and trends with the ICES Category 1 UWTV/harvest-rate assessment, and SPiCT vs ICES catch advice. Use when updating summary.qmd, answering "how does SPiCT compare with the current assessments", or drafting conclusions.
---

# Compare SPiCT with the Category 1 assessments

Read `knowledge/spict_conventions.md`, section "Known structural mismatches", first.

## Inputs

`summary.qmd` reads only `data/summary/<stock>_summary.rds`. It never refits. Each object holds
`meta`, `checks`, `residuals`, `ci`, `params`, `priors` (prior vs posterior), `status`, `mohn`,
`timeseries` (SPiCT ratios joined with the Category 1 series), `mantab`, `advice`, `sensitivity`.
If the summary needs a new quantity, add a field in `make_stock_summary()` and rerender the stock
documents. Do not load fits in the summary.

## How to compare (and how not to)

- **Reference points differ in kind.** MSY Btrigger is mostly Bloss, not 0.5 BMSY, and the FMSY
  proxy is a per-recruit HR. Compare **classifications** (above/below) and **trends** (correlation
  of log series over survey years), not the size of the ratios. Never write "SPiCT agrees with
  ICES that B/BMSY = x".
- **Catch advice.** ICES Category 1 advice is total catch including surviving discards. SPiCT
  catch is dead removals. Compare the `spict_catch_total` conversion with `ices_advice`.
- **Weight by acceptance.** An advice ratio from a non-accepted assessment is not evidence about
  the stock, only about the configuration. Keep accepted and non-accepted stocks apart in
  statements.
- **Correlation is not validation.** SPiCT B/BMSY is fitted to the UWTV index, so a high
  correlation with UWTV abundance is expected by construction. The informative comparisons are
  F/FMSY vs HR (partly independent: HR uses catch numbers) and disagreements in status.
- Selection: the 16 stocks are not a random sample of Nephrops stocks. Do not generalise beyond
  "Category 1 UWTV stocks, generic configuration".

## Writing conclusions

Derive counts and medians in code (inline R), never type them. Each conclusion sentence in the
document should name the table or figure it rests on. Flag what would change the conclusions:
stock-specific B0/K priors, a biomass index, and longer UWTV series.
