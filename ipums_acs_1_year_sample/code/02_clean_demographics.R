################################################################################
# 02_clean_demographics.R
#
# Purpose: Load the ACS working dataset and demonstrate cleaning of:
#          (1) Demographics: race/ethnicity, sex, age, marital status
#          (2) Education: years of education, degree indicators
#          (3) Employment and income
#          (4) Health insurance (if available; 2008+ only)
#          (5) Immigration and citizenship (if available)
#          (6) Descriptive statistics and simple regressions
#
# Input:   [acs_root]/output/acs_working.rds  (from 01_load_and_subset.R)
# Output:  Descriptive statistics and regression output to console
#
# Usage:   Update the acs_root path below, then source this file:
#            source("/path/to/ipums_acs_1_year_sample/code/02_clean_demographics.R")
#
# Required packages: haven, dplyr
#   Install with: install.packages(c("haven", "dplyr"))
#
# Notes:   This is a STARTER script. It demonstrates how to clean key
#          variables. Users should extend this for their own analysis.
#          Variable coding follows the Kuka et al. (2020) replication code.
#
#          The script uses variables that are standard in most IPUMS ACS
#          extracts. Health insurance and immigration sections are guarded
#          since those variables may not be in every extract.
#
# Author:  Austin Denteh (adapted from Kuka et al. 2020 replication code)
# Date:    February 2026
################################################################################

library(haven)
library(dplyr)

# ============================================================================
# 1. DEFINE PATHS AND LOAD DATA
# ============================================================================

acs_root <- "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/ipums_acs_1_year_sample"

acs <- readRDS(file.path(acs_root, "output", "acs_working.rds"))
cat(sprintf("Loaded %s observations.\n", format(nrow(acs), big.mark = ",")))

# --- Quick check: core variables ---
# These should be in any IPUMS ACS extract. If missing, the extract
# may need to be recreated with more variables selected.
core_vars <- c("year", "age", "sex", "race", "hispan", "educd",
               "empstat", "incwage", "poverty")
missing_core <- core_vars[!core_vars %in% names(acs)]
if (length(missing_core) > 0) {
  warning("The following core variables are not in your extract: ",
          paste(missing_core, collapse = ", "),
          "\nSome sections below may produce errors.",
          "\nConsider creating a new IPUMS extract that includes these variables.")
}

# ============================================================================
# 2. DEMOGRAPHICS: RACE AND ETHNICITY
# ============================================================================
# Create mutually exclusive race/ethnicity categories.
# Hispanic ethnicity takes precedence over race (following Kuka et al.).

acs <- acs %>%
  mutate(
    hisp    = as.integer(hispan != 0),
    white   = as.integer(race == 1 & hisp == 0),
    black   = as.integer(race == 2 & hisp == 0),
    asian   = as.integer(race %in% c(4, 5, 6) & hisp == 0),
    other   = as.integer(hisp == 0 & white == 0 & black == 0 & asian == 0),
    race_eth = case_when(
      white == 1 ~ "White NH",
      black == 1 ~ "Black NH",
      hisp == 1  ~ "Hispanic",
      asian == 1 ~ "Asian NH",
      other == 1 ~ "Other NH"
    )
  )

cat("\n--- Race/ethnicity ---\n")
race_tab <- acs %>% count(race_eth) %>% mutate(pct = round(n / sum(n) * 100, 1))
print(as.data.frame(race_tab), row.names = FALSE)

# ============================================================================
# 3. DEMOGRAPHICS: SEX, AGE, MARITAL STATUS
# ============================================================================

acs <- acs %>%
  mutate(
    female   = as.integer(sex == 2),
    age_18_24 = as.integer(age >= 18 & age <= 24),
    age_25_34 = as.integer(age >= 25 & age <= 34),
    age_35_44 = as.integer(age >= 35 & age <= 44),
    age_45_54 = as.integer(age >= 45 & age <= 54),
    age_55_64 = as.integer(age >= 55 & age <= 64),
    age_65plus = as.integer(age >= 65)
  )

# Marital status (may not be in every extract)
if ("marst" %in% names(acs)) {
  acs <- acs %>% mutate(married = as.integer(marst %in% c(1, 2)))
}

cat("\n--- Age distribution ---\n")
print(summary(acs$age))

cat("\n--- Sex ---\n")
print(table(Female = acs$female))

# ============================================================================
# 4. EDUCATION
# ============================================================================
# Map detailed IPUMS education codes (educd) to years of education.
# Then create degree attainment indicators.
# Coding follows Kuka et al. (2020) Appendix.

acs <- acs %>%
  mutate(
    yrsed = case_when(
      educd == 2  ~ 0,                              # no school
      educd == 14 ~ 2,                              # nursery-4th
      educd %in% c(13, 15) ~ 4,                     # 1st-4th grade
      educd == 16 ~ 5,                              # 5th-6th grade
      educd == 17 ~ 6,                              # 5th-6th grade
      educd == 22 ~ 7,                              # 7th-8th grade
      educd == 23 ~ 8,                              # 7th-8th grade
      educd == 25 ~ 9,                              # 9th grade
      educd == 26 ~ 10,                             # 10th grade
      educd == 30 ~ 11,                             # 11th grade
      educd %in% c(40, 50, 61, 63, 64) ~ 12,       # 12th / HS / GED
      educd == 65 ~ 13,                             # some college <1yr
      educd %in% c(70, 71) ~ 14,                    # some college / associate's
      educd == 101 ~ 16,                            # bachelor's
      educd == 114 ~ 18,                            # master's
      educd == 115 ~ 19,                            # professional
      educd == 116 ~ 21                             # doctorate
    ),
    hs           = as.integer(yrsed >= 12 & educd != 61),   # HS+ (excl 12th no diploma)
    some_college = as.integer(yrsed > 12),
    college      = as.integer(yrsed >= 16)
  )

cat("\n--- Years of education ---\n")
print(table(acs$yrsed, useNA = "ifany"))

cat("\n--- Education attainment ---\n")
cat(sprintf("  HS or more:      %.1f%%\n", mean(acs$hs, na.rm = TRUE) * 100))
cat(sprintf("  Some college:    %.1f%%\n", mean(acs$some_college, na.rm = TRUE) * 100))
cat(sprintf("  College degree:  %.1f%%\n", mean(acs$college, na.rm = TRUE) * 100))

# ============================================================================
# 5. EMPLOYMENT
# ============================================================================
# empstat: 0 = N/A (under 16), 1 = employed, 2 = unemployed, 3 = NILF

acs <- acs %>%
  mutate(
    employed   = ifelse(empstat == 0, NA, as.integer(empstat == 1)),
    unemployed = ifelse(empstat == 0, NA, as.integer(empstat == 2)),
    in_lf      = ifelse(empstat == 0, NA, as.integer(empstat %in% c(1, 2)))
  )

cat("\n--- Employment status (ages 16+) ---\n")
emp_tab <- acs %>% filter(age >= 16) %>%
  summarize(employed = mean(employed, na.rm = TRUE),
            unemployed = mean(unemployed, na.rm = TRUE),
            lfp = mean(in_lf, na.rm = TRUE),
            n = sum(!is.na(employed)))
print(as.data.frame(emp_tab), row.names = FALSE)

# ============================================================================
# 6. INCOME AND POVERTY
# ============================================================================

acs <- acs %>%
  mutate(
    # Poverty status (poverty==0 means not determined)
    inpov = ifelse(poverty == 0, NA, as.integer(poverty <= 100)),
    finc_to_pov = ifelse(poverty == 0, NA, poverty / 100),
    # Wage income (999998/999999 = missing/N/A)
    wage = ifelse(incwage >= 999998, NA, incwage)
  )

cat("\n--- Poverty status ---\n")
cat(sprintf("  In poverty: %.1f%%\n", mean(acs$inpov, na.rm = TRUE) * 100))

cat("\n--- Wage income (conditional on positive) ---\n")
print(summary(acs$wage[acs$wage > 0]))

# ============================================================================
# 7. HEALTH INSURANCE (if available)
# ============================================================================
# hcovany: 1 = no coverage, 2 = with coverage (available 2008+)
# These variables may not be in every extract.

if ("hcovany" %in% names(acs)) {

  acs <- acs %>%
    mutate(
      any_insurance = as.integer(hcovany == 2),
      uninsured     = as.integer(hcovany == 1)
    )

  if ("hcovpriv" %in% names(acs)) acs$priv_ins <- as.integer(acs$hcovpriv == 2)
  if ("hcovpub"  %in% names(acs)) acs$pub_ins  <- as.integer(acs$hcovpub == 2)
  if ("hinscaid" %in% names(acs)) acs$medicaid  <- as.integer(acs$hinscaid == 2)
  if ("hinscare" %in% names(acs)) acs$medicare  <- as.integer(acs$hinscare == 2)

  cat("\n--- Health insurance (2008+) ---\n")
  ins_tab <- acs %>% filter(year >= 2008) %>%
    summarize(any_ins = mean(any_insurance, na.rm = TRUE),
              unins   = mean(uninsured, na.rm = TRUE),
              n = n())
  print(as.data.frame(ins_tab), row.names = FALSE)

} else {
  cat("\n[SKIP] Health insurance: hcovany not in extract.\n")
}

# ============================================================================
# 8. IMMIGRATION AND CITIZENSHIP (if available)
# ============================================================================

if ("citizen" %in% names(acs)) {
  acs <- acs %>%
    mutate(
      noncitizen  = ifelse(citizen == 0, NA, as.integer(citizen == 3)),
      usborn      = ifelse(citizen == 0, NA, as.integer(citizen %in% c(4, 5))),
      naturalized = ifelse(citizen == 0, NA, as.integer(citizen == 2))
    )
  cat("\n--- Citizenship ---\n")
  cit_tab <- acs %>%
    summarize(usborn = mean(usborn, na.rm = TRUE),
              naturalized = mean(naturalized, na.rm = TRUE),
              noncitizen = mean(noncitizen, na.rm = TRUE),
              n = sum(!is.na(noncitizen)))
  print(as.data.frame(cit_tab), row.names = FALSE)
} else {
  cat("\n[SKIP] Citizenship: citizen not in extract.\n")
}

if ("bpl" %in% names(acs)) {
  acs <- acs %>%
    mutate(
      bpl_us      = as.integer(bpl >= 1 & bpl <= 120),
      bpl_mexico  = as.integer(bpl == 200),
      bpl_centam  = as.integer(bpl >= 210 & bpl <= 300),
      bpl_asia    = as.integer(bpl >= 500 & bpl < 600),
      bpl_europe  = as.integer(bpl >= 400 & bpl < 500)
    )
}

# ============================================================================
# 9. DESCRIPTIVE STATISTICS
# ============================================================================

cat("\n============================================\n")
cat("   DESCRIPTIVE STATISTICS\n")
cat("============================================\n")

cat("\n--- Key demographic variables ---\n")
print(summary(acs[c("female", "age", "hisp", "white", "black", "asian")]))

cat("\n--- Education variables ---\n")
print(summary(acs[c("yrsed", "hs", "some_college", "college")]))

cat("\n--- Employment and income ---\n")
print(summary(acs[c("employed", "in_lf", "wage", "inpov", "finc_to_pov")]))

# --- Insurance trends by year ---
if ("uninsured" %in% names(acs)) {
  cat("\n--- Uninsured rate by year (2008+) ---\n")
  ins_trend <- acs %>% filter(year >= 2008) %>%
    group_by(year) %>%
    summarize(uninsured_rate = mean(uninsured, na.rm = TRUE),
              n = n(), .groups = "drop")
  print(as.data.frame(ins_trend), row.names = FALSE)

  cat("\n--- Uninsured rate by race/ethnicity (2008+) ---\n")
  ins_race <- acs %>% filter(year >= 2008) %>%
    group_by(race_eth) %>%
    summarize(uninsured_rate = mean(uninsured, na.rm = TRUE),
              n = n(), .groups = "drop")
  print(as.data.frame(ins_race), row.names = FALSE)
}

# ============================================================================
# 10. EXAMPLE REGRESSION
# ============================================================================
# Simple OLS: uninsured = f(demographics, education)
# This is just a demonstration -- not a causal model.

cat("\n============================================\n")
cat("   EXAMPLE REGRESSION\n")
cat("============================================\n")

if ("uninsured" %in% names(acs)) {

  cat("\n--- OLS: Uninsured on demographics (2008+, ages 18-64) ---\n")

  reg_data <- acs %>%
    filter(year >= 2008, age >= 18, age <= 64,
           !is.na(uninsured), !is.na(race_eth), !is.na(hs),
           !is.na(college))

  fit <- lm(uninsured ~ female + age + factor(race_eth) + hs + college +
               factor(year),
             data = reg_data, weights = perwt)
  print(summary(fit))

} else {
  cat("\n[SKIP] Insurance regression requires hcovany in extract.\n")
  cat("  Alternative: try a wage regression:\n")
  cat("    lm(wage ~ female + age + factor(race_eth) + hs + college, data = acs, weights = perwt)\n")
}

cat("\n============================================\n")
cat("   CLEANING COMPLETE\n")
cat("============================================\n")
cat("Variables created: race_eth, female, yrsed, hs, college,\n")
cat("  employed, in_lf, wage, inpov, and more.\n")
cat("\nThis is a starter script -- extend for your own analysis.\n")

################################################################################
# NOTES:
#
# 1. CUSTOM EXTRACTS:
#    The core sections (demographics, education, employment, income) use
#    variables that are standard in most IPUMS ACS extracts. Health
#    insurance and immigration sections are lightly guarded since those
#    variables may not be in every extract.
#
# 2. SAMPLE RESTRICTIONS:
#    This script does not restrict the sample. For specific analyses:
#    - Working-age adults: filter(age >= 18, age <= 64)
#    - Children: filter(age < 18)
#    - Non-institutionalized: filter(!gq %in% c(3, 4))
#
# 3. SURVEY WEIGHTS:
#    Always use perwt for person-level estimates:
#      lm(..., weights = perwt)
#    For proper standard errors, use the survey package:
#      library(survey)
#      des <- svydesign(ids = ~cluster, strata = ~strata,
#                       weights = ~perwt, data = acs)
#      svyglm(uninsured ~ female + age, design = des)
#
# 4. EDUCATION CODING:
#    The yrsed variable follows the Kuka et al. mapping from IPUMS
#    detailed education codes (educd). Some rare categories may be
#    unmapped (yrsed will be NA for those observations).
#
# 5. INSURANCE VARIABLES:
#    Health insurance variables (hcovany, hcovpriv, hcovpub, etc.)
#    are only available from 2008 onwards.
#
# 6. IMMIGRATION:
#    - citizen == 3 identifies non-citizens
#    - bpl gives detailed birthplace codes
################################################################################
