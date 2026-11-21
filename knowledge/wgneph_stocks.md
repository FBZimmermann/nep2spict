# Nephrops stocks with UWTV surveys (WGNEPH)

Source: ICES (2026). Working Group for the Assessment of *Nephrops* Stocks (WGNEPH). ICES
Scientific Reports 7:51. <https://doi.org/10.17895/ices.pub.30477911> (the 2025 meeting; per-FU
chapters are separate PDFs on the figshare record, files 01–31). Data for the models come from the
2026 SAG records (assessment year 2026, advice for 2027), which add the 2026 UWTV survey point.

## Which stocks are in scope

WGNEPH 2025 (section 1.2) groups the assessments into:

| ICES category | Method | Stocks |
|---|---|---|
| 1 | UWTV abundance + harvest rate (HR) relative to a per-recruit FMSY proxy | FU 3-4, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, 19, 20-21, 22, 23-24 |
| 2 | SPiCT (status and short-term forecast) | FU 25, 26-27, 32 |
| 3 | rfb rule | FU 28-29, 30 (UWTV, Gulf of Cadiz), 31 (downgraded from SPiCT in 2025) |
| 4–5 | Survey trends / catch-based | FU 5, 10, 33, 34, outside-FU stocks |

**This project models the 16 Category 1 stocks.** They are the stocks that have both a UWTV
survey and a UWTV-based assessment against which SPiCT can be compared. Excluded on purpose:

- FU 30 (Cadiz): has a UWTV survey but Category 3 advice and no 2026 SAG record (biennial).
- FU 10 (Noup) and FU 34 (Devil's Hole): surveyed intermittently, Category 4, no FMSY proxy or
  MSY Btrigger in SAG.
- FU 32: SPiCT is already the accepted assessment, with a trawl-survey index (no UWTV). It is the
  configuration template for this project (local project `NephropsFU32`).
- FU 31: downgraded from SPiCT in 2025 because Mohn's rho for B/BMSY and F/FMSY exceeded the
  accepted range and the confidence intervals were wide. A useful precedent for how WGNEPH applies
  the acceptance criteria.

## Category 1 assessment method, in brief

- **Stock size** is the UWTV abundance estimate (burrow density × area, bias-corrected) in
  numbers. SAG stores it in the `SSB` field with the label `UWTV_index`. The units label in SAG is
  not reliable across stocks (e.g. "thousands" next to MSY Btrigger = 540 000).
- **Fishing pressure** is the harvest rate: dead removals in numbers / UWTV abundance, in %. SAG
  stores it in the `F` field.
- **FMSY proxy** is a harvest rate from per-recruit analysis: F0.1, F35%SPR or Fmax, chosen per FU
  from sex-specific and combined per-recruit curves (WGNSSK 2010 framework, WKMSYRef4 2016
  revisions). Examples: FU 7 7.5 % (F0.1), FU 8 16.3 % (Fmax), FU 9 11.8 % (F35%SPR), FU 13 15.1 %
  Clyde / 12.0 % Jura (the WGNEPH 2025 chapter text; SAG 2026 lists 15.1 % for both components).
- **MSY Btrigger** is in most FUs the lowest observed UWTV abundance (Bloss), i.e. a
  precautionary trigger, **not** a fraction of BMSY. FU 3-4 and FU 23-24 have no stock-size
  reference point.
- **Advice** for year y+1 = FMSY HR × abundance in y (the survey year), converted to tonnes with
  recent mean weights and discard rates. The advised catch is total catch, including the
  surviving discards.

## Discard survival assumptions (from the WGNEPH 2025 chapters)

| FU | Survival | Note |
|---|---|---|
| 3-4 | 25 % | High-survivability exemption since 2017 |
| 6 | 15 % | 2013 benchmark |
| 7, 8, 9, 11, 12, 13 | 25 % | Creel discards assumed 100 % survival in FUs 11–13 |
| 14, 15 | 10 % | IBPNeph 2015 / WKNEPH |
| 16 | – | No discard series in SAG; dead discards set to zero |
| 17, 19, 20-21, 22 | 25 % | Irish trials suggest up to 64 % |
| 23-24 | 50 % | Revised; abundance recalculated accordingly |

Values are in `data/config/stocks.csv` with their source.

## UWTV survey timing (used for `timeI`)

Survey months are recorded in `data/config/stocks.csv`. Values marked "assumed" were not found in
the chapter text and need checking against the stock annexes. The model's Euler step is 1/16 year,
so timing errors of one month matter little.

## Stock notes relevant for SPiCT

- **Short UWTV series**: FU 3-4 (2017–), FU 23-24 (2016–), FU 16 (2012–), FU 20-21 (2013–). In
  these stocks the index has little contrast, so the priors will drive the estimates.
- **Discard series start late** in FU 6 (2000), FU 17 (2002), FU 19 (2006) and FU 20-21 (2012).
  Earlier discards are imputed from the ratio in the first five years with data, and those years
  get higher catch uncertainty (`stdevfacC`).
- **FU 13** has two UWTV components (Firth of Clyde, Sound of Jura) that share FU-level catches and
  HR. The SPiCT index is the summed abundance in years where both components were surveyed.
- **FU 6** has empty SAG rows to 2029, which are dropped.
- **FU 23-24**: the survey season changed (September 2014, July 2015, April–May from 2016).
