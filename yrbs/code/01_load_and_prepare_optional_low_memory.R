################################################################################
# 01_load_and_prepare_optional_low_memory.R
#
# Purpose: Optional low-memory alternative to 01_load_and_prepare.R.
#          Reads the 9 raw CDC SAS files one at a time, keeps only the columns
#          needed by 02_clean_and_analyze.R plus user-requested extras, filters
#          years/site types/state codes, and appends the reduced files into the
#          usual output/yrbs_combined.rds file.
#
# Important: This script targets the raw SAS files directly. It does not require
#            data/raw/sadc_2023_combined_all.dta to exist.
#
# Input:   data/raw/sadc_2023_*.sas7bdat
# Output:  output/yrbs_combined.rds
#          output/yrbs_combined_low_memory_from_r.dta (optional)
#          output/_tmp_low_memory/*.rds (temporary chunk files)
#
# Usage:   Run from yrbs/, yrbs/code/, from the repo root, or set YRBS_ROOT.
#
# Author:  Austin Denteh (legacy code), Claude Code, and Codex
# Date:    April 2026
################################################################################

library(haven)
library(dplyr)

resolve_yrbs_root <- function(script_name) {
  env_root <- Sys.getenv("YRBS_ROOT", unset = "")

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
  candidates <- c(env_root, search_paths, file.path(search_paths, "yrbs"))
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
      "Could not locate the yrbs/ directory.",
      "Run this script from yrbs/, yrbs/code/, from the repo root,",
      "or set YRBS_ROOT to the yrbs path.",
      paste0("Current working directory: ", getwd()),
      'Manual override: Sys.setenv(YRBS_ROOT = "/path/to/yrbs")'
    )
  )
}

normalize_var_names <- function(x) {
  x <- unname(x)
  x <- x[nzchar(x)]
  unique(tolower(x))
}

# ============================================================================
# USER SETTINGS
# ============================================================================
# Recommended for most student projects. It keeps selected YRBS variables,
# years, site types, or state samples and avoids building/loading the full
# combined .dta file.

# Keep all available years by default. To keep selected years, use:
# years_to_keep <- c(2019, 2021, 2023)
years_to_keep <- NULL

# Keep State rows by default because the public-use National file does not
# include state identifiers. You may broaden this deliberately if your project
# needs another sample:
# site_types_to_keep <- c("National")
# site_types_to_keep <- c("State", "District")
# site_types_to_keep <- NULL  # keep all site types
site_types_to_keep <- c("State")

# Keep all site codes by default. Use this for state-level subsets, for example:
# states_to_keep <- c("NC", "SC", "VA")
# State codes are applied after AZB -> AZ and NYA -> NY recoding.
states_to_keep <- NULL

# Add additional raw variable names here if you want extra columns carried
# forward. This script keeps extra variables but does not harmonize or recode
# them. Handle any changing meanings/codes in 02_clean_and_analyze.R or in your
# analysis code.
# Example:
# extra_keep_vars <- c("q32", "q34", "qn32")
extra_keep_vars <- c()

# If TRUE, delete and rebuild the temporary low-memory folder each time.
overwrite_temp_files <- TRUE

# If TRUE, remove output/_tmp_low_memory/ after a successful run.
cleanup_temp_files <- TRUE

# If TRUE, also write a Stata export of the reduced appended dataset.
# This uses a separate filename so it does not overwrite the Stata output.
write_dta_export <- FALSE

# ============================================================================
# 1. DEFINE PATHS
# ============================================================================
# Auto-detect the dataset root from the current working directory.
#
# Optional manual override if auto-detection fails:
# Sys.setenv(YRBS_ROOT = "/path/to/yrbs")

yrbs_root <- resolve_yrbs_root("01_load_and_prepare_optional_low_memory.R")
cat(paste0("Using YRBS root: ", yrbs_root, "\n"))

raw_sas_dir <- file.path(yrbs_root, "data", "raw")
out_rds     <- file.path(yrbs_root, "output", "yrbs_combined.rds")
out_dta     <- file.path(yrbs_root, "output", "yrbs_combined_low_memory_from_r.dta")
temp_dir    <- file.path(yrbs_root, "output", "_tmp_low_memory")

sas_files <- c(
  "sadc_2023_national.sas7bdat",
  "sadc_2023_district.sas7bdat",
  "sadc_2023_state_a_d.sas7bdat",
  "sadc_2023_state_e_h.sas7bdat",
  "sadc_2023_state_i_l.sas7bdat",
  "sadc_2023_state_m.sas7bdat",
  "sadc_2023_state_n_p.sas7bdat",
  "sadc_2023_state_q_t.sas7bdat",
  "sadc_2023_state_u_z.sas7bdat"
)

missing_files <- sas_files[!file.exists(file.path(raw_sas_dir, sas_files))]
if (length(missing_files) > 0) {
  stop(paste("Missing raw SAS file(s):", paste(missing_files, collapse = ", ")))
}

if (dir.exists(temp_dir)) {
  if (overwrite_temp_files) {
    unlink(temp_dir, recursive = TRUE, force = TRUE)
  } else {
    stop(
      paste(
        "Temporary folder already exists:", temp_dir,
        "Set overwrite_temp_files <- TRUE or remove the folder first."
      )
    )
  }
}
dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# 2. DEFINE KEEP LIST AND FILTERS
# ============================================================================

core_keep_vars <- c(
  "year", "sitetype", "sitecode", "sitename", "weight",
  "sex", "age", "grade", "race4",
  "q14", "q26", "q27", "q28", "q29", "q30",
  "q33", "q42", "q48",
  "qn14", "qn26", "qn27", "qn28"
)

extra_keep_vars <- normalize_var_names(extra_keep_vars)
keep_vars <- unique(c(core_keep_vars, extra_keep_vars))

if (!is.null(years_to_keep)) {
  years_to_keep <- sort(unique(as.integer(years_to_keep)))
  if (length(years_to_keep) == 0 || any(is.na(years_to_keep))) {
    stop("years_to_keep must be NULL or a numeric vector of valid years.")
  }
}

if (!is.null(site_types_to_keep)) {
  site_types_to_keep <- unique(tolower(trimws(site_types_to_keep)))
  site_types_to_keep <- site_types_to_keep[nzchar(site_types_to_keep)]
  if (length(site_types_to_keep) == 0) {
    stop("site_types_to_keep must be NULL or contain at least one site type.")
  }
}

if (!is.null(states_to_keep)) {
  states_to_keep <- unique(toupper(trimws(states_to_keep)))
  states_to_keep <- states_to_keep[nzchar(states_to_keep)]
  if (length(states_to_keep) == 0) {
    stop("states_to_keep must be NULL or contain at least one state code.")
  }
}

cat("Low-memory settings:\n")
cat("  Years: ", if (is.null(years_to_keep)) "all" else paste(years_to_keep, collapse = ", "), "\n", sep = "")
cat("  Site types: ", if (is.null(site_types_to_keep)) "all" else paste(site_types_to_keep, collapse = ", "), "\n", sep = "")
cat("  State/site codes: ", if (is.null(states_to_keep)) "all" else paste(states_to_keep, collapse = ", "), "\n", sep = "")
cat("  Variables requested: ", length(keep_vars), "\n\n", sep = "")

# ============================================================================
# 3. READ EACH RAW SAS CHUNK, FILTER, AND SAVE TEMP FILES
# ============================================================================

temp_files <- character()

for (sas_file in sas_files) {
  sas_path <- file.path(raw_sas_dir, sas_file)
  cat(paste0("Reading selected columns from ", sas_file, "...\n"))

  chunk <- read_sas(sas_path, col_select = any_of(keep_vars))
  names(chunk) <- tolower(names(chunk))

  missing_core <- setdiff(core_keep_vars, names(chunk))
  if (length(missing_core) > 0) {
    stop(
      paste0(
        "Required variable(s) missing from ", sas_file, ": ",
        paste(missing_core, collapse = ", ")
      )
    )
  }

  chunk <- chunk %>%
    mutate(
      sitecode = case_when(
        sitecode == "AZB" ~ "AZ",
        sitecode == "NYA" ~ "NY",
        TRUE ~ sitecode
      )
    )

  if (!is.null(years_to_keep)) {
    chunk <- chunk %>% filter(year %in% years_to_keep)
  }

  if (!is.null(site_types_to_keep)) {
    chunk <- chunk %>% filter(tolower(sitetype) %in% site_types_to_keep)
  }

  if (!is.null(states_to_keep)) {
    chunk <- chunk %>% filter(toupper(sitecode) %in% states_to_keep)
  }

  if (nrow(chunk) == 0) {
    cat("  Kept 0 rows after filters; skipping temp file.\n")
    next
  }

  temp_file <- file.path(
    temp_dir,
    paste0(tools::file_path_sans_ext(sas_file), "_selected.rds")
  )
  saveRDS(chunk, temp_file)
  temp_files <- c(temp_files, temp_file)

  cat(paste0("  Kept ", format(nrow(chunk), big.mark = ","), " rows and ",
             ncol(chunk), " columns.\n"))

  rm(chunk)
  gc()
}

if (length(temp_files) == 0) {
  stop("No observations matched the requested filters.")
}

# ============================================================================
# 4. APPEND TEMP FILES AND SAVE WORKING OUTPUT
# ============================================================================

cat("\nAppending reduced chunk files...\n")
yrbs <- bind_rows(lapply(temp_files, readRDS)) %>%
  arrange(year, sitetype, sitecode)

saveRDS(yrbs, out_rds)
cat(paste0("Saved: ", out_rds, "\n"))

if (write_dta_export) {
  write_dta(yrbs, out_dta)
  cat(paste0("Saved: ", out_dta, "\n"))
}

cat(paste0("Observations: ", format(nrow(yrbs), big.mark = ","), "\n"))
cat(paste0("Variables: ", ncol(yrbs), "\n"))

# ============================================================================
# 5. VALIDATION CHECKS
# ============================================================================

cat("\n============================================\n")
cat("   VALIDATION CHECKS\n")
cat("============================================\n\n")

cat(paste0("[INFO] Years loaded: ", paste(sort(unique(yrbs$year)), collapse = ", "), "\n"))
cat(paste0("[INFO] Site types loaded: ", paste(sort(unique(yrbs$sitetype)), collapse = ", "), "\n"))

key_vars <- c("year", "sitetype", "sitecode", "sitename", "weight",
              "sex", "age", "grade", "race4", "q14", "q26", "q27",
              "q28", "q29", "q30", "q33", "q42", "q48")
present <- key_vars %in% names(yrbs)
if (all(present)) {
  cat("[PASS] Core variables needed by 02_clean_and_analyze.R are present\n")
} else {
  cat(paste0("[FAIL] Missing: ", paste(key_vars[!present], collapse = ", "), "\n"))
}

if (sum(!is.na(yrbs$weight)) > 0 && mean(yrbs$weight, na.rm = TRUE) > 0) {
  cat("[PASS] Survey weight has non-missing, positive values\n")
} else {
  cat("[FAIL] Survey weight has no non-missing positive values\n")
}

cat("\n--- Observations by year ---\n")
print(as.data.frame(yrbs %>% count(year)), row.names = FALSE)

cat("\n--- Observations by site type ---\n")
print(as.data.frame(yrbs %>% count(sitetype)), row.names = FALSE)

if (cleanup_temp_files) {
  unlink(temp_dir, recursive = TRUE, force = TRUE)
  cat(paste0("\nRemoved temporary folder: ", temp_dir, "\n"))
} else {
  cat(paste0("\nTemporary files kept in: ", temp_dir, "\n"))
}

cat("\n============================================\n")
cat("   LOW-MEMORY LOAD COMPLETE\n")
cat("============================================\n")
cat("Next step: run code/02_clean_and_analyze.R\n")
