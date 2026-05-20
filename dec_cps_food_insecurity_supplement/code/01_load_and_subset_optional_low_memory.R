################################################################################
# 01_load_and_subset_optional_low_memory.R
#
# Purpose: Optional low-memory alternative to 01_load_and_subset.R.
#          Reads only the raw columns needed by 02_clean_and_analyze.R plus
#          user-requested extras, optionally filters years and states, creates
#          identifiers, and saves the usual output/dec_cps_working.rds file.
#
# Important: This script is designed for the standard starter workflow.
#            It does NOT import every raw variable. If you need most of the
#            IPUMS CPS extract, use 01_load_and_subset.R instead.
#
# Input:   data/raw/*.dta              (pre-converted, if available)
#      OR  data/raw/cps_00014.dat      (raw IPUMS ASCII + .xml metadata)
# Output:  output/dec_cps_working.rds
#          output/dec_cps_working_low_memory_from_r.dta (optional)
#
# Usage:   Run from dec_cps_food_insecurity_supplement/, from code/,
#          from the repo root, or set dec_cps_root_manual / DEC_CPS_ROOT.
#
# Author:  Austin Denteh (legacy code), Claude Code, and Codex
# Date:    April 2026
################################################################################

library(haven)
library(dplyr)

# Optional manual path override. Leave as NULL for auto-detection.
# Example:
# dec_cps_root_manual <- "/Users/yourname/path/to/eco-322-public-data/dec_cps_food_insecurity_supplement"
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

normalize_var_names <- function(x) {
  x <- unname(x)
  x <- x[!is.na(x) & nzchar(x)]
  unique(tolower(x))
}

coalesce_family_columns <- function(df, output_name, candidate_vars) {
  present <- candidate_vars[candidate_vars %in% names(df)]
  if (length(present) == 0) {
    return(df)
  }

  if (output_name %in% names(df) && !(output_name %in% present)) {
    stop(
      paste0(
        "extra_var_families output name '", output_name,
        "' already exists in the data. Choose a different family name."
      )
    )
  }

  merged <- df[[present[[1]]]]
  if (length(present) > 1) {
    for (var_name in present[-1]) {
      merged <- dplyr::coalesce(merged, df[[var_name]])
    }
  }

  df[[output_name]] <- merged
  df
}

# ============================================================================
# USER SETTINGS
# ============================================================================
# This script is optional. Most users should keep using 01_load_and_subset.R.
# Use this version if the full December CPS extract strains your machine.
#
# What this script does:
#   1. Reads only selected raw columns from the IPUMS CPS extract
#   2. Optionally keeps selected survey years and/or state FIPS codes
#   3. Carries user-requested extra raw variables forward
#   4. Saves output/dec_cps_working.rds for 02_clean_and_analyze.R
#
# What this script does NOT do:
#   - It does not keep every raw IPUMS CPS variable
#   - It does not clean or harmonize variables itself
#   - It does not automatically harmonize extra user-added variables
#   - It only merges user-added alias families; it does not recode changing
#     meanings or value definitions across years

# Keep all available years by default. To keep selected years, edit below or
# set years_to_keep before sourcing this script.
# Example:
# years_to_keep <- c(2018, 2020, 2024)
if (!exists("years_to_keep", inherits = TRUE)) {
  years_to_keep <- NULL
}

# Keep all states by default. To keep selected states, edit below or set
# states_to_keep before sourcing this script. Use numeric FIPS codes.
# states_to_keep <- c(37, 45, 51)  # NC, SC, VA
if (!exists("states_to_keep", inherits = TRUE)) {
  states_to_keep <- NULL
}

# Add stable raw variable names here if you want extra columns carried forward.
# Example variables available in this Dec CPS extract:
# extra_keep_vars <- c("fsstmpvalc", "fstotxpnc")
if (!exists("extra_keep_vars", inherits = TRUE)) {
  extra_keep_vars <- c()
}

# Add cross-year raw variable families here when names differ by year.
# The list name becomes the merged output column name in dec_cps_working.rds.
# IMPORTANT: This only merges raw aliases into one column. If the coding or
# meaning of your added variable changes across years, harmonize that variable
# later in 02_clean_and_analyze.R / .do or in your analysis code.
# Example template after you verify the raw aliases have comparable coding:
# extra_var_families <- list(
#   merged_name = c("old_raw_name", "new_raw_name")
# )
if (!exists("extra_var_families", inherits = TRUE)) {
  extra_var_families <- list()
}

# If TRUE, also write a Stata export of the reduced working dataset.
# This uses a separate filename so it does not overwrite the Stata output.
if (!exists("write_dta_export", inherits = TRUE)) {
  write_dta_export <- FALSE
}

# ============================================================================
# 1. DEFINE PATHS
# ============================================================================

dec_cps_root <- resolve_dec_cps_root("01_load_and_subset_optional_low_memory.R")
cat(paste0("Using December CPS root: ", dec_cps_root, "\n"))

raw_dir <- file.path(dec_cps_root, "data", "raw")
out_rds <- file.path(dec_cps_root, "output", "dec_cps_working.rds")
out_dta <- file.path(dec_cps_root, "output", "dec_cps_working_low_memory_from_r.dta")

# ============================================================================
# 2. DEFINE CORE KEEP LIST
# ============================================================================

core_keep_vars <- normalize_var_names(c(
  "year", "serial", "month", "cpsid", "region", "statefip", "faminc",
  "fshwtscale", "fsstatus", "fsrawscr", "fsstatusd", "fsstatusa",
  "fsstatusc", "fsrawscra", "fsrawscrc",
  "fsfdstmp", "fsstmpjan", "fsstmpfeb", "fsstmpmar", "fsstmpapr",
  "fsstmpmay", "fsstmpjun", "fsstmpjul", "fsstmpaug", "fsstmpsep",
  "fsstmpoct", "fsstmpnov", "fsstmpdec",
  "fslnchfrc", "fswic", "fsfdbnk", "fssoupk",
  "fssuppwth", "hhrespln", "pernum", "wtfinl", "relate", "age", "sex",
  "race", "marst", "nchild", "nativity", "hispan", "empstat", "educ99",
  "lineno"
))

required_loader_vars <- c("year", "serial", "month", "pernum")
extra_keep_vars <- normalize_var_names(extra_keep_vars)
extra_var_families <- lapply(extra_var_families, normalize_var_names)

if (length(extra_var_families) > 0) {
  family_names <- names(extra_var_families)
  if (is.null(family_names) || any(!nzchar(family_names))) {
    stop("Each entry in extra_var_families must have a descriptive name.")
  }

  cat(
    paste(
      "[INFO] extra_var_families only merge raw aliases into one column.",
      "If coding or meanings change across years, harmonize that added variable",
      "later in 02_clean_and_analyze.R / .do or in your analysis code.\n"
    )
  )
}

target_keep_vars <- unique(c(
  core_keep_vars,
  extra_keep_vars,
  normalize_var_names(unlist(extra_var_families, use.names = FALSE))
))

if (!is.null(years_to_keep)) {
  years_to_keep <- sort(unique(as.integer(years_to_keep)))
  if (length(years_to_keep) == 0 || any(is.na(years_to_keep))) {
    stop("years_to_keep must be NULL or a numeric vector of valid years.")
  }
}

if (!is.null(states_to_keep)) {
  states_to_keep <- sort(unique(as.integer(states_to_keep)))
  if (length(states_to_keep) == 0 || any(is.na(states_to_keep))) {
    stop("states_to_keep must be NULL or a numeric vector of state FIPS codes.")
  }
}

# ============================================================================
# 3. AUTO-DETECT AND LOAD SELECTED COLUMNS
# ============================================================================

cat("============================================\n")
cat("   LOW-MEMORY DECEMBER CPS FSS LOAD\n")
cat("============================================\n\n")

dta_files <- list.files(raw_dir, pattern = "\\.dta$", full.names = TRUE)
dta_files <- dta_files[!grepl("\\.do$", dta_files)]
dat_path <- file.path(raw_dir, "cps_00014.dat")
xml_path <- file.path(raw_dir, "cps_00014.xml")

if (length(dta_files) > 0) {
  raw_file <- dta_files[1]
  cat("Loading selected columns from pre-converted .dta:", basename(raw_file), "\n")

  dta_header <- read_dta(raw_file, n_max = 0)
  available_map <- setNames(names(dta_header), tolower(names(dta_header)))
  selected_vars <- unname(available_map[intersect(target_keep_vars, names(available_map))])

  if (length(selected_vars) == 0) {
    stop("None of the requested variables were found in the .dta file.")
  }

  cps <- read_dta(raw_file, col_select = all_of(selected_vars))

} else if (file.exists(dat_path) && file.exists(xml_path)) {
  cat("No .dta found. Loading selected columns from raw IPUMS ASCII...\n")
  cat("Using ipumsr with cps_00014.dat + cps_00014.xml...\n")

  if (!requireNamespace("ipumsr", quietly = TRUE)) {
    stop("The ipumsr package is required to read .dat files.\n",
         "Install with: install.packages('ipumsr')")
  }

  ddi <- ipumsr::read_ipums_ddi(xml_path)
  available_map <- setNames(ddi$var_info$var_name, tolower(ddi$var_info$var_name))
  selected_vars <- unname(available_map[intersect(target_keep_vars, names(available_map))])

  if (length(selected_vars) == 0) {
    stop("None of the requested variables were found in cps_00014.xml.")
  }

  cps <- ipumsr::read_ipums_micro(ddi, vars = selected_vars, data_file = dat_path)

} else {
  stop("No data file found in data/raw/.\n",
       "Option 1: Place a pre-converted .dta in data/raw/.\n",
       "Option 2: Place cps_00014.dat + cps_00014.xml in data/raw/.\n",
       "See README.md for instructions.")
}

names(cps) <- tolower(names(cps))

missing_required <- setdiff(required_loader_vars, names(cps))
if (length(missing_required) > 0) {
  stop("Required variable(s) missing from the extract: ",
       paste(missing_required, collapse = ", "))
}

missing_extra <- setdiff(extra_keep_vars, names(cps))
if (length(missing_extra) > 0) {
  cat("[INFO] Extra variable(s) not found in this extract: ",
      paste(missing_extra, collapse = ", "), "\n", sep = "")
}

# ============================================================================
# 4. FILTER YEARS AND STATES
# ============================================================================

if (!is.null(years_to_keep)) {
  cps <- cps %>% filter(year %in% years_to_keep)
}

if (!is.null(states_to_keep)) {
  if (!"statefip" %in% names(cps)) {
    stop("states_to_keep requires statefip, but statefip is not in the extract.")
  }
  cps <- cps %>% filter(statefip %in% states_to_keep)
}

if (nrow(cps) == 0) {
  stop("No observations remain after applying year/state filters.")
}

for (family_name in names(extra_var_families)) {
  cps <- coalesce_family_columns(cps, family_name, extra_var_families[[family_name]])
}

# ============================================================================
# 5. VALIDATE AND CREATE IDENTIFIERS
# ============================================================================

cat(sprintf("\nData loaded.\n  Observations: %s\n  Variables:    %d\n",
            format(nrow(cps), big.mark = ","), ncol(cps)))

cat("\n--- Verifying all records are December ---\n")
print(table(cps$month))
stopifnot(all(cps$month == 12))
cat("[PASS] All records are December (month == 12).\n")

cps <- cps %>%
  mutate(
    hhid    = year * 10000000 + serial,
    individ = hhid * 100 + pernum
  )

dup_check <- cps %>% group_by(year, individ) %>% filter(n() > 1)
if (nrow(dup_check) > 0) {
  warning("Duplicate year-individ combinations found!")
} else {
  cat("[PASS] Unique person ID (individ) verified.\n")
}

cat("\n--- Low-memory selection summary ---\n")
cat("Years: ", paste(sort(unique(cps$year)), collapse = ", "), "\n", sep = "")
if ("statefip" %in% names(cps)) {
  cat("States retained: ", length(unique(cps$statefip)), "\n", sep = "")
}
cat("Variables retained: ", ncol(cps), "\n", sep = "")

# ============================================================================
# 6. SAVE
# ============================================================================

dir.create(file.path(dec_cps_root, "output"), showWarnings = FALSE, recursive = TRUE)
saveRDS(cps, out_rds)
cat(sprintf("\nSaved: %s\n", out_rds))

if (write_dta_export) {
  write_dta(cps, out_dta)
  cat(sprintf("Saved Stata export: %s\n", out_dta))
}

cat("\n============================================\n")
cat("   LOW-MEMORY LOAD COMPLETE\n")
cat("============================================\n")
cat("Next step: run 02_clean_and_analyze.R\n")
