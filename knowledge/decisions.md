# Decision log

Newest first. Each entry: date, decision, reason, who decided (agent proposal vs project lead).
Entries marked **[proposed]** are agent defaults that await review by the project lead.

## 2026-11-21: sdi prior x3 sensitivity run (project lead)

Added "sdi prior x3" (prior median 3 × mean UWTV CV, SD 0.5) to `run_sensitivity()`. Reason
(project lead): UWTV confidence intervals are typically too narrow because of methodological
flaws (they cover sampling variance only), so the realistic index error may be well above the
CV. The base configuration is unchanged. Results: `summary.qmd`, section "Index observation
error". The sensitivity cache key now includes the code of `run_sensitivity()` and `sens_row()`.

## 2026-11-21: sdi prior test (agent)

Base fits for FU 7, 8, 11, 15 (and FU 17 for one variant) were run with three index observation-error
settings: a prior centred on the mean UWTV CV (SD 0.5), no prior, and a prior with median
max(CV, 0.15). Terminal B/BMSY changed by at most 6 % (FU 15: 0.68 / 0.65 / 0.64) and F/FMSY by at
most 5 %. The estimated sdi was 1.5–3 times the sampling CV (FU 8: CV 0.09, sdi 0.15–0.17;
FU 11: CV 0.08, sdi 0.15–0.16; FU 15: CV 0.03, sdi 0.06–0.10). This confirms that UWTV CVs
understate total observation error. **Kept**: prior centred on the CV with SD 0.5; "sdi prior
off" and "sdi prior x2" stay as sensitivity runs. Test script and results:
scratchpad only (not kept). Rerun from `run_sensitivity()` if needed.

## 2026-11-21 — project set-up [proposed]

1. **Stocks**: the 16 Category 1 UWTV stocks from WGNEPH 2025. FU 30, 10 and 34 are excluded
   (see `wgneph_stocks.md`).
2. **Data year**: SAG assessment year 2026 (the latest published, advice for 2027), which includes
   the 2026 UWTV survey. The WGNEPH 2025 report is the background source. To use the 2025
   assessments instead, set `settings$sag_year <- 2025` and `advice_year <- 2026`, and update the
   SAG keys in `stocks.csv` (2025 keys: `getListStocks(2025)`).
3. **FU 13**: summed Clyde + Jura abundance as one FU index, with FU-level catch. Alternatives: two
   indices in SPiCT (separate q), or Clyde only.
4. **Catch** = landings + dead discards (stock-specific survival). Discards before the first
   discard year are imputed from the first five years with data, with 1.5 × catch uncertainty.
5. **Catch start** = max(first landings year, first index year − 20).
6. **Priors**: r from the FU32 template (species-level). B0/K generic 0.5 (SD 0.5) for all
   stocks, in place of FU32's 0.75/0.25. sdi prior centred on the mean UWTV CV with SD 0.5. See
   the sdi test below.
7. **Index timing**: survey month from the WGNEPH chapters where stated, otherwise assumed. See
   `stocks.csv`.
8. **Mohn's rho verdict** with the shorter-lived bar [−0.22, 0.30]; the longer-lived bar is also
   reported.
9. **Forecast**: intermediate-year catch = last observed dead removals. Advice comparison
   converts SPiCT dead removals to the ICES advice type (total catch or, for FU 23-24 in 2026,
   landings).

## Open questions for the project lead

- Stock-specific B0/K priors from each fishery's history (largest expected influence).
- Verify the r prior source (SeaLifeBase *Nephrops* meta-analysis, as cited in FU32).
- Survey timing for FU 3-4, 7, 14, 16, 17, 19, 20-21, 22 (assumed).
- Whether the abundance index should be replaced by a biomass index as the base case (the spict
  guidelines ask for biomass). A proper biomass index needs UWTV length or weight data, which are
  not in SAG.
