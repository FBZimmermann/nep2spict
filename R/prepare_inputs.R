# Build the SPiCT input table for one stock from cached SAG records.
#
# Output (data/input/<stock>_input.rds) is a list with
#   $data    one row per year: landings, discards (total, observed or imputed), dead discards,
#            dead removals (the SPiCT catch), the UWTV index with its log-scale SE, the harvest
#            rate, stdevfac multipliers, and the ICES status ratios (abundance / MSY Btrigger,
#            HR / FMSY).
#   $refpts  ICES Category 1 reference points from SAG (MSY Btrigger in index units, FMSY as HR %)
#   $meta    one-row overview used in the summary document
#
# Conventions (knowledge/spict_conventions.md): catches in tonnes; catch = landings + dead
# discards; index scaled by its own mean inside the SPiCT setup, not here; stdevfac vectors
# average to 1.

# Clean one SAG summary table to the columns this project uses.
clean_sag_summary <- function(rec, max_year) {
  s <- rec$summary
  ci_def <- rec$refpts$ConfidenceIntervalDefinition[1]
  z <- if (!is.na(ci_def) && grepl("2\\s*\\*\\s*sd", ci_def, ignore.case = TRUE)) 2 else 1.96
  tibble(
    year     = as.integer(s$Year),
    landings = as.numeric(s$landings),
    discards = as.numeric(s$discards),
    sag_catches = as.numeric(s$catches),
    index    = as.numeric(s$SSB),
    index_lo = as.numeric(s$low_SSB),
    index_hi = as.numeric(s$high_SSB),
    hr       = as.numeric(s$F),
    component = if (!is.null(s$AssessmentComponent)) as.character(s$AssessmentComponent) else NA_character_
  ) |>
    filter(year <= max_year) |>
    mutate(
      index_sd = (index_hi - index_lo) / (2 * z),  # SD on the natural scale (symmetric CI assumed)
      ci_z     = z
    )
}

# Combine components that share FU-level catches but have separate UWTV indices (FU13).
combine_components <- function(tabs) {
  base <- tabs[[1]]
  for (t in tabs[-1]) {
    same <- isTRUE(all.equal(base$landings, t$landings[match(base$year, t$year)]))
    if (!same) warning("Component landings differ; using the first component's catches.")
  }
  idx <- bind_rows(tabs) |>
    group_by(year) |>
    summarise(
      n_comp   = sum(!is.na(index)),
      index    = sum(index),                     # NA if any component is missing
      index_sd = sqrt(sum(index_sd^2)),
      .groups  = "drop"
    ) |>
    mutate(index = ifelse(n_comp == length(tabs), index, NA_real_),
           index_sd = ifelse(n_comp == length(tabs), index_sd, NA_real_))
  base |>
    select(-index, -index_lo, -index_hi, -index_sd) |>
    left_join(idx |> select(year, index, index_sd), by = "year") |>
    mutate(index_lo = index - ci_z * index_sd, index_hi = index + ci_z * index_sd)
}

build_stock_input <- function(stock, stocks = read_stock_table(), year = settings$sag_year,
                              save = TRUE) {
  cfg  <- stocks[stocks$stock == stock, ]
  if (nrow(cfg) != 1) stop("Stock ", stock, " not found in data/config/stocks.csv")
  keys <- as.integer(strsplit(cfg$sag_keys, ";")[[1]])
  recs <- lapply(keys, get_sag_record, year = year)
  tabs <- lapply(recs, clean_sag_summary, max_year = year)
  d    <- if (length(tabs) > 1) combine_components(tabs) else tabs[[1]]

  # ---- Reference points (ICES Category 1, from SAG) ----------------------------------------
  rp_all <- bind_rows(lapply(recs, function(r) as.data.frame(r$refpts)))
  refpts <- tibble(
    component    = if (length(recs) > 1) vapply(tabs, \(t) t$component[1], "") else NA_character_,
    MSYBtrigger  = as.numeric(rp_all$MSYBtrigger),
    FMSY_HR      = as.numeric(rp_all$FMSY),
    CI_def       = rp_all$ConfidenceIntervalDefinition,
    stock_size_units = vapply(recs, \(r) as.character(r$summary$stockSizeUnits[1]), ""),
    pressure_desc    = vapply(recs, \(r) as.character(r$summary$fishingPressureDescription[1]), "")
  )
  # For summed components, MSY Btrigger is the sum of component triggers (same units as index)
  btrig <- if (length(recs) > 1) sum(refpts$MSYBtrigger) else refpts$MSYBtrigger[1]
  fmsy  <- refpts$FMSY_HR[1]

  # ---- Catch series --------------------------------------------------------------------------
  first_index <- min(d$year[!is.na(d$index)])
  first_land  <- min(d$year[!is.na(d$landings)])
  catch_start <- if (!is.na(cfg$catch_start)) cfg$catch_start else
    max(first_land, first_index - settings$catch_start_lag)
  last_catch  <- max(d$year[!is.na(d$landings)])

  has_disc   <- any(!is.na(d$discards))
  disc_years <- d$year[!is.na(d$discards) & !is.na(d$landings)]
  ref_years  <- head(sort(disc_years), settings$discard_ref_n)
  ref_ratio  <- if (has_disc)
    with(d[d$year %in% ref_years, ], sum(discards) / sum(landings)) else 0

  d <- d |>
    filter(year >= catch_start) |>
    arrange(year) |>
    mutate(
      discards_imputed = has_disc & is.na(discards) & !is.na(landings),
      discards_used    = case_when(
        !has_disc          ~ 0,
        !is.na(discards)   ~ discards,
        !is.na(landings)   ~ landings * ref_ratio,
        TRUE               ~ NA_real_),
      dead_discards    = discards_used * (1 - cfg$discard_survival),
      catch            = landings + dead_discards,      # dead removals (t) = SPiCT catch
      catch_total      = landings + discards_used,      # landings + all discards (t)
      discard_rate_wt  = discards_used / catch_total
    )

  # No gaps allowed in the catch series
  cy <- d$year[!is.na(d$catch)]
  gaps <- setdiff(min(cy):max(cy), cy)
  if (length(gaps)) stop(stock, ": catch series has gaps in ", paste(gaps, collapse = ", "))

  # ---- Uncertainty multipliers ----------------------------------------------------------------
  d <- d |>
    mutate(
      index_cv = index_sd / index,
      index_se_log = sqrt(log(1 + index_cv^2)),
      sdfacC_raw = ifelse(discards_imputed, settings$sdfacC_imputed, 1)
    )
  ic <- !is.na(d$catch)
  d$stdevfacC <- NA_real_
  d$stdevfacC[ic] <- d$sdfacC_raw[ic] / mean(d$sdfacC_raw[ic])
  ii <- !is.na(d$index)
  se <- d$index_se_log[ii]
  se[is.na(se) | se <= 0] <- mean(se[!is.na(se) & se > 0])
  d$stdevfacI <- NA_real_
  d$stdevfacI[ii] <- se / mean(se)
  stopifnot(abs(mean(d$stdevfacC[ic]) - 1) < 1e-8, abs(mean(d$stdevfacI[ii]) - 1) < 1e-8)

  # ---- Biomass-index variant (sensitivity only) ----------------------------------------------
  # Mean weight of dead removals: w = removals (t) / (HR/100 * N). Biomass index B = N * w,
  # i.e. removals / (HR/100). Undefined in the assessment year (no HR yet): use the mean weight
  # of the last three years. Units are arbitrary (SPiCT rescales the index).
  d <- d |>
    mutate(mean_wt = ifelse(!is.na(hr) & hr > 0 & !is.na(index), catch / (hr / 100 * index), NA_real_))
  w_recent <- mean(tail(na.omit(d$mean_wt), 3))
  d <- d |>
    mutate(mean_wt_used = ifelse(is.na(mean_wt) & !is.na(index), w_recent, mean_wt),
           index_biomass = index * mean_wt_used)

  # ---- ICES status ratios -------------------------------------------------------------------
  d <- d |>
    mutate(B_Btrigger_ices = index / btrig,
           HR_FMSY_ices    = hr / fmsy)

  ratio_check <- median(d$B_Btrigger_ices, na.rm = TRUE)
  units_ok    <- is.na(ratio_check) || (ratio_check > 0.1 && ratio_check < 10)
  if (!units_ok) warning(stock, ": index / MSY Btrigger median ratio = ", signif(ratio_check, 3),
                         " - units of MSY Btrigger and index may differ in SAG.")

  meta <- tibble(
    stock = stock, fu = cfg$fu, area = cfg$area, ecoregion = cfg$ecoregion,
    sag_keys = cfg$sag_keys, sag_year = year,
    catch_start = catch_start, catch_end = last_catch,
    index_start = first_index, index_end = max(d$year[!is.na(d$index)]),
    n_index = sum(!is.na(d$index)),
    discard_start = if (has_disc) min(disc_years) else NA_integer_,
    n_imputed_discards = sum(d$discards_imputed),
    discard_ref_ratio = ref_ratio, discard_survival = cfg$discard_survival,
    index_timing = cfg$index_timing,
    mean_index_cv = mean(d$index_cv, na.rm = TRUE),
    MSYBtrigger = btrig, FMSY_HR = fmsy, btrigger_units_ok = units_ok,
    stock_size_units = refpts$stock_size_units[1]
  )

  out <- list(stock = stock, data = d, refpts = refpts, meta = meta, cfg = cfg,
              sag_keys = keys, sag_retrieved = recs[[1]]$retrieved)
  if (save) {
    dir.create(path_data("input"), showWarnings = FALSE)
    saveRDS(out, path_data("input", paste0(stock, "_input.rds")))
  }
  out
}
