################################################################################
# 01_reshape_and_save.R
#
# Purpose: Load the RAND HRS Longitudinal File 2022 (V1) in wide format,
#          reshape ALL wave-varying variables from wide to long panel format,
#          and save.
#
# Input:   data/raw/randhrs1992_2022v1.dta  (wide format, one row per person)
# Output:  output/hrs_long.rds              (R native format)
#          output/hrs_long.dta              (Stata format)
#          output/hrs_long.csv              (CSV)
#
# Usage:   Update the hrs_root path below, then source this file:
#            source("/path/to/hrs/code/01_reshape_and_save.R")
#
# Data:    RAND HRS Longitudinal File 2022 (V1), May 2025
#          16 waves (1992-2022), 45,234 respondents, 8 entry cohorts
#
# Approach:
#   This script reshapes ALL wave-varying variables (r*, s*, h* prefixed),
#   not just a curated subset. It programmatically discovers all variable
#   stubs by inspecting column names, mirroring the approach used in the
#   Stata do-file (which was adapted from the legacy code).
#
# Required packages: haven, dplyr, tidyr, stringr
#   Install with: install.packages(c("haven", "dplyr", "tidyr", "stringr"))
#
# Author:  Auto-generated starter script (adapted from prepare_data_denteh.do)
# Date:    February 2026
################################################################################

# --- Load packages -----------------------------------------------------------
library(haven)
library(dplyr)
library(tidyr)
library(stringr)

# --- Define paths ------------------------------------------------------------
# Set the root directory for the HRS folder.
# Users should update this path to match their system.
hrs_root <- "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/hrs"

raw_data <- file.path(hrs_root, "data", "raw", "randhrs1992_2022v1.dta")
out_rds  <- file.path(hrs_root, "output", "hrs_long.rds")
out_dta  <- file.path(hrs_root, "output", "hrs_long.dta")
out_csv  <- file.path(hrs_root, "output", "hrs_long.csv")

# =============================================================================
# 1. LOAD THE FULL RAW DATA
# =============================================================================
# Load the entire RAND HRS file — all variables.
# The file is ~1.7 GB and has 45,234 observations with thousands of variables.
# This requires substantial RAM (8+ GB recommended).

cat("Loading RAND HRS data (full file — this may take a minute)...\n")
hrs_wide <- read_dta(raw_data)
cat(sprintf("Loaded %d respondents with %d variables.\n",
            nrow(hrs_wide), ncol(hrs_wide)))

# =============================================================================
# 2. IDENTIFY VARIABLE GROUPS
# =============================================================================
# RAND HRS variables follow the naming convention:
#   [R/S/H][wave_number][concept]
# where wave_number is 1-16.
#
# Time-invariant variables use prefixes like RA, RE, HA, etc. (no wave number).
# We need to separate:
#   (a) Time-invariant variables (carry along as-is)
#   (b) Wave-varying variables (reshape to long)

all_names <- names(hrs_wide)

# --- 2a. Identify wave-varying R-prefix variables ----------------------------
# These match: r{1-16}{concept} but NOT ra*, re* (time-invariant)
r_wave_vars <- all_names[str_detect(all_names, "^r\\d+")]
cat(sprintf("Found %d R-prefix wave-varying variables.\n", length(r_wave_vars)))

# --- 2b. Identify wave-varying H-prefix variables ----------------------------
# These match: h{1-16}{concept} but NOT hhid, hhidpn, hacohort, etc.
h_wave_vars <- all_names[str_detect(all_names, "^h\\d+")]
cat(sprintf("Found %d H-prefix wave-varying variables.\n", length(h_wave_vars)))

# --- 2c. Identify wave-varying S-prefix variables ----------------------------
# These match: s{1-16}{concept}
s_wave_vars <- all_names[str_detect(all_names, "^s\\d+")]
cat(sprintf("Found %d S-prefix wave-varying variables.\n", length(s_wave_vars)))

# --- 2d. Identify INW variables (in-wave indicator) --------------------------
inw_vars <- all_names[str_detect(all_names, "^inw\\d+$")]
cat(sprintf("Found %d INW variables.\n", length(inw_vars)))

# --- 2e. Everything else is time-invariant -----------------------------------
all_wave_vars <- c(r_wave_vars, h_wave_vars, s_wave_vars, inw_vars)
time_invariant_vars <- setdiff(all_names, all_wave_vars)
cat(sprintf("Found %d time-invariant variables.\n", length(time_invariant_vars)))

# =============================================================================
# 3. RESHAPE FROM WIDE TO LONG
# =============================================================================
# Strategy: pivot each prefix group separately, then join.
# This avoids issues with mixed naming patterns across prefixes.

cat("Reshaping from wide to long format — this may take several minutes...\n")

# --- Fix duplicate value labels -----------------------------------------------
# Some RAND HRS variables have duplicate value labels (multiple numeric codes
# mapped to the same label text). This causes haven's label validation to fail
# during pivot_longer. We strip labels from any column with duplicates.
fix_dup_labels <- function(df) {
  for (v in names(df)) {
    labs <- attr(df[[v]], "labels")
    if (!is.null(labs) && any(duplicated(labs))) {
      attr(df[[v]], "labels") <- NULL
    }
  }
  df
}
hrs_wide <- fix_dup_labels(hrs_wide)
cat("  Fixed any duplicate value labels.\n")

# --- 3a. Extract time-invariant variables ------------------------------------
ti <- hrs_wide %>% select(all_of(c("hhidpn", time_invariant_vars)))
# Deduplicate in case hhidpn was already in time_invariant_vars
ti <- ti[, !duplicated(names(ti))]

# --- 3b. Reshape INW (in-wave indicator) -------------------------------------
if (length(inw_vars) > 0) {
  inw_long <- hrs_wide %>%
    select(hhidpn, all_of(inw_vars)) %>%
    pivot_longer(
      cols = all_of(inw_vars),
      names_to = "wave",
      names_prefix = "inw",
      values_to = "inw"
    ) %>%
    mutate(wave = as.integer(wave))
  cat(sprintf("  INW reshaped: %d rows.\n", nrow(inw_long)))
}

# --- 3c. Reshape R-prefix variables (respondent) -----------------------------
if (length(r_wave_vars) > 0) {
  r_long <- hrs_wide %>%
    select(hhidpn, all_of(r_wave_vars)) %>%
    pivot_longer(
      cols = all_of(r_wave_vars),
      names_to = c("wave", ".value"),
      names_pattern = "^r(\\d+)(.+)$"
    ) %>%
    mutate(wave = as.integer(wave)) %>%
    rename_with(~ paste0("r", .), .cols = -c(hhidpn, wave))
  cat(sprintf("  R-prefix reshaped: %d rows, %d columns.\n",
              nrow(r_long), ncol(r_long)))
}

# --- 3d. Reshape H-prefix variables (household) ------------------------------
if (length(h_wave_vars) > 0) {
  h_long <- hrs_wide %>%
    select(hhidpn, all_of(h_wave_vars)) %>%
    pivot_longer(
      cols = all_of(h_wave_vars),
      names_to = c("wave", ".value"),
      names_pattern = "^h(\\d+)(.+)$"
    ) %>%
    mutate(wave = as.integer(wave)) %>%
    rename_with(~ paste0("h", .), .cols = -c(hhidpn, wave))
  cat(sprintf("  H-prefix reshaped: %d rows, %d columns.\n",
              nrow(h_long), ncol(h_long)))
}

# --- 3e. Reshape S-prefix variables (spouse) ---------------------------------
# Note: The S-prefix group includes s[wave]hhidpn (spouse's HHIDPN), which
# after pivot would create a column named "hhidpn" — colliding with the
# respondent ID. We temporarily rename the ID column to avoid the clash,
# then rename back after prefixing the reshaped columns with "s".
if (length(s_wave_vars) > 0) {
  s_long <- hrs_wide %>%
    select(hhidpn, all_of(s_wave_vars)) %>%
    rename(.resp_id = hhidpn) %>%
    pivot_longer(
      cols = all_of(s_wave_vars),
      names_to = c("wave", ".value"),
      names_pattern = "^s(\\d+)(.+)$"
    ) %>%
    mutate(wave = as.integer(wave)) %>%
    rename_with(~ paste0("s", .), .cols = -c(.resp_id, wave)) %>%
    rename(hhidpn = .resp_id)
  cat(sprintf("  S-prefix reshaped: %d rows, %d columns.\n",
              nrow(s_long), ncol(s_long)))
}

# --- 3f. Join everything together --------------------------------------------
cat("Joining all reshaped components...\n")

hrs_long <- ti %>%
  left_join(inw_long, by = "hhidpn") %>%
  left_join(r_long,   by = c("hhidpn", "wave")) %>%
  left_join(h_long,   by = c("hhidpn", "wave")) %>%
  left_join(s_long,   by = c("hhidpn", "wave"))

cat(sprintf("Reshaped to long format: %d person-wave observations, %d variables.\n",
            nrow(hrs_long), ncol(hrs_long)))

# =============================================================================
# 4. CREATE SURVEY YEAR VARIABLE
# =============================================================================
# Map wave numbers to the primary survey year.
# Note: Waves 1-3 have different years for HRS vs. AHEAD cohorts.
# We use the HRS year as the primary year here.

wave_year_map <- tibble(
  wave = 1:16,
  year = c(1992, 1994, 1996, 1998, 2000, 2002, 2004, 2006,
           2008, 2010, 2012, 2014, 2016, 2018, 2020, 2022)
)

hrs_long <- hrs_long %>%
  left_join(wave_year_map, by = "wave")

# =============================================================================
# 5. SORT AND SAVE
# =============================================================================

hrs_long <- hrs_long %>% arrange(hhidpn, wave)

# Save as R native format (.rds)
cat("Saving outputs...\n")
saveRDS(hrs_long, out_rds)
cat(sprintf("Saved: %s\n", out_rds))

# Save as Stata .dta
# Note: haven::write_dta() cannot write tagged NAs back as extended missing.
# All tagged NAs become regular NA (.) in the Stata file.
# Also note: write_dta has a limit of ~32,767 columns. If the reshaped file
# exceeds this, the .dta save will fail. The .rds file has no such limit.
tryCatch({
  write_dta(hrs_long, out_dta)
  cat(sprintf("Saved: %s\n", out_dta))
}, error = function(e) {
  cat(sprintf("Warning: Could not save .dta file: %s\n", e$message))
  cat("The .rds file was saved successfully and has all variables.\n")
})

# Save as CSV
# NOTE: The CSV will be very large given we reshaped all variables.
# You may want to skip this if disk space is a concern.
tryCatch({
  write.csv(hrs_long, out_csv, row.names = FALSE, na = "")
  cat(sprintf("Saved: %s\n", out_csv))
}, error = function(e) {
  cat(sprintf("Warning: Could not save .csv file: %s\n", e$message))
})

cat(sprintf("\nDone! Long-format panel has %d observations and %d variables.\n",
            nrow(hrs_long), ncol(hrs_long)))
cat("Next step: run 02_clean_demographics.R\n")

################################################################################
# NOTES FOR USERS:
#
# 1. ALL VARIABLES RESHAPED: This script reshapes every wave-varying variable
#    in the RAND HRS file. This gives you full access to all health, financial,
#    employment, cognition, and other variables in long format. The trade-off
#    is that the reshape takes longer and uses more memory.
#
# 2. MEMORY: Loading and reshaping the full file requires substantial RAM
#    (8+ GB recommended). If you run into memory issues:
#    - Consider using a machine with more RAM
#    - Or, modify the script to select only the variables you need before
#      reshaping (see the curated subset approach in the README)
#
# 3. MISSING VALUES: haven::read_dta() converts Stata extended missing values
#    (.D, .R, .X, etc.) to tagged NA values. You can inspect them with:
#      haven::print_tagged_na(hrs_long$rshlt)
#      haven::is_tagged_na(hrs_long$rshlt, "d")  # TRUE for .D values
#    For most analyses, simply treating all NA as missing is fine.
#
# 4. WAVE 1 DIFFERENCES: Some variables are defined differently or not
#    available in Wave 1 (1992). For example, CES-D is not derived for
#    Wave 1 because the response options differed.
#
# 5. UPDATING FOR NEW WAVES: When Wave 17 data becomes available:
#    - Update the filename in the paths section
#    - Add year 2024 to the wave_year_map
#    - The programmatic stub detection adapts automatically to new waves
#
# 6. HOW THE PROGRAMMATIC DETECTION WORKS:
#    The script identifies wave-varying variables by matching column names
#    against the regex pattern ^[rsh]\d+ (i.e., starts with r/s/h followed
#    by digits). It then uses pivot_longer() with names_pattern to split
#    the wave number from the concept name. This is the R equivalent of
#    the `ds` + `substr` approach used in the Stata legacy code.
################################################################################
