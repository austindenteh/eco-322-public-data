################################################################################
# 02_clean_demographics.R
#
# Purpose: Load the reshaped RAND HRS long-format dataset and demonstrate:
#          (1) Cleaning basic demographic variables for analysis
#          (2) Handling HRS missing values
#          (3) Producing descriptive statistics / sanity checks
#          (4) Running a simple regression
#
# Input:   [hrs_root]/output/hrs_long.rds  (from 01_reshape_and_save.R)
# Output:  Descriptive stats and regression output printed to console
#
# Usage:   Update the hrs_root path below, then source this file:
#            source("/path/to/hrs/code/02_clean_demographics.R")
#
# Required packages: haven, dplyr, tidyr, broom
#   Install with: install.packages(c("haven", "dplyr", "tidyr", "broom"))
#
# Notes:   This is a STARTER script. It demonstrates how to clean a subset
#          of variables. Users should extend this for their own analysis.
#
# Author:  Auto-generated starter script
# Date:    February 2026
################################################################################

# --- Load packages -----------------------------------------------------------
library(haven)
library(dplyr)
library(tidyr)
library(broom)

# =============================================================================
# 1. LOAD THE RESHAPED DATA
# =============================================================================

# Set the root directory for the HRS folder.
# Users should update this path to match their system.
hrs_root <- "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/hrs"

hrs <- readRDS(file.path(hrs_root, "output", "hrs_long.rds"))
cat(sprintf("Loaded %d person-wave observations.\n", nrow(hrs)))

# =============================================================================
# 2. UNDERSTAND THE PANEL STRUCTURE
# =============================================================================
# The HRS is an UNBALANCED panel: not all respondents are in all waves.
# `inw` indicates whether the respondent was interviewed (1 = yes, 0 = no).

cat("\n--- Response rates by wave ---\n")
response_by_wave <- hrs %>%
  group_by(wave) %>%
  summarise(
    n_total = n(),
    n_interviewed = sum(inw == 1, na.rm = TRUE),
    pct_interviewed = mean(inw == 1, na.rm = TRUE) * 100,
    .groups = "drop"
  )
print(response_by_wave, n = 16)

# How many waves does each respondent contribute?
waves_per_person <- hrs %>%
  group_by(hhidpn) %>%
  summarise(total_waves = sum(inw == 1, na.rm = TRUE), .groups = "drop")

cat("\n--- Distribution of waves responded ---\n")
print(table(waves_per_person$total_waves))

# =============================================================================
# 3. CLEAN DEMOGRAPHIC VARIABLES
# =============================================================================

cat("\n--- Cleaning demographic variables ---\n")

hrs <- hrs %>%
  mutate(
    # --- 3a. Gender ---
    # ragender: 1 = Male, 2 = Female (time-invariant)
    female = case_when(
      ragender == 1 ~ 0L,
      ragender == 2 ~ 1L,
      TRUE ~ NA_integer_
    ),

    # --- 3b. Education (4 categories) ---
    # raeduc: 1=Lt HS, 2=GED, 3=HS grad, 4=Some college, 5=College+
    educ_cat = case_when(
      raeduc == 1              ~ "Less than HS",
      raeduc %in% c(2, 3)     ~ "HS/GED",
      raeduc == 4              ~ "Some college",
      raeduc == 5              ~ "College+",
      TRUE                     ~ NA_character_
    ),
    educ_cat = factor(educ_cat,
                      levels = c("Less than HS", "HS/GED",
                                 "Some college", "College+")),

    # --- 3c. Race/ethnicity (4 categories) ---
    # raracem: 1=White, 2=Black, 3=Other
    # rahispan: 0=Not Hispanic, 1=Hispanic
    race_eth = case_when(
      rahispan == 1                       ~ "Hispanic",
      rahispan == 0 & raracem == 1        ~ "White NH",
      rahispan == 0 & raracem == 2        ~ "Black NH",
      rahispan == 0 & raracem == 3        ~ "Other NH",
      TRUE                                ~ NA_character_
    ),
    race_eth = factor(race_eth,
                      levels = c("White NH", "Black NH",
                                 "Hispanic", "Other NH")),

    # --- 3d. Marital status (4 categories) ---
    # rmstat: 1-3 = married/partnered, 4-6 = sep/divorced, 7 = widowed, 8 = never
    marital = case_when(
      rmstat %in% 1:3  ~ "Married/Partnered",
      rmstat %in% 4:6  ~ "Sep/Divorced",
      rmstat == 7       ~ "Widowed",
      rmstat == 8       ~ "Never married",
      TRUE              ~ NA_character_
    ),
    marital = factor(marital,
                     levels = c("Married/Partnered", "Sep/Divorced",
                                "Widowed", "Never married")),

    # --- 3e. Cohort labels ---
    cohort_label = case_when(
      hacohort %in% c(0, 1) ~ "AHEAD",
      hacohort == 2          ~ "CODA",
      hacohort == 3          ~ "HRS",
      hacohort == 4          ~ "War Baby",
      hacohort == 5          ~ "Early Boomer",
      hacohort == 6          ~ "Mid Boomer",
      hacohort == 7          ~ "Late Boomer",
      hacohort == 8          ~ "Early Gen X",
      TRUE                   ~ NA_character_
    ),
    cohort_label = factor(cohort_label,
                          levels = c("HRS", "AHEAD", "CODA", "War Baby",
                                     "Early Boomer", "Mid Boomer",
                                     "Late Boomer", "Early Gen X"))
  )

cat("Created: female, educ_cat, race_eth, marital, cohort_label\n")

# =============================================================================
# 4. HANDLE MISSING VALUES
# =============================================================================
# When loaded via haven::read_dta(), Stata extended missing values become
# tagged NAs. For most purposes, they behave just like regular NA.
#
# If you need to distinguish WHY a value is missing:
#   haven::is_tagged_na(x, "d")  # TRUE for .D (don't know)
#   haven::is_tagged_na(x, "r")  # TRUE for .R (refused)
#   haven::na_tag(x)             # Returns the tag letter
#
# For this starter script, we simply treat all NA as missing.

cat("\n--- Missing value patterns for self-rated health (rshlt) ---\n")
shlt_missing <- hrs %>%
  filter(wave >= 4) %>%  # All cohorts present from wave 4

  group_by(wave) %>%
  summarise(
    n_total = n(),
    n_valid = sum(!is.na(rshlt)),
    n_missing = sum(is.na(rshlt)),
    pct_missing = round(mean(is.na(rshlt)) * 100, 1),
    .groups = "drop"
  )
print(shlt_missing, n = 16)

# =============================================================================
# 5. DESCRIPTIVE STATISTICS
# =============================================================================
# Restrict to interviewed respondents for meaningful statistics.

interviewed <- hrs %>% filter(inw == 1)

cat("\n==========================================\n")
cat("   DESCRIPTIVE STATISTICS (interviewed only)\n")
cat("==========================================\n")

# --- 5a. Summary statistics for key variables --------------------------------
cat("\n--- Summary statistics (all waves pooled) ---\n")
key_vars <- c("ragey_b", "female", "rshlt", "rcesd", "rbmi", "rconde",
              "rhosp", "radl5a", "riadl5a", "rmobila", "hitot", "hatotb")

summary_stats <- interviewed %>%
  summarise(across(all_of(key_vars),
                   list(n = ~ sum(!is.na(.)),
                        mean = ~ mean(., na.rm = TRUE),
                        sd = ~ sd(., na.rm = TRUE),
                        min = ~ min(., na.rm = TRUE),
                        max = ~ max(., na.rm = TRUE)),
                   .names = "{.col}__{.fn}")) %>%
  pivot_longer(everything(),
               names_to = c("variable", "stat"),
               names_sep = "__") %>%
  pivot_wider(names_from = stat, values_from = value)

print(summary_stats, n = 20)

# --- 5b. Self-rated health by wave -------------------------------------------
cat("\n--- Self-rated health by wave ---\n")
shlt_by_wave <- interviewed %>%
  group_by(wave, year) %>%
  summarise(
    n = sum(!is.na(rshlt)),
    mean_shlt = round(mean(rshlt, na.rm = TRUE), 2),
    sd_shlt = round(sd(rshlt, na.rm = TRUE), 2),
    .groups = "drop"
  )
print(shlt_by_wave, n = 16)

# --- 5c. CES-D depression by wave -------------------------------------------
cat("\n--- CES-D depression score by wave ---\n")
cesd_by_wave <- interviewed %>%
  group_by(wave, year) %>%
  summarise(
    n = sum(!is.na(rcesd)),
    mean_cesd = round(mean(rcesd, na.rm = TRUE), 2),
    sd_cesd = round(sd(rcesd, na.rm = TRUE), 2),
    .groups = "drop"
  )
print(cesd_by_wave, n = 16)

# --- 5d. Demographics by gender and race/ethnicity ---------------------------
cat("\n--- Self-rated health by gender ---\n")
interviewed %>%
  filter(!is.na(rshlt), !is.na(female)) %>%
  group_by(Gender = ifelse(female == 1, "Female", "Male")) %>%
  summarise(
    n = n(),
    mean_shlt = round(mean(rshlt), 2),
    .groups = "drop"
  ) %>%
  print()

cat("\n--- Self-rated health by race/ethnicity ---\n")
interviewed %>%
  filter(!is.na(rshlt), !is.na(race_eth)) %>%
  group_by(race_eth) %>%
  summarise(
    n = n(),
    mean_shlt = round(mean(rshlt), 2),
    .groups = "drop"
  ) %>%
  print()

# --- 5e. Cohort distribution in Wave 16 (2022) -------------------------------
cat("\n--- Cohort distribution in Wave 16 (2022) ---\n")
interviewed %>%
  filter(wave == 16) %>%
  count(cohort_label) %>%
  mutate(pct = round(n / sum(n) * 100, 1)) %>%
  print()

# =============================================================================
# 6. SIMPLE REGRESSION EXAMPLE
# =============================================================================
# OLS regression of self-rated health on demographics.
# This is purely illustrative. For a real analysis you would:
#   - Consider the panel structure (fixed effects, random effects)
#   - Use survey weights (see the `survey` package)
#   - Think carefully about functional form and controls

cat("\n==========================================\n")
cat("   SIMPLE REGRESSION EXAMPLE\n")
cat("==========================================\n")

# --- 6a. OLS (pooled, no panel structure) ------------------------------------
cat("\n--- OLS: Self-rated health on demographics ---\n")
ols_model <- lm(rshlt ~ ragey_b + female + educ_cat + race_eth,
                data = interviewed)
print(summary(ols_model))

# Tidy output with broom
cat("\n--- Tidy coefficient table ---\n")
print(tidy(ols_model, conf.int = TRUE) %>%
        mutate(across(where(is.numeric), ~ round(., 4))))

# --- 6b. Weighted OLS --------------------------------------------------------
cat("\n--- Weighted OLS: Self-rated health on demographics ---\n")
wols_model <- lm(rshlt ~ ragey_b + female + educ_cat + race_eth,
                 data = interviewed,
                 weights = rwtresp)
print(tidy(wols_model, conf.int = TRUE) %>%
        mutate(across(where(is.numeric), ~ round(., 4))))

# --- 6c. Panel fixed effects (within estimator) ------------------------------
# Using the plm package is recommended for panel econometrics in R.
# Here we show a simple approach using lm() with individual dummies.
# For large datasets, use the `fixest` package instead:
#   library(fixest)
#   fe_model <- feols(rshlt ~ ragey_b + marital | hhidpn, data = interviewed)

cat("\n--- Note: For panel fixed effects in R, we recommend the `fixest` package:\n")
cat("    library(fixest)\n")
cat("    fe_model <- feols(rshlt ~ ragey_b + marital | hhidpn, data = interviewed)\n")
cat("    summary(fe_model)\n")
cat("  This is much faster than lm() with factor(hhidpn) for 45K+ individuals.\n")

# Quick demo if fixest is available
if (requireNamespace("fixest", quietly = TRUE)) {
  cat("\n--- Fixed effects: Self-rated health on age and marital status ---\n")
  fe_model <- fixest::feols(rshlt ~ ragey_b + marital | hhidpn,
                            data = interviewed)
  print(summary(fe_model))
} else {
  cat("  (Install fixest to run the FE example: install.packages('fixest'))\n")
}

cat("\n==========================================\n")
cat("   STARTER SCRIPT COMPLETE\n")
cat("==========================================\n")
cat("You now have:\n")
cat("  - Cleaned demographic variables: female, educ_cat, race_eth, marital\n")
cat("  - Descriptive statistics by wave, cohort, and demographics\n")
cat("  - Regression examples (OLS, weighted OLS, panel FE)\n")
cat("\nNext steps for your own analysis:\n")
cat("  - Choose your outcome variable(s) and clean them\n")
cat("  - Decide on your identification strategy\n")
cat("  - Consider panel methods (FE, RE, dynamic models)\n")
cat("  - Use appropriate survey weights (see the `survey` package)\n")
cat("  - Consult the codebook for variable details\n")

################################################################################
# NOTES FOR USERS:
#
# 1. SURVEY WEIGHTS: Use the `survey` package for proper weighted estimation:
#      library(survey)
#      des <- svydesign(ids = ~1, weights = ~rwtresp, data = interviewed)
#      svymean(~rshlt, des, na.rm = TRUE)
#      svyglm(rshlt ~ ragey_b + female, design = des)
#
# 2. PANEL METHODS: Key R packages for panel econometrics:
#    - `fixest`: Very fast fixed effects (recommended)
#    - `plm`: Classic panel data econometrics
#    - `lfe`: Linear models with multiple fixed effects
#    Example with fixest:
#      library(fixest)
#      feols(rshlt ~ ragey_b + marital | hhidpn + wave, data = interviewed)
#
# 3. ATTRITION: The HRS has non-trivial attrition. Respondents who die or
#    become too ill are more likely to drop out. Consider inverse probability
#    weighting or Heckman selection models.
#
# 4. MISSING VALUES: haven::read_dta() preserves Stata's extended missing
#    value tags. For most purposes, they behave as regular NA. To check tags:
#      haven::na_tag(hrs$rshlt)  # returns tag letters ("d", "r", etc.)
#
# 5. COGNITION: From Wave 14 (2018), some cognition measures were collected
#    via web interviews, which may not be directly comparable to phone/in-person.
################################################################################
