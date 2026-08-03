################################################################################
# 03_build_cross_era_bridge.R
#
# Purpose: Explicitly append already-cleaned BRFSS files from the 2000-2010
#          pre-2011 era and the 2011-plus era without hiding the 2011 sampling
#          and weighting break.
#
# Inputs:  output/brfss_pre2011_clean.rds
#          output/brfss_2011plus_clean.rds
# Output:  output/brfss_cross_era_bridge.rds
#          output/brfss_cross_era_bridge_from_r.dta  (optional)
#
# Important: This script performs mechanical alignment only. It does not
# normalize pooled weights, declare a pooled survey design, or establish that
# any outcome is trend-comparable across 2010 and 2011.
################################################################################

suppressPackageStartupMessages({
  library(dplyr)
  library(haven)
})

# ============================================================================
# USER SETTINGS
# ============================================================================

# Optional explicit input files. Leave NULL to use brfss/output/ defaults.
pre2011_clean_file_manual <- NULL
plus2011_clean_file_manual <- NULL

# Optional bridge output directory. Leave NULL to use brfss/output/.
bridge_output_dir_manual <- NULL

# Extra variables must exist under the same name in both cleaned era files.
# This setting does not harmonize different coding or meaning across eras.
extra_bridge_vars <- character(0)
# extra_bridge_vars <- c("my_harmonized_outcome")

# The bridge can be large. Keep the optional R-to-Stata export off by default.
write_dta_export <- FALSE

# Non-editing overrides for smoke tests or alternative builds:
# Sys.setenv(BRFSS_PRE2011_CLEAN_FILE = "/path/to/brfss_pre2011_clean.rds")
# Sys.setenv(BRFSS_2011PLUS_CLEAN_FILE = "/path/to/brfss_2011plus_clean.rds")
# Sys.setenv(BRFSS_BRIDGE_OUTPUT_DIR = "/path/to/scratch/output")

# ============================================================================
# HELPERS
# ============================================================================

resolve_brfss_root <- function(script_name) {
  env_root <- Sys.getenv("BRFSS_ROOT", unset = "")

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
    unique(paths)
  }

  candidates <- unique(c(
    parent_paths(getwd()),
    parent_paths(env_root)
  ))

  for (candidate in candidates) {
    direct <- file.path(candidate, "code", script_name)
    nested <- file.path(candidate, "brfss", "code", script_name)
    if (file.exists(direct) && file.exists(file.path(candidate, "README.md"))) {
      return(candidate)
    }
    if (file.exists(nested) && file.exists(file.path(candidate, "brfss", "README.md"))) {
      return(file.path(candidate, "brfss"))
    }
  }

  stop(
    paste0(
      "Could not locate the brfss/ directory. Run from brfss/, brfss/code/, ",
      "the repo root, or set BRFSS_ROOT before running ", script_name, "."
    )
  )
}

env_or_manual <- function(env_name, manual_value, default_value) {
  env_value <- Sys.getenv(env_name, unset = "")
  if (nzchar(env_value)) return(env_value)
  if (!is.null(manual_value) && nzchar(manual_value)) return(manual_value)
  default_value
}

load_selected_rds <- function(path, keep_vars, era_label) {
  if (!file.exists(path)) {
    stop(paste0("Missing ", era_label, " cleaned file: ", path))
  }

  cat(paste0("Loading ", era_label, " cleaned file: ", path, "\n"))
  full_data <- readRDS(path)
  names(full_data) <- tolower(names(full_data))

  missing_vars <- setdiff(keep_vars, names(full_data))
  if (length(missing_vars) > 0) {
    stop(
      paste0(
        era_label, " cleaned file is missing required bridge variable(s): ",
        paste(missing_vars, collapse = ", ")
      )
    )
  }

  selected <- full_data[, keep_vars, drop = FALSE]
  rm(full_data)
  invisible(gc())

  selected[] <- lapply(selected, function(x) {
    if (inherits(x, "haven_labelled")) zap_labels(x) else x
  })
  selected
}

same_or_missing <- function(x, y, tolerance = 1e-8) {
  (is.na(x) & is.na(y)) |
    (!is.na(x) & !is.na(y) & abs(as.numeric(x) - as.numeric(y)) <= tolerance)
}

# ============================================================================
# PATHS AND BRIDGE CONTRACT
# ============================================================================

brfss_root <- resolve_brfss_root("03_build_cross_era_bridge.R")
default_output_dir <- file.path(brfss_root, "output")

pre2011_clean_file <- env_or_manual(
  "BRFSS_PRE2011_CLEAN_FILE",
  pre2011_clean_file_manual,
  file.path(default_output_dir, "brfss_pre2011_clean.rds")
)
plus2011_clean_file <- env_or_manual(
  "BRFSS_2011PLUS_CLEAN_FILE",
  plus2011_clean_file_manual,
  file.path(default_output_dir, "brfss_2011plus_clean.rds")
)

plus_output_override <- Sys.getenv("BRFSS_OUTPUT_DIR", unset = "")
if (!nzchar(plus_output_override)) plus_output_override <- default_output_dir

bridge_output_dir <- env_or_manual(
  "BRFSS_BRIDGE_OUTPUT_DIR",
  bridge_output_dir_manual,
  plus_output_override
)
dir.create(bridge_output_dir, recursive = TRUE, showWarnings = FALSE)

out_rds <- file.path(bridge_output_dir, "brfss_cross_era_bridge.rds")
out_dta <- file.path(bridge_output_dir, "brfss_cross_era_bridge_from_r.dta")

common_bridge_vars <- c(
  "surveyyear", "statefips", "county_code_raw", "county_code_source",
  "countyfips", "seqno", "month", "year",
  "age", "age_cat", "female", "race_eth", "white", "black", "hispanic",
  "raceother", "educ_cat", "hsdropout", "hsgraduate", "somecollege",
  "college", "marital_cat", "married", "divorced", "widowed",
  "nevermarried", "income_cat", "working", "student",
  "genhealth", "fair_or_poor", "mental_days", "physical_days",
  "bmi", "bmi_cat", "smoker", "current_smoker", "diabetes",
  "asthma_ever", "asthma_current", "heartattack", "heartdisease"
)

extra_bridge_vars <- unique(tolower(trimws(extra_bridge_vars)))
extra_bridge_vars <- extra_bridge_vars[nzchar(extra_bridge_vars)]

reserved_vars <- c(
  "analysis_weight", "psu", "strata", "_llcpwt", "_psu", "_ststr",
  "analysis_weight_raw", "psu_raw", "strata_raw", "survey_era",
  "post2011", "sampling_frame", "weighting_method", "weight_source",
  "bmi_cat_era_specific", "bmi_cat_cross_era"
)
bad_extra_vars <- intersect(extra_bridge_vars, reserved_vars)
if (length(bad_extra_vars) > 0) {
  stop(
    paste0(
      "extra_bridge_vars contains reserved bridge name(s): ",
      paste(bad_extra_vars, collapse = ", ")
    )
  )
}

bridge_vars <- unique(c(common_bridge_vars, extra_bridge_vars))
pre_source_vars <- c("analysis_weight", "psu", "strata")
plus_source_vars <- c("_llcpwt", "_psu", "_ststr")

# ============================================================================
# LOAD ONE ERA AT A TIME AND IMMEDIATELY SELECT BRIDGE COLUMNS
# ============================================================================

pre <- load_selected_rds(
  pre2011_clean_file,
  unique(c(bridge_vars, pre_source_vars)),
  "pre-2011"
)

pre_rows <- nrow(pre)
if (pre_rows == 0 || any(!pre$surveyyear %in% 2000:2010, na.rm = TRUE)) {
  stop("Pre-2011 bridge input must contain only survey years 2000-2010.")
}

names(pre)[names(pre) == "bmi_cat"] <- "bmi_cat_era_specific"
pre$analysis_weight_raw <- as.numeric(pre$analysis_weight)
pre$psu_raw <- as.numeric(pre$psu)
pre$strata_raw <- as.numeric(pre$strata)
pre$analysis_weight <- NULL
pre$psu <- NULL
pre$strata <- NULL
pre$survey_era <- "pre2011"
pre$post2011 <- 0L
pre$sampling_frame <- "primarily_landline"
pre$weighting_method <- "post_stratification"
pre$weight_source <- "_FINALWT"

plus <- load_selected_rds(
  plus2011_clean_file,
  unique(c(bridge_vars, plus_source_vars)),
  "2011-plus"
)

plus_rows <- nrow(plus)
if (plus_rows == 0 || any(plus$surveyyear < 2011, na.rm = TRUE)) {
  stop("The 2011-plus bridge input must contain only survey years 2011 or later.")
}

names(plus)[names(plus) == "bmi_cat"] <- "bmi_cat_era_specific"
plus$analysis_weight_raw <- as.numeric(plus$`_llcpwt`)
plus$psu_raw <- as.numeric(plus$`_psu`)
plus$strata_raw <- as.numeric(plus$`_ststr`)
plus$`_llcpwt` <- NULL
plus$`_psu` <- NULL
plus$`_ststr` <- NULL
plus$survey_era <- "2011plus"
plus$post2011 <- 1L
plus$sampling_frame <- "landline_cell_dual_frame"
plus$weighting_method <- "raking"
plus$weight_source <- "_LLCPWT"

# Core bridge variables are numeric except the documented source field.
numeric_core_vars <- setdiff(common_bridge_vars, c("county_code_source", "bmi_cat"))
numeric_core_vars <- c(
  numeric_core_vars, "bmi_cat_era_specific", "analysis_weight_raw",
  "psu_raw", "strata_raw", "post2011"
)
for (var_name in numeric_core_vars) {
  pre[[var_name]] <- suppressWarnings(as.numeric(pre[[var_name]]))
  plus[[var_name]] <- suppressWarnings(as.numeric(plus[[var_name]]))
}

# Extra variables may retain their common numeric or character storage type.
for (var_name in extra_bridge_vars) {
  pre_is_numeric <- is.numeric(pre[[var_name]]) || is.logical(pre[[var_name]])
  plus_is_numeric <- is.numeric(plus[[var_name]]) || is.logical(plus[[var_name]])
  pre_is_character <- is.character(pre[[var_name]])
  plus_is_character <- is.character(plus[[var_name]])

  if (pre_is_numeric && plus_is_numeric) {
    pre[[var_name]] <- as.numeric(pre[[var_name]])
    plus[[var_name]] <- as.numeric(plus[[var_name]])
  } else if ((pre_is_character || pre_is_numeric) &&
             (plus_is_character || plus_is_numeric)) {
    pre[[var_name]] <- as.character(pre[[var_name]])
    plus[[var_name]] <- as.character(plus[[var_name]])
  } else {
    stop(
      paste0(
        "Extra bridge variable ", var_name,
        " has unsupported or incompatible storage types across eras."
      )
    )
  }
}

brfss_bridge <- bind_rows(pre, plus)
rm(pre, plus)
invisible(gc())

brfss_bridge <- brfss_bridge %>%
  mutate(
    bmi_cat_cross_era = case_when(
      !is.na(bmi) & bmi > 0 & bmi < 18.5 ~ 1,
      !is.na(bmi) & bmi >= 18.5 & bmi < 25 ~ 2,
      !is.na(bmi) & bmi >= 25 & bmi < 30 ~ 3,
      !is.na(bmi) & bmi >= 30 ~ 4,
      TRUE ~ NA_real_
    )
  )

# ============================================================================
# VALIDATION AND SAVE
# ============================================================================

if (nrow(brfss_bridge) != pre_rows + plus_rows) {
  stop("Bridge row count does not equal the sum of the two era inputs.")
}
if (any(brfss_bridge$survey_era == "pre2011" & brfss_bridge$surveyyear >= 2011,
        na.rm = TRUE) ||
    any(brfss_bridge$survey_era == "2011plus" & brfss_bridge$surveyyear < 2011,
        na.rm = TRUE)) {
  stop("survey_era does not match surveyyear around the 2011 break.")
}
if (any(!same_or_missing(
  brfss_bridge$post2011,
  as.numeric(brfss_bridge$surveyyear >= 2011)
))) {
  stop("post2011 does not match the survey-year boundary.")
}
if (any(!brfss_bridge$bmi_cat_cross_era %in% 1:4 &
        !is.na(brfss_bridge$bmi_cat_cross_era))) {
  stop("bmi_cat_cross_era contains an unexpected value.")
}

key_frame <- brfss_bridge[c("surveyyear", "statefips", "seqno")]
duplicate_key_rows <- sum(
  duplicated(key_frame) | duplicated(key_frame, fromLast = TRUE)
)

saveRDS(brfss_bridge, out_rds)
cat(paste0("Saved: ", out_rds, "\n"))

if (isTRUE(write_dta_export)) {
  tryCatch(
    {
      write_dta(brfss_bridge, out_dta)
      cat(paste0("Saved: ", out_dta, "\n"))
    },
    error = function(e) {
      warning(paste0("Could not write optional Stata export: ", e$message))
    }
  )
}

cat(paste0("[PASS] Pre-2011 rows: ", pre_rows, "\n"))
cat(paste0("[PASS] 2011-plus rows: ", plus_rows, "\n"))
cat(paste0("[PASS] Bridge rows: ", nrow(brfss_bridge), "\n"))
cat(paste0("[INFO] Rows in duplicated surveyyear + statefips + seqno groups: ",
           duplicate_key_rows, "\n"))
cat("[PASS] Era, weight-source, and cross-era BMI metadata validated.\n")
cat(
  paste(
    "[CAUTION] analysis_weight_raw contains each era's original annual weight.",
    "No pooled normalization or survey design has been imposed.\n"
  )
)

################################################################################
# MEMORY NOTE
#
# If these cleaned RDS inputs were produced by the optional low-memory loaders,
# they are already narrow. If they were produced by the full-width loaders, R
# must still open one wide RDS at a time before this script can select columns.
# On a constrained machine, rebuild both inputs with the low-memory loaders and
# use their extra-variable hooks for any additional bridge variables needed.
################################################################################
