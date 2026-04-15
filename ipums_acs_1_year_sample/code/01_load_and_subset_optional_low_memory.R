################################################################################
# 01_load_and_subset_optional_low_memory.R
#
# Purpose: Optional low-memory alternative to 01_load_and_subset.R.
#          Reads one yearly ACS file at a time, keeps only the raw columns
#          needed by 02_clean_demographics.R plus any user-requested extras,
#          writes temporary yearly files, and then appends them into the usual
#          output/acs_working.rds file.
#
# Important: This script is designed for the standard starter workflow.
#            It does NOT import the full ACS raw file. If you need many extra
#            raw variables beyond the starter workflow, use
#            01_load_and_subset.R instead.
#
# Input:   data/raw/acs_YYYY.dta
# Output:  output/acs_working.rds
#          output/acs_working_from_r.dta (optional)
#          output/_tmp_low_memory/*.rds (temporary yearly files)
#
# Usage:   Run from ipums_acs_1_year_sample/, ipums_acs_1_year_sample/code/,
#          or the repo root. You can also set ACS_ROOT explicitly.
#
# Author:  Austin Denteh (legacy code), Claude Code, and Codex
# Date:    April 2026
################################################################################

library(haven)
library(dplyr)

resolve_acs_root <- function(script_name) {
  env_root <- Sys.getenv("ACS_ROOT", unset = "")
  candidates <- c(
    if (nzchar(env_root)) env_root,
    getwd(),
    dirname(getwd()),
    file.path(getwd(), "ipums_acs_1_year_sample")
  )
  candidates <- unique(candidates[nzchar(candidates)])

  for (candidate in candidates) {
    if (dir.exists(candidate) &&
        file.exists(file.path(candidate, "README.md")) &&
        file.exists(file.path(candidate, "code", script_name))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }

  stop(
    paste(
      "Could not locate the ipums_acs_1_year_sample/ directory.",
      "Run this script from ipums_acs_1_year_sample/, ipums_acs_1_year_sample/code/,",
      "from the repo root, or set ACS_ROOT to the dataset path."
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
  years <- sort(unique(years))
  if (length(years) == 0) {
    return("no years")
  }
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
# This script is optional. Most users should keep using 01_load_and_subset.R.
# Use this version if loading many ACS years exhausts RAM on your machine.
#
# What this script does:
#   1. Reads one yearly ACS file at a time
#   2. Keeps only the raw columns needed by 02_clean_demographics.R
#   3. Saves a temporary yearly .rds file
#   4. Appends those yearly files into output/acs_working.rds
#
# What this script does NOT do:
#   - It does not keep the full ACS raw files in memory
#   - It does not clean or harmonize variables itself
#   - It does not automatically harmonize extra user-added variables
#   - It only merges user-added alias families; it does not recode changing
#     meanings or value definitions across years
#
# Important:
#   - This script expects yearly files named data/raw/acs_YYYY.dta
#   - It reduces memory pressure during import, but the final combined ACS
#     working file must still fit once appended

# Choose either a consecutive year range or an explicit year list.
# If years_to_load is not NULL, it overrides first_year/last_year.
# Example:
# years_to_load <- c(2015, 2016, 2018, 2024)
years_to_load <- NULL

# Consecutive-year option.
first_year <- 2023
last_year  <- 2024

# If TRUE, delete and rebuild the temporary low-memory folder each time.
overwrite_temp_files <- TRUE

# If TRUE, remove output/_tmp_low_memory/ after a successful run.
cleanup_temp_files <- TRUE

# If TRUE, also write a Stata export of the reduced appended dataset.
# This uses the same non-colliding export name as the main R loader.
write_dta_export <- FALSE

# Add stable raw variable names here if you want extra columns carried forward.
# Example:
# extra_keep_vars <- c("ageimmig", "english")
extra_keep_vars <- c()

# Add cross-year raw variable families here when names differ by year.
# The list name becomes the merged output column name in acs_working.rds.
# IMPORTANT: This only merges raw aliases into one column. If the coding or
# meaning of your added variable changes across years, you must harmonize that
# variable later in 02_clean_demographics.R / .do or in your analysis code.
# Example:
# extra_var_families <- list(
#   language_primary = c("language", "languaged")
# )
extra_var_families <- list()

# ============================================================================
# 1. DEFINE PATHS
# ============================================================================

acs_root <- resolve_acs_root("01_load_and_subset_optional_low_memory.R")
cat(paste0("Using ACS root: ", acs_root, "\n"))

raw_dir  <- file.path(acs_root, "data", "raw")
out_rds  <- file.path(acs_root, "output", "acs_working.rds")
out_dta  <- file.path(acs_root, "output", "acs_working_from_r.dta")
temp_dir <- file.path(acs_root, "output", "_tmp_low_memory")

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

core_keep_vars <- normalize_var_names(c(
  "year", "sample", "serial", "pernum", "perwt", "hhwt",
  "cluster", "strata",
  "statefip", "countyfip", "puma", "gq",
  "age", "sex", "race", "hispan", "marst",
  "educ", "educd",
  "empstat", "incwage", "poverty",
  "hcovany", "hcovpriv", "hcovpub", "hinscaid", "hinscare",
  "citizen", "bpl"
))

required_loader_vars <- c("year", "sample", "serial", "pernum")
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
      "later in 02_clean_demographics.R / .do or in your analysis code.\n"
    )
  )
}

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
cat(paste0("   LOW-MEMORY ACS LOAD (", year_label, ")\n"))
cat("============================================\n\n")

temp_files <- character(0)

load_one_year_low_memory <- function(yr) {
  year_file <- file.path(raw_dir, paste0("acs_", yr, ".dta"))

  if (!file.exists(year_file)) {
    stop(paste("Required yearly ACS file not found:", year_file))
  }

  cat(paste0("--- Year ", yr, " ---\n"))

  header <- read_dta(year_file, n_max = 0)
  header_raw <- names(header)
  header_lower <- tolower(header_raw)

  missing_required <- required_loader_vars[!required_loader_vars %in% header_lower]
  if (length(missing_required) > 0) {
    stop(
      paste(
        "Yearly file is missing required variables:",
        paste(missing_required, collapse = ", "),
        "\nFile:", year_file
      )
    )
  }

  keep_raw <- header_raw[header_lower %in% target_keep_vars]
  if (length(keep_raw) == 0) {
    stop(paste("No requested columns were found in:", year_file))
  }

  df <- read_dta(year_file, col_select = tidyselect::all_of(keep_raw))
  names(df) <- tolower(names(df))

  if ("year" %in% names(df)) {
    df$year <- as.integer(haven::zap_labels(df$year))
  }
  if ("sample" %in% names(df)) {
    df$sample <- as.integer(haven::zap_labels(df$sample))
  }

  expected_sample <- yr * 100 + 1
  if (!all(df$year == yr, na.rm = TRUE)) {
    stop(
      paste(
        "Year check failed for", basename(year_file),
        "- expected all rows to have year =", yr
      )
    )
  }
  if (!all(df$sample == expected_sample, na.rm = TRUE)) {
    stop(
      paste(
        "Sample check failed for", basename(year_file),
        "- expected all rows to have sample =", expected_sample
      )
    )
  }

  df <- df %>%
    mutate(individ = sample * 10000000000 + serial * 100 + pernum)

  if (dplyr::n_distinct(df$individ) != nrow(df)) {
    stop(
      paste(
        "Unique record ID check failed for", basename(year_file),
        "- individ is not unique within the yearly file."
      )
    )
  }

  temp_file <- file.path(temp_dir, paste0("acs_", yr, "_selected.rds"))
  saveRDS(df, temp_file)

  loaded_columns <- names(df)
  list(
    temp_file = temp_file,
    loaded_columns = loaded_columns,
    extra_hits = extra_keep_vars[extra_keep_vars %in% loaded_columns],
    family_hits = names(extra_var_families)[vapply(
      extra_var_families,
      function(family_vars) any(family_vars %in% loaded_columns),
      logical(1)
    )],
    n = nrow(df),
    k = ncol(df)
  )
}

for (yr in years) {
  result <- load_one_year_low_memory(yr)
  temp_files <- c(temp_files, result$temp_file)
  loaded_columns_any_year <- union(loaded_columns_any_year, result$loaded_columns)

  if (length(result$extra_hits) > 0) {
    extra_found_any_year[result$extra_hits] <- TRUE
  }
  if (length(result$family_hits) > 0) {
    family_found_any_year[result$family_hits] <- TRUE
    for (family_name in result$family_hits) {
      family_year_matches[[family_name]] <- sort(unique(c(family_year_matches[[family_name]], yr)))
    }
  }

  cat(
    paste0(
      "  Imported ", yr, ": ",
      format(result$n, big.mark = ","), " observations, ",
      result$k, " selected variables\n"
    )
  )
}

# ============================================================================
# 4. APPEND TEMP FILES
# ============================================================================

cat("\nAppending selected yearly files...\n")
acs <- bind_rows(lapply(temp_files, readRDS))

if (length(extra_var_families) > 0) {
  for (family_name in names(extra_var_families)) {
    acs <- coalesce_family_columns(acs, family_name, extra_var_families[[family_name]])
  }
}

acs <- acs %>% arrange(year, serial, pernum)

cat(sprintf("Total observations: %s\n", format(nrow(acs), big.mark = ",")))
cat(sprintf("Total selected variables: %d\n", ncol(acs)))

# ============================================================================
# 5. SAVE OUTPUT
# ============================================================================

cat("\n============================================\n")
cat("   SAVING LOW-MEMORY WORKING DATASET\n")
cat("============================================\n")

saveRDS(acs, out_rds)
cat(sprintf("Saved: %s\n", out_rds))

if (write_dta_export) {
  write_dta(acs, out_dta)
  cat(sprintf("Saved: %s\n", out_dta))
}

# ============================================================================
# 6. VALIDATION AND USER FEEDBACK
# ============================================================================

cat("\n============================================\n")
cat("   VALIDATION CHECKS\n")
cat("============================================\n")

cat("\n[INFO] Observations per year:\n")
year_tab <- acs %>% count(year) %>% mutate(pct = round(n / sum(n) * 100, 1))
print(as.data.frame(year_tab), row.names = FALSE)

loaded_years <- sort(unique(acs$year))
if (identical(loaded_years, years)) {
  cat(sprintf("[PASS] Loaded years match request: %s\n", make_year_label(loaded_years)))
} else {
  cat(sprintf(
    "[FAIL] Expected years %s but found %s\n",
    make_year_label(years),
    make_year_label(loaded_years)
  ))
}

core_family_names <- list(
  identifiers = c("year", "sample", "serial", "pernum", "individ"),
  survey_design = c("perwt", "hhwt", "cluster", "strata"),
  geography = c("statefip", "countyfip", "puma"),
  demographics = c("age", "sex", "race", "hispan", "marst"),
  education = c("educ", "educd"),
  economics = c("empstat", "incwage", "poverty"),
  insurance = c("hcovany", "hcovpriv", "hcovpub", "hinscaid", "hinscare"),
  immigration = c("citizen", "bpl")
)

for (family_name in names(core_family_names)) {
  family_vars <- core_family_names[[family_name]]
  found_family <- any(family_vars %in% loaded_columns_any_year)
  if (found_family) {
    cat(sprintf("[PASS] Found a supported %s variable family\n", family_name))
  } else {
    cat(sprintf("[FAIL] Missing the %s variable family\n", family_name))
  }
}

if (length(extra_keep_vars) > 0) {
  missing_extra <- extra_keep_vars[!extra_found_any_year]
  if (length(missing_extra) == 0) {
    cat("[PASS] All extra_keep_vars were found in at least one loaded year\n")
  } else {
    cat(sprintf(
      "[WARN] Some extra_keep_vars were never found: %s\n",
      paste(missing_extra, collapse = ", ")
    ))
  }
}

if (length(extra_var_families) > 0) {
  missing_families <- names(family_found_any_year)[!family_found_any_year]
  for (family_name in names(family_year_matches)) {
    matched_years <- family_year_matches[[family_name]]
    if (length(matched_years) > 0) {
      cat(sprintf(
        "[INFO] extra_var_family '%s' matched in year(s): %s\n",
        family_name,
        make_year_label(matched_years)
      ))
    }
  }
  if (length(missing_families) == 0) {
    cat("[PASS] All extra_var_families matched at least one loaded year\n")
  } else {
    cat(sprintf(
      "[WARN] Some extra_var_families never matched: %s\n",
      paste(missing_families, collapse = ", ")
    ))
  }
}

# ============================================================================
# 7. CLEAN UP TEMP FILES (OPTIONAL)
# ============================================================================

if (cleanup_temp_files) {
  unlink(temp_dir, recursive = TRUE, force = TRUE)
  cat(sprintf("\nRemoved temporary folder: %s\n", temp_dir))
} else {
  cat(sprintf("\nTemporary files kept in: %s\n", temp_dir))
}

cat("\n============================================\n")
cat("   LOW-MEMORY LOAD COMPLETE\n")
cat("============================================\n")
cat(sprintf("  Observations: %s\n", format(nrow(acs), big.mark = ",")))
cat(sprintf("  Variables:    %d\n", ncol(acs)))
cat("\nNext step: run 02_clean_demographics.R\n")
