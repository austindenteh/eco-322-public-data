################################################################################
# 01_load_and_subset.R
#
# Purpose: Load the IPUMS ACS extract, restrict to ACS 1-year samples
#          (2006-2024), create a unique person identifier, validate, and save.
#
# Input:   data/raw/usa_00001.dta.gz   (IPUMS ACS extract, compressed)
# Output:  output/acs_working.rds
#          output/acs_working.dta
#
# Data:    American Community Survey (ACS) 1-year samples via IPUMS USA.
#          Annual cross-sectional survey of approx. 3.5 million individuals
#          per year. Covers demographics, education, employment, income,
#          health insurance, immigration, disability, and housing.
#          The extract also contains decennial census samples (1970-2000)
#          which are dropped here to focus on the ACS period.
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

raw_dta  <- file.path(acs_root, "data", "raw", "usa_00001.dta.gz")
out_rds  <- file.path(acs_root, "output", "acs_working.rds")
out_dta  <- file.path(acs_root, "output", "acs_working.dta")

# ============================================================================
# 2. LOAD THE RAW DATA
# ============================================================================
# The IPUMS extract is a gzipped .dta file. haven::read_dta() can read
# .dta.gz directly. This file is very large (~12 GB compressed) and may
# take several minutes to load.

cat("============================================\n")
cat("   LOADING IPUMS ACS EXTRACT\n")
cat("============================================\n\n")

cat("Loading:", raw_dta, "\n")
cat("This may take several minutes for a large extract...\n")
acs <- read_dta(raw_dta)

cat(sprintf("\nRaw data loaded.\n  Observations: %s\n  Variables:    %d\n",
            format(nrow(acs), big.mark = ","), ncol(acs)))

# ============================================================================
# 3. LOWERCASE VARIABLE NAMES
# ============================================================================
# IPUMS variables are uppercase. Lowercase for consistency.

names(acs) <- tolower(names(acs))
cat("\nVariable names lowercased.\n")

# ============================================================================
# 4. RESTRICT TO ACS 1-YEAR SAMPLES (2006-2024)
# ============================================================================
# The extract may include decennial census samples (1970, 1980, 1990, 2000).
# Drop these to keep only ACS years.

cat("\n--- Year distribution (before restriction) ---\n")
print(table(acs$year))

n_before <- nrow(acs)
acs <- acs %>% filter(year >= 2006)
n_dropped <- n_before - nrow(acs)

cat(sprintf("\nDropped %s observations from pre-ACS samples.\n",
            format(n_dropped, big.mark = ",")))
cat(sprintf("Remaining observations: %s\n", format(nrow(acs), big.mark = ",")))

cat("\n--- Year distribution (after restriction) ---\n")
print(table(acs$year))

# ============================================================================
# 5. CREATE UNIQUE PERSON IDENTIFIER
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
# 6. BASIC VALIDATION
# ============================================================================

cat("\n============================================\n")
cat("   VALIDATION CHECKS\n")
cat("============================================\n")

# --- 6a. Year range ---
yr_range <- range(acs$year)
stopifnot(yr_range[1] >= 2006, yr_range[2] <= 2024)
cat(sprintf("\nYear range: %d to %d [OK]\n", yr_range[1], yr_range[2]))

# --- 6b. Key variables exist ---
key_vars <- c("year", "serial", "pernum", "perwt", "statefip", "age", "sex",
              "race", "hispan", "educ", "empstat", "hcovany", "poverty",
              "citizen", "bpl", "incwage")
cat("\nChecking key variables:\n")
for (v in key_vars) {
  if (v %in% names(acs)) {
    cat(sprintf("  %s: found [OK]\n", v))
  } else {
    cat(sprintf("  WARNING: %s not found in data.\n", v))
  }
}

# --- 6c. Sample sizes by year ---
cat("\n--- Observations per year ---\n")
yr_tab <- acs %>% count(year) %>% mutate(pct = round(n / sum(n) * 100, 1))
print(as.data.frame(yr_tab), row.names = FALSE)

# --- 6d. Weight summary ---
cat("\n--- Person weight (perwt) summary ---\n")
print(summary(acs$perwt))

# ============================================================================
# 7. SORT AND SAVE
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
# 1. IPUMS EXTRACT CONTENTS:
#    The extract (usa_00001) contains ACS 1-year samples for 2006-2024,
#    plus optional decennial census samples. This script drops the census
#    samples to focus on the ACS period.
#
# 2. SURVEY DESIGN:
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
# 3. FILE SIZE:
#    The raw extract is very large. If memory is an issue, consider
#    downloading a smaller extract from IPUMS with fewer variables or
#    fewer years.
#
# 4. COVID-19 NOTE (2020):
#    The 2020 ACS had disrupted data collection due to COVID-19.
#    The Census Bureau released experimental weights for 2020 data.
#    See docs/ for guidance on using 2020 data.
#
# 5. CREATING YOUR OWN EXTRACT:
#    Go to https://usa.ipums.org/usa/ to create a custom extract.
#    Select samples (ACS 1-year for desired years) and variables.
#    Download as Stata (.dta) format.
################################################################################
