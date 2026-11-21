# Create one assessment document per stock in stock/<stock>/<stock>_spict.qmd.
# Each document holds the stock's run settings and stock-specific notes and includes the shared
# body stock/_template/_spict_body.qmd. Existing documents are never overwritten (they may carry
# stock-specific edits); pass overwrite = TRUE explicitly to regenerate.
# Run from the project root:  Rscript R/create_stock_docs.R

source(here::here("R", "setup.R"))

create_stock_doc <- function(cfg, overwrite = FALSE) {
  dir <- file.path(proj_root, "stock", cfg$stock)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  f <- file.path(dir, paste0(cfg$stock, "_spict.qmd"))
  if (file.exists(f) && !overwrite) {
    message("Exists, not overwritten: ", f)
    return(invisible(f))
  }
  txt <- c(
    "---",
    sprintf('title: "SPiCT assessment of *Nephrops* in FU %s (%s)"', cfg$fu, cfg$area),
    'subtitle: "Exploratory test of SPiCT on a UWTV-assessed stock (not the basis of ICES advice)"',
    "date: today",
    "bibliography: ../../knowledge/references.bib",
    "params:",
    sprintf('  stock: "%s"', cfg$stock),
    "  refit: false            # true: refit even if a valid cached fit exists",
    "  run_retro: false",
    "  run_hindcast: false",
    "  run_checkini: false",
    "  run_sensitivity: false",
    "format:",
    "  html:",
    "    embed-resources: true",
    "    toc: true",
    "    toc-depth: 2",
    "    number-sections: true",
    "    code-fold: true",
    "    code-tools: true",
    "execute:",
    "  message: false",
    "  warning: false",
    "---",
    "",
    "::: {.callout-note}",
    "## Stock-specific notes",
    "",
    sprintf("%s", ifelse(is.na(cfg$notes) | cfg$notes == "", "None recorded.", cfg$notes)),
    "",
    "Stock settings (discard survival, survey timing, catch start, B0/K prior overrides) are in",
    "`data/config/stocks.csv`. Generic settings are in `R/setup.R`. Cached fits are reused only",
    "when their input key matches; set a `run_*` parameter to `true` to force a rerun.",
    ":::",
    "",
    "{{< include ../_template/_spict_body.qmd >}}",
    ""
  )
  writeLines(txt, f)
  message("Created: ", f)
  invisible(f)
}

stocks <- read_stock_table()
for (i in seq_len(nrow(stocks))) create_stock_doc(stocks[i, ])
