# Download and cache ICES data: SAG summary tables and reference points (icesSAG) and the
# published catch advice (ICES Advice and Scenarios Database, ASD web service).
# Raw responses are cached under data/sag/<year>/ and data/asd/<year>/ so that renders are
# reproducible offline and do not depend on later SAG edits.

sag_cache_dir <- function(year) {
  d <- path_data("sag", year)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

# Fetch (or read cached) SAG summary table and reference points for one assessment key.
get_sag_record <- function(key, year, refresh = FALSE) {
  f <- file.path(sag_cache_dir(year), paste0("sag_", key, ".rds"))
  if (file.exists(f) && !refresh) return(readRDS(f))
  rec <- list(
    key       = key,
    summary   = icesSAG::getSummaryTable(key),
    refpts    = icesSAG::getFishStockReferencePoints(key),
    retrieved = Sys.time(),
    icesSAG   = as.character(packageVersion("icesSAG"))
  )
  if (!is.data.frame(rec$summary) || nrow(rec$summary) == 0)
    stop("Empty SAG summary table for assessment key ", key)
  saveRDS(rec, f)
  rec
}

# Stock list for a year (cached), restricted to Nephrops.
get_sag_stocklist <- function(year, refresh = FALSE) {
  f <- file.path(sag_cache_dir(year), "stocklist_nep.rds")
  if (file.exists(f) && !refresh) return(readRDS(f))
  sl <- icesSAG::getListStocks(year) |> filter(grepl("^nep", StockKeyLabel))
  saveRDS(sl, f)
  sl
}

# Published ICES advice record (advised catch for the following year) from the ASD API.
# Endpoint verified 2026-11-21: https://asd.ices.dk/api/getAdviceViewRecord?stockcode=&year=
get_asd_advice <- function(stock, year, refresh = FALSE) {
  d <- path_data("asd", year)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  f <- file.path(d, paste0("asd_", stock, ".rds"))
  if (file.exists(f) && !refresh) return(readRDS(f))
  url <- sprintf("https://asd.ices.dk/api/getAdviceViewRecord?stockcode=%s&year=%d", stock, year)
  rec <- tryCatch(jsonlite::fromJSON(url), error = function(e) {
    warning("ASD request failed for ", stock, ": ", conditionMessage(e)); NULL
  })
  if (!is.null(rec) && length(rec) > 0) {
    rec <- as.data.frame(rec)
    rec$retrieved <- Sys.time()
    saveRDS(rec, f)
  }
  rec
}

# Download everything needed for the stocks in data/config/stocks.csv.
download_all <- function(stocks = read_stock_table(), year = settings$sag_year, refresh = FALSE) {
  get_sag_stocklist(year, refresh)
  for (i in seq_len(nrow(stocks))) {
    keys <- as.integer(strsplit(stocks$sag_keys[i], ";")[[1]])
    for (k in keys) get_sag_record(k, year, refresh)
    get_asd_advice(stocks$stock[i], year, refresh)
    # Previous year's advice, for "change from previous advice"
    get_asd_advice(stocks$stock[i], year - 1, refresh)
  }
  invisible(TRUE)
}
