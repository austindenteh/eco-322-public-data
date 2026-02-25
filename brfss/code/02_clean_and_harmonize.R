################################################################################
# 02_clean_and_harmonize.R
#
# Purpose: Clean and harmonize BRFSS variables across survey years.
#          Creates consistent demographic, health, and survey design variables
#          that can be used for pooled cross-year analysis.
#          Works with any year range from 2011-2024 (default: 2023-2024).
#
# Input:   output/brfss_appended.rds  (from 01_load_and_append.R)
# Output:  output/brfss_clean.rds
#          output/brfss_clean.dta  (for Stata users)
#
# Usage:   Set brfss_root to the brfss/ directory, then source this script.
#
# Key harmonization issues:
#   - Race/ethnicity: _racegr3 (2011-2021) vs. _racegr4 (2022+)
#   - Income: income2 (2011-2020) vs. income3 (2021+)
#   - Sex/gender: sex (2011-2021) vs. sexvar/birthsex (2022+)
#
# Author:  Austin Denteh (legacy code and Claude Code)
# Date:    February 2026
################################################################################

library(haven)      # write_dta()
library(dplyr)      # data wrangling
library(tidyr)      # drop_na(), replace_na()
library(survey)     # svydesign(), svyglm() for survey-weighted analysis
library(broom)      # tidy() for regression output

# ============================================================================
# 1. DEFINE PATHS
# ============================================================================

brfss_root <- "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/brfss"

in_rds   <- file.path(brfss_root, "output", "brfss_appended.rds")
out_rds  <- file.path(brfss_root, "output", "brfss_clean.rds")
out_dta  <- file.path(brfss_root, "output", "brfss_clean.dta")

# ============================================================================
# 2. LOAD APPENDED DATA
# ============================================================================

cat("Loading appended BRFSS data...\n")
brfss <- readRDS(in_rds)
cat(paste0("Loaded: ", nrow(brfss), " observations, ", ncol(brfss), " variables\n"))

# Standardize column names to lowercase (should already be, but ensure)
names(brfss) <- tolower(names(brfss))

# ============================================================================
# 3. HARMONIZE DEMOGRAPHICS
# ============================================================================

cat("\nHarmonizing demographics...\n")

# Ensure backward-compatibility columns exist (may be absent if only recent years loaded)
# This lets the case_when logic below work without errors for any year range.
if (!"sex" %in% names(brfss))       brfss$sex <- NA_real_
if (!"_racegr3" %in% names(brfss))  brfss$`_racegr3` <- NA_real_
if (!"_racegr4" %in% names(brfss))  brfss$`_racegr4` <- NA_real_
if (!"sexvar" %in% names(brfss))    brfss$sexvar <- NA_real_
if (!"birthsex" %in% names(brfss))  brfss$birthsex <- NA_real_
if (!"income2" %in% names(brfss))   brfss$income2 <- NA_real_
if (!"income3" %in% names(brfss))   brfss$income3 <- NA_real_

brfss <- brfss %>%
  mutate(

    # --- 3a. State FIPS code -------------------------------------------------
    statefips = `_state`,

    # --- 3b. Age -------------------------------------------------------------
    # _age80: Imputed age, top-coded at 80
    age = `_age80`,

    # _ageg5yr: Age in five-year categories (CDC calculated)
    age_cat = `_ageg5yr`,

    # --- 3c. Sex / Gender ----------------------------------------------------
    # SEX used through 2021 (1=Male, 2=Female).
    # 2022+: sexvar or birthsex.
    # Harmonize to a single female indicator.
    female = case_when(
      surveyyear <= 2021 & sex == 2 ~ 1L,
      surveyyear <= 2021 & sex == 1 ~ 0L,
      # 2022+: try sexvar first, then birthsex
      surveyyear >= 2022 & !is.na(sexvar) & sexvar == 2 ~ 1L,
      surveyyear >= 2022 & !is.na(sexvar) & sexvar == 1 ~ 0L,
      surveyyear >= 2022 & is.na(sexvar) & !is.na(birthsex) & birthsex == 2 ~ 1L,
      surveyyear >= 2022 & is.na(sexvar) & !is.na(birthsex) & birthsex == 1 ~ 0L,
      TRUE ~ NA_integer_
    ),

    # --- 3d. Race/Ethnicity --------------------------------------------------
    # _racegr3 (2011-2021): 1=White NH, 2=Black NH, 3=Other NH, 4=Multi NH, 5=Hispanic
    # _racegr4 (2022+): 1=White NH, 2=Black NH, 3=Asian NH, 4=AIAN NH, 5=Hispanic, 6=Other/Multi
    # Harmonize to 4 categories.
    race_eth = case_when(
      # 2011-2021
      surveyyear <= 2021 & `_racegr3` == 1 ~ 1L,  # White NH
      surveyyear <= 2021 & `_racegr3` == 2 ~ 2L,  # Black NH
      surveyyear <= 2021 & `_racegr3` == 5 ~ 3L,  # Hispanic
      surveyyear <= 2021 & `_racegr3` %in% c(3, 4) ~ 4L,  # Other/Multi NH
      # 2022+
      surveyyear >= 2022 & `_racegr4` == 1 ~ 1L,
      surveyyear >= 2022 & `_racegr4` == 2 ~ 2L,
      surveyyear >= 2022 & `_racegr4` == 5 ~ 3L,
      surveyyear >= 2022 & `_racegr4` %in% c(3, 4, 6) ~ 4L,
      TRUE ~ NA_integer_
    ),

    # Race indicators
    white    = as.integer(race_eth == 1),
    black    = as.integer(race_eth == 2),
    hispanic = as.integer(race_eth == 3),
    raceother = as.integer(race_eth == 4),

    # --- 3e. Education -------------------------------------------------------
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

    # --- 3f. Marital Status --------------------------------------------------
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

    # --- 3g. Income ----------------------------------------------------------
    # income2 (2011-2020): 8 categories (1=<$10K ... 8=$75K+)
    # income3 (2021+): 11 categories — collapse to 8 for comparability
    income_cat = case_when(
      surveyyear <= 2020 & income2 >= 1 & income2 <= 8 ~ as.integer(income2),
      surveyyear >= 2021 & income3 >= 1 & income3 <= 8 ~ as.integer(income3),
      surveyyear >= 2021 & income3 > 8 & income3 < 77 ~ 8L,
      TRUE ~ NA_integer_
    ),

    # --- 3h. Employment ------------------------------------------------------
    # employ1: 1=Employed, 2=Self-employed, 3-4=Unemployed, 5=Homemaker,
    #          6=Student, 7=Retired, 8=Unable to work
    working = case_when(
      employ1 %in% c(1, 2) ~ 1L,
      employ1 >= 3 & employ1 <= 8 ~ 0L,
      TRUE ~ NA_integer_
    ),

    student = case_when(
      employ1 == 6 ~ 1L,
      employ1 >= 1 & employ1 <= 8 & employ1 != 6 ~ 0L,
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

    # Diabetes (diabete4: 1=Yes, 3=No/pre-diabetes)
    diabetes = case_when(
      diabete4 == 1 ~ 1L,
      diabete4 == 3 ~ 0L,
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
if ("chccopd" %in% names(brfss)) {
  brfss <- brfss %>%
    mutate(copd = case_when(
      chccopd == 1 ~ 1L,
      chccopd == 2 ~ 0L,
      TRUE ~ NA_integer_
    ))
} else if ("chccopd1" %in% names(brfss)) {
  brfss <- brfss %>%
    mutate(copd = case_when(
      chccopd1 == 1 ~ 1L,
      chccopd1 == 2 ~ 0L,
      TRUE ~ NA_integer_
    ))
} else {
  brfss$copd <- NA_integer_
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
cat("   DESCRIPTIVE STATISTICS\n")
cat("============================================\n\n")

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
# 7. EXAMPLE REGRESSIONS
# ============================================================================

cat("\n============================================\n")
cat("   EXAMPLE REGRESSIONS\n")
cat("============================================\n\n")

# --- 7a. Unweighted OLS: mental health days ~ demographics -------------------
cat("--- OLS: Mental health days (unweighted) ---\n")
ols_model <- lm(mental_days ~ female + age + factor(race_eth) +
                  factor(educ_cat) + factor(surveyyear),
                data = brfss)
print(tidy(ols_model) %>% head(10))
cat("  (showing first 10 coefficients; full model has year fixed effects)\n")

# --- 7b. Survey-weighted regression ------------------------------------------
cat("\n--- Survey-weighted regression ---\n")
cat("Setting up survey design...\n")

# Identify the correct variable names for survey design
psu_var <- if ("_psu" %in% names(brfss)) "_psu" else "x_psu"
str_var <- if ("_ststr" %in% names(brfss)) "_ststr" else "x_ststr"
wt_var  <- if ("_llcpwt" %in% names(brfss)) "_llcpwt" else "x_llcpwt"

# Use a subset for the survey-weighted example (full data may be slow)
# Pick the most recent year in the data
example_year <- max(brfss$surveyyear, na.rm = TRUE)
cat(paste0("Using year ", example_year, " for survey-weighted examples\n"))

brfss_sub <- brfss %>%
  filter(surveyyear == example_year) %>%
  filter(!is.na(mental_days) & !is.na(female) & !is.na(age) &
         !is.na(race_eth) & !is.na(educ_cat))

svy_design <- svydesign(
  ids = as.formula(paste0("~ `", psu_var, "`")),
  strata = as.formula(paste0("~ `", str_var, "`")),
  weights = as.formula(paste0("~ `", wt_var, "`")),
  data = brfss_sub,
  nest = TRUE
)

svy_model <- svyglm(mental_days ~ female + age + factor(race_eth) +
                       factor(educ_cat),
                     design = svy_design)
cat(paste0("\nSurvey-weighted OLS (", example_year, " only):\n"))
print(tidy(svy_model))

# --- 7c. Survey-weighted logit: fair/poor health -----------------------------
cat(paste0("\n--- Survey-weighted logit: Fair/poor health (", example_year, " only) ---\n"))

brfss_sub2 <- brfss %>%
  filter(surveyyear == example_year) %>%
  filter(!is.na(fair_or_poor) & !is.na(female) & !is.na(age) &
         !is.na(race_eth) & !is.na(educ_cat))

svy_design2 <- svydesign(
  ids = as.formula(paste0("~ `", psu_var, "`")),
  strata = as.formula(paste0("~ `", str_var, "`")),
  weights = as.formula(paste0("~ `", wt_var, "`")),
  data = brfss_sub2,
  nest = TRUE
)

logit_model <- svyglm(fair_or_poor ~ female + age + factor(race_eth) +
                         factor(educ_cat),
                       design = svy_design2,
                       family = quasibinomial())
cat("\nSurvey-weighted logit:\n")
print(tidy(logit_model))

cat("\n============================================\n")
cat("   DONE\n")
cat("============================================\n")

################################################################################
# NOTES FOR USERS:
#
# 1. SURVEY WEIGHTS ARE ESSENTIAL: The BRFSS uses a complex survey design.
#    ALWAYS use the survey package (svydesign + svyglm) for population-
#    representative estimates. Unweighted analyses are for quick checks only.
#
# 2. COLUMN NAMES WITH UNDERSCORES: CDC calculated variables start with _.
#    In R, access them with backticks: brfss$`_age80` or brfss[["_age80"]].
#    This script creates clean names (age, bmi, etc.) to avoid this issue.
#
# 3. CROSS-YEAR HARMONIZATION: Variables harmonized here (race_eth,
#    income_cat, female) are comparable across all years 2011-2024,
#    regardless of which year range you loaded.
#
# 4. MEMORY MANAGEMENT: With 5+ million rows, consider:
#    - Using data.table instead of dplyr for faster operations
#    - Subsetting to years of interest before analysis
#    - Using arrow::open_dataset() for out-of-memory analysis
#
# 5. SURVEY-WEIGHTED EXAMPLES: The examples use the most recent year to
#    keep runtime reasonable. For multi-year pooled analysis, you may need
#    to adjust weights. See CDC documentation on combining BRFSS years.
#
# 6. SEXVAR vs. SEX: Starting in 2022, the BRFSS added gender identity
#    questions. SEXVAR captures sex assigned at birth. If you need gender
#    identity, look for SOMALE/SOFEMALE (sexual orientation) and TRNSGNDR
#    (transgender status) variables in 2022+ data.
################################################################################
