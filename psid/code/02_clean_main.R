################################################################################
# 02_clean_main.R
#
# Purpose: Add a few safe starter flags to the PSID person-year file created by
#          01_load_main.R. Substantive harmonization belongs in project-specific
#          analysis code after consulting PSID codebooks.
#
# Input:   output/psid_person_year.rds
# Output:  output/psid_person_year_clean.rds
################################################################################

library(dplyr)
library(haven)

# ============================================================================
# 1. USER SETTINGS
# ============================================================================
#
# Edit these defaults here, or set the same objects before calling source().
# Examples:
#   psid_output_dir <- "/private/tmp/psid_smoke"
#   psid_output_basename <- "psid_smoke"
#   psid_create_core_clean_vars <- FALSE
#   psid_run_examples <- TRUE

if (!exists("psid_root_manual", inherits = TRUE)) {
  psid_root_manual <- NULL
}
if (!exists("psid_output_dir", inherits = TRUE)) {
  psid_output_dir <- NULL
}
if (!exists("psid_output_basename", inherits = TRUE)) {
  psid_output_basename <- "psid"
}
if (!exists("psid_write_dta_export", inherits = TRUE)) {
  psid_write_dta_export <- FALSE
}
if (!exists("psid_run_examples", inherits = TRUE)) {
  psid_run_examples <- FALSE
}
if (!exists("psid_create_core_clean_vars", inherits = TRUE)) {
  psid_create_core_clean_vars <- TRUE
}

# ============================================================================
# 2. PATH HELPERS
# ============================================================================

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

resolve_psid_root <- function(script_name) {
  env_root <- Sys.getenv("PSID_ROOT", unset = "")
  search_roots <- c(getwd(), get_current_script_dir())
  search_paths <- unique(unlist(lapply(search_roots, parent_paths), use.names = FALSE))
  candidates <- c(psid_root_manual, env_root, search_paths, file.path(search_paths, "psid"))
  candidates <- unique(candidates[!is.na(candidates) & nzchar(candidates)])

  for (path in candidates) {
    path_norm <- normalizePath(path, winslash = "/", mustWork = FALSE)
    if (file.exists(file.path(path_norm, "README.md")) &&
        file.exists(file.path(path_norm, "code", script_name))) {
      return(path_norm)
    }
  }

  stop(
    "Could not locate the psid/ directory. Run from psid/, psid/code/, ",
    "repo root, or set psid_root_manual / PSID_ROOT.",
    call. = FALSE
  )
}

psid_root <- resolve_psid_root("02_clean_main.R")
if (is.null(psid_output_dir)) {
  psid_output_dir <- file.path(psid_root, "output")
}

person_in <- file.path(psid_output_dir, paste0(psid_output_basename, "_person_year.rds"))
person_out <- file.path(psid_output_dir, paste0(psid_output_basename, "_person_year_clean.rds"))
person_out_dta <- file.path(psid_output_dir, paste0(psid_output_basename, "_person_year_clean_from_r.dta"))

if (!file.exists(person_in)) {
  stop(
    "Could not find loader output:\n", person_in, "\n",
    "Run code/01_load_main.R first, or set psid_output_dir / psid_output_basename.",
    call. = FALSE
  )
}

person_year <- readRDS(person_in)

# ============================================================================
# 3. CLEAN STARTER SURFACE
# ============================================================================

to_numeric <- function(x) {
  suppressWarnings(as.numeric(x))
}

source_numeric <- function(data, var, min = -Inf, max = Inf, sentinels = numeric(0)) {
  if (!var %in% names(data)) {
    return(rep(NA_real_, nrow(data)))
  }
  out <- to_numeric(data[[var]])
  out[!is.finite(out)] <- NA_real_
  out[out %in% sentinels] <- NA_real_
  out[out < min | out > max] <- NA_real_
  out
}

source_binary <- function(data, var, true_values, false_values) {
  if (!var %in% names(data)) {
    return(rep(NA_integer_, nrow(data)))
  }
  x <- to_numeric(data[[var]])
  out <- rep(NA_integer_, length(x))
  out[x %in% true_values] <- 1L
  out[x %in% false_values] <- 0L
  out
}

clean <- person_year

if (isTRUE(psid_create_core_clean_vars)) {
  clean$sequence_number_clean <- source_numeric(clean, "sequence_number", min = 1, max = 99)
  clean$relation_to_head_clean <- source_numeric(clean, "relation_to_head", min = 0, max = 99)
  clean$family_size_clean <- source_numeric(clean, "family_size", min = 1, max = 50, sentinels = c(98, 99))
  clean$head_age_clean <- source_numeric(clean, "head_age", min = 0, max = 125, sentinels = c(998, 999))
  clean$age_individual_clean <- source_numeric(clean, "age_individual", min = 0, max = 125, sentinels = c(998, 999))
  clean$children_in_fu_clean <- source_numeric(clean, "children_in_fu", min = 0, max = 30, sentinels = c(98, 99))
  clean$age_youngest_child_clean <- source_numeric(clean, "age_youngest_child", min = 0, max = 30, sentinels = c(98, 99))
  clean$birth_month_clean <- source_numeric(clean, "month_individual_born", min = 1, max = 12, sentinels = c(98, 99))
  clean$birth_year_clean <- source_numeric(clean, "year_individual_born", min = 1800, max = 2026, sentinels = c(9998, 9999))
  clean$marital_pairs_indicator_clean <- source_numeric(clean, "marital_pairs_indicator", min = 0, max = 99)
  clean$move_month_clean <- source_numeric(clean, "month_moved_in_out", min = 1, max = 12, sentinels = c(98, 99))
  clean$move_year_clean <- source_numeric(clean, "year_moved_in_out", min = 1800, max = 2026, sentinels = c(9998, 9999))
  clean$education_years_clean <- source_numeric(clean, "years_completed_education", min = 0, max = 25, sentinels = c(98, 99))
  clean$current_state_clean <- source_numeric(clean, "current_state", min = 1, max = 99)
  clean$current_region_clean <- source_numeric(clean, "current_region", min = 1, max = 9)
  clean$metro_nonmetro_clean <- source_numeric(clean, "metro_nonmetro", min = 1, max = 9)
  clean$beale_rural_urban_clean <- source_numeric(clean, "beale_rural_urban", min = 1, max = 9)
  clean$head_total_work_hours_clean <- source_numeric(clean, "head_total_work_hours", min = 0, max = 8784, sentinels = c(9998, 9999))
  money_sentinels <- c(9999998, 9999999, 99999998, 99999999, 999999998, 999999999)
  clean$head_labor_income_clean <- source_numeric(clean, "head_labor_income", sentinels = money_sentinels)
  clean$food_expenditure_clean <- source_numeric(clean, "food_expenditure", min = 0, sentinels = money_sentinels)
  clean$total_family_income_clean <- source_numeric(clean, "total_family_income", sentinels = money_sentinels)

  clean$is_reference_person <- if_else(!is.na(clean$sequence_number_clean), clean$sequence_number_clean == 1, NA)
  clean$is_spouse_partner <- if_else(!is.na(clean$sequence_number_clean), clean$sequence_number_clean == 2, NA)
  clean$female <- source_binary(clean, "sex", true_values = 2, false_values = 1)
  clean$head_female <- source_binary(clean, "head_sex", true_values = 2, false_values = 1)
  clean$married_or_partnered <- source_binary(clean, "marital_status", true_values = 1, false_values = 2:5)
  clean$has_children_in_fu <- if_else(!is.na(clean$children_in_fu_clean), clean$children_in_fu_clean > 0, NA)
  clean$homeowner <- source_binary(clean, "housing_tenure", true_values = 1, false_values = c(5, 8))
  clean$renter <- source_binary(clean, "housing_tenure", true_values = 5, false_values = c(1, 8))
  clean$respondent <- source_binary(clean, "respondent_status", true_values = 1, false_values = 5)
  clean$changed_family_membership <- source_binary(
    clean,
    "moved_in_out",
    true_values = c(1, 2, 5, 6, 7, 8),
    false_values = 0
  )
  clean$employed <- source_binary(clean, "employment_status", true_values = 1, false_values = 2:8)
  clean$unemployed <- source_binary(clean, "employment_status", true_values = c(2, 3), false_values = c(1, 4:8))
  clean$not_in_labor_force <- source_binary(clean, "employment_status", true_values = 4:8, false_values = 1:3)
  clean$adult <- if_else(!is.na(clean$age_individual_clean), clean$age_individual_clean >= 18, NA)
  clean$has_positive_family_weight <- if_else(
    !is.na(source_numeric(clean, "family_weight", min = 0)),
    source_numeric(clean, "family_weight", min = 0) > 0,
    NA
  )
  clean$has_positive_individual_weight <- if_else(
    !is.na(source_numeric(clean, "individual_weight", min = 0)),
    source_numeric(clean, "individual_weight", min = 0) > 0,
    NA
  )
} else {
  if (!"sequence_number" %in% names(clean)) {
    clean$sequence_number <- NA_real_
  }
  clean <- clean %>%
    mutate(
      is_reference_person = sequence_number == 1,
      is_spouse_partner = sequence_number == 2
    )
}

if ("has_family_record" %in% names(clean)) {
  clean <- clean %>%
    mutate(
      family_record_status = if_else(
        has_family_record,
        "matched family record",
        "no selected family record"
      )
    )
} else {
  clean$family_record_status <- "not checked"
}

saveRDS(clean, person_out)
cat(paste0("Saved cleaned PSID person-year file: ", person_out, "\n"))
cat(paste0("Rows: ", nrow(clean), "\n"))

if (isTRUE(psid_write_dta_export)) {
  write_dta(clean, person_out_dta)
  cat(paste0("Saved optional Stata export: ", person_out_dta, "\n"))
}

if (isTRUE(psid_run_examples)) {
  print(count(clean, survey_year, family_record_status))
  if ("is_reference_person" %in% names(clean)) {
    print(count(clean, survey_year, is_reference_person))
  }
}
