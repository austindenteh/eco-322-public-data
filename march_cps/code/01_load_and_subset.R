################################################################################
# 01_load_and_subset.R
#
# Purpose: Load yearly IPUMS CPS ASEC extracts and save a working dataset.
#          The expected raw files are one file per survey year:
#          data/raw/cps_<extract id>_<year>.dta, e.g. cps_00015_2005.dta.
#
# Input:   data/raw/cps_*_YYYY.dta  (one file per ASEC survey year)
# Output:  output/cps_asec.rds
#          output/cps_asec_from_r.dta  (optional R export for Stata users)
#
# Usage:   Run from march_cps/, march_cps/code/, from the repo root,
#          or set cps_root_manual / CPS_ROOT explicitly.
#
# Data:    CPS Annual Social and Economic Supplement (March CPS).
#          Person-level records with income, employment, insurance,
#          demographics, and transfer programs. ~150K-200K persons/year.
#          Extracted from IPUMS CPS (https://cps.ipums.org).
#
# Author:  Austin Denteh (legacy code and Claude Code)
# Date:    February 2026; revised for yearly extracts May 2026
################################################################################

library(haven)      # read_dta(), write_dta()
library(dplyr)      # data wrangling

# ============================================================================
# 1. DEFINE PATHS AND YEAR SETTINGS
# ============================================================================

# Optional manual path override. Leave as NULL for auto-detection.
# Example:
# cps_root_manual <- "/Users/yourname/path/to/econ-data-starters/march_cps"
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

parse_years <- function(x) {
  x <- trimws(x)
  if (!nzchar(x)) return(NULL)

  pieces <- unlist(strsplit(x, "[,[:space:]]+"))
  years <- integer()
  for (piece in pieces) {
    if (!nzchar(piece)) next
    if (grepl("^[0-9]{4}:[0-9]{4}$", piece)) {
      endpoints <- as.integer(strsplit(piece, ":", fixed = TRUE)[[1]])
      years <- c(years, seq(endpoints[1], endpoints[2]))
    } else {
      years <- c(years, as.integer(piece))
    }
  }

  years <- sort(unique(years))
  if (any(is.na(years))) {
    stop("Could not parse year list: ", x, call. = FALSE)
  }
  years
}

detect_yearly_cps_files <- function(raw_dir) {
  dta_files <- sort(list.files(
    raw_dir,
    pattern = "^cps_[0-9]+_[0-9]{4}\\.dta$",
    full.names = TRUE
  ))

  if (length(dta_files) == 0) {
    legacy_files <- sort(list.files(raw_dir, pattern = "^cps_.*\\.dta$", full.names = FALSE))
    legacy_note <- if (length(legacy_files) > 0) {
      paste0("\nFound these CPS .dta files instead:\n",
             paste(" -", legacy_files, collapse = "\n"))
    } else {
      ""
    }
    stop(
      "No yearly CPS ASEC files found in data/raw/.\n",
      "Expected files named like cps_00015_2005.dta, cps_00016_2006.dta, ...",
      legacy_note,
      call. = FALSE
    )
  }

  years <- as.integer(sub("^cps_[0-9]+_([0-9]{4})\\.dta$", "\\1", basename(dta_files)))
  yearly <- data.frame(year = years, file = dta_files, stringsAsFactors = FALSE)
  yearly <- yearly[order(yearly$year, yearly$file), ]

  duplicate_years <- yearly$year[duplicated(yearly$year)]
  if (length(duplicate_years) > 0) {
    stop(
      "Multiple yearly CPS files were found for year(s): ",
      paste(unique(duplicate_years), collapse = ", "),
      "\nKeep one cps_<extract id>_<year>.dta file per year in data/raw/.",
      call. = FALSE
    )
  }

  yearly
}

# User settings ---------------------------------------------------------------

# Default March CPS teaching window. Set last_year <- 2025, or use CPS_YEARS,
# to load the full yearly-file set.
first_year <- 2005L
last_year <- 2010L

# To run a smaller smoke test without editing this file:
#   Sys.setenv(CPS_YEARS = "2021,2022")
#   Sys.setenv(CPS_YEARS = "2021:2025")
years_to_load <- NULL
env_years <- Sys.getenv("CPS_YEARS", unset = "")
if (nzchar(env_years)) {
  years_to_load <- parse_years(env_years)
}
if (is.null(years_to_load)) {
  years_to_load <- seq(first_year, last_year)
}

cps_root <- resolve_cps_root("01_load_and_subset.R")
raw_dir <- file.path(cps_root, "data", "raw")
dir.create(file.path(cps_root, "output"), showWarnings = FALSE, recursive = TRUE)

out_rds <- file.path(cps_root, "output", "cps_asec.rds")
out_dta <- file.path(cps_root, "output", "cps_asec_from_r.dta")

yearly_files <- detect_yearly_cps_files(raw_dir)
missing_years <- setdiff(years_to_load, yearly_files$year)
if (length(missing_years) > 0) {
  stop(
    "Missing yearly CPS file(s) for: ", paste(missing_years, collapse = ", "),
    "\nExpected one file per requested year, named cps_<extract id>_<year>.dta.",
    call. = FALSE
  )
}

yearly_files <- yearly_files[match(years_to_load, yearly_files$year), ]

cat("Using yearly CPS ASEC files:\n")
for (i in seq_len(nrow(yearly_files))) {
  cat(" - ", yearly_files$year[i], ": ", basename(yearly_files$file[i]), "\n", sep = "")
}

# ============================================================================
# 2. LOAD RAW DATA
# ============================================================================

cat("\n============================================\n")
cat("   LOADING CPS ASEC DATA\n")
cat("============================================\n\n")

load_one_year <- function(path, expected_year) {
  cat("Loading ", expected_year, ": ", basename(path), "\n", sep = "")
  cps_year <- read_dta(path)
  names(cps_year) <- tolower(names(cps_year))

  required_loader_vars <- c("year", "serial", "pernum")
  missing_required <- setdiff(required_loader_vars, names(cps_year))
  if (length(missing_required) > 0) {
    stop(
      "Required variable(s) missing from ", basename(path), ": ",
      paste(missing_required, collapse = ", "),
      call. = FALSE
    )
  }

  unexpected_years <- setdiff(unique(cps_year$year), expected_year)
  unexpected_years <- unexpected_years[!is.na(unexpected_years)]
  if (length(unexpected_years) > 0) {
    stop(
      basename(path), " contains YEAR values other than ", expected_year, ": ",
      paste(unexpected_years, collapse = ", "),
      call. = FALSE
    )
  }

  cat("  observations: ", nrow(cps_year), "; variables: ", ncol(cps_year), "\n", sep = "")
  cps_year
}

cps_list <- vector("list", nrow(yearly_files))
for (i in seq_len(nrow(yearly_files))) {
  cps_list[[i]] <- load_one_year(yearly_files$file[i], yearly_files$year[i])
}

cps <- bind_rows(cps_list)
rm(cps_list)

cat(paste0("\nLoaded total: ", nrow(cps), " observations, ", ncol(cps), " variables\n"))

# ============================================================================
# 3. CREATE KEY IDENTIFIERS
# ============================================================================

cps <- cps %>%
  mutate(individ = year * 10000000 + serial * 100 + pernum)

if (anyDuplicated(cps$individ) > 0) {
  stop("Duplicate individ values found. Check year, serial, and pernum.", call. = FALSE)
}

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
  cat(paste0("Saved optional R .dta export: ", out_dta, "\n"))
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

yr_range <- range(cps$year, na.rm = TRUE)
cat(paste0("[PASS] Year range: ", yr_range[1], " to ", yr_range[2], "\n"))

cat("\n[INFO] Observations per year:\n")
year_counts <- cps %>% count(year)
print(as.data.frame(year_counts), row.names = FALSE)

n_years <- length(unique(cps$year))
n_total <- nrow(cps)
if (n_total > n_years * 130000 & n_total < n_years * 250000) {
  cat(paste0("\n[PASS] Total observations (", n_total,
             ") is plausible for ", n_years, " years\n"))
} else {
  cat(paste0("\n[NOTE] Total observations (", n_total, ") for ", n_years, " years\n"))
}

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
