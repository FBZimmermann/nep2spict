# nep2spict — instructions for AI agents

Generic test of the SPiCT surplus production model on the ICES Category 1 *Nephrops* stocks that
are assessed with UWTV surveys (16 FUs, WGNEPH). It compares SPiCT with the current UWTV/harvest-rate
assessments and advice. This is exploratory work, **not** an advice basis. Project lead: Fabian
Zimmermann (IMR).

## Start of work

1. Read `knowledge/MEMORY.md` (index of background, conventions, decisions) before changing
   anything.
2. Use the project skills in `skills/` (they are not installed globally; read the `SKILL.md`
   directly):
   - `skills/nephrops-sag-data/`: data extraction and input checks
   - `skills/nephrops-spict-run/`: configure, run and verify stock assessments
   - `skills/spict-diagnostics-review/`: judge acceptance
   - `skills/nephrops-spict-compare/`: the cross-FU summary and comparison with ICES

## Layout

| Folder | Contents |
|---|---|
| `data/` | `config/stocks.csv` (per-stock settings), `sag/` and `asd/` (cached ICES downloads), `input/` (SPiCT inputs), `spict/<stock>/` (cached fits and diagnostics, render logs), `summary/` (per-stock summary objects) |
| `R/` | `setup.R` (settings, priors), `sag_data.R`, `prepare_inputs.R`, `spict_functions.R`, scripts `get_data.R`, `create_stock_docs.R`, `render_all.R` |
| `knowledge/` | Background, conventions, acceptance criteria, data quirks, decision log, bibliography |
| `skills/` | Agent skills for this project |
| `stock/` | `_template/_spict_body.qmd` (shared body) and one folder per FU with its `<stock>_spict.qmd` |
| `summary.qmd` | Cross-FU comparison (reads only `data/summary/`) |

## Rules

- R and Quarto are not on the default PATH:
  `export PATH="/c/Program Files/R/R-4.5.3/bin/x64:/c/Program Files/Quarto/bin:$PATH"`.
- A successful render is not verification. Inspect the saved summary objects and cross-check a
  number in a fresh session (`skills/nephrops-spict-run`).
- Configuration changes (priors, survival, timing, catch start, criteria thresholds) are the
  project lead's decisions. Propose them, then record the decision with its date and reason in
  `knowledge/decisions.md`.
- Never type result numbers into prose. Use inline R from the summary objects.
- Cached fits are keyed on their input (`inp_key()`). Do not bypass the key check.
- SAG/ASD data are public ICES data. The project contains no confidential IMR data; keep it that
  way (do not copy FU32 survey or logbook data in).
