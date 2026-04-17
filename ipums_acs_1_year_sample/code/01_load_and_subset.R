################################################################################
# 01_load_and_subset.R
#
# Purpose: Load yearly IPUMS ACS files, append them, create a unique record
#          identifier, validate, and save.
#
# Input:   data/raw/acs_YYYY.dta
#
# Output:  output/acs_working.rds
#          output/acs_working_from_r.dta
#
# Data:    American Community Survey (ACS) 1-year samples via IPUMS USA.
#          Annual cross-sectional survey of approx. 3.5 million individuals
#          per year. Covers demographics, education, employment, income,
#          health insurance, immigration, disability, and housing.
#
#          Source: IPUMS USA, University of Minnesota.
#          https://usa.ipums.org
#
# Usage:   Run from ipums_acs_1_year_sample/, ipums_acs_1_year_sample/code/,
#          or the repo root:
#            source("code/01_load_and_subset.R")
#          You can also set Sys.setenv(ACS_ROOT = "/path/to/ipums_acs_1_year_sample")
#
# Required packages: haven, dplyr
# Optional for larger full-column yearly appends: data.table
#   Install with: install.packages(c("haven", "dplyr", "data.table"))
#
# Author:  Austin Denteh (adapted from Kuka et al. 2020 replication code)
# Date:    February 2026
################################################################################

library(haven)
library(dplyr)

# ============================================================================
# 1. DEFINE PATHS
# ============================================================================
# Auto-detect the dataset root from ACS_ROOT, the dataset folder, the code/
# folder, or the repo root.
#
# Optional manual override if auto-detection fails:
# Sys.setenv(ACS_ROOT = "/path/to/ipums_acs_1_year_sample")

resolve_acs_root <- function() {
  env_root <- Sys.getenv("ACS_ROOT", unset = "")

  parent_paths <- function(path) {
    if (!nzchar(path) || !dir.exists(path)) {
      return(character())
    }

    path <- normalizePath(path, winslash = "/", mustWork = TRUE)
    paths <- path

    repeat {
      parent <- dirname(path)
      if (identical(parent, path)) {
        break
      }
      paths <- c(paths, parent)
      path <- parent
    }

    paths
  }

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

  search_paths <- unique(unlist(lapply(c(getwd(), rstudio_script_dir), parent_paths), use.names = FALSE))
  candidates <- c(
    if (nzchar(env_root)) env_root,
    search_paths,
    file.path(search_paths, "ipums_acs_1_year_sample")
  )
  candidates <- unique(candidates[nzchar(candidates)])

  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "code", "01_load_and_subset.R")) &&
        file.exists(file.path(candidate, "README.md"))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }

  stop(
    "Could not locate the ipums_acs_1_year_sample/ directory.\n",
    "Run this script from ipums_acs_1_year_sample/, ipums_acs_1_year_sample/code/, ",
    "or the repo root, or set ACS_ROOT first.\n",
    "Current working directory: ", getwd(), "\n",
    'Manual override: Sys.setenv(ACS_ROOT = "/path/to/ipums_acs_1_year_sample")'
  )
}

acs_root <- resolve_acs_root()
cat("Using ACS root:", acs_root, "\n")

out_rds  <- file.path(acs_root, "output", "acs_working.rds")
out_dta  <- file.path(acs_root, "output", "acs_working_from_r.dta")

# ============================================================================
 # 2. USER SETTINGS
 # ============================================================================
 # This main script keeps all available columns from the selected yearly ACS
 # files. If that is still too heavy for your machine, use
 # 01_load_and_subset_optional_low_memory.R instead.

 # Year-selection settings for yearly mode.
 # If years_to_load is not NULL, it overrides first_year/last_year.
 # Example:
 # years_to_load <- c(2015, 2016, 2018, 2024)
 years_to_load <- NULL
 first_year <- 2023
 last_year  <- 2024

 make_year_label <- function(years) {
   years <- sort(unique(years))
   if (length(years) == 0) {
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

 coerce_key_types <- function(df) {
   if ("year" %in% names(df)) {
     df$year <- as.integer(haven::zap_labels(df$year))
   }
   if ("sample" %in% names(df)) {
     df$sample <- as.integer(haven::zap_labels(df$sample))
   }
   df
 }

 append_full_years <- function(existing, next_df) {
   if (is.null(existing)) {
     return(next_df)
   }

   if (requireNamespace("data.table", quietly = TRUE)) {
     combined <- data.table::rbindlist(list(existing, next_df), use.names = TRUE, fill = TRUE)
     return(as.data.frame(combined))
   }

   bind_rows(existing, next_df)
 }

 load_one_full_year <- function(yr, raw_dir) {
   year_file <- file.path(raw_dir, paste0("acs_", yr, ".dta"))
   if (!file.exists(year_file)) {
     stop("Required yearly ACS file not found: ", year_file)
   }

   cat(paste0("--- Year ", yr, " ---\n"))
   df <- read_dta(year_file)
   names(df) <- tolower(names(df))
   df <- coerce_key_types(df)

   if (!("year" %in% names(df) && "sample" %in% names(df))) {
     stop("Yearly ACS file is missing year or sample: ", basename(year_file))
   }

   if (!all(df$year == yr, na.rm = TRUE)) {
     stop("Year check failed for ", basename(year_file), " -- expected all rows to have year = ", yr)
   }

   cat(sprintf("  Imported %d: %s observations, %d variables\n",
               yr, format(nrow(df), big.mark = ","), ncol(df)))
   df
 }

 raw_dir <- file.path(acs_root, "data", "raw")

 # ============================================================================
 # 3. LOAD YEARLY ACS FILES
 # ============================================================================
 # The main script now expects yearly ACS files named data/raw/acs_YYYY.dta.

 if (!is.null(years_to_load)) {
   years <- sort(unique(as.integer(years_to_load)))
   if (length(years) == 0 || any(is.na(years))) {
     stop("years_to_load must contain one or more valid numeric years.")
   }
 } else {
   years <- first_year:last_year
 }

 cat("============================================\n")
 cat(paste0("   BUILDING ACS WORKING FILE FROM YEARLY FILES (", make_year_label(years), ")\n"))
 cat("============================================\n\n")

 acs <- NULL
 for (yr in years) {
   year_df <- load_one_full_year(yr, raw_dir)
   acs <- append_full_years(acs, year_df)
   rm(year_df)
   invisible(gc(FALSE))
 }

 cat("\nNo non-ACS-1-year observations found -- yearly files are already restricted.\n")
 cat(sprintf("Remaining observations: %s\n", format(nrow(acs), big.mark = ",")))

 # ============================================================================
 # 4. CREATE UNIQUE PERSON IDENTIFIER
 # ============================================================================
 # Create a unique record ID for each person record in the saved extract.

 if ("sample" %in% names(acs)) {
   acs <- acs %>% mutate(individ = sample * 10000000000 + serial * 100 + pernum)
 } else {
   acs <- acs %>% mutate(individ = year * 10000000000 + serial * 100 + pernum)
 }

 if (anyDuplicated(acs$individ) > 0) {
   warning("Duplicate individ values found!")
 } else {
   cat("\nUnique record ID verified.\n")
 }

 # ============================================================================
 # 5. BASIC VALIDATION
 # ============================================================================

cat("\n============================================\n")
cat("   VALIDATION CHECKS\n")
cat("============================================\n")

# --- 5a. Year range ---
yr_range <- range(acs$year, na.rm = TRUE)
cat(sprintf("\nYear range: %d to %d\n", yr_range[1], yr_range[2]))
if (yr_range[1] >= 2006) {
  cat("  [OK] All years are ACS (2006+).\n")
} else {
  cat("  [WARN] Found years before 2006 -- check data.\n")
}

# --- 5b. Key variables exist ---
# These are common IPUMS variables used by the starter cleaning script.
key_vars <- c("year", "sample", "serial", "pernum", "perwt", "statefip", "age",
              "sex", "race", "hispan", "educ", "educd", "empstat", "hcovany",
              "poverty", "citizen", "bpl", "incwage")
cat("\nChecking key variables:\n")
n_found   <- 0
n_missing <- 0
for (v in key_vars) {
  if (v %in% names(acs)) {
    cat(sprintf("  %s: found [OK]\n", v))
    n_found <- n_found + 1
  } else {
    cat(sprintf("  %s: not in extract\n", v))
    n_missing <- n_missing + 1
  }
}
cat(sprintf("\n  Found %d of %d key variables.\n", n_found, length(key_vars)))
if (n_missing > 0) {
  cat(sprintf("  %d variable(s) not in this extract.\n", n_missing))
  cat("  The 02_clean_demographics.R script will skip sections whose source variables are missing.\n")
}

# --- 5c. Sample sizes by year ---
cat("\n--- Observations per year ---\n")
yr_tab <- acs %>% count(year) %>% mutate(pct = round(n / sum(n) * 100, 1))
print(as.data.frame(yr_tab), row.names = FALSE)

# --- 5d. Weight summary ---
if ("perwt" %in% names(acs)) {
  cat("\n--- Person weight (perwt) summary ---\n")
  print(summary(acs$perwt))
} else {
  cat("\n[INFO] perwt not found -- weight summary skipped.\n")
}

# ============================================================================
# 6. SORT AND SAVE
# ============================================================================

acs <- acs %>% arrange(year, serial, pernum)

cat("\nSaving working copy...\n")
saveRDS(acs, out_rds)
cat(sprintf("  Saved: %s\n", out_rds))

write_dta(acs, out_dta)
cat(sprintf("  Saved: %s\n", out_dta))

cat("\n============================================\n")
cat("   LOAD AND SUBSET COMPLETE\n")
cat("============================================\n")
cat(sprintf("  Observations: %s\n", format(nrow(acs), big.mark = ",")))
cat(sprintf("  Variables:    %d\n", ncol(acs)))
cat("\nNext step: run 02_clean_demographics.R\n")

################################################################################
# NOTES:
#
# 1. YEARLY ACS FILES:
#    The main script now expects yearly files named acs_YYYY.dta.
#    It keeps all available columns from the selected years.
#    If you only need the starter columns, use the optional low-memory
#    script instead.
#
# 2. YEAR SELECTION:
#    Use first_year / last_year for consecutive years or years_to_load
#    for an explicit year list.
#
# 3. CUSTOM IPUMS EXTRACTS:
#    Go to https://usa.ipums.org/usa/ to create yearly ACS extracts.
#    Select ACS 1-year samples for the desired years and download one
#    yearly file per sample as Stata (.dta) format.
#    The 02_clean_demographics.R script skips sections whose source
#    variables are not in your extract.
#
# 4. SURVEY DESIGN:
#    The ACS is a complex survey with stratification and clustering.
#    - Person weight: perwt (for person-level estimates)
#    - Household weight: hhwt (for household-level estimates)
#    - Replicate weights: repwtp1-repwtp80 (for standard errors)
#    - Strata: strata
#    - Cluster: cluster
#    To set up survey design in R:
#      library(survey)
#      des <- svydesign(ids = ~cluster, strata = ~strata,
#                       weights = ~perwt, data = acs)
#
# 5. IDENTIFIERS:
#    individ is a unique record ID within the saved extract.
#    It is not a longitudinal person ID across time.
#
# 6. COVID-19 NOTE (2020):
#    The 2020 ACS had disrupted data collection due to COVID-19.
#    The Census Bureau released experimental weights for 2020 data.
#    See docs/ for guidance on using 2020 data.
################################################################################
