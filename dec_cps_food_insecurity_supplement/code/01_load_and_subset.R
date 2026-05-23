################################################################################
# 01_load_and_subset.R
#
# Purpose: Load the IPUMS CPS December Food Security Supplement extract,
#          validate, create identifiers, and save a working dataset.
#          Auto-detects whether a pre-converted .dta file or raw .dat
#          file is available in data/raw/.
#
# Input:   data/raw/*.dta              (pre-converted, if available)
#      OR  data/raw/cps_00014.dat      (raw IPUMS ASCII + .xml metadata)
# Output:  output/dec_cps_working.rds
#          output/dec_cps_working_from_r.dta  (optional R export)
#
# Data:    Current Population Survey, Food Security Supplement (CPS-FSS).
#          Conducted each December. Person-level records with household
#          food security status, SNAP participation, food spending, and
#          food assistance programs. ~100,000-200,000 persons per year.
#
#          Extracted from IPUMS CPS (https://cps.ipums.org).
#
# Usage:   Run from dec_cps_food_insecurity_supplement/, from code/,
#          from the repo root, or set dec_cps_root_manual / DEC_CPS_ROOT.
#
# Required packages: haven, dplyr, ipumsr (for .dat loading)
#   Install with: install.packages(c("haven", "dplyr", "ipumsr"))
#
# Author:  Austin Denteh (legacy code and Claude Code)
# Date:    March 2026
################################################################################

library(haven)
library(dplyr)

# Optional manual path override. Leave as NULL for auto-detection.
# Example:
# dec_cps_root_manual <- "/Users/yourname/path/to/econ-data-starters/dec_cps_food_insecurity_supplement"
if (!exists("dec_cps_root_manual", inherits = TRUE)) {
  dec_cps_root_manual <- NULL
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

resolve_dec_cps_root <- function(script_name) {
  env_root <- Sys.getenv("DEC_CPS_ROOT", unset = "")

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
  candidates <- c(
    dec_cps_root_manual,
    env_root,
    search_paths,
    file.path(search_paths, "dec_cps_food_insecurity_supplement")
  )
  candidates <- unique(candidates[!is.na(candidates) & nzchar(candidates)])

  for (path in candidates) {
    path_norm <- normalizePath(path, winslash = "/", mustWork = FALSE)
    if (file.exists(file.path(path_norm, "README.md")) &&
        file.exists(file.path(path_norm, "code", script_name))) {
      return(path_norm)
    }
  }

  stop(
    "Could not locate the dec_cps_food_insecurity_supplement/ directory.\n",
    "Run this script from the dataset folder, from code/, from the repo root, ",
    "or set dec_cps_root_manual / DEC_CPS_ROOT to the dataset path.\n",
    paste0("Current working directory: ", getwd(), "\n"),
    'Manual override in this script: dec_cps_root_manual <- "/path/to/dec_cps_food_insecurity_supplement"\n',
    'Manual override before sourcing: Sys.setenv(DEC_CPS_ROOT = "/path/to/dec_cps_food_insecurity_supplement")',
    call. = FALSE
  )
}

# ============================================================================
# 1. DEFINE PATHS
# ============================================================================
# Auto-detect the dataset root from the current working directory, script path,
# RStudio source path, or a manual override.

dec_cps_root <- resolve_dec_cps_root("01_load_and_subset.R")
cat(paste0("Using December CPS root: ", dec_cps_root, "\n"))

out_rds <- file.path(dec_cps_root, "output", "dec_cps_working.rds")
out_dta <- file.path(dec_cps_root, "output", "dec_cps_working_from_r.dta")

# ============================================================================
# 2. AUTO-DETECT AND LOAD DATA
# ============================================================================
# The script checks for data files in data/raw/ in this order:
#   1. Pre-converted .dta file (fastest -- downloaded from Dropbox)
#   2. Raw IPUMS .dat file + .xml metadata (requires ipumsr package)

cat("============================================\n")
cat("   LOADING DECEMBER CPS FSS DATA\n")
cat("============================================\n\n")

raw_dir <- file.path(dec_cps_root, "data", "raw")
load_method <- ""

# --- Check for .dta files first ---
dta_files <- list.files(raw_dir, pattern = "\\.dta$", full.names = TRUE)
# Exclude the IPUMS .do file (cps_00014.do is NOT a .dta file, but just in case)
dta_files <- dta_files[!grepl("\\.do$", dta_files)]

if (length(dta_files) > 0) {
  raw_file <- dta_files[1]
  load_method <- "dta"
}

# --- Fall back to .dat + .xml ---
if (load_method == "") {
  dat_path <- file.path(raw_dir, "cps_00014.dat")
  xml_path <- file.path(raw_dir, "cps_00014.xml")
  if (file.exists(dat_path) && file.exists(xml_path)) {
    load_method <- "dat"
  }
}

# --- Error if nothing found ---
if (load_method == "") {
  stop("No data file found in data/raw/.\n",
       "Option 1: Download a pre-converted .dta from Dropbox.\n",
       "Option 2: Place cps_00014.dat + cps_00014.xml in data/raw/.\n",
       "See README.md for instructions.")
}

# --- Load the data ---
if (load_method == "dta") {
  cat("Loading pre-converted .dta:", basename(raw_file), "\n")
  cat("This may take a few minutes for large files...\n")
  cps <- read_dta(raw_file)

} else if (load_method == "dat") {
  cat("No .dta found. Loading from raw IPUMS ASCII...\n")
  cat("Using ipumsr to read cps_00014.dat + cps_00014.xml...\n")
  cat("This may take several minutes...\n")

  if (!requireNamespace("ipumsr", quietly = TRUE)) {
    stop("The ipumsr package is required to read .dat files.\n",
         "Install with: install.packages('ipumsr')")
  }
  library(ipumsr)
  ddi <- read_ipums_ddi(xml_path)
  cps <- read_ipums_micro(ddi)
}

cat(sprintf("\nData loaded.\n  Observations: %s\n  Variables:    %d\n",
            format(nrow(cps), big.mark = ","), ncol(cps)))

# ============================================================================
# 3. LOWERCASE VARIABLE NAMES
# ============================================================================
# IPUMS variables may be uppercase. Lowercase for consistency.

names(cps) <- tolower(names(cps))
cat("\nVariable names lowercased.\n")

# ============================================================================
# 4. VERIFY DECEMBER ONLY
# ============================================================================
# All records should be from December (month == 12).

cat("\n--- Verifying all records are December ---\n")
print(table(cps$month))
stopifnot(all(cps$month == 12))
cat("[PASS] All records are December (month == 12).\n")

# ============================================================================
# 5. CREATE UNIQUE IDENTIFIERS
# ============================================================================
# IPUMS CPS identifies individuals by year + serial (household) + pernum
# (person within household). Create unique IDs.

cps <- cps %>%
  mutate(
    hhid    = year * 10000000 + serial,
    individ = hhid * 100 + pernum
  )

# Verify uniqueness
dup_check <- cps %>% group_by(year, individ) %>% filter(n() > 1)
if (nrow(dup_check) > 0) {
  warning("Duplicate year-individ combinations found!")
} else {
  cat("\n[PASS] Unique person ID (individ) verified.\n")
}

# ============================================================================
# 6. VALIDATION CHECKS
# ============================================================================

cat("\n============================================\n")
cat("   VALIDATION CHECKS\n")
cat("============================================\n")

# --- 6a. Year range ---
yr_range <- range(cps$year)
cat(sprintf("\nYear range: %d to %d\n", yr_range[1], yr_range[2]))
if (yr_range[1] >= 2001 & yr_range[2] <= 2025) {
  cat("  [PASS] Year range is within expected bounds (2001-2025).\n")
} else {
  cat("  [INFO] Year range differs from expected 2001-2025.\n")
}

# --- 6b. Observations per year ---
cat("\n--- Observations per year ---\n")
yr_tab <- cps %>% count(year) %>% mutate(pct = round(n / sum(n) * 100, 1))
print(as.data.frame(yr_tab), row.names = FALSE)

# --- 6c. Key variables exist ---
key_vars <- c("year", "serial", "pernum", "fssuppwth", "fshwtscale", "wtfinl",
              "fsstatus", "fsstatusd", "fsrawscr", "fsfdstmp",
              "age", "sex", "race", "hispan", "empstat", "educ99")
cat("\nChecking key variables:\n")
n_found   <- 0
n_missing <- 0
for (v in key_vars) {
  if (v %in% names(cps)) {
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
  cat("  Some sections in 02_clean_and_analyze.R may be skipped.\n")
}

# --- 6d. Food security scale weight ---
if ("fshwtscale" %in% names(cps)) {
  cat("\n--- Food security scale weight (fshwtscale) ---\n")
  print(summary(cps$fshwtscale))
  cat(sprintf("  Non-missing, positive: %s\n",
              format(sum(cps$fshwtscale > 0 & !is.na(cps$fshwtscale)), big.mark = ",")))
}

# --- 6e. Food security status ---
if ("fsstatusd" %in% names(cps)) {
  cat("\n--- Food security status (detailed) ---\n")
  print(table(cps$fsstatusd, useNA = "ifany"))
}

# ============================================================================
# 7. SORT AND SAVE
# ============================================================================

cps <- cps %>% arrange(year, serial, pernum)

cat("\nSaving working copy...\n")
saveRDS(cps, out_rds)
cat(sprintf("  Saved: %s\n", out_rds))

write_dta(cps, out_dta)
cat(sprintf("  Saved: %s\n", out_dta))

cat("\n============================================\n")
cat("   LOAD AND SUBSET COMPLETE\n")
cat("============================================\n")
cat(sprintf("  Observations: %s\n", format(nrow(cps), big.mark = ",")))
cat(sprintf("  Variables:    %d\n", ncol(cps)))
cat("\nNext step: run 02_clean_and_analyze.R\n")

################################################################################
# NOTES:
#
# 1. DATA LOADING:
#    The IPUMS extract (cps_00014) is a fixed-format ASCII file (.dat).
#    The ipumsr package reads it using the accompanying DDI metadata (.xml).
#    If a pre-converted .dta file is available (from Dropbox), the script
#    loads that instead for faster startup.
#
# 2. WEIGHTS:
#    - fshwtscale: Use for food security status/score analyses
#    - fssuppwth:  Use for other FSS variables (SNAP, food spending)
#    - wtfinl:     Use for basic CPS demographic variables
#    - earnwt:     Use for earnings-related variables
#
# 3. DECEMBER ONLY:
#    All records are from the December CPS. The Food Security Supplement
#    is administered only in December.
#
# 4. HOUSEHOLD VS. PERSON:
#    Food security is measured at the household level. All persons in a
#    household share the same food security status. Consider restricting
#    to one person per household (e.g., relate == 101 for reference person)
#    when analyzing food security outcomes.
#
# 5. CREATING YOUR OWN EXTRACT:
#    Go to https://cps.ipums.org to create a custom December CPS extract.
#    Select "December" samples for desired years.
#    Download the .dat + .xml files and place in data/raw/.
################################################################################
