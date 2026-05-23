################################################################################
# 01_load_and_subset_optional_low_memory.R
#
# Purpose: Optional low-memory loader for the CPS ASEC starter. Reads yearly
#          files one at a time and keeps only the variables needed by
#          02_clean_demographics.R, plus optional extras.
#
# Input:   data/raw/cps_*_YYYY.dta  (one file per ASEC survey year)
# Output:  output/cps_asec.rds
#          output/cps_asec_from_r.dta  (optional R export for Stata users)
#
# Usage:   Run from march_cps/, march_cps/code/, from the repo root,
#          or set cps_root_manual / CPS_ROOT explicitly.
################################################################################

library(haven)
library(dplyr)
library(tidyselect)

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
      "extra_var_families output name '", output_name,
      "' already exists in the data. Choose a different family name.",
      call. = FALSE
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
years_to_load <- NULL

# To run a smaller smoke test without editing this file:
#   Sys.setenv(CPS_YEARS = "2021,2022")
#   Sys.setenv(CPS_YEARS = "2021:2025")
env_years <- Sys.getenv("CPS_YEARS", unset = "")
if (nzchar(env_years)) {
  years_to_load <- parse_years(env_years)
}
if (is.null(years_to_load)) {
  years_to_load <- seq(first_year, last_year)
}

# Replicate weights are useful for variance estimation but add many columns.
keep_replicate_weights <- FALSE

# Add extra stable IPUMS variable names here, e.g. c("diffhear", "diffeye").
extra_keep_vars <- character()

# Add cross-year raw variable families here when names differ by year.
# The list name becomes the merged output column name in cps_asec.rds.
# IMPORTANT: This only merges raw aliases into one column. If the coding or
# meaning of your added variable changes across years, harmonize that variable
# later in 02_clean_demographics.R / .do or in your analysis code.
# Example:
# extra_var_families <- list(
#   employer_plan = c("covergh", "grpdeply")
# )
extra_var_families <- list()

overwrite_temp_files <- TRUE
cleanup_temp_files <- TRUE
write_dta_export <- TRUE

# Core starter variables ------------------------------------------------------

base_keep_vars <- normalize_var_names(c(
  "year", "serial", "pernum", "cpsidp", "cpsid", "cpsidv",
  "asecwt", "statefip",
  "age", "sex", "race", "hispan", "educ", "educ99", "schlcoll",
  "marst", "empstat", "labforce", "fullpart", "wkswork1",
  "inctot", "incwage", "incss", "incssi", "incwelfr", "incunemp",
  "incbus", "hhincome",
  "foodstmp",
  "phinsur", "himcaidly", "himcarely", "covergh", "anycovly", "anycovnw",
  "nativity", "citizen", "bpl", "yrimmig",
  "offpov", "offpovuniv", "offtotval", "offcutoff", "poverty", "cutoff"
))
repwt_vars <- paste0("repwtp", 1:160)
extra_keep_vars <- normalize_var_names(extra_keep_vars)
extra_var_families <- lapply(extra_var_families, normalize_var_names)

if (length(extra_var_families) > 0) {
  family_names <- names(extra_var_families)
  if (is.null(family_names) || any(!nzchar(family_names))) {
    stop("Each entry in extra_var_families must have a descriptive name.", call. = FALSE)
  }

  cat(
    paste(
      "[INFO] extra_var_families only merge raw aliases into one column.",
      "If coding or meanings change across years, harmonize that added variable",
      "later in 02_clean_demographics.R / .do or in your analysis code.\n"
    )
  )
}

family_alias_vars <- normalize_var_names(unlist(extra_var_families, use.names = FALSE))
selected_vars <- unique(c(
  base_keep_vars,
  if (keep_replicate_weights) repwt_vars else character(),
  extra_keep_vars,
  family_alias_vars
))
missing_report_vars <- unique(c(
  base_keep_vars,
  if (keep_replicate_weights) repwt_vars else character(),
  extra_keep_vars
))

# Load ------------------------------------------------------------------------

cps_root <- resolve_cps_root("01_load_and_subset_optional_low_memory.R")
raw_dir <- file.path(cps_root, "data", "raw")
out_dir <- file.path(cps_root, "output")
tmp_dir <- file.path(out_dir, "_tmp_low_memory")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)

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

cat("Using yearly CPS ASEC files for low-memory load:\n")
for (i in seq_len(nrow(yearly_files))) {
  cat(" - ", yearly_files$year[i], ": ", basename(yearly_files$file[i]), "\n", sep = "")
}

missing_by_year <- list()
temp_files <- character(nrow(yearly_files))
extra_found_any_year <- setNames(logical(length(extra_keep_vars)), extra_keep_vars)
family_found_any_year <- setNames(logical(length(extra_var_families)), names(extra_var_families))
family_year_matches <- setNames(vector("list", length(extra_var_families)), names(extra_var_families))

for (i in seq_len(nrow(yearly_files))) {
  year <- yearly_files$year[i]
  path <- yearly_files$file[i]
  tmp_rds <- file.path(tmp_dir, paste0("cps_", year, "_selected.rds"))
  temp_files[i] <- tmp_rds

  if (file.exists(tmp_rds) && !overwrite_temp_files) {
    cat("Reusing temp file for ", year, ": ", tmp_rds, "\n", sep = "")
    next
  }

  cat("Reading selected columns for ", year, ": ", basename(path), "\n", sep = "")
  cps_year <- read_dta(
    path,
    col_select = any_of(unique(c(selected_vars, toupper(selected_vars))))
  )
  names(cps_year) <- tolower(names(cps_year))

  missing_selected <- setdiff(missing_report_vars, names(cps_year))
  if (length(missing_selected) > 0) {
    missing_by_year[[as.character(year)]] <- missing_selected
  }

  if (length(extra_keep_vars) > 0) {
    extra_found_any_year[names(extra_found_any_year) %in% intersect(extra_keep_vars, names(cps_year))] <- TRUE
  }
  if (length(extra_var_families) > 0) {
    for (family_name in names(extra_var_families)) {
      if (any(extra_var_families[[family_name]] %in% names(cps_year))) {
        family_found_any_year[family_name] <- TRUE
        family_year_matches[[family_name]] <- sort(unique(c(family_year_matches[[family_name]], year)))
      }
    }
  }

  required_loader_vars <- c("year", "serial", "pernum")
  missing_required <- setdiff(required_loader_vars, names(cps_year))
  if (length(missing_required) > 0) {
    stop(
      "Required variable(s) missing from ", basename(path), ": ",
      paste(missing_required, collapse = ", "),
      call. = FALSE
    )
  }

  unexpected_years <- setdiff(unique(cps_year$year), year)
  unexpected_years <- unexpected_years[!is.na(unexpected_years)]
  if (length(unexpected_years) > 0) {
    stop(
      basename(path), " contains YEAR values other than ", year, ": ",
      paste(unexpected_years, collapse = ", "),
      call. = FALSE
    )
  }

  cps_year <- cps_year %>%
    mutate(individ = year * 10000000 + serial * 100 + pernum) %>%
    arrange(year, serial, pernum)

  if (anyDuplicated(cps_year$individ) > 0) {
    stop("Duplicate individ values found in ", basename(path), call. = FALSE)
  }

  saveRDS(cps_year, tmp_rds)
  cat("  saved temp file: ", tmp_rds, "\n", sep = "")
  rm(cps_year)
  gc(verbose = FALSE)
}

if (length(missing_by_year) > 0) {
  cat("\nVariables not found in at least one yearly extract:\n")
  for (year in names(missing_by_year)) {
    cat(" - ", year, ": ", paste(missing_by_year[[year]], collapse = ", "), "\n", sep = "")
  }
  cat("\n")
}

cat("Appending selected yearly files...\n")
cps <- bind_rows(lapply(temp_files, readRDS)) %>%
  arrange(year, serial, pernum)

if (length(extra_var_families) > 0) {
  for (family_name in names(extra_var_families)) {
    cps <- coalesce_family_columns(cps, family_name, extra_var_families[[family_name]])
  }
}

if (anyDuplicated(cps$individ) > 0) {
  stop("Duplicate individ values found. Check year, serial, and pernum.", call. = FALSE)
}

out_rds <- file.path(out_dir, "cps_asec.rds")
out_dta <- file.path(out_dir, "cps_asec_from_r.dta")

saveRDS(cps, out_rds)
cat("Saved:", out_rds, "\n")

if (write_dta_export) {
  tryCatch({
    write_dta(cps, out_dta)
    cat("Saved optional R .dta export:", out_dta, "\n")
  }, error = function(e) {
    cat("Could not save .dta:", e$message, "\n")
  })
}

if (cleanup_temp_files) {
  unlink(temp_files)
  if (length(list.files(tmp_dir, all.files = FALSE, no.. = TRUE)) == 0) {
    unlink(tmp_dir, recursive = TRUE)
  }
}

cat("Observations:", nrow(cps), "\n")
cat("Variables:", ncol(cps), "\n")
cat("Year range:", min(cps$year, na.rm = TRUE), "to", max(cps$year, na.rm = TRUE), "\n")

if (length(extra_keep_vars) > 0) {
  missing_extra <- names(extra_found_any_year)[!extra_found_any_year]
  if (length(missing_extra) == 0) {
    cat("[PASS] All extra_keep_vars were found in at least one loaded year\n")
  } else {
    cat("[WARN] Some extra_keep_vars were never found:", paste(missing_extra, collapse = ", "), "\n")
  }
}

if (length(extra_var_families) > 0) {
  missing_families <- names(family_found_any_year)[!family_found_any_year]
  for (family_name in names(family_year_matches)) {
    matched_years <- family_year_matches[[family_name]]
    if (length(matched_years) > 0) {
      cat("[INFO] extra_var_family '", family_name, "' matched in year(s): ",
          paste(matched_years, collapse = ", "), "\n", sep = "")
    }
  }
  if (length(missing_families) == 0) {
    cat("[PASS] All extra_var_families matched at least one loaded year\n")
  } else {
    cat("[WARN] Some extra_var_families never matched:",
        paste(missing_families, collapse = ", "), "\n")
  }
}

cat("\nNext step: run 02_clean_demographics.R\n")
