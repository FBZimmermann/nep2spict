# Data sources and their quirks

## ICES Stock Assessment Graphs (SAG), via icesSAG

- Package: [icesSAG](https://github.com/ices-tools-prod/icesSAG) (CRAN 1.6.2 installed; GitHub
  1.6.6). No token is needed for published records.
- `getListStocks(year)` gives the assessment keys. 2026 keys for the stocks in scope are in
  `data/config/stocks.csv` (`sag_keys`; FU 13 has two keys, Clyde 25984 and Jura 25985).
- `getSummaryTable(key)`: columns used are `Year`, `landings`, `discards`, `catches`, `SSB`
  (UWTV abundance), `low_SSB`, `high_SSB`, `F` (harvest rate, %).
- `getFishStockReferencePoints(key)`: `MSYBtrigger` (index units), `FMSY` (HR %),
  `ConfidenceIntervalDefinition` (`"95%"` or `"2*sd"`).
- Raw responses are cached in `data/sag/<year>/sag_<key>.rds` with a retrieval timestamp.
  `Rscript R/get_data.R --refresh` re-downloads them.

### Quirks found (verified 2026-11-21 on the 2026 records)

- `catches` is empty for most stocks. Where it is filled (e.g. FU 23-24), it equals landings +
  **total** discards (2022: 2694 + 791 = 3485). SAG `discards` are therefore total discards, and
  dead discards have to be derived with the stock's discard survival.
- `stockSizeUnits` is inconsistent ("thousands", "billions", "Number of individuals"). MSY
  Btrigger is in the same units as `SSB` within a stock. `prepare_inputs.R` checks that the median
  of abundance / MSY Btrigger lies in 0.1–10; all 14 stocks with an MSY Btrigger pass.
- CIs are given as ±2 SD or 95 % (±1.96 SD) on the natural scale. The log-scale SE is
  `sqrt(log(1 + CV^2))` with `CV = (high - low) / (2 z) / est`.
- UWTV CVs are small (stock means 3–14 %). They measure station-sampling precision only, not the
  total observation error of the index (burrow occupancy, counting bias, edge effects, year-to-year
  changes in survey coverage).
- FU 6 has empty rows to 2029. FU 16 has no discards. In FU 13, both component records carry
  identical FU-level landings, discards and HR.

## ICES Advice and Scenarios Database (ASD)

- Endpoint: `https://asd.ices.dk/api/getAdviceViewRecord?stockcode=<stock>&year=<assessment year>`
  (verified 2026-11-21). It returns `adviceValue` (t), `adviceSentence`, `adviceDOI`,
  `adviceApplicableFrom`, `stockCategory`.
- The old `sg.ices.dk/adviceview/API` path returns 404.
- The 2026 records hold the advice for 2027. The 2025 records give the previous advice.
- Cached in `data/asd/<year>/asd_<stock>.rds`.

## WGNEPH report

- figshare record 30477911. The API (`https://api.figshare.com/v2/articles/30477911`) lists one
  PDF per chapter. The landing page returns HTTP 403 to scripted clients; the API and the
  `ndownloader` links work.
- The PDFs are not stored in the project. Re-download them from the API when needed.
