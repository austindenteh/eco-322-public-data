################################################################################
# 01_load_and_append.R
#
# Purpose: Import BRFSS SAS Transport (.XPT) files for each survey year,
#          add a survey year identifier, and bind all years into a single
#          stacked dataset.
#
# Input:   data/raw/LLCP20XX.XPT   (default: 2023-2024; expandable to 2011-2024)
# Output:  output/brfss_appended.rds
#          output/brfss_appended.dta  (for Stata users)
#
# Usage:   Set brfss_root to the brfss/ directory, then source this script.
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

# ============================================================================
# 1. DEFINE PATHS
# ============================================================================
# Update this path to match your system.

brfss_root <- "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/brfss"

raw_dir  <- file.path(brfss_root, "data", "raw")
out_rds  <- file.path(brfss_root, "output", "brfss_appended.rds")
out_dta  <- file.path(brfss_root, "output", "brfss_appended.dta")

# ============================================================================
# 2. DEFINE YEAR RANGE
# ============================================================================
# 2011 is the first year of the dual-frame (landline + cell) methodology.
# The scripts default to 2023-2024 to keep download/processing sizes manageable.
#
# To expand to more years, download the corresponding LLCP20XX.XPT files
# from the shared Dropbox folder (see README) and change first_year below.
# Examples:
#   first_year <- 2011    # Full 14-year range (2011-2024, ~12 GB)
#   first_year <- 2019    # Recent 6 years (2019-2024)
#   first_year <- 2023    # Default 2 years (2023-2024)

first_year <- 2023
last_year  <- 2024
years <- first_year:last_year

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
cat(paste0("   LOADING BRFSS DATA (", first_year, "-", last_year, ")\n"))
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

# Save as Stata .dta (for Stata users)
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

# --- 5a. Check year range ---
yr_range <- range(brfss$surveyyear, na.rm = TRUE)
if (yr_range[1] == first_year & yr_range[2] == last_year) {
  cat(paste0("[PASS] Survey year range: ", yr_range[1], " to ", yr_range[2], "\n"))
} else {
  cat(paste0("[FAIL] Expected year range ", first_year, "-", last_year,
             " but found ", yr_range[1], " to ", yr_range[2], "\n"))
}

# --- 5b. Check observations per year ---
cat("\n[INFO] Observations per survey year:\n")
year_counts <- brfss %>% count(surveyyear)
print(as.data.frame(year_counts), row.names = FALSE)

# --- 5c. Check total is plausible ---
# Each year typically has 400,000-500,000 respondents.
n_total <- nrow(brfss)
n_years_loaded <- length(unique(brfss$surveyyear))
lower_bound <- n_years_loaded * 350000
upper_bound <- n_years_loaded * 600000
if (n_total > lower_bound & n_total < upper_bound) {
  cat(paste0("\n[PASS] Total observations (", n_total,
             ") is plausible for ", n_years_loaded, " year(s)\n"))
} else {
  cat(paste0("\n[FAIL] Total observations (", n_total,
             ") seems implausible for ", n_years_loaded, " year(s)\n"))
}

# --- 5d. Check key survey design variables exist ---
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
#    - Race/ethnicity: _racegr3 (2011-2021) vs. _racegr4 (2022+)
#    - Income: income2 (2011-2020) vs. income3 (2021+)
#    - Sex: sex (2011-2021) vs. sexvar/birthsex (2022+)
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
#    - Change first_year in Section 2 (e.g., 2011 for the full range)
#    - Re-run this script
#
# 7. ADDING NEW YEARS: When new BRFSS data become available:
#    - Download the LLCP20XX.XPT file from CDC
#    - Place it in data/raw/
#    - Update last_year in Section 2
#    - Re-run this script
################################################################################
