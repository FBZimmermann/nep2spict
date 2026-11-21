# Download and cache all ICES inputs (SAG + ASD) for the stocks in data/config/stocks.csv,
# then build the SPiCT input tables in data/input/.
# Run from the project root:  Rscript R/get_data.R            (use cache)
#                             Rscript R/get_data.R --refresh  (re-download)

source(here::here("R", "setup.R"))
source(path_R("sag_data.R"))
source(path_R("prepare_inputs.R"))

refresh <- "--refresh" %in% commandArgs(trailingOnly = TRUE)
stocks  <- read_stock_table()

download_all(stocks, settings$sag_year, refresh = refresh)

inputs <- lapply(stocks$stock, function(s) {
  message("Preparing input: ", s)
  build_stock_input(s, stocks = stocks)
})
names(inputs) <- stocks$stock

# Print a compact overview for checking
overview <- bind_rows(lapply(inputs, function(x) x$meta))
print(as.data.frame(overview))
