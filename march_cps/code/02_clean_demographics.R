################################################################################
# 02_clean_demographics.R
#
# Purpose: Clean and create analysis-ready variables from CPS ASEC data.
#          Covers demographics, income, employment, health insurance,
#          education, immigration, and transfer programs.
#
# Input:   output/cps_asec.rds  (from 01_load_and_subset.R)
# Output:  output/cps_clean.rds
#          output/cps_clean_from_r.dta  (optional R export for Stata users)
#
# Usage:   Run from march_cps/, march_cps/code/, from the repo root,
#          or set cps_root_manual / CPS_ROOT explicitly.
#
# Author:  Austin Denteh (legacy code and Claude Code)
# Date:    February 2026
################################################################################

library(haven)
library(dplyr)

# ============================================================================
# 1. DEFINE PATHS
# ============================================================================

# Optional manual path override. Leave as NULL for auto-detection.
# Example:
# cps_root_manual <- "/Users/yourname/path/to/eco-322-public-data/march_cps"
if (!exists("cps_root_manual", inherits = TRUE)) {
  cps_root_manual <- NULL
}

get_current_script_dir <- function() {
  command_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", command_args, value = TRUE)
  if (length(file_arg) > 0) {
    script_path <- sub("^--file=", "", file_arg[[1]])
    return(dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE)))
  }

  frame_paths <- vapply(sys.frames(), function(frame) {
    if (!is.null(frame$ofile)) frame$ofile else ""
  }, character(1))
  frame_paths <- frame_paths[nzchar(frame_paths)]
  if (length(frame_paths) > 0) {
    return(dirname(normalizePath(tail(frame_paths, 1), winslash = "/", mustWork = FALSE)))
  }

  ""
}

parent_paths <- function(path) {
  if (!nzchar(path) || !dir.exists(path)) return(character())
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  paths <- path

  repeat {
    parent <- dirname(path)
    if (identical(parent, path)) break
    paths <- c(paths, parent)
    path <- parent
  }

  paths
}

resolve_cps_root <- function(script_name) {
  env_root <- Sys.getenv("CPS_ROOT", unset = "")

  rstudio_script_dir <- ""
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    rstudio_script <- tryCatch(
      rstudioapi::getSourceEditorContext()$path,
      error = function(e) ""
    )
    if (nzchar(rstudio_script)) {
      rstudio_script_dir <- dirname(rstudio_script)
    }
  }

  search_roots <- c(getwd(), get_current_script_dir(), rstudio_script_dir)
  search_paths <- unique(unlist(lapply(search_roots, parent_paths), use.names = FALSE))
  candidates <- c(cps_root_manual, env_root, search_paths, file.path(search_paths, "march_cps"))
  candidates <- unique(candidates[!is.na(candidates) & nzchar(candidates)])

  for (path in candidates) {
    path_norm <- normalizePath(path, winslash = "/", mustWork = FALSE)
    if (file.exists(file.path(path_norm, "README.md")) &&
        file.exists(file.path(path_norm, "code", script_name))) {
      return(path_norm)
    }
  }

  stop(
    "Could not locate the march_cps/ directory.\n",
    "Run this script from march_cps/, march_cps/code/, from the repo root, ",
    "or set cps_root_manual / CPS_ROOT to the march_cps path.\n",
    paste0("Current working directory: ", getwd(), "\n"),
    'Manual override in this script: cps_root_manual <- "/path/to/march_cps"\n',
    'Manual override before sourcing: Sys.setenv(CPS_ROOT = "/path/to/march_cps")',
    call. = FALSE
  )
}

cps_root <- resolve_cps_root("02_clean_demographics.R")
in_rds  <- file.path(cps_root, "output", "cps_asec.rds")
out_rds <- file.path(cps_root, "output", "cps_clean.rds")
out_dta <- file.path(cps_root, "output", "cps_clean_from_r.dta")

# Keep example analyses available for teaching without making cleaning heavy.
run_examples <- FALSE

# ============================================================================
# 2. LOAD DATA
# ============================================================================

cat("Loading CPS ASEC data...\n")
cps <- readRDS(in_rds)
names(cps) <- tolower(names(cps))
cat(paste0("Loaded: ", nrow(cps), " observations, ", ncol(cps), " variables\n"))

# ============================================================================
# 3. DEMOGRAPHICS
# ============================================================================

cat("\nCleaning demographics...\n")

cps <- cps %>%
  mutate(
    # Age groups
    age_cat = case_when(
      age <= 17 ~ 1L, age <= 25 ~ 2L, age <= 34 ~ 3L,
      age <= 44 ~ 4L, age <= 54 ~ 5L, age <= 64 ~ 6L,
      TRUE ~ 7L
    ),
    working_age = as.integer(age >= 18 & age <= 64),

    # Sex
    female = as.integer(sex == 2),

    # Race/ethnicity (Hispanic first, then by race among non-Hispanic)
    race_eth = case_when(
      hispan >= 100 & hispan <= 412 ~ 3L,   # Hispanic
      race == 100 & hispan == 0 ~ 1L,        # White NH
      race == 200 & hispan == 0 ~ 2L,        # Black NH
      hispan == 0 ~ 4L,                       # Other NH
      TRUE ~ NA_integer_
    ),
    white    = as.integer(race_eth == 1),
    black    = as.integer(race_eth == 2),
    hispanic = as.integer(race_eth == 3),
    raceother = as.integer(race_eth == 4),

    # Marital status
    marital_cat = case_when(
      marst %in% c(1, 2) ~ 1L,   # Married
      marst %in% c(3, 4) ~ 2L,   # Divorced/separated
      marst == 5 ~ 3L,            # Widowed
      marst == 6 ~ 4L,            # Never married
      TRUE ~ NA_integer_
    ),
    married = as.integer(marital_cat == 1)
  )

# ============================================================================
# 4. EDUCATION
# ============================================================================

cps <- cps %>%
  mutate(
    educ_cat = case_when(
      educ >= 2 & educ <= 71 ~ 1L,     # Less than HS
      educ == 73 ~ 2L,                   # HS grad/GED
      educ >= 80 & educ <= 92 ~ 3L,     # Some college/Associate
      educ >= 111 & educ < 999 ~ 4L,    # Bachelor's+
      TRUE ~ NA_integer_
    ),
    hsdropout   = as.integer(educ_cat == 1),
    hsgraduate  = as.integer(educ_cat == 2),
    somecollege = as.integer(educ_cat == 3),
    college     = as.integer(educ_cat == 4),

    enrolled = if ("schlcoll" %in% names(.)) {
      as.integer(schlcoll >= 1 & schlcoll <= 4)
    } else NA_integer_
  )

# ============================================================================
# 5. EMPLOYMENT AND LABOR FORCE
# ============================================================================

cps <- cps %>%
  mutate(
    employed = case_when(
      empstat >= 10 & empstat <= 12 ~ 1L,
      empstat >= 20 & empstat <= 36 ~ 0L,
      TRUE ~ NA_integer_
    ),
    unemployed = case_when(
      empstat >= 20 & empstat <= 22 ~ 1L,
      empstat >= 10 & empstat <= 12 ~ 0L,
      TRUE ~ NA_integer_
    ),
    in_labor_force = case_when(
      labforce == 2 ~ 1L,
      labforce == 1 ~ 0L,
      TRUE ~ NA_integer_
    ),
    nilf = case_when(
      labforce == 1 ~ 1L,
      labforce == 2 ~ 0L,
      TRUE ~ NA_integer_
    ),
    fulltime_ly = if ("fullpart" %in% names(.)) {
      ifelse(fullpart %in% c(1, 2), as.integer(fullpart == 1), NA_integer_)
    } else NA_integer_,
    weeks_worked = if ("wkswork1" %in% names(.)) {
      ifelse(wkswork1 > 0 & wkswork1 < 99, as.numeric(wkswork1), NA_real_)
    } else NA_real_
  )

# ============================================================================
# 6. INCOME
# ============================================================================

cps <- cps %>%
  mutate(
    totalinc    = ifelse(inctot < 9999998, inctot, NA_real_),
    wageinc     = ifelse(incwage > 0 & incwage < 9999998, incwage, NA_real_),
    has_wageinc = as.integer(incwage > 0 & incwage < 9999998),
    lnwage      = ifelse(!is.na(wageinc) & wageinc > 0, log(wageinc), NA_real_),

    businc = if ("incbus" %in% names(.)) {
      ifelse(incbus > -9999998 & incbus < 9999998, incbus, NA_real_)
    } else NA_real_,

    ssinc       = ifelse(incss > 0 & incss < 99999, incss, NA_real_),
    receives_ss = as.integer(incss > 0 & incss < 99999),

    ssiinc        = ifelse(incssi > 0 & incssi < 99999, incssi, NA_real_),
    receives_ssi  = as.integer(incssi > 0 & incssi < 99999),

    welfareinc       = ifelse(incwelfr > 0 & incwelfr < 99999, incwelfr, NA_real_),
    receives_welfare = as.integer(incwelfr > 0 & incwelfr < 99999),

    uiinc       = ifelse(incunemp > 0 & incunemp < 99999, incunemp, NA_real_),
    receives_ui = as.integer(incunemp > 0 & incunemp < 99999)
  )

# ============================================================================
# 7. SNAP
# ============================================================================

cps <- cps %>%
  mutate(snap = case_when(
    foodstmp == 2 ~ 1L,
    foodstmp == 1 ~ 0L,
    TRUE ~ NA_integer_
  ))

# ============================================================================
# 8. HEALTH INSURANCE
# ============================================================================

cps <- cps %>%
  mutate(
    has_private_ins = if ("phinsur" %in% names(.)) {
      ifelse(phinsur %in% c(1, 2), as.integer(phinsur == 2), NA_integer_)
    } else NA_integer_,

    medicaid = if ("himcaidly" %in% names(.)) {
      ifelse(himcaidly %in% c(1, 2), as.integer(himcaidly == 2), NA_integer_)
    } else NA_integer_,

    medicare = if ("himcarely" %in% names(.)) {
      ifelse(himcarely %in% c(1, 2), as.integer(himcarely == 2), NA_integer_)
    } else NA_integer_,

    employer_ins = if ("covergh" %in% names(.)) {
      ifelse(covergh %in% c(1, 2), as.integer(covergh == 2), NA_integer_)
    } else NA_integer_,

    any_ins_ly = if ("anycovly" %in% names(.)) {
      ifelse(anycovly %in% c(1, 2), as.integer(anycovly == 2), NA_integer_)
    } else NA_integer_,

    any_ins_now = if ("anycovnw" %in% names(.)) {
      ifelse(anycovnw %in% c(1, 2), as.integer(anycovnw == 1), NA_integer_)
    } else NA_integer_
  )

# Uninsured indicator
if ("anycovly" %in% names(cps)) {
  cps <- cps %>%
    mutate(uninsured = case_when(
      anycovly == 1 ~ 1L,
      anycovly == 2 ~ 0L,
      # Fallback for years without anycovly
      is.na(anycovly) & phinsur == 1 & himcaidly == 1 & himcarely == 1 ~ 1L,
      is.na(anycovly) & (phinsur == 2 | himcaidly == 2 | himcarely == 2) ~ 0L,
      TRUE ~ NA_integer_
    ))
} else {
  cps <- cps %>%
    mutate(uninsured = case_when(
      phinsur == 1 & himcaidly == 1 & himcarely == 1 ~ 1L,
      phinsur == 2 | himcaidly == 2 | himcarely == 2 ~ 0L,
      TRUE ~ NA_integer_
    ))
}

# ============================================================================
# 9. IMMIGRATION
# ============================================================================

if ("nativity" %in% names(cps)) {
  cps <- cps %>%
    mutate(
      foreign_born = as.integer(nativity == 5),
      us_citizen   = if ("citizen" %in% names(.)) as.integer(citizen %in% c(1, 2, 3, 4)) else NA_integer_,
      noncitizen   = if ("citizen" %in% names(.)) as.integer(citizen == 5) else NA_integer_,
      naturalized  = if ("citizen" %in% names(.)) as.integer(citizen == 4) else NA_integer_,
      bpl_foreign  = if ("bpl" %in% names(.)) as.integer(bpl >= 15000) else NA_integer_,
      yrimm        = if ("yrimmig" %in% names(.)) {
        ifelse(yrimmig > 0 & yrimmig < 9999, as.numeric(yrimmig), NA_real_)
      } else NA_real_
    )
}

# ============================================================================
# 10. POVERTY
# ============================================================================

if (all(c("offpov", "offpovuniv", "offtotval", "offcutoff") %in% names(cps))) {
  cps <- cps %>%
    mutate(
      official_poverty_ratio = ifelse(
        offpovuniv == 1 & offtotval < 9999999999 & offcutoff > 0 & offcutoff < 999999,
        offtotval / offcutoff,
        NA_real_
      ),
      below_poverty = case_when(
        offpov == 1 ~ 1L,
        offpov == 2 ~ 0L,
        TRUE ~ NA_integer_
      ),
      below_138fpl = ifelse(is.na(official_poverty_ratio), NA_integer_,
                            as.integer(official_poverty_ratio < 1.38)),
      below_200fpl = ifelse(is.na(official_poverty_ratio), NA_integer_,
                            as.integer(official_poverty_ratio < 2)),
      below_400fpl = ifelse(is.na(official_poverty_ratio), NA_integer_,
                            as.integer(official_poverty_ratio < 4))
    )
} else if ("poverty" %in% names(cps)) {
  cps <- cps %>%
    mutate(
      official_poverty_ratio = NA_real_,
      below_poverty = case_when(
        poverty == 10 ~ 1L,
        poverty %in% c(20, 21, 22, 23) ~ 0L,
        TRUE ~ NA_integer_
      ),
      below_138fpl = NA_integer_,
      below_200fpl = NA_integer_,
      below_400fpl = NA_integer_
    )
}

# ============================================================================
# 11. SAVE
# ============================================================================

cat("\nSaving cleaned dataset...\n")
cps <- cps %>% arrange(year, serial, pernum)

saveRDS(cps, out_rds)
cat(paste0("Saved: ", out_rds, "\n"))

tryCatch({
  write_dta(cps, out_dta)
  cat(paste0("Saved optional R .dta export: ", out_dta, "\n"))
}, error = function(e) {
  cat(paste0("Could not save .dta: ", e$message, "\n"))
})

cat(paste0("Observations: ", nrow(cps), "\n"))
cat(paste0("Variables: ", ncol(cps), "\n"))

# ============================================================================
# 12. DESCRIPTIVE STATISTICS
# ============================================================================

cat("\n============================================\n")
cat("   DESCRIPTIVE STATISTICS (optional; not run by default)\n")
cat("============================================\n\n")

if (run_examples) {
  cat("--- Sample sizes by year ---\n")
  print(as.data.frame(cps %>% count(year)), row.names = FALSE)

  cat("\n--- Age (working-age adults) ---\n")
  print(summary(cps$age[cps$working_age == 1]))

  cat("\n--- Race/ethnicity ---\n")
  race_labels <- c("1" = "White NH", "2" = "Black NH",
                   "3" = "Hispanic", "4" = "Other NH")
  race_table <- cps %>%
    filter(!is.na(race_eth)) %>%
    count(race_eth) %>%
    mutate(pct = round(n / sum(n) * 100, 1),
           label = race_labels[as.character(race_eth)])
  print(as.data.frame(race_table), row.names = FALSE)

  cat("\n--- Education ---\n")
  print(as.data.frame(cps %>% filter(!is.na(educ_cat)) %>% count(educ_cat)),
        row.names = FALSE)
} else {
  cat("Set run_examples <- TRUE near the top of this script to print tables.\n")
}

# ============================================================================
# 13. EXAMPLE REGRESSIONS
# ============================================================================

cat("\n============================================\n")
cat("   EXAMPLE REGRESSIONS (optional; not run by default)\n")
cat("============================================\n\n")

if (run_examples) {
  if (!requireNamespace("broom", quietly = TRUE)) {
    stop("Install the broom package or set run_examples <- FALSE.", call. = FALSE)
  }

  # OLS: log wages ~ demographics (working-age adults)
  cat("--- OLS: Log wage income (unweighted, working-age adults) ---\n")
  ols <- lm(
    lnwage ~ female + age + factor(race_eth) + factor(educ_cat) + factor(year),
    data = cps %>% filter(working_age == 1)
  )
  print(broom::tidy(ols) %>% head(10))
  cat("  (showing first 10 coefficients)\n")

  # Weighted OLS
  cat("\n--- Weighted OLS: Log wage income ---\n")
  wols <- lm(
    lnwage ~ female + age + factor(race_eth) + factor(educ_cat) + factor(year),
    data = cps %>% filter(working_age == 1),
    weights = asecwt
  )
  print(broom::tidy(wols) %>% head(10))
} else {
  cat("Set run_examples <- TRUE near the top of this script to run examples.\n")
}

cat("\n============================================\n")
cat("   DONE\n")
cat("============================================\n")

################################################################################
# NOTES: See Stata version (02_clean_demographics.do) for detailed notes on
# weights, income reference period, insurance redesign, and IPUMS citation.
#
# For survey-weighted analysis in R, use:
#   library(survey)
#   des <- svydesign(ids = ~1, weights = ~asecwt, data = cps)
#   svyglm(uninsured ~ female + age + factor(race_eth), design = des)
#
# For replicate weight variance estimation (2005+):
#   library(survey)
#   repwt_cols <- paste0("repwtp", 1:160)
#   des <- svrepdesign(weights = ~asecwt, repweights = cps[repwt_cols],
#                      type = "successive-difference", data = cps)
################################################################################
