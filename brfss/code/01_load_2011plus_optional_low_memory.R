################################################################################
# 01_load_2011plus_optional_low_memory.R
#
# Purpose: Optional low-memory alternative to 01_load_2011plus.R.
#          Reads one BRFSS year at a time, keeps only the raw columns needed by
#          02_clean_2011plus.R plus any user-requested extras, writes
#          temporary yearly files, and then appends them into the usual
#          output/brfss_2011plus_appended.rds file.
#
# Important: This script is designed for the standard starter workflow.
#            It does NOT import the full BRFSS raw file. If you need many extra
#            raw variables or optional-module variables, use
#            01_load_2011plus.R instead.
#
# Input:   data/raw/LLCP20XX.XPT
# Output:  output/brfss_2011plus_appended.rds
#          output/brfss_2011plus_appended_low_memory_from_r.dta (optional)
#          output/_tmp_low_memory/*.rds (temporary yearly files)
#
# Usage:   Run from brfss/, from the repo root, or set BRFSS_ROOT explicitly.
#
# Author:  Austin Denteh (legacy code), Claude Code, and Codex
# Date:    April 2026
################################################################################

library(haven)      # read_xpt(), write_dta()
library(dplyr)      # bind_rows(), arrange()
library(purrr)      # map(), compact()

resolve_brfss_root <- function(script_name) {
  env_root <- Sys.getenv("BRFSS_ROOT", unset = "")

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
  candidates <- c(env_root, search_paths, file.path(search_paths, "brfss"))
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
      "Could not locate the brfss/ directory.",
      "Run this script from brfss/, brfss/code/, from the repo root,",
      "or set BRFSS_ROOT to the brfss path.",
      paste0("Current working directory: ", getwd()),
      'Manual override: Sys.setenv(BRFSS_ROOT = "/path/to/brfss")'
    )
  )
}

normalize_var_names <- function(x) {
  x <- unname(x)
  x <- x[nzchar(x)]
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

make_year_label <- function(years) {
  if (length(years) == 0) {
    return("no years")
  }

  years <- sort(unique(years))
  if (length(years) == 1) {
    return(as.character(years))
  }

  if (identical(years, seq.int(min(years), max(years)))) {
    return(paste0(min(years), "-", max(years)))
  }

  paste(years, collapse = ", ")
}

# ============================================================================
# USER SETTINGS
# ============================================================================
# This script is optional. Most users should keep using 01_load_2011plus.R.
# Use this version if loading many BRFSS years exhausts RAM on your machine.
#
# What this script does:
#   1. Reads one year at a time
#   2. Keeps only the raw columns needed by 02_clean_2011plus.R
#   3. Saves a temporary yearly .rds file
#   4. Appends those yearly files into output/brfss_2011plus_appended.rds
#
# What this script does NOT do:
#   - It does not import the full BRFSS raw file
#   - It does not harmonize variables itself
#   - It does not automatically harmonize extra user-added variables
#   - It only merges user-added alias families; it does not recode changing
#     meanings or value definitions across years
#
# If you need many extra raw variables or optional-module variables, use the
# standard 01_load_2011plus.R workflow instead.

# Choose either a consecutive year range or an explicit year list.
# If years_to_load is not NULL, it overrides first_year/last_year.
# Example:
# years_to_load <- c(2012, 2014, 2018, 2024)
years_to_load <- NULL

# Consecutive-year option.
first_year <- 2023
last_year  <- 2024

env_years <- Sys.getenv("BRFSS_YEARS", unset = "")
if (nzchar(env_years)) {
  years_to_load <- as.integer(strsplit(env_years, "[,[:space:]]+")[[1]])
}

# If TRUE, delete and rebuild the temporary low-memory folder each time.
overwrite_temp_files <- TRUE

# If TRUE, remove output/_tmp_low_memory/ after a successful run.
cleanup_temp_files <- TRUE

# If TRUE, also write a Stata export of the reduced appended dataset.
# This uses a separate filename so it does not overwrite the standard export.
write_dta_export <- FALSE

# Add stable raw variable names here if you want extra columns carried forward.
# Example:
# extra_keep_vars <- c("sleptim1", "internet")
extra_keep_vars <- c()

# Add cross-year raw variable families here when names differ by year.
# The list name becomes the merged output column name in brfss_2011plus_appended.rds.
# IMPORTANT: This only merges raw aliases into one column. If the coding or
# meaning of your added variable changes across years, you must harmonize that
# variable later in 02_clean_2011plus.R / .do or in your analysis code.
# Example:
# extra_var_families <- list(
#   sleep_hours = c("sleptim1", "sleptim2"),
#   internet_use = c("internet", "intern2"),
#   dental_visit = c("_denvst2", "_denvst3")
# )
extra_var_families <- list()

# ============================================================================
# 1. DEFINE PATHS
# ============================================================================
# Auto-detect the dataset root from the current working directory.
#
# Optional manual override if auto-detection fails:
# Sys.setenv(BRFSS_ROOT = "/path/to/brfss")

brfss_root <- resolve_brfss_root("01_load_2011plus_optional_low_memory.R")
cat(paste0("Using BRFSS root: ", brfss_root, "\n"))

raw_dir  <- file.path(brfss_root, "data", "raw")
output_override <- Sys.getenv("BRFSS_OUTPUT_DIR", unset = "")
out_dir <- if (nzchar(output_override)) output_override else file.path(brfss_root, "output")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_rds  <- file.path(out_dir, "brfss_2011plus_appended.rds")
out_dta  <- file.path(out_dir, "brfss_2011plus_appended_low_memory_from_r.dta")
temp_dir <- file.path(out_dir, "_tmp_low_memory")

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
# 2. DEFINE CORE KEEP LIST
# ============================================================================

core_keep_families <- list(
  survey_design = c("_psu", "_ststr", "_llcpwt"),
  geography = c("_state", "ctycode1"),
  record_id = c("seqno"),
  interview_timing = c("imonth", "iyear"),
  demographics = c(
    "_impage", "_age80", "_ageg5yr",
    "sex", "sexvar", "birthsex",
    "_racegr2", "_racegr3", "_racegr4",
    "educa", "marital", "income2", "income3", "employ", "employ1"
  ),
  health = c(
    "genhlth", "menthlth", "physhlth",
    "_bmi5", "_bmi5cat", "_smoker3",
    "diabete3", "diabete4", "asthma3", "asthnow",
    "cvdcrhd4", "cvdinfr4",
    "chccopd", "chccopd1", "chccopd3"
  )
)

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
      "later in 02_clean_2011plus.R / .do or in your analysis code.\n"
    )
  )
}

core_keep_vars <- normalize_var_names(unlist(core_keep_families, use.names = FALSE))
target_keep_vars <- unique(c(
  core_keep_vars,
  extra_keep_vars,
  normalize_var_names(unlist(extra_var_families, use.names = FALSE))
))

if (!is.null(years_to_load)) {
  years <- sort(unique(as.integer(years_to_load)))
  if (length(years) == 0 || any(is.na(years))) {
    stop("years_to_load must contain one or more valid numeric years.")
  }
} else {
  years <- first_year:last_year
}

year_label <- make_year_label(years)
loaded_columns_any_year <- character(0)
extra_found_any_year <- setNames(logical(length(extra_keep_vars)), extra_keep_vars)
family_found_any_year <- setNames(logical(length(extra_var_families)), names(extra_var_families))
family_year_matches <- setNames(vector("list", length(extra_var_families)), names(extra_var_families))

# ============================================================================
# 3. LOAD EACH YEAR, KEEP SELECTED COLUMNS, SAVE TEMP FILES
# ============================================================================

cat("============================================\n")
cat(paste0("   LOW-MEMORY BRFSS LOAD (", year_label, ")\n"))
cat("============================================\n\n")

load_one_year_low_memory <- function(yr) {
  xpt_file <- file.path(raw_dir, paste0("LLCP", yr, ".XPT"))

  if (!file.exists(xpt_file)) {
    warning(paste("File not found for year", yr, ":", xpt_file))
    return(NULL)
  }

  cat(paste0("--- Year ", yr, " ---\n"))

  header <- read_xpt(xpt_file, n_max = 0)
  header_raw   <- names(header)
  header_lower <- tolower(header_raw)
  keep_raw     <- header_raw[header_lower %in% target_keep_vars]

  if (length(keep_raw) == 0) {
    warning(paste("No requested columns were found for year", yr))
    return(NULL)
  }

  df <- read_xpt(
    xpt_file,
    col_select = tidyselect::all_of(keep_raw)
  )
  names(df) <- tolower(names(df))
  df$surveyyear <- yr

  temp_file <- file.path(temp_dir, paste0("brfss_", yr, "_selected.rds"))
  saveRDS(df, temp_file)

  cat(paste0("  Imported ", yr, ": ", nrow(df), " observations, ",
             ncol(df), " selected variables\n"))

  list(
    year = yr,
    temp_file = temp_file,
    n = nrow(df),
    k = ncol(df),
    header_lower = header_lower
  )
}

year_info <- map(years, load_one_year_low_memory)
year_info <- compact(year_info)

if (length(year_info) == 0) {
  stop("No BRFSS years were loaded. Check your raw files and year settings.")
}

for (info in year_info) {
  loaded_columns_any_year <- unique(c(loaded_columns_any_year, info$header_lower))

  if (length(extra_keep_vars) > 0) {
    extra_found_any_year[names(extra_found_any_year) %in% intersect(extra_keep_vars, info$header_lower)] <- TRUE
  }

  if (length(extra_var_families) > 0) {
    for (family_name in names(extra_var_families)) {
      if (any(extra_var_families[[family_name]] %in% info$header_lower)) {
        family_found_any_year[family_name] <- TRUE
        family_year_matches[[family_name]] <- c(family_year_matches[[family_name]], info$year)
      }
    }
  }
}

# ============================================================================
# 4. APPEND TEMP FILES
# ============================================================================

cat("\nAppending selected yearly files...\n")

brfss <- NULL
for (info in year_info) {
  df <- readRDS(info$temp_file)
  brfss <- if (is.null(brfss)) df else bind_rows(brfss, df)
  rm(df)
  gc()
}

if (length(extra_var_families) > 0) {
  for (family_name in names(extra_var_families)) {
    brfss <- coalesce_family_columns(
      df = brfss,
      output_name = family_name,
      candidate_vars = extra_var_families[[family_name]]
    )
  }
}

brfss <- brfss %>% arrange(surveyyear)

cat(paste0("Total observations: ", nrow(brfss), "\n"))
cat(paste0("Total selected variables: ", ncol(brfss), "\n"))

# ============================================================================
# 5. SAVE OUTPUTS
# ============================================================================

cat("\n============================================\n")
cat("   SAVING LOW-MEMORY APPENDED DATASET\n")
cat("============================================\n\n")

saveRDS(brfss, out_rds)
cat(paste0("Saved: ", out_rds, "\n"))

if (write_dta_export) {
  tryCatch({
    write_dta(brfss, out_dta)
    cat(paste0("Saved: ", out_dta, "\n"))
  }, error = function(e) {
    cat(paste0("Could not save .dta export: ", e$message, "\n"))
    cat("The .rds file was saved successfully.\n")
  })
}

# ============================================================================
# 6. VALIDATION AND USER FEEDBACK
# ============================================================================

cat("\n============================================\n")
cat("   VALIDATION CHECKS\n")
cat("============================================\n\n")

year_counts <- brfss %>% count(surveyyear)
print(as.data.frame(year_counts), row.names = FALSE)

loaded_years <- sort(unique(brfss$surveyyear))
if (identical(loaded_years, years)) {
  cat(paste0("\n[PASS] Loaded years match request: ", make_year_label(loaded_years), "\n"))
} else {
  cat(paste0("\n[FAIL] Expected years ", year_label,
             " but found ", make_year_label(loaded_years), "\n"))
}

core_family_found <- vapply(
  core_keep_families,
  function(vars) any(vars %in% loaded_columns_any_year),
  logical(1)
)

for (family_name in names(core_family_found)) {
  if (core_family_found[[family_name]]) {
    cat(paste0("[PASS] Found a supported ", family_name, " variable family\n"))
  } else {
    cat(paste0("[FAIL] Missing the ", family_name, " variable family\n"))
  }
}

if (length(extra_keep_vars) > 0) {
  missing_extra <- names(extra_found_any_year)[!extra_found_any_year]
  if (length(missing_extra) == 0) {
    cat("[PASS] All extra_keep_vars were found in at least one loaded year\n")
  } else {
    cat(paste0("[WARN] Some extra_keep_vars were never found: ",
               paste(missing_extra, collapse = ", "), "\n"))
  }
}

if (length(extra_var_families) > 0) {
  missing_families <- names(family_found_any_year)[!family_found_any_year]
  if (length(missing_families) == 0) {
    cat("[PASS] All extra_var_families were matched in at least one loaded year\n")
  } else {
    cat(paste0("[WARN] Some extra_var_families were never matched: ",
               paste(missing_families, collapse = ", "), "\n"))
  }

  for (family_name in names(family_year_matches)) {
    matched_years <- sort(unique(family_year_matches[[family_name]]))
    if (length(matched_years) > 0) {
      cat(paste0("[INFO] extra_var_families$", family_name,
                 " matched in years: ", make_year_label(matched_years), "\n"))
    }
  }
}

if (cleanup_temp_files) {
  unlink(temp_dir, recursive = TRUE, force = TRUE)
  cat(paste0("[INFO] Removed temporary folder: ", temp_dir, "\n"))
} else {
  cat(paste0("[INFO] Temporary files kept in: ", temp_dir, "\n"))
}

cat("\n============================================\n")
cat("   VALIDATION COMPLETE\n")
cat("============================================\n")
cat("\nNext step: run 02_clean_2011plus.R\n")

################################################################################
# NOTES FOR USERS:
#
# 1. SAME NEXT STEP: The output is still brfss_2011plus_appended.rds, so you
#    can run 02_clean_2011plus.R exactly as usual after this script.
#
# 2. EXTRA VARIABLES: extra_keep_vars are best when a variable name is stable
#    across years. extra_var_families are best when the raw names differ by
#    year. Each family definition creates one merged output column by filling
#    from the listed aliases in order. This does NOT recode changing meanings
#    or value definitions for you.
#
# 3. USE THE FULL SCRIPT WHEN NEEDED: If your project depends on many raw BRFSS
#    columns or optional-module variables, use 01_load_2011plus.R instead.
################################################################################
