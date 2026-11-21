# Generic SPiCT setup, fitting, diagnostics, management and summary functions for Nephrops
# stocks with UWTV surveys. Derived from the FU32 template (R/spict_assessment_functions.R in
# NephropsFU32) and the spict-wise conventions (knowledge/spict_conventions.md).

# ---- Input object -------------------------------------------------------------------------------

# Default priors for a stock: FU32 template values for species-level parameters, generic
# weakly-informative values for stock-history parameters, overridable in data/config/stocks.csv.
# overrides = FALSE gives the generic configuration, ignoring stocks.csv (used to report whether a
# stock with tuned priors is assessable without them).
default_priors <- function(input, s = settings, overrides = TRUE) {
  cfg <- input$cfg
  use <- function(x) overrides && !is.null(x) && !is.na(x)
  list(
    r_median      = s$r_median, r_sd = s$r_sd,
    bkfrac_median = if (use(cfg$bkfrac_median)) cfg$bkfrac_median else s$bkfrac_median,
    bkfrac_sd     = if (use(cfg$bkfrac_sd))     cfg$bkfrac_sd     else s$bkfrac_sd,
    sdb_median    = s$sdb_median, sdb_sd = s$sdb_sd,
    sdc_median    = s$sdc_median, sdc_sd = s$sdc_sd,
    sdi_median    = input$meta$mean_index_cv, sdi_sd = s$sdi_sd,
    use_sdi_prior = TRUE,
    logn          = log(2), estimate_n = FALSE, n_prior_sd = 0.5
  )
}

# Build and configure the SPiCT input list.
#   index_var: "index" (UWTV abundance, default) or "index_biomass" (sensitivity)
#   catch_start: optional first catch year (default: from the input table)
make_spict_inp <- function(input, priors = default_priors(input), index_var = "index",
                           timing = input$cfg$index_timing, catch_start = NULL,
                           catch_var = "catch", dteuler = settings$dteuler) {
  d  <- input$data
  if (!is.null(catch_start)) d <- d |> filter(year >= catch_start)
  dc <- d |> filter(!is.na(.data[[catch_var]]))
  di <- d |> filter(!is.na(.data[[index_var]]))

  sfC <- dc$stdevfacC / mean(dc$stdevfacC)
  sfI <- di$stdevfacI / mean(di$stdevfacI)
  inp <- list(
    timeC     = dc$year,
    obsC      = dc[[catch_var]],                         # tonnes
    timeI     = di$year + timing,                        # fractional year of the survey
    obsI      = di[[index_var]] / mean(di[[index_var]]), # scaled by its own mean
    stdevfacC = sfC,
    stdevfacI = sfI,
    dteuler   = dteuler
  )
  inp <- check.inp(inp, verbose = FALSE)

  # Production curve shape: Schaefer, fixed (unless a sensitivity estimates n)
  inp$ini$logn <- priors$logn
  if (priors$estimate_n) {
    inp$priors$logn <- c(priors$logn, priors$n_prior_sd, 1)
    inp$phases$logn <- 1
  } else {
    inp$priors$logn <- c(0, 0, 0)
    inp$phases$logn <- -1
  }

  # Lognormal priors c(log mean, sd, use); mean-corrected as in the FU32 template
  ln_prior <- function(m, sd) c(log(m) - 0.5 * sd^2, sd, 1)
  inp$priors$logbkfrac <- ln_prior(priors$bkfrac_median, priors$bkfrac_sd)
  inp$priors$logr      <- ln_prior(priors$r_median, priors$r_sd)
  inp$priors$logsdb    <- c(log(priors$sdb_median), priors$sdb_sd, 1)
  inp$priors$logsdc    <- c(log(priors$sdc_median), priors$sdc_sd, 1)
  inp$priors$logsdi    <- list(if (priors$use_sdi_prior)
    c(log(priors$sdi_median), priors$sdi_sd, 1) else c(0, 0, 0))
  inp$priors$logalpha  <- c(0, 0, 0)   # deactivated: observation/process error ratio
  inp$priors$logbeta   <- c(0, 0, 0)   # deactivated: catch/F error ratio

  inp$getJointPrecision <- FALSE
  inp$optimiser.control <- list(iter.max = 1e5, eval.max = 1e5)
  inp
}

# ---- Fitting ------------------------------------------------------------------------------------

# residuals: "all" (OSA + process; process residuals cost ~3x a fit), "osa", or "none"
fit_spict_safe <- function(inp, residuals = c("all", "osa", "none")) {
  residuals <- match.arg(residuals)
  fit <- tryCatch(fit.spict(inp), error = function(e) {
    structure(list(error = conditionMessage(e), inp = inp), class = "spict_error")
  })
  if (inherits(fit, "spict_error")) return(fit)
  if (residuals != "none" && fit$opt$convergence == 0)
    fit <- tryCatch(calc.osa.resid(fit), error = function(e) fit)
  if (residuals == "all" && fit$opt$convergence == 0)
    fit <- tryCatch(calc.process.resid(fit), error = function(e) fit)
  fit
}

is_ok_fit <- function(fit) {
  !inherits(fit, "spict_error") && !is.null(fit$opt) && fit$opt$convergence == 0
}

# Hash of everything that determines a fit: data, uncertainty multipliers, priors, settings.
inp_key <- function(inp) {
  rlang::hash(list(inp$timeC, inp$obsC, inp$timeI, inp$obsI, inp$stdevfacC, inp$stdevfacI,
                   inp$priors, inp$phases, inp$ini$logn, inp$dteuler,
                   as.character(packageVersion("spict"))))
}

# Drop the full joint covariance matrix ($cov, ~80 MB per fit), which no spict plotting or
# extraction function uses once process residuals have been computed (checked in spict 1.3.9:
# only calc.process.resid(), get.cov() and calc.prager.stats() read it; spict itself prunes it
# from retro base runs in prune.baserun()). Applied to nested retro/hindcast/management fits.
slim_fit <- function(x) {
  strip <- function(y) { if (is.list(y) && !is.null(y$cov) && !is.null(y$cov.fixed)) y$cov <- NA; y }
  if (!is.list(x)) return(x)
  x <- strip(x)
  for (nm in c("retro", "hindcast", "man"))
    if (is.list(x[[nm]])) x[[nm]] <- lapply(x[[nm]], strip)
  x
}

# Run (or load) an expensive step and cache it with the key of the input it came from.
# A cached object is reused only when run = FALSE and its key matches: a cached diagnostic from a
# superseded fit is never returned.
cached <- function(file, key, run, expr) {
  if (!run && file.exists(file)) {
    obj <- readRDS(file)
    if (identical(obj$key, key)) return(obj$value)
    message("Cache ", basename(file), " is stale (input changed); recomputing.")
  }
  res <- slim_fit(force(expr))
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  saveRDS(list(key = key, value = res, created = Sys.time()), file)
  res
}

# ---- Diagnostics -------------------------------------------------------------------------------

# OSA residual test p-values from fit$diagn (bias, Ljung-Box autocorrelation, Shapiro normality)
residual_tests <- function(fit) {
  dg <- fit$diagn
  if (is.null(dg)) return(tibble(series = character(), test = character(), p = numeric()))
  tibble(name = names(dg), p = unlist(dg)) |>
    filter(grepl("\\.p$", name)) |>
    mutate(test   = case_when(grepl("^bias", name) ~ "bias",
                              grepl("^LBox", name) ~ "autocorrelation",
                              grepl("^shapiro", name) ~ "normality"),
           series = sub("^(bias|LBox|shapiro|acf)", "", sub("\\.p$", "", name)),
           # C = catch, I1.. = indices (observation residuals); B, F = process residuals
           type   = ifelse(series %in% c("B", "F"), "process", "observation")) |>
    filter(!is.na(test)) |>   # drop spict's separate acf p-values; LBox is the autocorrelation test
    select(type, series, test, p)
}

# 95 % CI width of terminal B/Bmsy and F/Fmsy in orders of magnitude (log10(upper/lower)), and
# spict's calc.om() value (difference of floored log10 bounds) for reference.
ci_orders <- function(fit) {
  om <- calc.om(fit)
  tibble(quantity = rownames(om),
         lower = om[, "lower"], est = om[, "est"], upper = om[, "upper"],
         log10_ratio = log10(om[, "upper"] / om[, "lower"]),
         calc_om = om[, "order magnitude"])
}

# Prior-to-posterior SD ratio for the parameters with informative priors. A ratio near 1 means the
# data add little information (the posterior sits on the prior).
prior_posterior <- function(fit) {
  pr <- fit$inp$priors
  pars <- c("logr", "logbkfrac", "logsdb", "logsdc", "logsdi")
  bind_rows(lapply(pars, function(p) {
    pri <- if (p == "logsdi") pr$logsdi[[1]] else pr[[p]]
    if (is.null(pri) || pri[3] == 0) return(NULL)
    post <- get.par(p, fit, exp = FALSE)
    if (p == "logsdi") post <- post[1, , drop = FALSE]
    tibble(parameter = sub("^log", "", p),
           prior_median = exp(pri[1]), prior_sd = pri[2],
           post_median = exp(post[1, "est"]), post_sd = post[1, "sd"],
           sd_ratio = post[1, "sd"] / pri[2],
           shift_in_prior_sd = (post[1, "est"] - pri[1]) / pri[2])
  }))
}

# Maximum relative deviation of each check.ini trial's estimates from the base run (row 1).
# NA for trials that did not converge.
ini_relative_deviation <- function(resmat) {
  est  <- resmat[, colnames(resmat) != "Distance", drop = FALSE]
  base <- est[1, ]
  apply(est[-1, , drop = FALSE], 1, function(v) {
    if (any(is.na(v))) return(NA_real_)
    max(ifelse(base == 0, abs(v), abs(v / base - 1)))
  })
}

# The ICES/spict acceptance checklist (spict guidelines; ICES WKLIFE), with verdicts.
acceptance_checks <- function(fit, retro_fit = NULL, ini = NULL, hind = NULL, s = settings) {
  rt <- residual_tests(fit) |> filter(type == "observation")
  ci <- ci_orders(fit)
  bmsyk <- calc.bmsyk(fit)
  rows <- list(
    tibble(id = 1, check = "Convergence", criterion = "opt$convergence = 0",
           value = as.character(fit$opt$convergence), pass = fit$opt$convergence == 0),
    tibble(id = 2, check = "Finite variances", criterion = "all sd finite",
           value = if (all(is.finite(fit$sd))) "all finite" else
             paste(sum(!is.finite(fit$sd)), "not finite"),
           pass = all(is.finite(fit$sd))),
    tibble(id = 3, check = "OSA residuals", criterion = "all p > 0.05 (bias, autocorrelation, normality)",
           value = if (nrow(rt)) paste0(sum(rt$p <= 0.05, na.rm = TRUE), " of ", nrow(rt), " tests p <= 0.05;",
                                        " min p = ", fmt(min(rt$p, na.rm = TRUE), 3)) else "not available",
           pass = nrow(rt) > 0 && all(rt$p > 0.05, na.rm = TRUE))
  )
  if (!is.null(retro_fit) && !is.null(retro_fit$retro)) {
    rho <- tryCatch(mohns_rho(retro_fit, what = c("FFmsy", "BBmsy")), error = function(e) c(FFmsy = NA, BBmsy = NA))
    inside <- function(x, bar) !is.na(x) && x >= bar[1] && x <= bar[2]
    rows <- c(rows, list(tibble(
      id = 4, check = "Retrospective pattern",
      criterion = sprintf("Mohn's rho in [%.2f, %.2f] (short-lived bar)", s$rho_bar_short[1], s$rho_bar_short[2]),
      value = sprintf("B/Bmsy %.3f; F/Fmsy %.3f", rho["BBmsy"], rho["FFmsy"]),
      pass = inside(rho["BBmsy"], s$rho_bar_short) && inside(rho["FFmsy"], s$rho_bar_short),
      pass_long = inside(rho["BBmsy"], s$rho_bar_long) && inside(rho["FFmsy"], s$rho_bar_long))))
  } else {
    rows <- c(rows, list(tibble(id = 4, check = "Retrospective pattern", criterion = "Mohn's rho",
                                value = "not run", pass = NA)))
  }
  rows <- c(rows, list(
    tibble(id = 5, check = "Production curve", criterion = "0.1 < Bmsy/K < 0.9",
           value = fmt(bmsyk, 2), pass = bmsyk > 0.1 && bmsyk < 0.9),
    tibble(id = 6, check = "Assessment uncertainty",
           criterion = "95% CI of B/Bmsy and F/Fmsy < 1 order of magnitude",
           value = sprintf("B/Bmsy %.2f; F/Fmsy %.2f", ci$log10_ratio[1], ci$log10_ratio[2]),
           pass = all(ci$log10_ratio < s$om_max))
  ))
  if (!is.null(ini) && !is.null(ini$check.ini)) {
    # spict's "Distance" is Euclidean on the natural scale and dominated by K and MSY (tonnes), so
    # an absolute threshold is scale-dependent. Use the maximum relative deviation of any
    # estimated parameter from the base run instead.
    rel <- ini_relative_deviation(ini$check.ini$resmat)
    conv <- rel[!is.na(rel)]
    rows <- c(rows, list(tibble(
      id = 7, check = "Initial values",
      criterion = sprintf("converged trials reach the base optimum (max relative deviation < %g %%)", 100 * s$ini_rel_tol),
      value = sprintf("%d/%d converged; %d deviate; max deviation %.2g %%", length(conv), length(rel),
                      sum(conv > s$ini_rel_tol), 100 * max(c(conv, 0))),
      pass = length(conv) > 0 && all(conv < s$ini_rel_tol))))
  } else {
    rows <- c(rows, list(tibble(id = 7, check = "Initial values", criterion = "check.ini", value = "not run", pass = NA)))
  }
  out <- bind_rows(rows)
  if (!"pass_long" %in% names(out)) out$pass_long <- NA
  # Supplementary (not part of the ICES acceptance list)
  mase <- if (!is.null(hind) && !is.null(hind$hindcast)) tryCatch(calc.mase(hind), error = function(e) NULL) else NULL
  mase_val <- if (!is.null(mase)) suppressWarnings(as.numeric(mase$MASE[1])) else NA_real_
  out <- bind_rows(out, tibble(
    id = 8, check = "Hindcast (supplementary)", criterion = "MASE < 1",
    value = if (is.na(mase_val)) "not run" else fmt(mase_val, 2),
    pass = if (is.na(mase_val)) NA else mase_val < 1, pass_long = NA))
  out
}

# ---- Management --------------------------------------------------------------------------------

# Management scenarios for the advice year (FU32 template): ICES MSY hockey-stick with the 35th
# percentile of the catch (breakpoint 0.5 Bmsy), F = Fmsy, F = Fsq and F = 0.
run_management <- function(fit, intermediate_catch, advice_year = settings$advice_year,
                           s = settings) {
  man <- manage(fit, scenarios = c("currentF", "Fmsy", "noF"),
                intermediatePeriodCatch = intermediate_catch,
                maninterval = c(advice_year, advice_year + 1),
                maneval = advice_year + 1, verbose = FALSE)
  man <- add.man.scenario(man, scenarioTitle = "ICES MSY rule (35th percentile)",
                          intermediatePeriodCatch = intermediate_catch,
                          maninterval = c(advice_year, advice_year + 1),
                          maneval = advice_year + 1,
                          fractiles = list(catch = s$catch_fractile),
                          breakpointB = s$btrigger_bmsy, limitB = s$blim_bmsy,
                          verbose = FALSE)
  man
}

# Tail probabilities for each scenario (FU32 template spictRisk(), lognormal assumption).
spict_risk <- function(man, bmsyfrac = settings$btrigger_bmsy, years = man$inp$maninterval,
                       s = settings) {
  bind_rows(lapply(seq_along(man$man), function(i) {
    m <- man$man[[i]]
    lB <- get.par("logBBmsy", m, exp = FALSE)
    lF <- get.par("logFFmsy", m, exp = FALSE)
    tt <- as.numeric(rownames(lB))
    ind <- which(tt >= years[1] & tt <= years[2])
    iB  <- ind[length(ind)]
    pB  <- pnorm(log(c(1, s$blim_bmsy, bmsyfrac)), lB[iB, "est"], lB[iB, "sd"])
    pF  <- pnorm(log(c(1, s$flim_fmsy)), mean(lF[ind, "est"]), mean(lF[ind, "sd"]))
    tibble(scenario = names(man$man)[i],
           P_B_below_Bmsy = pB[1], P_B_below_Blim = pB[2], P_B_below_Btrigger = pB[3],
           P_F_above_Fmsy = 1 - pF[1], P_F_above_Flim = 1 - pF[2])
  }))
}

# Management table: catch, F/Fmsy, B/Bmsy per scenario plus risks.
management_table <- function(man, s = settings) {
  sm <- sumspict.manage(man, include.unc = FALSE, verbose = FALSE)
  est <- as.data.frame(sm$est)
  est$scenario <- names(man$man)
  tb <- tibble(scenario = est$scenario,
               catch_dead = est[["C"]],
               FFmsy = est[[grep("F/Fmsy", names(est), value = TRUE)[1]]],
               BBmsy = est[[grep("B/Bmsy", names(est), value = TRUE)[1]]])
  left_join(tb, spict_risk(man, s = s), by = "scenario")
}

# Convert SPiCT dead-removal catch into the ICES total-catch definition (landings + all
# discards), using the recent mean discard rate by weight and the discard survival.
recent_discard_rate <- function(input, nyears = 3) {
  d <- input$data |> filter(!is.na(discard_rate_wt), !discards_imputed)
  dr <- mean(tail(d$discard_rate_wt, nyears))
  if (!is.finite(dr)) 0 else dr
}
dead_to_total_catch <- function(catch_dead, input, nyears = 3) {
  catch_dead / (1 - recent_discard_rate(input, nyears) * input$cfg$discard_survival)
}
# Landings equivalent of dead removals: total catch x (1 - discard rate)
dead_to_landings <- function(catch_dead, input, nyears = 3) {
  dead_to_total_catch(catch_dead, input, nyears) * (1 - recent_discard_rate(input, nyears))
}

# ICES advice value for the stock: summed over advice components (FU 13: Clyde + Jura).
ices_advice_value <- function(advice) {
  if (is.null(advice) || !nrow(advice)) return(list(value = NA_real_, type = NA, doi = NA, n = 0))
  v <- suppressWarnings(as.numeric(trimws(advice$adviceValue)))
  list(value = if (all(is.na(v))) NA_real_ else sum(v, na.rm = TRUE),
       type = paste(unique(advice$adviceType), collapse = "/"),
       doi = paste(unique(advice$adviceDOI), collapse = "; "),
       n = nrow(advice))
}

# ---- Extraction --------------------------------------------------------------------------------

# Annual B/Bmsy (at the start of the year) and F/Fmsy (annual mean) with 95 % CI.
spict_timeseries <- function(fit) {
  b <- get.par("logBBmsy", fit, exp = TRUE)
  f <- get.par("logFFmsy", fit, exp = TRUE)
  bb <- as_tibble(b[, 1:3]) |> setNames(c("BBmsy_lo", "BBmsy", "BBmsy_hi")) |>
    mutate(time = as.numeric(rownames(b)))
  ff <- as_tibble(f[, 1:3]) |> setNames(c("FFmsy_lo", "FFmsy", "FFmsy_hi")) |>
    mutate(time = as.numeric(rownames(f)))
  bt <- bb |> filter(abs(time - round(time)) < 1e-6) |> mutate(year = round(time)) |> select(-time)
  ft <- ff |> mutate(year = floor(time + 1e-9)) |> group_by(year) |>
    summarise(across(c(FFmsy_lo, FFmsy, FFmsy_hi), mean), .groups = "drop")
  full_join(bt, ft, by = "year") |> arrange(year)
}

# Key parameter estimates with 95 % CI (natural scale)
spict_parameters <- function(fit) {
  pars <- c(r = "logr", K = "logK", MSY = "logMSY", Fmsy = "logFmsy", Bmsy = "logBmsy",
            n = "logn", sdb = "logsdb", sdf = "logsdf", sdi = "logsdi", sdc = "logsdc",
            q = "logq", bkfrac = "logbkfrac")
  bind_rows(lapply(names(pars), function(nm) {
    p <- tryCatch(get.par(pars[[nm]], fit, exp = TRUE), error = function(e) NULL)
    if (is.null(p)) return(NULL)
    tibble(parameter = nm, lo = p[1, 1], est = p[1, 2], hi = p[1, 3], cv = p[1, 5])
  })) |> mutate(bmsyk = calc.bmsyk(fit))
}

# Terminal status: B/Bmsy at the last index time (assessment year) and F/Fmsy in the last catch year.
spict_status <- function(fit, assessment_year = settings$sag_year) {
  ts <- spict_timeseries(fit)
  b  <- get.par("logBBmsy", fit, exp = TRUE)
  tb <- as.numeric(rownames(b))
  iB <- which.min(abs(tb - max(unlist(fit$inp$timeI))))
  f  <- ts |> filter(year == max(fit$inp$timeC))
  tibble(B_year = round(tb[iB], 2), BBmsy = b[iB, 2], BBmsy_lo = b[iB, 1], BBmsy_hi = b[iB, 3],
         F_year = f$year, FFmsy = f$FFmsy, FFmsy_lo = f$FFmsy_lo, FFmsy_hi = f$FFmsy_hi)
}

# Compact estimates for sensitivity comparisons
sens_row <- function(fit, label, group) {
  if (!is_ok_fit(fit)) return(tibble(group = group, label = label, converged = FALSE))
  st <- spict_status(fit)
  pp <- spict_parameters(fit)
  tibble(group = group, label = label, converged = TRUE,
         BBmsy = st$BBmsy, BBmsy_lo = st$BBmsy_lo, BBmsy_hi = st$BBmsy_hi,
         FFmsy = st$FFmsy, FFmsy_lo = st$FFmsy_lo, FFmsy_hi = st$FFmsy_hi,
         r = pp$est[pp$parameter == "r"], K = pp$est[pp$parameter == "K"],
         MSY = pp$est[pp$parameter == "MSY"], sdi = pp$est[pp$parameter == "sdi"],
         sdb = pp$est[pp$parameter == "sdb"],
         osa_fail = { rt <- residual_tests(fit) |> filter(type == "observation"); sum(rt$p <= 0.05, na.rm = TRUE) },
         ci_B = { ci <- ci_orders(fit); ci$log10_ratio[1] })
}

# ---- Sensitivity -------------------------------------------------------------------------------

run_sensitivity <- function(input, base_priors = default_priors(input)) {
  pr <- base_priors
  mod <- function(...) modifyList(pr, list(...))
  runs <- list(
    list("Base", "base", make_spict_inp(input, pr)),
    list("r prior x0.5", "r prior", make_spict_inp(input, mod(r_median = pr$r_median * 0.5))),
    list("r prior x1.5", "r prior", make_spict_inp(input, mod(r_median = pr$r_median * 1.5))),
    list("r prior sd x2", "r prior", make_spict_inp(input, mod(r_sd = pr$r_sd * 2))),
    list("B0/K 0.25", "B0/K prior", make_spict_inp(input, mod(bkfrac_median = 0.25))),
    list("B0/K 0.75", "B0/K prior", make_spict_inp(input, mod(bkfrac_median = 0.75, bkfrac_sd = 0.25))),
    list("sdi prior off", "obs. error", make_spict_inp(input, mod(use_sdi_prior = FALSE))),
    list("sdi prior x2", "obs. error", make_spict_inp(input, mod(sdi_median = pr$sdi_median * 2))),
    # UWTV CIs understate total observation error (design, edge effects, burrow-detection and
    # occupancy assumptions); x3 is the project lead's request (2026-11-21)
    list("sdi prior x3", "obs. error", make_spict_inp(input, mod(sdi_median = pr$sdi_median * 3))),
    list("Shape n estimated (prior 2, sd 0.5)", "shape", make_spict_inp(input, mod(estimate_n = TRUE))),
    list("Fox shape (n = 1.01 fixed)", "shape", make_spict_inp(input, mod(logn = log(1.01)))),
    list("Biomass index (N x mean weight)", "index", make_spict_inp(input, pr, index_var = "index_biomass")),
    list("Catch incl. all discards", "catch", make_spict_inp(input, pr, catch_var = "catch_total")),
    list("Catch from first index year", "catch", make_spict_inp(input, pr, catch_start = input$meta$index_start))
  )
  bind_rows(lapply(runs, function(x) {
    f <- fit_spict_safe(x[[3]], residuals = "osa")
    sens_row(f, x[[1]], x[[2]])
  }))
}

# Fit the generic configuration (no stocks.csv prior overrides) for a stock whose base run uses
# tuned priors, so the report can state whether the stock is assessable without the tuning.
generic_check <- function(input, generic_priors = default_priors(input, overrides = FALSE)) {
  f <- fit_spict_safe(make_spict_inp(input, generic_priors), residuals = "osa")
  conv <- if (inherits(f, "spict_error")) NA_integer_ else as.integer(f$opt$convergence)
  msg  <- if (inherits(f, "spict_error")) f$error else f$opt$message
  sens_row(f, "Generic configuration", "generic") |>
    mutate(convergence_code = conv, message = msg,
           bkfrac_median = generic_priors$bkfrac_median, bkfrac_sd = generic_priors$bkfrac_sd)
}

# Configuration flag stored in every summary object (also for failed stocks).
#   tuned: text from stocks.csv `tuned` (NA = generic configuration)
#   generic: generic_check() row when tuned, else NULL
config_status <- function(input, fit_ok, generic = NULL) {
  tuned <- input$cfg$tuned
  tuned <- if (is.null(tuned) || is.na(tuned) || tuned == "") NA_character_ else tuned
  list(tuned = tuned, is_tuned = !is.na(tuned), base_converged = fit_ok,
       generic_converged = if (is.na(tuned)) fit_ok else isTRUE(generic$converged),
       generic = generic)
}

# ---- Summary object ----------------------------------------------------------------------------

make_stock_summary <- function(input, fit, man, mantab, checks, sens = NULL, retro_fit = NULL,
                               advice = NULL, advice_prev = NULL, generic = NULL) {
  ts <- spict_timeseries(fit) |>
    left_join(input$data |> select(year, landings, discards_used, catch, catch_total, index,
                                   index_lo, index_hi, hr, B_Btrigger_ices, HR_FMSY_ices),
              by = "year")
  rule_row <- mantab |> filter(grepl("35th", scenario))
  spict_adv_dead  <- rule_row$catch_dead
  spict_adv_total <- dead_to_total_catch(spict_adv_dead, input)
  spict_adv_land  <- dead_to_landings(spict_adv_dead, input)
  ia <- ices_advice_value(advice)
  ip <- ices_advice_value(advice_prev)
  # Compare like with like: ICES advice is usually total catch; FU 23-24 (2026) advises landings
  spict_comparable <- if (isTRUE(grepl("Landings", ia$type))) spict_adv_land else spict_adv_total
  rho <- if (!is.null(retro_fit$retro)) tryCatch(mohns_rho(retro_fit, what = c("FFmsy", "BBmsy")),
                                                 error = function(e) c(FFmsy = NA, BBmsy = NA)) else c(FFmsy = NA, BBmsy = NA)
  list(
    stock       = input$stock,
    meta        = input$meta,
    refpts      = input$refpts,
    checks      = checks,
    residuals   = residual_tests(fit),
    ci          = ci_orders(fit),
    params      = spict_parameters(fit),
    priors      = prior_posterior(fit),
    status      = spict_status(fit),
    mohn        = rho,
    timeseries  = ts,
    mantab      = mantab,
    advice      = tibble(
      advice_year = settings$advice_year,
      spict_catch_dead = spict_adv_dead,
      spict_catch_total = spict_adv_total,
      spict_landings = spict_adv_land,
      ices_advice = ia$value,
      ices_advice_type = ia$type,
      ices_advice_components = ia$n,
      ices_advice_prev = ip$value,
      ices_advice_prev_type = ip$type,
      ices_advice_doi = ia$doi,
      spict_comparable = spict_comparable,
      ratio_spict_ices = spict_comparable / ia$value),
    sensitivity = sens,
    config      = config_status(input, fit_ok = TRUE, generic = generic),
    settings    = settings,
    spict_version = as.character(packageVersion("spict")),
    created     = Sys.time()
  )
}
