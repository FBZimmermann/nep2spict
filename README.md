# nep2spict — SPiCT on Nephrops stocks with UWTV surveys

A generic test of the SPiCT surplus production model ([Pedersen & Berg 2017](https://doi.org/10.1111/faf.12174))
on the 16 ICES Category 1 *Nephrops* stocks that are assessed with underwater TV (UWTV) surveys
(WGNEPH; [ICES 2026](https://doi.org/10.17895/ices.pub.30477911)). Each stock is fitted with one
configuration derived from the accepted FU32 SPiCT assessment. The results are checked against
the SPiCT acceptance criteria and compared with the current UWTV/harvest-rate assessments and the
ICES advice.

**Exploratory. Not a basis for advice.**

## Quick start

```bash
export PATH="/c/Program Files/R/R-4.5.3/bin/x64:/c/Program Files/Quarto/bin:$PATH"
Rscript R/get_data.R          # download/cache SAG + ASD, build SPiCT inputs
Rscript R/create_stock_docs.R # create missing stock/<stock>/<stock>_spict.qmd
Rscript R/render_all.R        # render all stocks (parallel), then summary.qmd
```

R packages: spict (GitHub DTUAqua/spict), icesSAG, icesAdvice, tidyverse, patchwork, kableExtra,
here, jsonlite, rlang.

## Structure

- `data/`: `config/stocks.csv` (per-stock settings with sources), `sag/`, `asd/` (cached ICES
  downloads), `input/`, `spict/<stock>/` (cached fits and diagnostics), `summary/`
- `R/`: settings, data extraction, SPiCT functions, run scripts
- `knowledge/`: background on the stocks, data quirks, SPiCT conventions, acceptance criteria,
  decision log
- `skills/`: agent skills for data, running, reviewing and comparing
- `stock/`: one folder per FU, each with a Quarto document that runs and reports the assessment
- `summary.qmd`: comparison across FUs

## Data

Public ICES data only: Stock Assessment Graphs via [icesSAG](https://github.com/ices-tools-prod/icesSAG)
and the Advice and Scenarios Database API.
