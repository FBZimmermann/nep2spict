---
name: nephrops-sag-data
description: Extract, cache and check ICES SAG (icesSAG) and ASD advice data for Nephrops UWTV stocks and turn them into SPiCT inputs (dead-removal catch, UWTV index with log-scale SE, stdevfac multipliers). Use when refreshing data for a new assessment year, adding a stock, or when input numbers look wrong.
---

# Nephrops SAG data → SPiCT inputs

Read first: `knowledge/data_sources.md` (SAG field meanings and quirks) and
`knowledge/wgneph_stocks.md` (which stocks, discard survival, timing).

## Steps

1. **Stock table.** `data/config/stocks.csv` holds one row per stock: SAG key(s), component rule
   (`single` or `sum_index`), discard survival and its source, survey timing and its source,
   optional overrides (`catch_start`, `bkfrac_median`, `bkfrac_sd`). Put the source of every value
   in the row. New assessment year: look up the new keys with
   `icesSAG::getListStocks(<year>)` (filter `^nep`). FU 13 has one key per component.
2. **Year.** Set `settings$sag_year` and `settings$advice_year` in `R/setup.R`.
3. **Download.** `Rscript R/get_data.R` (add `--refresh` to bypass the cache). It caches raw
   records in `data/sag/<year>/` and `data/asd/<year>/` and writes `data/input/<stock>_input.rds`.
4. **Check, every time** (a silent join failure shows up as a plausible-looking number, not as an error):
   - The printed overview: catch and index year ranges, number of imputed discard years, mean CV,
     and `btrigger_units_ok` (index / MSY Btrigger median in 0.1–10).
   - Landings against the WGNEPH chapter table for the last 2–3 years.
   - SAG `catches`, where present, should equal landings + discards (total discards).
   - No gaps in the catch series (`build_stock_input()` stops on gaps).
   - For `sum_index` stocks, component landings are identical (a warning is issued if not) and
     the index is NA in years where any component was not surveyed.
5. **Record.** Add data issues to `knowledge/data_sources.md` (quirks) or the stock's `notes`
   column. Dated decisions go in `knowledge/decisions.md`.

## Traps

- SAG `discards` are **total** discards. Dead discards = discards × (1 − survival).
- SAG units labels are unreliable. Trust the within-stock consistency check, not the label.
- CI definition is `2*sd` or `95%`; `clean_sag_summary()` picks z accordingly.
- Do not change discard survival or survey timing silently. They change the inputs, so all
  cached fits for that stock are invalidated (the cache key includes the input).
- UWTV CVs (3–14 %) measure sampling precision only. Do not use them as total observation error.
