################################################################################
# 02_clean_2011plus.R
#
# Purpose: Clean and harmonize BRFSS variables across survey years.
#          Creates consistent demographic, health, and survey design variables
#          that can be used for pooled cross-year analysis.
#          Works with any year range from 2011-2024 (default: 2023-2024).
#
# Input:   output/brfss_2011plus_appended.rds  (from 01_load_2011plus.R)
# Output:  output/brfss_2011plus_clean.rds
#          output/brfss_2011plus_clean_from_r.dta  (R export for Stata users)
#
# Usage:   Run from brfss/, from the repo root, or set BRFSS_ROOT explicitly.
#
# Key harmonization issues:
#   - Race/ethnicity: _racegr2 (2011-2014) vs. _racegr3 (2015-2021, 2023-2024)
#     vs. _racegr4 (2022)
#   - Income: income2 (2011-2020) vs. income3 (2021-2024)
#   - Sex/gender: sex (2011-2020) vs. sexvar/birthsex (2021-2024)
#   - Age: _impage (2011-2012) vs. _age80 (2013-2024)
#   - Employment: employ (2011-2012) vs. employ1 (2013-2024)
#   - Diabetes: diabete3 (2011-2014) vs. diabete4 (later years)
#   - COPD: chccopd/chccopd1 (older layouts) vs. chccopd3 (newer layouts)
#
# Author:  Austin Denteh (legacy code and Claude Code)
# Date:    February 2026
################################################################################

library(haven)      # write_dta()
library(dplyr)      # data wrangling
library(tidyr)      # drop_na(), replace_na()

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
    return(suppressWarnings(as.numeric(trimws(x))))
  }

  as.numeric(x)
}

# ============================================================================
# 1. DEFINE PATHS
# ============================================================================
# Auto-detect the dataset root from the current working directory.
#
# Optional manual override if auto-detection fails:
# Sys.setenv(BRFSS_ROOT = "/path/to/brfss")

brfss_root <- resolve_brfss_root("02_clean_2011plus.R")
cat(paste0("Using BRFSS root: ", brfss_root, "\n"))

output_override <- Sys.getenv("BRFSS_OUTPUT_DIR", unset = "")
out_dir <- if (nzchar(output_override)) output_override else file.path(brfss_root, "output")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
in_rds   <- file.path(out_dir, "brfss_2011plus_appended.rds")
out_rds  <- file.path(out_dir, "brfss_2011plus_clean.rds")
out_dta  <- file.path(out_dir, "brfss_2011plus_clean_from_r.dta")

# ============================================================================
# 2. LOAD APPENDED DATA
# ============================================================================

cat("Loading appended BRFSS data...\n")
brfss <- readRDS(in_rds)
cat(paste0("Loaded: ", nrow(brfss), " observations, ", ncol(brfss), " variables\n"))

# Standardize column names to lowercase (should already be, but ensure)
names(brfss) <- tolower(names(brfss))
input_names <- names(brfss)

support_vars <- c(
  "ctycode1", "sex", "_racegr2", "_racegr3", "_racegr4", "_impage", "_age80",
  "sexvar", "birthsex", "income2", "income3", "employ", "employ1",
  "diabete3", "diabete4", "chccopd", "chccopd1", "chccopd3"
)
added_placeholder_vars <- setdiff(support_vars, names(brfss))

for (var_name in added_placeholder_vars) {
  brfss[[var_name]] <- NA_real_
}

imonth_num <- coerce_numeric_if_present(brfss, "imonth")
iyear_num  <- coerce_numeric_if_present(brfss, "iyear")
ctycode1_num <- coerce_numeric_if_present(brfss, "ctycode1")

# ============================================================================
# 3. HARMONIZE DEMOGRAPHICS
# ============================================================================

cat("\nHarmonizing demographics...\n")

brfss <- brfss %>%
  mutate(

    # --- 3a. State FIPS code -------------------------------------------------
    statefips = `_state`,

    # CTYCODE1 is a three-digit county code in the 2011-2012 public files.
    # Later 2011-plus files do not expose it. Exclude CDC nonresponse codes.
    county_code_raw = ifelse(
      ctycode1_num >= 1 & ctycode1_num <= 840 &
        !(ctycode1_num %in% c(777, 888, 999)),
      ctycode1_num,
      NA_real_
    ),
    county_code_source = ifelse(!is.na(county_code_raw), "ctycode1", NA_character_),
    countyfips = ifelse(
      !is.na(statefips) & !is.na(county_code_raw),
      as.numeric(statefips) * 1000 + county_code_raw,
      NA_real_
    ),

    # --- 3b. Interview month and year ---------------------------------------
    # Retain the raw fields in a numeric form matching Stata's destring step.
    imonth = imonth_num,
    iyear = iyear_num,
    month = ifelse(imonth_num >= 1 & imonth_num <= 12, imonth_num, NA_real_),
    year = iyear_num,

    # --- 3c. Age -------------------------------------------------------------
    # _age80 is the standard newer imputed age. _impage is the early fallback.
    age = case_when(
      !is.na(`_age80`) ~ as.numeric(`_age80`),
      is.na(`_age80`) & !is.na(`_impage`) ~ as.numeric(`_impage`),
      TRUE ~ NA_real_
    ),

    # _ageg5yr: Age in five-year categories (CDC calculated)
    age_cat = `_ageg5yr`,

    # --- 3d. Sex / Gender ----------------------------------------------------
    # Prefer the most specific newer source variable available, then fall back.
    female = case_when(
      !is.na(sexvar) & sexvar == 2 ~ 1L,
      !is.na(sexvar) & sexvar == 1 ~ 0L,
      is.na(sexvar) & !is.na(birthsex) & birthsex == 2 ~ 1L,
      is.na(sexvar) & !is.na(birthsex) & birthsex == 1 ~ 0L,
      is.na(sexvar) & is.na(birthsex) & sex == 2 ~ 1L,
      is.na(sexvar) & is.na(birthsex) & sex == 1 ~ 0L,
      TRUE ~ NA_integer_
    ),

    # --- 3e. Race/Ethnicity --------------------------------------------------
    # The CDC's computed race/ethnicity variable changed names over time:
    #   2011-2014: _racegr2 (1=White NH, 2=Black NH, 3=Other NH, 4=Multi NH, 5=Hispanic)
    #   2015-2021: _racegr3 (same 1-5 coding)
    #   2022:      _racegr4 (same 1-5 coding, renamed because _RACE changed)
    #   2023-2024: _racegr3 again
    # Collapse the five-level CDC variable to four categories by combining
    # Other NH and Multiracial NH.
    race_eth = case_when(
      # Use _racegr2 wherever it has non-missing values (2011-2014)
      `_racegr2` == 1 ~ 1L,  # White NH
      `_racegr2` == 2 ~ 2L,  # Black NH
      `_racegr2` == 5 ~ 3L,  # Hispanic
      `_racegr2` %in% c(3, 4) ~ 4L,  # Other/Multi NH
      # Use _racegr3 wherever it has non-missing values (2015-2021, 2023+)
      `_racegr3` == 1 ~ 1L,  # White NH
      `_racegr3` == 2 ~ 2L,  # Black NH
      `_racegr3` == 5 ~ 3L,  # Hispanic
      `_racegr3` %in% c(3, 4) ~ 4L,  # Other/Multi NH
      # Use _racegr4 wherever it has non-missing values (2022)
      `_racegr4` == 1 ~ 1L,
      `_racegr4` == 2 ~ 2L,
      `_racegr4` == 5 ~ 3L,
      `_racegr4` %in% c(3, 4) ~ 4L,
      TRUE ~ NA_integer_
    ),

    # Race indicators
    white    = as.integer(race_eth == 1),
    black    = as.integer(race_eth == 2),
    hispanic = as.integer(race_eth == 3),
    raceother = as.integer(race_eth == 4),

    # --- 3f. Education -------------------------------------------------------
    # educa: 1-3=Less than HS, 4=HS grad, 5=Some college, 6=College grad, 9=Refused
    educ_cat = case_when(
      educa >= 1 & educa <= 3 ~ 1L,  # Less than HS
      educa == 4 ~ 2L,                # HS graduate/GED
      educa == 5 ~ 3L,                # Some college
      educa == 6 ~ 4L,                # College graduate
      TRUE ~ NA_integer_
    ),

    hsdropout   = as.integer(educ_cat == 1),
    hsgraduate  = as.integer(educ_cat == 2),
    somecollege = as.integer(educ_cat == 3),
    college     = as.integer(educ_cat == 4),

    # --- 3g. Marital Status --------------------------------------------------
    # marital: 1=Married, 2=Divorced, 3=Widowed, 4=Separated,
    #          5=Never married, 6=Unmarried couple, 9=Refused
    marital_cat = case_when(
      marital %in% c(1, 6) ~ 1L,   # Married/partnered
      marital %in% c(2, 4) ~ 2L,   # Divorced/separated
      marital == 3 ~ 3L,            # Widowed
      marital == 5 ~ 4L,            # Never married
      TRUE ~ NA_integer_
    ),

    married      = as.integer(marital_cat == 1),
    divorced     = as.integer(marital_cat == 2),
    widowed      = as.integer(marital_cat == 3),
    nevermarried = as.integer(marital_cat == 4),

    # --- 3h. Income ----------------------------------------------------------
    # income2 (2011-2020): 8 categories (1=<$10K ... 8=$75K+)
    # income3 (2021+): 11 categories — collapse to 8 for comparability
    income_cat = case_when(
      surveyyear <= 2020 & income2 >= 1 & income2 <= 8 ~ as.integer(income2),
      surveyyear >= 2021 & income3 >= 1 & income3 <= 8 ~ as.integer(income3),
      surveyyear >= 2021 & income3 > 8 & income3 < 77 ~ 8L,
      TRUE ~ NA_integer_
    ),

    # --- 3i. Employment ------------------------------------------------------
    # employ/employ1: 1=Employed, 2=Self-employed, 3-4=Unemployed,
    #                 5=Homemaker, 6=Student, 7=Retired, 8=Unable to work
    working = case_when(
      employ1 %in% c(1, 2) ~ 1L,
      employ1 >= 3 & employ1 <= 8 ~ 0L,
      is.na(employ1) & employ %in% c(1, 2) ~ 1L,
      is.na(employ1) & employ >= 3 & employ <= 8 ~ 0L,
      TRUE ~ NA_integer_
    ),

    student = case_when(
      employ1 == 6 ~ 1L,
      employ1 >= 1 & employ1 <= 8 & employ1 != 6 ~ 0L,
      is.na(employ1) & employ == 6 ~ 1L,
      is.na(employ1) & employ >= 1 & employ <= 8 & employ != 6 ~ 0L,
      TRUE ~ NA_integer_
    )
  )

# ============================================================================
# 4. HEALTH OUTCOMES
# ============================================================================

cat("Creating health outcome variables...\n")

brfss <- brfss %>%
  mutate(

    # --- 4a. General health --------------------------------------------------
    # genhlth: 1=Excellent, 2=Very good, 3=Good, 4=Fair, 5=Poor
    genhealth = ifelse(genhlth >= 1 & genhlth <= 5, genhlth, NA_real_),
    fair_or_poor = ifelse(!is.na(genhealth), as.integer(genhealth >= 4), NA_integer_),

    # --- 4b. Mental health days ----------------------------------------------
    # menthlth: 1-30=days, 88=none, 77=DK, 99=Refused
    mental_days = case_when(
      menthlth >= 1 & menthlth <= 30 ~ as.numeric(menthlth),
      menthlth == 88 ~ 0,
      TRUE ~ NA_real_
    ),

    # --- 4c. Physical health days --------------------------------------------
    physical_days = case_when(
      physhlth >= 1 & physhlth <= 30 ~ as.numeric(physhlth),
      physhlth == 88 ~ 0,
      TRUE ~ NA_real_
    ),

    # --- 4d. BMI -------------------------------------------------------------
    # _bmi5: BMI * 100 (e.g., 2500 = 25.0)
    bmi = ifelse(`_bmi5` < 9999, `_bmi5` / 100, NA_real_),

    # _bmi5cat: 1=Underweight, 2=Normal, 3=Overweight, 4=Obese
    bmi_cat = ifelse(`_bmi5cat` >= 1 & `_bmi5cat` <= 4, `_bmi5cat`, NA_real_),

    # --- 4e. Smoking status --------------------------------------------------
    # _smoker3: 1=Current daily, 2=Current some days, 3=Former, 4=Never
    smoker = ifelse(`_smoker3` >= 1 & `_smoker3` <= 4, `_smoker3`, NA_real_),
    current_smoker = ifelse(!is.na(smoker), as.integer(smoker %in% c(1, 2)), NA_integer_),

    # --- 4f. Chronic conditions ----------------------------------------------
    # Consistent coding: 1=Yes, 2=No

    # Diabetes (diabete3/diabete4: 1=Yes, 3=No/pre-diabetes)
    diabetes = case_when(
      diabete4 == 1 ~ 1L,
      diabete4 == 3 ~ 0L,
      is.na(diabete4) & diabete3 == 1 ~ 1L,
      is.na(diabete4) & diabete3 == 3 ~ 0L,
      TRUE ~ NA_integer_
    ),

    # Asthma
    asthma_ever = case_when(
      asthma3 == 1 ~ 1L,
      asthma3 == 2 ~ 0L,
      TRUE ~ NA_integer_
    ),

    asthma_current = case_when(
      asthnow == 1 ~ 1L,
      asthnow == 2 ~ 0L,
      TRUE ~ NA_integer_
    ),

    # Heart disease (angina or coronary heart disease)
    heartdisease = case_when(
      cvdcrhd4 == 1 ~ 1L,
      cvdcrhd4 == 2 ~ 0L,
      TRUE ~ NA_integer_
    ),

    # Heart attack
    heartattack = case_when(
      cvdinfr4 == 1 ~ 1L,
      cvdinfr4 == 2 ~ 0L,
      TRUE ~ NA_integer_
    )
  )

# Handle COPD — variable name varies across years
brfss <- brfss %>%
  mutate(copd = case_when(
    chccopd3 == 1 ~ 1L,
    chccopd3 == 2 ~ 0L,
    chccopd == 1 ~ 1L,
    chccopd == 2 ~ 0L,
    chccopd1 == 1 ~ 1L,
    chccopd1 == 2 ~ 0L,
    TRUE ~ NA_integer_
  ))

expected_county_raw <- ifelse(
  ctycode1_num >= 1 & ctycode1_num <= 840 &
    !(ctycode1_num %in% c(777, 888, 999)),
  ctycode1_num,
  NA_real_
)
expected_countyfips <- ifelse(
  !is.na(brfss$statefips) & !is.na(expected_county_raw),
  as.numeric(brfss$statefips) * 1000 + expected_county_raw,
  NA_real_
)
county_mismatch <- !(
  (is.na(brfss$countyfips) & is.na(expected_countyfips)) |
    (!is.na(brfss$countyfips) & !is.na(expected_countyfips) &
       brfss$countyfips == expected_countyfips)
)
if (any(county_mismatch)) {
  stop(paste0("[FAIL] countyfips does not follow CTYCODE1 in ", sum(county_mismatch), " row(s)."))
}
cat(paste0("[PASS] CTYCODE1 county construction validated; non-missing countyfips rows: ",
           sum(!is.na(brfss$countyfips)), "\n"))

if (length(added_placeholder_vars) > 0) {
  brfss <- brfss %>% select(-any_of(added_placeholder_vars))
}

# ============================================================================
# 5. SAVE
# ============================================================================

cat("\nSaving cleaned dataset...\n")

brfss <- brfss %>% arrange(surveyyear, statefips)

saveRDS(brfss, out_rds)
cat(paste0("Saved: ", out_rds, "\n"))

tryCatch({
  write_dta(brfss, out_dta)
  cat(paste0("Saved: ", out_dta, "\n"))
}, error = function(e) {
  cat(paste0("Could not save .dta: ", e$message, "\n"))
  cat("The .rds file was saved successfully.\n")
})

cat(paste0("Observations: ", nrow(brfss), "\n"))
cat(paste0("Variables: ", ncol(brfss), "\n"))

# ============================================================================
# 6. DESCRIPTIVE STATISTICS
# ============================================================================

cat("\n============================================\n")
cat("   DESCRIPTIVE STATISTICS (optional; not run by default)\n")
cat("============================================\n\n")

# Uncomment this block if you want example descriptive statistics and regressions.
if (FALSE) {

# --- 6a. Sample sizes by year ------------------------------------------------
cat("--- Sample sizes by year ---\n")
year_counts <- brfss %>%
  count(surveyyear) %>%
  as.data.frame()
print(year_counts, row.names = FALSE)

# --- 6b. Demographics (unweighted) -------------------------------------------
cat("\n--- Age distribution ---\n")
print(summary(brfss$age))

cat("\n--- Gender ---\n")
print(table(brfss$female, useNA = "ifany"))

cat("\n--- Race/ethnicity ---\n")
race_labels <- c("1" = "White NH", "2" = "Black NH",
                 "3" = "Hispanic", "4" = "Other/Multi NH")
race_table <- brfss %>%
  filter(!is.na(race_eth)) %>%
  count(race_eth) %>%
  mutate(pct = round(n / sum(n) * 100, 1),
         label = race_labels[as.character(race_eth)])
print(as.data.frame(race_table), row.names = FALSE)

cat("\n--- Education ---\n")
educ_labels <- c("1" = "Less than HS", "2" = "HS grad/GED",
                 "3" = "Some college", "4" = "College grad")
educ_table <- brfss %>%
  filter(!is.na(educ_cat)) %>%
  count(educ_cat) %>%
  mutate(pct = round(n / sum(n) * 100, 1),
         label = educ_labels[as.character(educ_cat)])
print(as.data.frame(educ_table), row.names = FALSE)

# --- 6c. Health outcomes (unweighted) ----------------------------------------
cat("\n--- Self-rated health ---\n")
print(table(brfss$genhealth, useNA = "ifany"))

cat("\n--- Mental health days (past 30) ---\n")
print(summary(brfss$mental_days))

cat("\n--- BMI ---\n")
print(summary(brfss$bmi))

# ============================================================================
# 7. EXAMPLE ANALYSIS
# ============================================================================

cat("\n============================================\n")
cat("   EXAMPLE ANALYSIS\n")
cat("============================================\n\n")

# Keep the example section lightweight by using reproducible samples.
# The cleaned outputs above are written before these examples run.
example_seed <- 322
example_max_n <- 25000L

# --- 7a. Unweighted OLS on a sampled analysis frame --------------------------
cat("--- OLS: Mental health days (sampled, unweighted) ---\n")
ols_df <- brfss %>%
  filter(!is.na(mental_days) & !is.na(female) & !is.na(age) &
         !is.na(race_eth) & !is.na(educ_cat))

if (nrow(ols_df) > example_max_n) {
  set.seed(example_seed)
  ols_df <- ols_df %>% slice_sample(n = example_max_n)
  cat(paste0("Using ", example_max_n, " sampled rows for the OLS example\n"))
} else {
  cat(paste0("Using all ", nrow(ols_df), " eligible rows for the OLS example\n"))
}

ols_model <- lm(mental_days ~ female + age + factor(race_eth) +
                  factor(educ_cat) + factor(surveyyear),
                data = ols_df)
print(broom::tidy(ols_model) %>% head(10))
cat("  (showing first 10 coefficients; full model has year fixed effects)\n")

# --- 7b. Weighted examples on the most recent year ---------------------------
cat("\n--- Weighted examples ---\n")
cat("Setting up lightweight weighted examples for the most recent year...\n")

# Identify the correct weight variable name
wt_var <- if ("_llcpwt" %in% names(brfss)) "_llcpwt" else "x_llcpwt"

# Pick the most recent year in the data and sample complete cases
# so the examples finish quickly on typical laptops.
example_year <- max(brfss$surveyyear, na.rm = TRUE)
cat(paste0("Using year ", example_year, " for weighted examples\n"))

brfss_sub <- brfss %>%
  filter(surveyyear == example_year) %>%
  filter(!is.na(fair_or_poor) & !is.na(mental_days) & !is.na(female) &
         !is.na(age) & !is.na(race_eth) & !is.na(educ_cat) &
         !is.na(.data[[wt_var]]) & .data[[wt_var]] > 0)

if (nrow(brfss_sub) > example_max_n) {
  set.seed(example_seed)
  brfss_sub <- brfss_sub %>% slice_sample(n = example_max_n)
  cat(paste0("Using ", example_max_n,
             " sampled rows from ", example_year,
             " for the weighted examples\n"))
} else {
  cat(paste0("Using all ", nrow(brfss_sub),
             " eligible rows from ", example_year,
             " for the weighted examples\n"))
}

example_weights <- brfss_sub[[wt_var]]
example_glm_weights <- example_weights / mean(example_weights, na.rm = TRUE)

cat(paste0("\nWeighted mean of fair/poor health (", example_year, " sample):\n"))
print(setNames(weighted.mean(brfss_sub$fair_or_poor, w = example_weights, na.rm = TRUE),
               "fair_or_poor"))

wls_model <- lm(
  mental_days ~ female + age + factor(race_eth) + factor(educ_cat),
  data = brfss_sub,
  weights = example_weights
)
cat(paste0("\nWeighted OLS (", example_year, " sample):\n"))
print(broom::tidy(wls_model))

wlogit_model <- glm(
  fair_or_poor ~ female + age + factor(race_eth) + factor(educ_cat),
  data = brfss_sub,
  family = quasibinomial(),
  weights = example_glm_weights
)
cat(paste0("\nWeighted logit (", example_year, " sample):\n"))
print(broom::tidy(wlogit_model))
}

cat("\n============================================\n")
cat("   DONE\n")
cat("============================================\n")

################################################################################
# NOTES FOR USERS:
#
# 1. SURVEY WEIGHTS ARE ESSENTIAL: The BRFSS uses a complex survey design.
#    In this starter, the weighted examples use _LLCPWT directly in
#    weighted.mean(), lm(..., weights = ...), and glm(..., weights = ...).
#    The logistic example rescales weights to mean 1 for numerical stability.
#    This is a simple weighted workflow, not full design-based survey
#    inference. Unweighted analyses are for quick checks only.
#
# 2. COLUMN NAMES WITH UNDERSCORES: CDC calculated variables start with _.
#    In R, access them with backticks: brfss$`_age80` or brfss[["_age80"]].
#    This script creates clean names (age, bmi, etc.) to avoid this issue.
#
# 3. CROSS-YEAR HARMONIZATION: Variables harmonized here (race_eth,
#    income_cat, female, diabetes, working, and copd) are built from whichever source variable is
#    present in a given year, which makes the transition-year logic more robust.
#
# 4. MEMORY MANAGEMENT: With 5+ million rows, consider:
#    - Using data.table instead of dplyr for faster operations
#    - Subsetting to years of interest before analysis
#    - Using arrow::open_dataset() for out-of-memory analysis
#
# 5. WEIGHTED EXAMPLES: The examples use a reproducible sample from the most
#    recent year to keep runtime reasonable. For final estimates, re-run your
#    own model on the full analysis sample. For multi-year pooled analysis, you
#    may need to adjust weights. See CDC documentation on combining BRFSS years.
#
# 6. OUTPUTS: This script writes brfss_2011plus_clean.rds and a separate
#    brfss_2011plus_clean_from_r.dta export so it does not overwrite the
#    Stata-native brfss_2011plus_clean.dta produced by 02_clean_2011plus.do.
#
# 7. SEXVAR vs. SEX: The 2021-2024 public files use SEXVAR, and some years
#    also include BIRTHSEX. Older years use SEX. If you need gender identity,
#    look for SOMALE/SOFEMALE (sexual orientation) and TRNSGNDR
#    (transgender status) variables in 2022+ data.
################################################################################
