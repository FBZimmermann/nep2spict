# Project setup: packages, paths, global settings and plotting defaults.
# Sourced at the top of every script and Quarto document.

suppressPackageStartupMessages({
  library(spict)
  library(icesSAG)
  library(icesAdvice)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(readr)
  library(stringr)
  library(ggplot2)
  library(patchwork)
  library(knitr)
  library(kableExtra)
})

# ---- Paths --------------------------------------------------------------------------------------
proj_root <- here::here()
path_data <- function(...) file.path(proj_root, "data", ...)
path_R    <- function(...) file.path(proj_root, "R", ...)

# ---- Global settings ----------------------------------------------------------------------------
# sag_year:        assessment year of the SAG records used as model inputs
# advice_year:     year the ICES advice applies to (TAC year of the SPiCT forecast)
settings <- list(
  sag_year        = 2026,
  advice_year     = 2027,
  dteuler         = 1/16,
  # Priors (FU32 template; see knowledge/priors.md for sources and deviations)
  r_median        = 0.52,  r_sd   = 0.25,   # Nephrops meta-analysis via SeaLifeBase (FU32 template)
  bkfrac_median   = 0.50,  bkfrac_sd = 0.50, # generic, weakly informative (FU32 used 0.75/0.25)
  sdb_median      = 0.15,  sdb_sd = 0.20,   # FU32 template
  sdc_median      = 0.10,  sdc_sd = 0.25,   # FU32 template
  sdi_sd          = 0.50,                   # median = mean UWTV CV of the stock; FU32 used sd 0.25
  # Catch-series rules
  catch_start_lag = 20,    # catch series starts at most this many years before the first index year
  sdfacC_imputed  = 1.5,   # relative catch uncertainty in years with imputed discards (before normalising)
  discard_ref_n   = 5,     # first n years with discard data used to impute earlier discard ratios
  # ICES conventions for SPiCT advice
  btrigger_bmsy   = 0.5,
  blim_bmsy       = 0.3,
  flim_fmsy       = 1.7,
  catch_fractile  = 0.35,
  # Diagnostics
  nretro          = 5,
  nhindcast       = 5,
  ncheckini       = 30,
  rho_bar_long    = c(-0.15, 0.20),  # Hurtado-Ferro et al. (2015), longer-lived
  rho_bar_short   = c(-0.22, 0.30),  # Hurtado-Ferro et al. (2015), shorter-lived
  om_max          = 1,               # 95 % CI of B/Bmsy and F/Fmsy spans < 1 order of magnitude
  ini_rel_tol     = 0.01             # check.ini: max relative deviation of estimates from base run
)

# ---- Stock table --------------------------------------------------------------------------------
read_stock_table <- function() {
  readr::read_csv(path_data("config", "stocks.csv"), show_col_types = FALSE,
                  col_types = readr::cols(.default = "c")) |>
    mutate(across(c(discard_survival, index_timing, catch_start, bkfrac_median, bkfrac_sd),
                  as.numeric))
}

# ---- Plot and table defaults --------------------------------------------------------------------
report_theme <- theme_light() + theme(
  text             = element_text(size = 11),
  strip.background = element_rect(fill = "white"),
  strip.text       = element_text(color = "black")
)

# Wraps a base-R plot call, reducing margins and suppressing "figure margins too large" so a
# document render never aborts on a small device (from the FU32 template).
safe_plot <- function(f, mar = c(3, 4, 2, 1)) {
  op <- par(no.readonly = TRUE)
  on.exit(par(op), add = TRUE)
  par(mar = mar)
  tryCatch(f(), error = function(e) {
    if (grepl("margins too large|figure region", conditionMessage(e), ignore.case = TRUE))
      invisible(NULL)
    else stop(e)
  })
}

fmt <- function(x, d = 2) formatC(x, format = "f", digits = d, big.mark = " ")
