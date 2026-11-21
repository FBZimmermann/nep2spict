# SPiCT configuration and conventions

Merged from the FU32 template (NephropsFU32 `5_SPiCT_assessment.qmd` and
`R/spict_assessment_functions.R`) and spict-wise (`knowledge/spict.md`, version 0.2.13). Where the
two differ, the choice made here is stated. Implemented in `make_spict_inp()` in
`R/spict_functions.R`.

## Input

| Element | Convention | Origin |
|---|---|---|
| Catch | Dead removals in tonnes: landings + discards × (1 − survival) | FU32 |
| Index | UWTV abundance (numbers), scaled by its own mean | spict-wise (scaling); Category 1 basis |
| Index timing | `year + survey fraction` per stock (`stocks.csv`) | spict-wise. FU32 used `year` (= Jan 1) |
| `stdevfacI` | log-scale SE from the UWTV CI, divided by its mean | FU32, spict-wise |
| `stdevfacC` | 1 in years with observed discards, 1.5 in years with imputed discards, normalised to mean 1 | spict-wise pattern (ramp). FU32 used the catch/landings ratio |
| Catch series start | max(first landings year, first index year − 20), overridable | This project. The guidelines note that shortening the catch series to the index period can help |
| Assessment-year catch | Not entered. Index for the assessment year is entered | FU32 |
| Euler step | 1/16 year | FU32, spict default |

## Priors

| Parameter | Prior | Origin and status |
|---|---|---|
| n (shape) | fixed at 2 (Schaefer); `phases$logn = -1`, no prior on a fixed parameter | FU32, spict-wise. FU32 also set a tight prior; dropped because the parameter is fixed |
| r | lognormal, median 0.52 (mean-corrected), SD 0.25 | FU32: "SeaLifeBase meta-analysis of 37 *Nephrops* stocks, median 0.52 (95 % CI 0.34–0.78)". **Source not re-verified here.** Species-level, so applied to all FUs |
| B0/K | lognormal, median 0.5, SD 0.5 | Generic, weakly informative (spict guidelines examples). FU32 used 0.75/0.25 because of FU32's fishery history. Override per stock in `stocks.csv` |
| sdb | lognormal, median 0.15, SD 0.2 | FU32 code value (the FU32 text says median 0.2) |
| sdc | lognormal, median 0.1, SD 0.25 | FU32 |
| sdi | lognormal, median = stock's mean UWTV CV, SD 0.5 | FU32 used SD 0.25. Widened because the UWTV CV covers only part of the observation error (see `data_sources.md`) |
| alpha, beta | deactivated | FU32, spict-wise |

**Priors carried over from another stock are placeholders** (spict-wise). The r prior is
species-level and applies to all FUs. The B0/K prior is the one most likely to need a
stock-specific value, from the history of each fishery before the start of the catch series.

**Tuned stocks.** FU 12 and FU 3-4 use B0/K 0.75 (SD 0.25), because the generic prior does not
converge (`decisions.md`, 2026-11-21). This is tuning, flagged in `stocks.csv` column `tuned`.
Every prior override in `stocks.csv` triggers a refit with the generic configuration
(`generic_check()`, cache `fit_generic.rds`), stored in the summary object as `config`. A new
override set only to get convergence must also fill `tuned`, so the stock documents and the
summary flag it (callout, "†" in FU labels, "TUNED B0/K").

**Sensitivity runs** (`run_sensitivity()`): r prior ×0.5, ×1.5, SD ×2; B0/K 0.25 and 0.75; sdi
prior off, ×2 and ×3 the CV (×3 added at the project lead's request because UWTV CIs are too
narrow); n estimated; Fox shape; biomass index; catch including all discards; catch from the
first index year.

## Management (forecast)

- Intermediate year (assessment year): catch = last observed catch (status quo).
- Advice year (assessment year + 1): scenarios ICES MSY rule (35th percentile of the catch
  distribution, breakpoint 0.5 BMSY, limit 0.3 BMSY), F = FMSY, F = Fsq, F = 0. As in the FU32
  template.
- Risk: P(B < BMSY), P(B < Blim = 0.3 BMSY), P(B < 0.5 BMSY), P(F > FMSY), P(F > Flim = 1.7 FMSY),
  under a lognormal assumption (`spict_risk()`, from FU32 `spictRisk()`).
- For comparison with ICES advice (total catch including surviving discards), SPiCT's
  dead-removal catch is converted to total catch as `C_dead / (1 - d × s)`, with d the mean
  discard rate by weight over the last 3 years with observed discards and s the survival.

## Known structural mismatches with the Category 1 assessment

1. **Abundance vs biomass.** The spict guidelines say indices "should be in terms of biomass (not
   numbers)". The UWTV index counts burrows of all sizes, while the catch is in tonnes. Changes in
   mean size (recruitment pulses, MCRS changes) break proportionality. Sensitivity
   "Biomass index (N × mean weight)" uses mean weight of removals = dead removals (t) /
   (HR/100 × N). Caveats: catch mean weight is not population mean weight, and the derivation
   reuses the catch.
2. **Reference points differ in kind.** Category 1 MSY Btrigger is mostly Bloss (lowest observed
   abundance), and FMSY is a per-recruit HR proxy. SPiCT estimates production-model BMSY and FMSY.
   The status comparison therefore uses classifications (above/below) and trends (correlation of
   B/BMSY with abundance/MSY Btrigger), not equality of ratios.
3. **UWTV as an absolute index.** Category 1 treats UWTV abundance as absolute (bias-corrected).
   SPiCT treats it as relative (q estimated). The estimated q (with biomass in tonnes and the index
   in numbers) has no direct interpretation.

## Reading

- Pedersen, M.W. & Berg, C.W. (2017). A stochastic surplus production model in continuous time.
  *Fish and Fisheries* 18, 226–243. <https://doi.org/10.1111/faf.12174>
- Mildenberger, T.K., Berg, C.W., Pedersen, M.W., Kokkalis, A. & Nielsen, J.R. (2020). Time-variant
  productivity in biomass dynamic models on seasonal and long-term scales. *ICES Journal of Marine
  Science* 77, 174–187. <https://doi.org/10.1093/icesjms/fsz154>
- Hurtado-Ferro, F. et al. (2015). Looking in the rear-view mirror: bias and retrospective patterns
  in integrated, age-structured stock assessment models. *ICES Journal of Marine Science* 72,
  99–110. <https://doi.org/10.1093/icesjms/fsu198>
- spict-wise: <https://github.com/DeepWaterIMR/spict-wise> (version 0.2.13, 2026-11-04).
