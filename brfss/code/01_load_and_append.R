################################################################################
# 01_load_and_append.R
#
# Purpose: Import BRFSS SAS Transport (.XPT) files for each survey year,
#          add a survey year identifier, and bind all years into a single
#          stacked dataset.
#
# Input:   data/raw/LLCP20XX.XPT   (default: 2023-2024; expandable to 2011-2024)
# Output:  output/brfss_appended.rds
#          output/brfss_appended_from_r.dta  (optional R export for Stata users)
#
# Usage:   Run from brfss/, from the repo root, or set BRFSS_ROOT explicitly.
#
# Data:    Behavioral Risk Factor Surveillance System (BRFSS)
#          CDC annual telephone health survey, 400,000+ adults per year.
#          We focus on 2011 forward because the BRFSS switched from
#          landline-only to a dual-frame (landline + cell phone) design
#          in 2011, making pre-2011 data not directly comparable.
#
# Author:  Austin Denteh (legacy code and Claude Code)
# Date:    February 2026
################################################################################

library(haven)      # read_xpt() for SAS Transport files
library(dplyr)      # bind_rows(), mutate()
library(purrr)      # map()

resolve_brfss_root <- function(script_name) {
  env_root <- Sys.getenv("BRFSS_ROOT", unset = "")
  candidates <- c(env_root, getwd(), dirname(getwd()), file.path(getwd(), "brfss"))
  candidates <- unique(candidates[nzchar(candidates)])

  for (path in candidates) {
    if (dir.exists(path) &&
        file.exists(file.path(path, "README.md")) &&
        file.exists(file.path(path, "code", script_name))) {
      return(normalizePath(path, winslash = "/", mustWork = TRUE))
    }
  }

  stop(
    paste(
      "Could not locate the brfss/ directory.",
      "Run this script from brfss/, brfss/code/, from the repo root,",
      "or set BRFSS_ROOT to the brfss path."
    )
  )
}

make_year_label <- function(years) {
  years <- sort(unique(as.integer(years)))

  if (length(years) == 0 || any(is.na(years))) {
    return("no years")
  }

  if (length(years) == 1) {
    return(as.character(years))
  }

  if (identical(years, seq.int(min(years), max(years)))) {
    return(paste0(min(years), "-", max(years)))
  }

  paste(years, collapse = ", ")
}

# ============================================================================
# 1. DEFINE PATHS
# ============================================================================
# Auto-detect the dataset root from the current working directory.
# You can also set BRFSS_ROOT explicitly if needed.

brfss_root <- resolve_brfss_root("01_load_and_append.R")
cat(paste0("Using BRFSS root: ", brfss_root, "\n"))

raw_dir  <- file.path(brfss_root, "data", "raw")
out_rds  <- file.path(brfss_root, "output", "brfss_appended.rds")
out_dta  <- file.path(brfss_root, "output", "brfss_appended_from_r.dta")

# ============================================================================
# 2. DEFINE YEARS TO LOAD
# ============================================================================
# 2011 is the first year of the dual-frame (landline + cell) methodology.
# The scripts default to 2023-2024 to keep download/processing sizes manageable.
#
# Choose either a consecutive year range or an explicit year list.
# If years_to_load is not NULL, it overrides first_year/last_year.
# Examples:
#   years_to_load <- c(2011, 2014, 2024)  # Non-consecutive year list
#   first_year <- 2011    # Full 14-year range (2011-2024, ~12 GB)
#   first_year <- 2019    # Recent 6 years (2019-2024)
#   first_year <- 2023    # Default 2 years (2023-2024)

years_to_load <- NULL
first_year <- 2023
last_year  <- 2024

if (!is.null(years_to_load)) {
  years <- sort(unique(as.integer(years_to_load)))
  if (length(years) == 0 || any(is.na(years))) {
    stop("years_to_load must contain one or more valid numeric years.")
  }
} else {
  years <- first_year:last_year
}

year_label <- make_year_label(years)

# ============================================================================
# 3. LOAD EACH YEAR AND BIND
# ============================================================================
# For each year:
#   (a) Read the SAS Transport file using haven::read_xpt()
#   (b) Add a surveyyear variable
#   (c) Standardize column names to lowercase for consistency
#
# haven::read_xpt() preserves variable labels and formats from SAS.
#
# NOTE: Each XPT file is 600 MB - 1.2 GB, so this takes a while.
# On a typical machine, expect 2-5 minutes per year.

cat("============================================\n")
cat(paste0("   LOADING BRFSS DATA (", year_label, ")\n"))
cat("============================================\n\n")

load_one_year <- function(yr) {

  xpt_file <- file.path(raw_dir, paste0("LLCP", yr, ".XPT"))

  if (!file.exists(xpt_file)) {
    warning(paste("File not found for year", yr, ":", xpt_file))
    return(NULL)
  }

  cat(paste0("--- Year ", yr, " ---\n"))

  df <- read_xpt(xpt_file)

  # Standardize column names to lowercase
  names(df) <- tolower(names(df))

  # Add survey year identifier
  df$surveyyear <- yr

  cat(paste0("  Imported ", yr, ": ", nrow(df), " observations, ",
             ncol(df), " variables\n"))

  return(df)
}

# Load all years — bind_rows handles differing column sets gracefully
all_years <- map(years, load_one_year)
all_years <- all_years[!sapply(all_years, is.null)]

cat("\nBinding all years together...\n")
brfss <- bind_rows(all_years)

# Free memory
rm(all_years)
gc()

cat(paste0("Total observations: ", nrow(brfss), "\n"))
cat(paste0("Total variables: ", ncol(brfss), "\n"))

# ============================================================================
# 4. SORT AND SAVE
# ============================================================================

cat("\n============================================\n")
cat("   SAVING APPENDED DATASET\n")
cat("============================================\n\n")

brfss <- brfss %>% arrange(surveyyear)

# Save as RDS (R native format — preserves all attributes, fastest I/O)
saveRDS(brfss, out_rds)
cat(paste0("Saved: ", out_rds, "\n"))

# Save as a separate Stata .dta export for R users.
# This avoids overwriting the Stata-native output from 01_load_and_append.do.
# NOTE: Stata has a 32,767-variable limit and 2 billion obs limit.
# haven::write_dta() handles the conversion.
tryCatch({
  write_dta(brfss, out_dta)
  cat(paste0("Saved: ", out_dta, "\n"))
}, error = function(e) {
  cat(paste0("Could not save .dta: ", e$message, "\n"))
  cat("This can happen if the dataset exceeds Stata's limits.\n")
  cat("The .rds file was saved successfully.\n")
})

# ============================================================================
# 5. VALIDATION CHECKS
# ============================================================================

cat("\n============================================\n")
cat("   VALIDATION CHECKS\n")
cat("============================================\n\n")

# --- 5a. Check loaded years ---
loaded_years <- sort(unique(brfss$surveyyear))
if (identical(loaded_years, years)) {
  cat(paste0("[PASS] Loaded years match request: ", make_year_label(loaded_years), "\n"))
} else {
  cat(paste0("[FAIL] Expected years ", year_label,
             " but found ", make_year_label(loaded_years), "\n"))
}

# --- 5b. Check observations per year ---
cat("\n[INFO] Observations per survey year:\n")
year_counts <- brfss %>% count(surveyyear)
print(as.data.frame(year_counts), row.names = FALSE)

# --- 5c. Check key survey design variables exist ---
design_vars <- c("x_psu", "x_ststr", "x_llcpwt")
# Note: haven::read_xpt converts _ prefix to x_ in some versions.
# Also check the underscore-prefix versions.
design_vars_alt <- c("_psu", "_ststr", "_llcpwt")

found_design <- sapply(design_vars, function(v) v %in% names(brfss)) |
                sapply(design_vars_alt, function(v) v %in% names(brfss))

if (all(found_design)) {
  cat("[PASS] Survey design variables present\n")
} else {
  cat("[INFO] Some survey design variable names may differ.\n")
  cat("  Looking for PSU, strata, and weight variables...\n")
  psu_cols <- grep("psu", names(brfss), ignore.case = TRUE, value = TRUE)
  str_cols <- grep("ststr", names(brfss), ignore.case = TRUE, value = TRUE)
  wt_cols  <- grep("llcpwt", names(brfss), ignore.case = TRUE, value = TRUE)
  cat(paste0("  PSU columns found: ", paste(psu_cols, collapse = ", "), "\n"))
  cat(paste0("  Strata columns found: ", paste(str_cols, collapse = ", "), "\n"))
  cat(paste0("  Weight columns found: ", paste(wt_cols, collapse = ", "), "\n"))
}

# --- 5d. Check supported harmonization families exist ---
family_map <- list(
  sex = c("sex", "sexvar", "birthsex"),
  race = c("_racegr2", "_racegr3", "_racegr4"),
  income = c("income2", "income3"),
  age = c("_impage", "_age80"),
  employment = c("employ", "employ1"),
  diabetes = c("diabete3", "diabete4"),
  copd = c("chccopd", "chccopd1", "chccopd3")
)

family_labels <- c(
  sex = "SEX / SEXVAR / BIRTHSEX",
  race = "_RACEGR2 / _RACEGR3 / _RACEGR4",
  income = "INCOME2 / INCOME3",
  age = "_IMPAGE / _AGE80",
  employment = "EMPLOY / EMPLOY1",
  diabetes = "DIABETE3 / DIABETE4",
  copd = "CHCCOPD / CHCCOPD1 / CHCCOPD3"
)

for (family_name in names(family_map)) {
  found_family <- any(family_map[[family_name]] %in% names(brfss))
  if (found_family) {
    cat(paste0("[PASS] Found a supported ", family_name,
               " variable family (", family_labels[[family_name]], ")\n"))
  } else {
    cat(paste0("[FAIL] No supported ", family_name,
               " variable family found (", family_labels[[family_name]], ")\n"))
  }
}

# --- 5e. Check no year has zero observations ---
if (all(year_counts$n > 0)) {
  cat("[PASS] All years have observations\n")
} else {
  empty_years <- year_counts$surveyyear[year_counts$n == 0]
  cat(paste0("[FAIL] Years with 0 observations: ",
             paste(empty_years, collapse = ", "), "\n"))
}

cat("\n============================================\n")
cat("   VALIDATION COMPLETE\n")
cat("============================================\n")
cat("\nNext step: run 02_clean_and_harmonize.R\n")

################################################################################
# NOTES FOR USERS:
#
# 1. METHODOLOGY BREAK IN 2011: The BRFSS switched from landline-only to a
#    dual-frame (landline + cell phone) design in 2011. This fundamentally
#    changed the sampling, weighting, and resulting estimates. Pre-2011 data
#    are NOT directly comparable. This repository focuses on 2011 forward.
#
# 2. COLUMN NAME CONVENTION: haven::read_xpt() converts SAS names to
#    lowercase. Variables with leading underscores (CDC calculated variables
#    like _LLCPWT, _AGE80, _RACEGR3) are imported as-is in recent haven
#    versions. If you see x_ prefixes, that is an older haven behavior.
#
# 3. VARIABLE CHANGES ACROSS YEARS:
#    - Race/ethnicity: _racegr2 (2011-2014) vs. _racegr3 (2015-2021, 2023-2024)
#      vs. _racegr4 (2022)
#    - Income: income2 (2011-2020) vs. income3 (2021-2024)
#    - Sex: sex (2011-2020) vs. sexvar/birthsex (2021-2024)
#    - COPD: chccopd/chccopd1 (older layouts) vs. chccopd3 (modern layouts)
#    These are harmonized in 02_clean_and_harmonize.R.
#
# 4. bind_rows() HANDLING: dplyr::bind_rows() gracefully handles differing
#    column sets — columns that exist in some years but not others will have
#    NA for the years where they are absent.
#
# 5. MEMORY: The full appended dataset is very large (5+ million obs).
#    Ensure you have 16+ GB of RAM. Consider using data.table::fread()
#    or arrow::read_parquet() for even faster I/O if needed.
#
# 6. EXPANDING YEAR RANGE: To include more years:
#    - Download the LLCP20XX.XPT files from Dropbox or CDC
#    - Place them in data/raw/
#    - Set first_year / last_year for a consecutive range, or
#      set years_to_load for an explicit year list
#    - Re-run this script
#
# 7. ADDING NEW YEARS: When new BRFSS data become available:
#    - Download the LLCP20XX.XPT file from CDC
#    - Place it in data/raw/
#    - Update last_year or years_to_load in Section 2
#    - Re-run this script
################################################################################
