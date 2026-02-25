################################################################################
# 01_load_and_subset.R
#
# Purpose: Load an IPUMS CPS ASEC extract and save a working dataset.
#          Auto-detects which data file is in data/raw/ (see README).
#
# Input:   data/raw/cps_*.dta        (auto-detects IPUMS CPS extract)
# Output:  output/cps_asec.rds
#          output/cps_asec.dta
#
# Usage:   Set cps_root to the march_cps/ directory, then source this script.
#
# Data:    CPS Annual Social and Economic Supplement (March CPS).
#          Person-level records with income, employment, insurance,
#          demographics, and transfer programs. ~150K-200K persons/year.
#          Extracted from IPUMS CPS (https://cps.ipums.org).
#          Two extracts available (script auto-detects):
#            cps_00012_2021_2025.dta  (2021-2025, ~2.6 GB — quick start)
#            cps_00011_2005_2025.dta  (2005-2025, ~14 GB — full analysis)
#
# Author:  Austin Denteh (legacy code and Claude Code)
# Date:    February 2026
################################################################################

library(haven)      # read_dta(), write_dta()
library(dplyr)      # data wrangling

# ============================================================================
# 1. DEFINE PATHS
# ============================================================================

cps_root <- "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/march_cps"

out_rds <- file.path(cps_root, "output", "cps_asec.rds")
out_dta <- file.path(cps_root, "output", "cps_asec.dta")

# --- Auto-detect which data file is present ---
# Checks for available CPS extract files in data/raw/.
# Prefers the smaller (2021-2025) extract so the script runs quickly.
candidates <- c("cps_00012_2021_2025.dta", "cps_00012_2001_2025.dta",
                 "cps_00011_2005_2025.dta", "cps_00010.dta")
raw_dta <- NA
for (f in candidates) {
  path <- file.path(cps_root, "data", "raw", f)
  if (file.exists(path)) { raw_dta <- path; break }
}
if (is.na(raw_dta)) {
  # Fallback: use any .dta file in data/raw/
  dta_files <- list.files(file.path(cps_root, "data", "raw"),
                          pattern = "\\.dta$", full.names = TRUE)
  if (length(dta_files) > 0) raw_dta <- dta_files[1]
}
if (is.na(raw_dta)) stop("No CPS data file found in data/raw/. Download from the shared Dropbox folder — see README.md")
cat(paste0("Using data file: ", basename(raw_dta), "\n"))

# ============================================================================
# 2. LOAD RAW DATA
# ============================================================================

cat("============================================\n")
cat("   LOADING CPS ASEC DATA\n")
cat("============================================\n\n")

cps <- read_dta(raw_dta)
cat(paste0("Loaded: ", nrow(cps), " observations, ", ncol(cps), " variables\n"))

# Standardize column names to lowercase
names(cps) <- tolower(names(cps))

# ============================================================================
# 3. CREATE KEY IDENTIFIERS
# ============================================================================

cps <- cps %>%
  mutate(individ = serial * 100 + pernum)

# ============================================================================
# 4. SORT AND SAVE
# ============================================================================

cat("\n============================================\n")
cat("   SAVING DATASET\n")
cat("============================================\n\n")

cps <- cps %>% arrange(year, serial, pernum)

saveRDS(cps, out_rds)
cat(paste0("Saved: ", out_rds, "\n"))

tryCatch({
  write_dta(cps, out_dta)
  cat(paste0("Saved: ", out_dta, "\n"))
}, error = function(e) {
  cat(paste0("Could not save .dta: ", e$message, "\n"))
})

cat(paste0("Observations: ", nrow(cps), "\n"))
cat(paste0("Variables: ", ncol(cps), "\n"))

# ============================================================================
# 5. VALIDATION CHECKS
# ============================================================================

cat("\n============================================\n")
cat("   VALIDATION CHECKS\n")
cat("============================================\n\n")

# Year range
yr_range <- range(cps$year, na.rm = TRUE)
cat(paste0("[PASS] Year range: ", yr_range[1], " to ", yr_range[2], "\n"))

# Observations per year
cat("\n[INFO] Observations per year:\n")
year_counts <- cps %>% count(year)
print(as.data.frame(year_counts), row.names = FALSE)

# Total plausibility
n_years <- length(unique(cps$year))
n_total <- nrow(cps)
if (n_total > n_years * 130000 & n_total < n_years * 250000) {
  cat(paste0("\n[PASS] Total observations (", n_total,
             ") is plausible for ", n_years, " years\n"))
} else {
  cat(paste0("\n[NOTE] Total observations (", n_total, ") for ", n_years, " years\n"))
}

# Key variables
key_vars <- c("year", "serial", "pernum", "cpsidp", "asecwt", "statefip",
              "age", "sex", "race", "hispan", "educ", "empstat", "labforce",
              "inctot", "incwage", "incss", "incwelfr", "incssi")
present <- key_vars %in% names(cps)
if (all(present)) {
  cat("[PASS] All key variables present\n")
} else {
  cat(paste0("[FAIL] Missing: ", paste(key_vars[!present], collapse = ", "), "\n"))
}

cat("\n============================================\n")
cat("   VALIDATION COMPLETE\n")
cat("============================================\n")
cat("\nNext step: run 02_clean_demographics.R\n")
