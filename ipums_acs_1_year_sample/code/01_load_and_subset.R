################################################################################
# 01_load_and_subset.R
#
# Purpose: Load an IPUMS ACS extract, restrict to ACS 1-year samples
#          (drop any pre-2006 census samples), create a unique person
#          identifier, validate, and save.
#
# Input:   data/raw/<any IPUMS .dta or .dta.gz file>
#          The script auto-detects whichever file is present.
#          You can also specify a file manually (see Section 2).
#
# Output:  output/acs_working.rds
#          output/acs_working.dta
#
# Data:    American Community Survey (ACS) 1-year samples via IPUMS USA.
#          Annual cross-sectional survey of approx. 3.5 million individuals
#          per year. Covers demographics, education, employment, income,
#          health insurance, immigration, disability, and housing.
#
#          Source: IPUMS USA, University of Minnesota.
#          https://usa.ipums.org
#
# Usage:   Update the acs_root path below, then source this file:
#            source("/path/to/ipums_acs_1_year_sample/code/01_load_and_subset.R")
#
# Required packages: haven, dplyr
#   Install with: install.packages(c("haven", "dplyr"))
#
# Author:  Austin Denteh (adapted from Kuka et al. 2020 replication code)
# Date:    February 2026
################################################################################

library(haven)
library(dplyr)

# ============================================================================
# 1. DEFINE PATHS
# ============================================================================
# Set the root directory for the ipums_acs_1_year_sample/ folder.
# Users should update this path to match their system.

acs_root <- "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/ipums_acs_1_year_sample"

out_rds  <- file.path(acs_root, "output", "acs_working.rds")
out_dta  <- file.path(acs_root, "output", "acs_working.dta")

# ============================================================================
# 2. IDENTIFY DATA FILE
# ============================================================================
# Specify your data file below, OR leave blank ("") to auto-detect.
# The script will look for the first .dta or .dta.gz file in data/raw/.
#
# Examples:
#   data_file <- file.path(acs_root, "data", "raw", "usa_00003_2023_2024.dta")   # smallest (11 GB)
#   data_file <- file.path(acs_root, "data", "raw", "usa_00002_2020_2024.dta")   # medium (17 GB)
#   data_file <- file.path(acs_root, "data", "raw", "usa_00001_2006_2024.dta")   # full (45 GB)
#   data_file <- file.path(acs_root, "data", "raw", "my_custom_extract.dta.gz")  # your own IPUMS extract

data_file <- ""

# --- Auto-detect if not specified ---
if (data_file == "") {
  raw_dir <- file.path(acs_root, "data", "raw")
  candidates <- list.files(raw_dir, pattern = "\\.(dta\\.gz|dta)$", full.names = TRUE)

  if (length(candidates) == 0) {
    stop("No .dta or .dta.gz file found in data/raw/.\n",
         "Download data from Dropbox or IPUMS and place in data/raw/.\n",
         "See README.md for instructions.")
  }

  # Prefer .dta.gz if available (compressed IPUMS format), else .dta
  gz_files  <- candidates[grepl("\\.dta\\.gz$", candidates)]
  dta_files <- candidates[grepl("\\.dta$", candidates) & !grepl("\\.dta\\.gz$", candidates)]

  if (length(gz_files) > 0) {
    data_file <- gz_files[1]
  } else {
    data_file <- dta_files[1]
  }

  cat("Auto-detected data file:", basename(data_file), "\n")
}

# ============================================================================
# 3. LOAD THE RAW DATA
# ============================================================================
# haven::read_dta() reads both .dta and .dta.gz files.
# Large files may take several minutes to load.

cat("============================================\n")
cat("   LOADING IPUMS ACS EXTRACT\n")
cat("============================================\n\n")

cat("Loading:", data_file, "\n")
cat("This may take several minutes for a large extract...\n")
acs <- read_dta(data_file)

cat(sprintf("\nRaw data loaded.\n  Observations: %s\n  Variables:    %d\n",
            format(nrow(acs), big.mark = ","), ncol(acs)))

# ============================================================================
# 4. LOWERCASE VARIABLE NAMES
# ============================================================================
# IPUMS variables are uppercase. Lowercase for consistency.

names(acs) <- tolower(names(acs))
cat("\nVariable names lowercased.\n")

# ============================================================================
# 5. RESTRICT TO ACS 1-YEAR SAMPLES (2006+)
# ============================================================================
# Some extracts include decennial census samples (1970, 1980, 1990, 2000).
# Drop these to keep only ACS years. If your extract only contains ACS
# years, this step does nothing.

cat("\n--- Year distribution (before restriction) ---\n")
print(table(acs$year))

n_before <- nrow(acs)
acs <- acs %>% filter(year >= 2006)
n_dropped <- n_before - nrow(acs)

if (n_dropped > 0) {
  cat(sprintf("\nDropped %s observations from pre-ACS samples.\n",
              format(n_dropped, big.mark = ",")))
} else {
  cat("\nNo pre-ACS samples found -- all observations retained.\n")
}
cat(sprintf("Remaining observations: %s\n", format(nrow(acs), big.mark = ",")))

cat("\n--- Year distribution (after restriction) ---\n")
print(table(acs$year))

# ============================================================================
# 6. CREATE UNIQUE PERSON IDENTIFIER
# ============================================================================
# IPUMS identifies individuals by year + serial (household) + pernum (person
# within household). Create a single unique ID.

acs <- acs %>% mutate(individ = serial * 100 + pernum)

# Verify uniqueness within year
dup_check <- acs %>% group_by(year, individ) %>% filter(n() > 1)
if (nrow(dup_check) > 0) {
  warning("Duplicate year-individ combinations found!")
} else {
  cat("\nUnique ID (individ = serial*100 + pernum) verified.\n")
}

# ============================================================================
# 7. BASIC VALIDATION
# ============================================================================

cat("\n============================================\n")
cat("   VALIDATION CHECKS\n")
cat("============================================\n")

# --- 7a. Year range ---
yr_range <- range(acs$year)
cat(sprintf("\nYear range: %d to %d\n", yr_range[1], yr_range[2]))
if (yr_range[1] >= 2006) {
  cat("  [OK] All years are ACS (2006+).\n")
} else {
  cat("  [WARN] Found years before 2006 -- check data.\n")
}

# --- 7b. Key variables exist ---
# These are common IPUMS variables. Custom extracts may have fewer.
key_vars <- c("year", "serial", "pernum", "perwt", "statefip", "age", "sex",
              "race", "hispan", "educ", "empstat", "hcovany", "poverty",
              "citizen", "bpl", "incwage")
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
  cat("  Sections using missing variables will be skipped in 02_clean_demographics.R.\n")
}

# --- 7c. Sample sizes by year ---
cat("\n--- Observations per year ---\n")
yr_tab <- acs %>% count(year) %>% mutate(pct = round(n / sum(n) * 100, 1))
print(as.data.frame(yr_tab), row.names = FALSE)

# --- 7d. Weight summary ---
if ("perwt" %in% names(acs)) {
  cat("\n--- Person weight (perwt) summary ---\n")
  print(summary(acs$perwt))
} else {
  cat("\n[INFO] perwt not found -- weight summary skipped.\n")
}

# ============================================================================
# 8. SORT AND SAVE
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
# 1. DATA FILE AUTO-DETECTION:
#    The script scans data/raw/ for .dta.gz and .dta files. If multiple
#    files are present, it uses the first one found (alphabetically).
#    You can override this by setting data_file in Section 2.
#
# 2. PRE-BUILT EXTRACTS ON DROPBOX:
#    Three extract options are available (see README):
#    - usa_00001_2006_2024.dta  (45 GB, full 19-year range)
#    - usa_00002_2020_2024.dta  (17 GB, 5 recent years)
#    - usa_00003_2023_2024.dta  (11 GB, 2 recent years)
#
# 3. CUSTOM IPUMS EXTRACTS:
#    Go to https://usa.ipums.org/usa/ to create a custom extract.
#    Select samples (ACS 1-year for desired years) and variables.
#    Download as Stata (.dta) format and place in data/raw/.
#    The 02_clean_demographics.R script gracefully skips sections
#    that require variables not in your extract.
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
# 5. COVID-19 NOTE (2020):
#    The 2020 ACS had disrupted data collection due to COVID-19.
#    The Census Bureau released experimental weights for 2020 data.
#    See docs/ for guidance on using 2020 data.
################################################################################
