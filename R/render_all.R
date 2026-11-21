# Render all stock assessment documents (in parallel) and then the summary document.
# Run from the project root:
#   Rscript R/render_all.R                 # all stocks, then summary.qmd
#   Rscript R/render_all.R nep.fu.7 nep.fu.8   # selected stocks only, then summary.qmd
#   Rscript R/render_all.R --summary-only
# Quarto must be on the PATH. Logs go to data/spict/<stock>/render.log.

source(here::here("R", "setup.R"))

args    <- commandArgs(trailingOnly = TRUE)
stocks  <- read_stock_table()$stock
sel     <- setdiff(args, "--summary-only")
if (length(sel)) stocks <- intersect(stocks, sel)
if ("--summary-only" %in% args) stocks <- character()
n_cores <- max(1, min(length(stocks), parallel::detectCores() - 2))

render_one <- function(stock, root) {
  qmd <- file.path(root, "stock", stock, paste0(stock, "_spict.qmd"))
  log <- file.path(root, "data", "spict", stock, "render.log")
  dir.create(dirname(log), recursive = TRUE, showWarnings = FALSE)
  t0 <- Sys.time()
  status <- system2("quarto", c("render", shQuote(qmd)), stdout = log, stderr = log)
  data.frame(stock = stock, status = status,
             minutes = round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1))
}

if (length(stocks)) {
  message("Rendering ", length(stocks), " stock documents on ", n_cores, " workers ...")
  cl <- parallel::makeCluster(n_cores)
  on.exit(parallel::stopCluster(cl), add = TRUE)
  res <- do.call(rbind, parallel::parLapply(cl, stocks, render_one, root = proj_root))
  print(res)
  if (any(res$status != 0)) warning("Failed renders: ", paste(res$stock[res$status != 0], collapse = ", "),
                                    ". See data/spict/<stock>/render.log.")
}

message("Rendering summary.qmd ...")
status <- system2("quarto", c("render", shQuote(file.path(proj_root, "summary.qmd"))))
if (status != 0) stop("summary.qmd failed to render")
