################################################################################
# 02_clean_pre2011.R
#
# Purpose: Clean and harmonize BRFSS pre-2011 landline-era variables for 2000-2010.
#          This cleaner consumes output from either pre-2011 loader and
#          creates a public starter dataset with stable variable names.
#
# Input:   output/brfss_pre2011_appended.rds
# Output:  output/brfss_pre2011_clean.rds
#          output/brfss_pre2011_clean_from_r.dta (optional)
#
# Usage:   Run from brfss/, from brfss/code/, from the repo root, or set
#          BRFSS_ROOT explicitly.
################################################################################

library(haven)
library(dplyr)

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

coerce_numeric_if_present <- function(df, var_name) {
  if (!var_name %in% names(df)) {
    return(rep(NA_real_, nrow(df)))
  }

  x <- df[[var_name]]
  if (inherits(x, c("haven_labelled", "labelled", "labelled_spss"))) {
    x <- unclass(x)
  }
  if (is.character(x)) {
    x <- iconv(x, from = "", to = "UTF-8", sub = "")
    return(suppressWarnings(as.numeric(trimws(x))))
  }
  as.numeric(x)
}

first_valid <- function(..., invalid = c(777, 888, 999)) {
  values <- list(...)
  out <- rep(NA_real_, length(values[[1]]))

  for (x in values) {
    ok <- is.na(out) & !is.na(x) & !(x %in% invalid)
    out[ok] <- x[ok]
  }

  out
}

first_valid_source <- function(named_values, invalid = c(777, 888, 999)) {
  n <- length(named_values[[1]])
  out <- rep(NA_character_, n)

  for (nm in names(named_values)) {
    x <- named_values[[nm]]
    ok <- is.na(out) & !is.na(x) & !(x %in% invalid)
    out[ok] <- nm
  }

  out
}

first_valid_county <- function(...) {
  values <- list(...)
  out <- rep(NA_real_, length(values[[1]]))

  for (x in values) {
    ok <- is.na(out) & !is.na(x) & x >= 1 & x <= 840 & !(x %in% c(777, 888, 999))
    out[ok] <- x[ok]
  }

  out
}

first_valid_county_source <- function(named_values) {
  n <- length(named_values[[1]])
  out <- rep(NA_character_, n)

  for (nm in names(named_values)) {
    x <- named_values[[nm]]
    ok <- is.na(out) & !is.na(x) & x >= 1 & x <= 840 & !(x %in% c(777, 888, 999))
    out[ok] <- nm
  }

  out
}

assert_clean_range <- function(df, var_name, min_value, max_value) {
  if (!var_name %in% names(df)) {
    stop(paste0("[FAIL] Missing variable for range check: ", var_name))
  }

  x <- suppressWarnings(as.numeric(df[[var_name]]))
  bad <- !is.na(x) & (x < min_value | x > max_value)
  if (any(bad)) {
    stop(
      paste0(
        "[FAIL] ", var_name, " has ", sum(bad),
        " value(s) outside [", min_value, ", ", max_value, "]."
      )
    )
  }

  cat(paste0("[PASS] ", var_name, " values are within [", min_value, ", ", max_value, "] when non-missing.\n"))
}

assert_clean_set <- function(df, var_name, allowed_values) {
  if (!var_name %in% names(df)) {
    stop(paste0("[FAIL] Missing variable for value-set check: ", var_name))
  }

  x <- suppressWarnings(as.numeric(df[[var_name]]))
  bad <- !is.na(x) & !(x %in% allowed_values)
  if (any(bad)) {
    bad_values <- paste(sort(unique(x[bad])), collapse = ", ")
    stop(paste0("[FAIL] ", var_name, " has unexpected value(s): ", bad_values))
  }

  cat(paste0("[PASS] ", var_name, " uses only expected non-missing values: ", paste(allowed_values, collapse = ", "), "\n"))
}

assert_clean_equal <- function(label, observed, expected, tolerance = 1e-8) {
  observed <- suppressWarnings(as.numeric(observed))
  expected <- suppressWarnings(as.numeric(expected))

  both_missing <- is.na(observed) & is.na(expected)
  mismatch <- !both_missing & (
    is.na(observed) != is.na(expected) |
      abs(observed - expected) > tolerance
  )

  if (any(mismatch)) {
    first_bad <- which(mismatch)[[1]]
    stop(
      paste0(
        "[FAIL] ", label, " has ", sum(mismatch),
        " mismatched row(s). First mismatch row: ", first_bad,
        "; observed=", observed[[first_bad]],
        "; expected=", expected[[first_bad]]
      )
    )
  }

  cat(paste0("[PASS] ", label, "\n"))
}

assert_clean_equal_chr <- function(label, observed, expected) {
  observed <- as.character(observed)
  expected <- as.character(expected)

  both_missing <- (is.na(observed) | observed == "") & (is.na(expected) | expected == "")
  mismatch <- !both_missing & (observed != expected)

  if (any(mismatch)) {
    first_bad <- which(mismatch)[[1]]
    stop(
      paste0(
        "[FAIL] ", label, " has ", sum(mismatch),
        " mismatched row(s). First mismatch row: ", first_bad,
        "; observed=", observed[[first_bad]],
        "; expected=", expected[[first_bad]]
      )
    )
  }

  cat(paste0("[PASS] ", label, "\n"))
}

binary_from_raw <- function(x, yes_values, no_values) {
  case_when(
    x %in% yes_values ~ 1,
    x %in% no_values ~ 0,
    TRUE ~ NA_real_
  )
}

# ============================================================================
# USER SETTINGS
# ============================================================================

# Optional manual root override:
# Sys.setenv(BRFSS_ROOT = "/path/to/econ-data-starters/brfss")

# Optional output directory override for smoke tests or scratch builds.
pre2011_output_dir_manual <- NULL
# pre2011_output_dir_manual <- "/private/tmp/brfss_pre2011_output"

# Optional non-editing override for smoke tests:
# Sys.setenv(BRFSS_PRE2011_OUTPUT_DIR = "/private/tmp/brfss_pre2011_output")
env_output_dir <- Sys.getenv("BRFSS_PRE2011_OUTPUT_DIR", unset = "")
if (nzchar(env_output_dir)) {
  pre2011_output_dir_manual <- env_output_dir
}

# If TRUE, also write a Stata export from R. The Stata cleaner writes its own
# native .dta output, so this is off by default.
write_dta_export <- FALSE

# ============================================================================
# 1. DEFINE PATHS
# ============================================================================

brfss_root <- resolve_brfss_root("02_clean_pre2011.R")
cat(paste0("Using BRFSS root: ", brfss_root, "\n"))

out_dir <- if (!is.null(pre2011_output_dir_manual)) {
  pre2011_output_dir_manual
} else {
  file.path(brfss_root, "output")
}

in_rds  <- file.path(out_dir, "brfss_pre2011_appended.rds")
out_rds <- file.path(out_dir, "brfss_pre2011_clean.rds")
out_dta <- file.path(out_dir, "brfss_pre2011_clean_from_r.dta")

if (!file.exists(in_rds)) {
  stop(
    paste0(
      "Input file not found: ", in_rds,
      "\nRun 01_load_pre2011.R or ",
      "01_load_pre2011_optional_low_memory.R first."
    )
  )
}

# ============================================================================
# 2. LOAD APPENDED DATA
# ============================================================================

cat("Loading appended pre-2011 BRFSS data...\n")
brfss <- readRDS(in_rds)
names(brfss) <- tolower(names(brfss))

# DIABETES is the raw fixed-core name in 2000-2003. Preserve it under an
# era-specific name before creating the harmonized diabetes indicator.
if ("diabetes" %in% names(brfss) && !"diabetes_pre2004" %in% names(brfss)) {
  names(brfss)[names(brfss) == "diabetes"] <- "diabetes_pre2004"
}

# HISPANIC is also a raw questionnaire field in some full-width early files.
# Preserve it before creating the harmonized regression indicator below.
if ("hispanic" %in% names(brfss) && !"hispanic_raw" %in% names(brfss)) {
  names(brfss)[names(brfss) == "hispanic"] <- "hispanic_raw"
}

cat(paste0("Loaded: ", nrow(brfss), " observations, ", ncol(brfss), " variables\n"))

years_present <- sort(unique(as.integer(brfss$surveyyear)))
invalid_years <- setdiff(years_present, 2000:2010)
if (length(invalid_years) > 0) {
  stop(
    paste0(
      "This cleaner supports 2000-2010 only. Invalid year(s) in input: ",
      paste(invalid_years, collapse = ", ")
    )
  )
}

support_vars <- c(
  "_state", "_psu", "_ststr", "_finalwt", "_poststr",
  "ctycode", "_impcty", "cpcounty",
  "imonth", "iyear",
  "age", "_impage", "_ageg5yr",
  "sex", "_racegr", "_racegr2", "_raceg2", "_raceg3_", "race2", "hispanc2",
  "educa", "marital", "income2", "employ",
  "genhlth", "menthlth", "physhlth",
  "hlthplan", "persdoc", "persdoc2", "medcost", "checkup", "checkup1",
  "diabetes_pre2004", "diabete2", "asthma", "asthma2", "asthnow",
  "cvdinfar", "cvdcorhd", "cvdstrok",
  "cvdinfr2", "cvdinfr3", "cvdinfr4",
  "cvdcrhd2", "cvdcrhd3", "cvdcrhd4",
  "cvdstrk2", "cvdstrk3",
  "_bmi2", "_bmi2cat", "_rfbmi2",
  "_bmi3", "_bmi3cat", "_rfbmi3",
  "_bmi4", "_bmi4cat", "_rfbmi4",
  "_smoker2", "_smoker3"
)

added_placeholder_vars <- setdiff(support_vars, names(brfss))
for (var_name in added_placeholder_vars) {
  brfss[[var_name]] <- NA_real_
}

numeric_vars <- unique(c(support_vars, "surveyyear"))
num <- lapply(numeric_vars, function(v) coerce_numeric_if_present(brfss, v))
names(num) <- numeric_vars

county_values <- list(
  ctycode = num$ctycode,
  `_impcty` = num$`_impcty`,
  cpcounty = num$cpcounty
)

bmi_values <- list(
  `_bmi4` = num$`_bmi4`,
  `_bmi3` = num$`_bmi3`,
  `_bmi2` = num$`_bmi2`
)

# ============================================================================
# 3. CLEAN AND HARMONIZE
# ============================================================================

cat("Creating harmonized pre-2011 variables...\n")

brfss <- brfss %>%
  mutate(
    # Survey design and geography
    statefips = num$`_state`,
    psu = num$`_psu`,
    strata = num$`_ststr`,
    analysis_weight = num$`_finalwt`,
    final_weight = num$`_finalwt`,
    poststrat_weight = num$`_poststr`,
    design_era = "pre2011_landline_poststratification",

    county_code_raw = first_valid_county(num$ctycode, num$`_impcty`, num$cpcounty),
    county_code_source = first_valid_county_source(county_values),
    countyfips = ifelse(
      !is.na(statefips) & !is.na(county_code_raw) &
        county_code_raw >= 1 & county_code_raw <= 840,
      statefips * 1000 + county_code_raw,
      NA_real_
    ),

    # Timing
    month = ifelse(num$imonth >= 1 & num$imonth <= 12, num$imonth, NA_real_),
    year = num$iyear,

    # Demographics
    age_raw = num$age,
    age = case_when(
      num$`_impage` >= 18 & num$`_impage` <= 99 ~ num$`_impage`,
      num$age >= 18 & num$age <= 99 ~ num$age,
      TRUE ~ NA_real_
    ),
    age_cat = ifelse(num$`_ageg5yr` >= 1 & num$`_ageg5yr` <= 14, num$`_ageg5yr`, NA_real_),

    female = case_when(
      num$sex == 2 ~ 1L,
      num$sex == 1 ~ 0L,
      TRUE ~ NA_integer_
    ),

    race_eth = case_when(
      num$`_racegr` == 1 ~ 1L,
      num$`_racegr` == 2 ~ 2L,
      num$`_racegr` == 3 ~ 3L,
      num$`_racegr` == 4 ~ 4L,
      num$`_racegr2` == 1 ~ 1L,
      num$`_racegr2` == 2 ~ 2L,
      num$`_racegr2` == 5 ~ 3L,
      num$`_racegr2` %in% c(3, 4) ~ 4L,
      num$`_raceg2` == 1 ~ 1L,
      num$`_raceg2` == 2 ~ 2L,
      num$`_raceg2` %in% c(3, 4) ~ 4L,
      num$`_raceg3_` == 1 ~ 1L,
      num$`_raceg3_` == 2 ~ 2L,
      num$`_raceg3_` %in% c(3, 4, 5) ~ 4L,
      num$hispanc2 == 1 ~ 3L,
      TRUE ~ NA_integer_
    ),
    white = as.integer(race_eth == 1),
    black = as.integer(race_eth == 2),
    hispanic = as.integer(race_eth == 3),
    raceother = as.integer(race_eth == 4),

    educ_cat = case_when(
      num$educa >= 1 & num$educa <= 3 ~ 1L,
      num$educa == 4 ~ 2L,
      num$educa == 5 ~ 3L,
      num$educa == 6 ~ 4L,
      TRUE ~ NA_integer_
    ),
    hsdropout = as.integer(educ_cat == 1),
    hsgraduate = as.integer(educ_cat == 2),
    somecollege = as.integer(educ_cat == 3),
    college = as.integer(educ_cat == 4),

    marital_cat = case_when(
      num$marital %in% c(1, 6) ~ 1L,
      num$marital %in% c(2, 4) ~ 2L,
      num$marital == 3 ~ 3L,
      num$marital == 5 ~ 4L,
      TRUE ~ NA_integer_
    ),
    married = as.integer(marital_cat == 1),
    divorced = as.integer(marital_cat == 2),
    widowed = as.integer(marital_cat == 3),
    nevermarried = as.integer(marital_cat == 4),

    income_cat = ifelse(num$income2 >= 1 & num$income2 <= 8, num$income2, NA_real_),

    working = case_when(
      num$employ %in% c(1, 2) ~ 1L,
      num$employ >= 3 & num$employ <= 8 ~ 0L,
      TRUE ~ NA_integer_
    ),
    student = case_when(
      num$employ == 6 ~ 1L,
      num$employ >= 1 & num$employ <= 8 & num$employ != 6 ~ 0L,
      TRUE ~ NA_integer_
    ),

    # Health and access
    genhealth = ifelse(num$genhlth >= 1 & num$genhlth <= 5, num$genhlth, NA_real_),
    fair_or_poor = ifelse(!is.na(genhealth), as.integer(genhealth >= 4), NA_integer_),

    mental_days = case_when(
      num$menthlth >= 1 & num$menthlth <= 30 ~ num$menthlth,
      num$menthlth == 88 ~ 0,
      TRUE ~ NA_real_
    ),
    physical_days = case_when(
      num$physhlth >= 1 & num$physhlth <= 30 ~ num$physhlth,
      num$physhlth == 88 ~ 0,
      TRUE ~ NA_real_
    ),

    insured = case_when(
      num$hlthplan == 1 ~ 1L,
      num$hlthplan == 2 ~ 0L,
      TRUE ~ NA_integer_
    ),
    personal_doctor_raw = first_valid(num$persdoc2, num$persdoc),
    has_personal_doctor = case_when(
      personal_doctor_raw %in% c(1, 2) ~ 1L,
      personal_doctor_raw == 3 ~ 0L,
      TRUE ~ NA_integer_
    ),
    cost_barrier = case_when(
      num$medcost == 1 ~ 1L,
      num$medcost == 2 ~ 0L,
      TRUE ~ NA_integer_
    ),
    checkup_raw = first_valid(num$checkup, num$checkup1),
    checkup_within_year = case_when(
      checkup_raw == 1 ~ 1L,
      checkup_raw %in% c(2, 3, 4, 8) ~ 0L,
      TRUE ~ NA_integer_
    ),

    bmi_raw = first_valid(num$`_bmi4`, num$`_bmi3`, num$`_bmi2`),
    bmi_source = first_valid_source(bmi_values),
    bmi = case_when(
      num$`_bmi4` >= 1 & num$`_bmi4` <= 9998 ~ num$`_bmi4` / 100,
      num$`_bmi3` >= 1 & num$`_bmi3` <= 9998 ~ num$`_bmi3` / 100,
      surveyyear == 2002 & num$`_bmi2` >= 1 & num$`_bmi2` <= 9998 ~ num$`_bmi2` / 100,
      surveyyear == 2001 & num$`_bmi2` >= 1 & num$`_bmi2` <= 999998 ~ num$`_bmi2` / 10000,
      surveyyear == 2000 & num$`_bmi2` >= 1 & num$`_bmi2` <= 998 ~ num$`_bmi2` / 10,
      TRUE ~ NA_real_
    ),
    bmi_cat_raw = first_valid(num$`_bmi4cat`, num$`_bmi3cat`, num$`_bmi2cat`),
    bmi_cat = ifelse(bmi_cat_raw >= 1 & bmi_cat_raw <= 3, bmi_cat_raw, NA_real_),

    smoker = case_when(
      num$`_smoker3` >= 1 & num$`_smoker3` <= 4 ~ num$`_smoker3`,
      num$`_smoker2` >= 1 & num$`_smoker2` <= 4 ~ num$`_smoker2`,
      TRUE ~ NA_real_
    ),
    current_smoker = ifelse(!is.na(smoker), as.integer(smoker %in% c(1, 2)), NA_integer_),

    diabetes_raw = first_valid(num$diabete2, num$diabetes_pre2004),
    diabetes = case_when(
      num$diabete2 == 1 ~ 1L,
      num$diabete2 %in% c(2, 3, 4) ~ 0L,
      is.na(num$diabete2) & num$diabetes_pre2004 == 1 ~ 1L,
      is.na(num$diabete2) & num$diabetes_pre2004 %in% c(2, 3) ~ 0L,
      TRUE ~ NA_integer_
    ),
    asthma_ever_raw = first_valid(num$asthma2, num$asthma),
    asthma_ever = case_when(
      asthma_ever_raw == 1 ~ 1L,
      asthma_ever_raw == 2 ~ 0L,
      TRUE ~ NA_integer_
    ),
    asthma_current = case_when(
      num$asthnow == 1 ~ 1L,
      num$asthnow == 2 ~ 0L,
      TRUE ~ NA_integer_
    ),

    heartattack_raw = first_valid(num$cvdinfr4, num$cvdinfr3, num$cvdinfr2, num$cvdinfar),
    heartattack = case_when(
      heartattack_raw == 1 ~ 1L,
      heartattack_raw == 2 ~ 0L,
      TRUE ~ NA_integer_
    ),
    heartdisease_raw = first_valid(num$cvdcrhd4, num$cvdcrhd3, num$cvdcrhd2, num$cvdcorhd),
    heartdisease = case_when(
      heartdisease_raw == 1 ~ 1L,
      heartdisease_raw == 2 ~ 0L,
      TRUE ~ NA_integer_
    ),
    stroke_raw = first_valid(num$cvdstrk3, num$cvdstrk2, num$cvdstrok),
    stroke = case_when(
      stroke_raw == 1 ~ 1L,
      stroke_raw == 2 ~ 0L,
      TRUE ~ NA_integer_
    )
  )

if (length(added_placeholder_vars) > 0) {
  brfss <- brfss %>% select(-any_of(added_placeholder_vars))
}

brfss <- brfss %>% arrange(surveyyear, statefips, countyfips)

# ============================================================================
# 4. SAVE AND VALIDATE
# ============================================================================

cat("\n============================================\n")
cat("   SAVING CLEAN PRE-2011 DATASET\n")
cat("============================================\n\n")

saveRDS(brfss, out_rds)
cat(paste0("Saved: ", out_rds, "\n"))

if (isTRUE(write_dta_export)) {
  tryCatch(
    {
      write_dta(brfss, out_dta)
      cat(paste0("Saved: ", out_dta, "\n"))
    },
    error = function(e) {
      cat(paste0("Could not save .dta export: ", e$message, "\n"))
      cat("The .rds file was saved successfully.\n")
    }
  )
}

cat("\n============================================\n")
cat("   VALIDATION CHECKS\n")
cat("============================================\n\n")

required_clean_vars <- c(
  "surveyyear", "statefips", "analysis_weight", "psu", "strata",
  "county_code_raw", "countyfips",
  "age", "female", "race_eth", "educ_cat", "income_cat",
  "insured", "genhealth", "bmi", "current_smoker", "diabetes"
)

missing_clean <- setdiff(required_clean_vars, names(brfss))
if (length(missing_clean) == 0) {
  cat(paste0("[PASS] Required clean variables present: ", paste(required_clean_vars, collapse = ", "), "\n"))
} else {
  stop(paste0("[FAIL] Missing clean variable(s): ", paste(missing_clean, collapse = ", ")))
}

assert_clean_range(brfss, "surveyyear", 2000, 2010)
assert_clean_range(brfss, "statefips", 1, 99)
assert_clean_range(brfss, "county_code_raw", 1, 840)
assert_clean_range(brfss, "month", 1, 12)
assert_clean_range(brfss, "age", 18, 99)
assert_clean_set(brfss, "age_cat", 1:14)
assert_clean_set(brfss, "female", 0:1)
assert_clean_set(brfss, "race_eth", 1:4)
assert_clean_set(brfss, "educ_cat", 1:4)
assert_clean_set(brfss, "marital_cat", 1:4)
assert_clean_set(brfss, "income_cat", 1:8)
assert_clean_set(brfss, "genhealth", 1:5)
assert_clean_range(brfss, "mental_days", 0, 30)
assert_clean_range(brfss, "physical_days", 0, 30)
assert_clean_range(brfss, "bmi", 0, 100)
assert_clean_set(brfss, "bmi_cat", 1:3)
assert_clean_set(brfss, "smoker", 1:4)

binary_vars <- c(
  "white", "black", "hispanic", "raceother",
  "hsdropout", "hsgraduate", "somecollege", "college",
  "married", "divorced", "widowed", "nevermarried",
  "working", "student", "fair_or_poor",
  "insured", "has_personal_doctor", "cost_barrier",
  "checkup_within_year", "current_smoker", "diabetes",
  "asthma_ever", "asthma_current", "heartattack",
  "heartdisease", "stroke"
)
for (var_name in binary_vars) {
  assert_clean_set(brfss, var_name, 0:1)
}

raw <- function(var_name) coerce_numeric_if_present(brfss, var_name)

expected_county_raw <- first_valid_county(raw("ctycode"), raw("_impcty"), raw("cpcounty"))
expected_county_source <- first_valid_county_source(
  list(
    ctycode = raw("ctycode"),
    `_impcty` = raw("_impcty"),
    cpcounty = raw("cpcounty")
  )
)
expected_countyfips <- ifelse(
  !is.na(raw("_state")) & !is.na(expected_county_raw) &
    expected_county_raw >= 1 & expected_county_raw <= 840,
  raw("_state") * 1000 + expected_county_raw,
  NA_real_
)

expected_age <- case_when(
  raw("_impage") >= 18 & raw("_impage") <= 99 ~ raw("_impage"),
  raw("age_raw") >= 18 & raw("age_raw") <= 99 ~ raw("age_raw"),
  TRUE ~ NA_real_
)
expected_checkup_raw <- first_valid(raw("checkup"), raw("checkup1"))
expected_smoker <- case_when(
  raw("_smoker3") >= 1 & raw("_smoker3") <= 4 ~ raw("_smoker3"),
  raw("_smoker2") >= 1 & raw("_smoker2") <= 4 ~ raw("_smoker2"),
  TRUE ~ NA_real_
)
expected_race_eth <- case_when(
  raw("_racegr") == 1 ~ 1,
  raw("_racegr") == 2 ~ 2,
  raw("_racegr") == 3 ~ 3,
  raw("_racegr") == 4 ~ 4,
  raw("_racegr2") == 1 ~ 1,
  raw("_racegr2") == 2 ~ 2,
  raw("_racegr2") == 5 ~ 3,
  raw("_racegr2") %in% c(3, 4) ~ 4,
  raw("_raceg2") == 1 ~ 1,
  raw("_raceg2") == 2 ~ 2,
  raw("_raceg2") %in% c(3, 4) ~ 4,
  raw("_raceg3_") == 1 ~ 1,
  raw("_raceg3_") == 2 ~ 2,
  raw("_raceg3_") %in% c(3, 4, 5) ~ 4,
  raw("hispanc2") == 1 ~ 3,
  TRUE ~ NA_real_
)
expected_personal_doctor_raw <- first_valid(raw("persdoc2"), raw("persdoc"))
expected_bmi_raw <- first_valid(raw("_bmi4"), raw("_bmi3"), raw("_bmi2"))
expected_bmi_source <- first_valid_source(
  list(`_bmi4` = raw("_bmi4"), `_bmi3` = raw("_bmi3"), `_bmi2` = raw("_bmi2"))
)
expected_bmi <- case_when(
  raw("_bmi4") >= 1 & raw("_bmi4") <= 9998 ~ raw("_bmi4") / 100,
  raw("_bmi3") >= 1 & raw("_bmi3") <= 9998 ~ raw("_bmi3") / 100,
  brfss$surveyyear == 2002 & raw("_bmi2") >= 1 & raw("_bmi2") <= 9998 ~ raw("_bmi2") / 100,
  brfss$surveyyear == 2001 & raw("_bmi2") >= 1 & raw("_bmi2") <= 999998 ~ raw("_bmi2") / 10000,
  brfss$surveyyear == 2000 & raw("_bmi2") >= 1 & raw("_bmi2") <= 998 ~ raw("_bmi2") / 10,
  TRUE ~ NA_real_
)
expected_bmi_cat_raw <- first_valid(raw("_bmi4cat"), raw("_bmi3cat"), raw("_bmi2cat"))
expected_bmi_cat <- ifelse(
  expected_bmi_cat_raw >= 1 & expected_bmi_cat_raw <= 3,
  expected_bmi_cat_raw,
  NA_real_
)
expected_diabetes_raw <- first_valid(raw("diabete2"), raw("diabetes_pre2004"))
expected_diabetes <- case_when(
  raw("diabete2") == 1 ~ 1,
  raw("diabete2") %in% c(2, 3, 4) ~ 0,
  is.na(raw("diabete2")) & raw("diabetes_pre2004") == 1 ~ 1,
  is.na(raw("diabete2")) & raw("diabetes_pre2004") %in% c(2, 3) ~ 0,
  TRUE ~ NA_real_
)
expected_asthma_ever_raw <- first_valid(raw("asthma2"), raw("asthma"))

assert_clean_equal("statefips matches _STATE", brfss$statefips, raw("_state"))
assert_clean_equal("psu matches _PSU", brfss$psu, raw("_psu"))
assert_clean_equal("strata matches _STSTR", brfss$strata, raw("_ststr"))
assert_clean_equal("analysis_weight matches _FINALWT", brfss$analysis_weight, raw("_finalwt"))
assert_clean_equal("county_code_raw matches CTYCODE/_IMPCTY/CPCOUNTY first-valid rule", brfss$county_code_raw, expected_county_raw)
assert_clean_equal_chr("county_code_source identifies the first valid county source", brfss$county_code_source, expected_county_source)
assert_clean_equal("countyfips equals statefips * 1000 + county code", brfss$countyfips, expected_countyfips)
assert_clean_equal("age follows _IMPAGE then AGE fallback", brfss$age, expected_age)
assert_clean_equal("female is SEX == 2", brfss$female, binary_from_raw(raw("sex"), 2, 1))
assert_clean_equal("race_eth follows _RACEGR/_RACEGR2 and documented fallbacks", brfss$race_eth, expected_race_eth)
assert_clean_equal("educ_cat follows EDUCA categories", brfss$educ_cat, case_when(raw("educa") %in% 1:3 ~ 1, raw("educa") == 4 ~ 2, raw("educa") == 5 ~ 3, raw("educa") == 6 ~ 4, TRUE ~ NA_real_))
assert_clean_equal("working follows EMPLOY 1/2 versus 3-8", brfss$working, binary_from_raw(raw("employ"), 1:2, 3:8))
assert_clean_equal("genhealth keeps GENHLTH 1-5", brfss$genhealth, ifelse(raw("genhlth") >= 1 & raw("genhlth") <= 5, raw("genhlth"), NA_real_))
assert_clean_equal("mental_days maps MENTHLTH 88 to zero", brfss$mental_days, case_when(raw("menthlth") >= 1 & raw("menthlth") <= 30 ~ raw("menthlth"), raw("menthlth") == 88 ~ 0, TRUE ~ NA_real_))
assert_clean_equal("physical_days maps PHYSHLTH 88 to zero", brfss$physical_days, case_when(raw("physhlth") >= 1 & raw("physhlth") <= 30 ~ raw("physhlth"), raw("physhlth") == 88 ~ 0, TRUE ~ NA_real_))
assert_clean_equal("insured follows HLTHPLAN yes/no", brfss$insured, binary_from_raw(raw("hlthplan"), 1, 2))
assert_clean_equal("personal_doctor_raw follows PERSDOC2 then PERSDOC", brfss$personal_doctor_raw, expected_personal_doctor_raw)
assert_clean_equal("has_personal_doctor follows PERSDOC2/PERSDOC 1/2 versus 3", brfss$has_personal_doctor, binary_from_raw(expected_personal_doctor_raw, 1:2, 3))
assert_clean_equal("cost_barrier follows MEDCOST yes/no", brfss$cost_barrier, binary_from_raw(raw("medcost"), 1, 2))
assert_clean_equal("checkup_within_year follows CHECKUP/CHECKUP1", brfss$checkup_within_year, binary_from_raw(expected_checkup_raw, 1, c(2, 3, 4, 8)))
assert_clean_equal("bmi_raw follows _BMI4/_BMI3/_BMI2", brfss$bmi_raw, expected_bmi_raw)
assert_clean_equal_chr("bmi_source identifies the first available BMI source", brfss$bmi_source, expected_bmi_source)
assert_clean_equal("bmi applies the documented year-specific implied decimals", brfss$bmi, expected_bmi, tolerance = 1e-8)
assert_clean_equal("bmi_cat follows _BMI4CAT/_BMI3CAT/_BMI2CAT", brfss$bmi_cat, expected_bmi_cat)
assert_clean_equal("smoker follows _SMOKER3 then _SMOKER2", brfss$smoker, expected_smoker)
assert_clean_equal("current_smoker is smoker 1/2", brfss$current_smoker, ifelse(!is.na(expected_smoker), as.numeric(expected_smoker %in% c(1, 2)), NA_real_))
assert_clean_equal("diabetes_raw follows DIABETE2 then DIABETES", brfss$diabetes_raw, expected_diabetes_raw)
assert_clean_equal("diabetes follows DIABETE2/DIABETES documented codes", brfss$diabetes, expected_diabetes)
assert_clean_equal("asthma_ever_raw follows ASTHMA2 then ASTHMA", brfss$asthma_ever_raw, expected_asthma_ever_raw)
assert_clean_equal("asthma_ever follows ASTHMA2/ASTHMA yes/no", brfss$asthma_ever, binary_from_raw(expected_asthma_ever_raw, 1, 2))
assert_clean_equal("asthma_current follows ASTHNOW yes/no", brfss$asthma_current, binary_from_raw(raw("asthnow"), 1, 2))
assert_clean_equal("heartattack follows CVDINFR aliases", brfss$heartattack, binary_from_raw(brfss$heartattack_raw, 1, 2))
assert_clean_equal("heartdisease follows CVDCRHD aliases", brfss$heartdisease, binary_from_raw(brfss$heartdisease_raw, 1, 2))
assert_clean_equal("stroke follows CVDSTRK aliases", brfss$stroke, binary_from_raw(brfss$stroke_raw, 1, 2))

cat("\n[INFO] Observations per survey year:\n")
print(table(brfss$surveyyear))

county_nonmissing <- sum(!is.na(brfss$countyfips))
cat(paste0("[INFO] Non-missing countyfips rows: ", county_nonmissing, "\n"))

cat("\n[INFO] Non-missing counts for key clean variables:\n")
print(
  sapply(
    c("countyfips", "age", "female", "race_eth", "educ_cat", "income_cat",
      "insured", "genhealth", "bmi", "current_smoker", "diabetes"),
    function(var_name) sum(!is.na(brfss[[var_name]]))
  )
)

if (all(is.na(brfss$analysis_weight))) {
  stop("[FAIL] analysis_weight is missing for all rows.")
} else {
  cat("[PASS] analysis_weight has non-missing values.\n")
}

cat("\n============================================\n")
cat("   COMPLETE\n")
cat("============================================\n")
cat(paste0("Clean pre-2011 file: ", out_rds, "\n"))
