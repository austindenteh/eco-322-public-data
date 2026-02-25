################################################################################
# 02_clean_demographics.R
#
# Purpose: Load the ACS working dataset and demonstrate cleaning of:
#          (1) Demographics: race/ethnicity, sex, age, marital status
#          (2) Education: years of education, degree indicators
#          (3) Employment and income
#          (4) Health insurance
#          (5) Immigration and citizenship
#          (6) Poverty and public assistance
#          (7) Descriptive statistics and simple regressions
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
    married  = as.integer(marst %in% c(1, 2)),
    age_18_24 = as.integer(age >= 18 & age <= 24),
    age_25_34 = as.integer(age >= 25 & age <= 34),
    age_35_44 = as.integer(age >= 35 & age <= 44),
    age_45_54 = as.integer(age >= 45 & age <= 54),
    age_55_64 = as.integer(age >= 55 & age <= 64),
    age_65plus = as.integer(age >= 65)
  )

cat("\n--- Age distribution ---\n")
print(summary(acs$age))

cat("\n--- Sex ---\n")
print(table(Female = acs$female))

cat("\n--- Marital status ---\n")
print(table(Married = acs$married))

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
# 7. HEALTH INSURANCE
# ============================================================================
# hcovany: 1 = no coverage, 2 = with coverage (available 2008+)

acs <- acs %>%
  mutate(
    any_insurance = as.integer(hcovany == 2),
    priv_ins      = as.integer(hcovpriv == 2),
    pub_ins       = as.integer(hcovpub == 2),
    medicaid      = as.integer(hinscaid == 2),
    medicare      = as.integer(hinscare == 2),
    uninsured     = as.integer(hcovany == 1)
  )

cat("\n--- Health insurance (2008+) ---\n")
ins_tab <- acs %>% filter(year >= 2008) %>%
  summarize(any_ins = mean(any_insurance, na.rm = TRUE),
            private = mean(priv_ins, na.rm = TRUE),
            public  = mean(pub_ins, na.rm = TRUE),
            unins   = mean(uninsured, na.rm = TRUE),
            n = n())
print(as.data.frame(ins_tab), row.names = FALSE)

# ============================================================================
# 8. IMMIGRATION AND CITIZENSHIP
# ============================================================================

acs <- acs %>%
  mutate(
    # Citizenship (citizen: 0=N/A, 1=born abroad US parents, 2=naturalized,
    #              3=not citizen, 4=born in US, 5=born in territories)
    noncitizen  = ifelse(citizen == 0, NA, as.integer(citizen == 3)),
    usborn      = ifelse(citizen == 0, NA, as.integer(citizen %in% c(4, 5))),
    naturalized = ifelse(citizen == 0, NA, as.integer(citizen == 2)),
    # Birthplace regions
    bpl_us      = as.integer(bpl >= 1 & bpl <= 120),
    bpl_mexico  = as.integer(bpl == 200),
    bpl_centam  = as.integer(bpl >= 210 & bpl <= 300),
    bpl_asia    = as.integer(bpl >= 500 & bpl < 600),
    bpl_europe  = as.integer(bpl >= 400 & bpl < 500),
    bpl_africa  = as.integer(bpl >= 800 & bpl < 900),
    # Year and age at immigration
    ageimmig = ifelse(yrimmig > 0, yrimmig - birthyr, NA),
    # Language
    english   = as.integer(language == 1),
    spanish   = as.integer(language == 12),
    nonfluent = as.integer(speakeng %in% c(1, 6))
  ) %>%
  mutate(ageimmig = ifelse(!is.na(ageimmig) & ageimmig < 0, NA, ageimmig))

cat("\n--- Citizenship ---\n")
cit_tab <- acs %>%
  summarize(usborn = mean(usborn, na.rm = TRUE),
            naturalized = mean(naturalized, na.rm = TRUE),
            noncitizen = mean(noncitizen, na.rm = TRUE),
            n = sum(!is.na(noncitizen)))
print(as.data.frame(cit_tab), row.names = FALSE)

cat("\n--- Birthplace region ---\n")
bpl_tab <- acs %>%
  summarize(us = mean(bpl_us), mexico = mean(bpl_mexico),
            centam = mean(bpl_centam), asia = mean(bpl_asia),
            europe = mean(bpl_europe))
print(as.data.frame(bpl_tab), row.names = FALSE)

# ============================================================================
# 9. PUBLIC ASSISTANCE
# ============================================================================

acs <- acs %>%
  mutate(foodstamp = as.integer(foodstmp == 2))

cat("\n--- Food stamps/SNAP ---\n")
cat(sprintf("  Receiving SNAP: %.1f%%\n", mean(acs$foodstamp, na.rm = TRUE) * 100))

# ============================================================================
# 10. DESCRIPTIVE STATISTICS
# ============================================================================

cat("\n============================================\n")
cat("   DESCRIPTIVE STATISTICS\n")
cat("============================================\n")

# --- 10a. Summary of key variables ---
cat("\n--- Key demographic variables ---\n")
demo_vars <- c("female", "age", "married", "hisp", "white", "black", "asian")
print(summary(acs[demo_vars]))

cat("\n--- Education variables ---\n")
ed_vars <- c("yrsed", "hs", "some_college", "college")
print(summary(acs[ed_vars]))

cat("\n--- Employment and income ---\n")
econ_vars <- c("employed", "in_lf", "wage", "inpov", "finc_to_pov")
print(summary(acs[econ_vars]))

# --- 10b. Insurance trends by year ---
cat("\n--- Uninsured rate by year (2008+) ---\n")
ins_trend <- acs %>% filter(year >= 2008) %>%
  group_by(year) %>%
  summarize(uninsured_rate = mean(uninsured, na.rm = TRUE),
            n = n(), .groups = "drop")
print(as.data.frame(ins_trend), row.names = FALSE)

# --- 10c. Uninsured by race/ethnicity ---
cat("\n--- Uninsured rate by race/ethnicity (2008+) ---\n")
ins_race <- acs %>% filter(year >= 2008) %>%
  group_by(race_eth) %>%
  summarize(uninsured_rate = mean(uninsured, na.rm = TRUE),
            n = n(), .groups = "drop")
print(as.data.frame(ins_race), row.names = FALSE)

# ============================================================================
# 11. EXAMPLE REGRESSION
# ============================================================================
# Simple OLS: uninsured = f(demographics, education)
# This is just a demonstration -- not a causal model.

cat("\n============================================\n")
cat("   EXAMPLE REGRESSION\n")
cat("============================================\n")

cat("\n--- OLS: Uninsured on demographics (2008+, ages 18-64) ---\n")

reg_data <- acs %>%
  filter(year >= 2008, age >= 18, age <= 64,
         !is.na(uninsured), !is.na(race_eth), !is.na(hs),
         !is.na(college), !is.na(noncitizen))

fit <- lm(uninsured ~ female + age + factor(race_eth) + hs + college +
             married + noncitizen + factor(year),
           data = reg_data, weights = perwt)
print(summary(fit))

cat("\n============================================\n")
cat("   CLEANING COMPLETE\n")
cat("============================================\n")
cat("Variables created: race_eth, female, married, yrsed, hs,\n")
cat("  some_college, college, employed, in_lf, wage, inpov,\n")
cat("  any_insurance, uninsured, noncitizen, usborn, and more.\n")
cat("\nThis is a starter script -- extend for your own analysis.\n")

################################################################################
# NOTES:
#
# 1. SAMPLE RESTRICTIONS:
#    This script does not restrict the sample. For specific analyses:
#    - Working-age adults: filter(age >= 18, age <= 64)
#    - Children: filter(age < 18)
#    - Non-institutionalized: filter(!gq %in% c(3, 4))
#
# 2. SURVEY WEIGHTS:
#    Always use perwt for person-level estimates:
#      lm(..., weights = perwt)
#    For proper standard errors, use the survey package:
#      library(survey)
#      des <- svydesign(ids = ~cluster, strata = ~strata,
#                       weights = ~perwt, data = acs)
#      svyglm(uninsured ~ female + age, design = des)
#
# 3. EDUCATION CODING:
#    The yrsed variable follows the Kuka et al. mapping from IPUMS
#    detailed education codes (educd). Some rare categories may be
#    unmapped (yrsed will be NA for those observations).
#
# 4. INSURANCE VARIABLES:
#    Health insurance variables (hcovany, hcovpriv, hcovpub, etc.)
#    are only available from 2008 onwards.
#
# 5. IMMIGRATION:
#    - citizen == 3 identifies non-citizens
#    - yrimmig gives year of immigration (0 = born in US)
#    - bpl gives detailed birthplace codes
#
# 6. COMMON RESEARCH APPLICATIONS:
#    - Insurance coverage (ACA effects, Medicaid expansion)
#    - Immigration (DACA, citizenship status, assimilation)
#    - Education attainment and returns to education
#    - Labor market outcomes (employment, wages)
#    - Poverty and public assistance
#    - Disability and health
################################################################################
