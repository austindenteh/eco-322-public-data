################################################################################
# 02_clean_and_analyze.R
#
# Purpose: Clean and create analysis-ready variables from the NHIS combined
#          adult file spanning ALL years (2004-2024). Handles the 2019
#          redesign break with era-specific coding logic.
#
#          Covers: demographics, health insurance, health status, chronic
#          conditions, health care utilization, mental health, and BMI.
#
#          The key challenge is that variable CODING differs across eras:
#            - Pre-2019: insurance 1=mentioned, 2=probed yes, 3=no
#            - Post-2019: insurance 1=yes, 2=no
#          Variable NAMES have been harmonized in 01_load_and_append.R
#          (e.g., age_p -> agep_a, sex -> sex_a), but coding must be
#          handled here using the era_post2019 indicator.
#
# Input:   output/nhis_adult.rds  (from 01_load_and_append.R)
# Output:  output/nhis_adult_clean.rds
#          output/nhis_adult_clean.dta
#
# Author:  Austin Denteh (legacy code and Claude Code)
# Date:    February 2026
################################################################################

library(haven)
library(dplyr)
library(broom)
library(survey)

# ============================================================================
# 1. DEFINE PATHS
# ============================================================================

nhis_root <- "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/nhis"

in_rds  <- file.path(nhis_root, "output", "nhis_adult.rds")
out_rds <- file.path(nhis_root, "output", "nhis_adult_clean.rds")
out_dta <- file.path(nhis_root, "output", "nhis_adult_clean.dta")

# ============================================================================
# 2. LOAD DATA
# ============================================================================

cat("\n============================================\n")
cat("   LOADING NHIS ADULT DATA\n")
cat("============================================\n\n")

nhis <- readRDS(in_rds)
names(nhis) <- tolower(names(nhis))
cat(paste0("Loaded: ", nrow(nhis), " observations, ", ncol(nhis), " variables\n"))

# Confirm era indicator exists
if (!"era_post2019" %in% names(nhis)) {
  nhis$era_post2019 <- as.integer(nhis$srvy_yr >= 2019)
  cat("[INFO] Created era_post2019 indicator from srvy_yr\n")
}

cat(paste0("  Pre-2019 obs:  ", sum(nhis$era_post2019 == 0), "\n"))
cat(paste0("  Post-2019 obs: ", sum(nhis$era_post2019 == 1), "\n"))

# ============================================================================
# 3. DEMOGRAPHICS
# ============================================================================
# Variable names have been harmonized to 2019+ convention:
#   agep_a     : Age in years (both eras)
#   sex_a      : Sex (both eras: 1=Male, 2=Female)
#   hisp_a     : Hispanic origin (both eras: 1=Hispanic, 2=Not Hispanic)
#   raceallp_a : Race (CODING DIFFERS — see below)
#   educ_a     : Education (CODING DIFFERS — see below)
#   citizenp_a : Citizenship (similar coding)
#
# RACE CODING:
#   Pre-2019 (racerpi2): 1=White, 2=Black/AA, 3=AIAN, 4-15=various Asian/PI
#   Post-2019 (raceallp_a): 1=White, 2=Black, 3=AIAN, 4=Asian,
#                           5=Not releasable, 6=Multiple
#   -> For broad categories (White, Black), codes match across eras.
#     For Asian: pre-2019 uses various codes 4-15; post-2019 uses 4.
#
# EDUCATION CODING:
#   Pre-2019 (educ1): 00=Never, 01-12=Grade 1-12, 13=HS grad, 14=GED,
#                     15-17=Some college/AA, 18=Bachelor's, 19-21=Graduate
#   Post-2019 (educ_a): 00=Never, 01-09=Less than HS, 10=HS/GED,
#                        11-12=Some college/AA, 13=Bachelor's, 14-16=Graduate

cat("\n============================================\n")
cat("   CLEANING DEMOGRAPHICS\n")
cat("============================================\n\n")

# --- Sex ---
nhis <- nhis %>%
  mutate(
    female = case_when(
      sex_a == 2 ~ 1L,
      sex_a == 1 ~ 0L,
      TRUE ~ NA_integer_
    )
  )

# --- Age categories ---
nhis <- nhis %>%
  mutate(
    age_cat = case_when(
      agep_a >= 18 & agep_a <= 25 ~ "18-25",
      agep_a >= 26 & agep_a <= 34 ~ "26-34",
      agep_a >= 35 & agep_a <= 44 ~ "35-44",
      agep_a >= 45 & agep_a <= 54 ~ "45-54",
      agep_a >= 55 & agep_a <= 64 ~ "55-64",
      agep_a >= 65 & agep_a <= 74 ~ "65-74",
      agep_a >= 75               ~ "75+",
      TRUE ~ NA_character_
    )
  )

# --- Race/ethnicity (era-aware) ---
nhis <- nhis %>%
  mutate(
    race_eth = case_when(
      # Hispanic (any race) — same coding across eras
      hisp_a == 1 ~ "Hispanic",
      # White NH — code 1 in both eras
      raceallp_a == 1 & hisp_a == 2 ~ "White NH",
      # Black NH — code 2 in both eras
      raceallp_a == 2 & hisp_a == 2 ~ "Black NH",
      # Asian NH — code 4 in post-2019; codes 4-14 in pre-2019
      raceallp_a == 4 & hisp_a == 2 & era_post2019 == 1 ~ "Asian NH",
      raceallp_a >= 4 & raceallp_a <= 14 & hisp_a == 2 & era_post2019 == 0 ~ "Asian NH",
      # Other NH — everything else with valid data
      !is.na(raceallp_a) & hisp_a == 2 ~ "Other NH",
      TRUE ~ NA_character_
    )
  )

# --- Education (era-aware) ---
if ("educ_a" %in% names(nhis)) {
  nhis <- nhis %>%
    mutate(
      educ_cat = case_when(
        # Pre-2019 coding (educ1 stored as educ_a)
        educ_a <= 12 & era_post2019 == 0                      ~ "Less than HS",
        educ_a %in% c(13, 14) & era_post2019 == 0             ~ "HS/GED",
        educ_a %in% c(15, 16, 17) & era_post2019 == 0         ~ "Some college/AA",
        educ_a == 18 & era_post2019 == 0                       ~ "Bachelor's",
        educ_a %in% c(19, 20, 21) & era_post2019 == 0         ~ "Graduate",
        # Post-2019 coding
        educ_a <= 9 & era_post2019 == 1                        ~ "Less than HS",
        educ_a == 10 & era_post2019 == 1                       ~ "HS/GED",
        educ_a %in% c(11, 12) & era_post2019 == 1             ~ "Some college/AA",
        educ_a == 13 & era_post2019 == 1                       ~ "Bachelor's",
        educ_a %in% c(14, 15, 16) & era_post2019 == 1         ~ "Graduate",
        TRUE ~ NA_character_
      )
    )
}

# --- Citizenship/Immigration ---
if ("citizenp_a" %in% names(nhis)) {
  nhis <- nhis %>%
    mutate(
      us_born = case_when(
        citizenp_a %in% c(1, 2, 3) & citizenp_a < 7 ~ 1L,
        citizenp_a %in% c(4, 5) & citizenp_a < 7    ~ 0L,
        TRUE ~ NA_integer_
      ),
      citizen = case_when(
        citizenp_a %in% c(1, 2, 3, 4) & citizenp_a < 7 ~ 1L,
        citizenp_a == 5 & citizenp_a < 7                ~ 0L,
        TRUE ~ NA_integer_
      ),
      noncitizen = case_when(
        citizenp_a == 5 & citizenp_a < 7                ~ 1L,
        citizenp_a %in% c(1, 2, 3, 4) & citizenp_a < 7 ~ 0L,
        TRUE ~ NA_integer_
      )
    )
}

# ============================================================================
# 4. HEALTH INSURANCE (ERA-AWARE CODING)
# ============================================================================
# CRITICAL: Insurance variables use DIFFERENT coding by era.
#
# Pre-2019: 1=Mentioned/Yes, 2=Probed yes, 3=No, >3=missing
#   For notcov: 1=Not covered, 2=Covered, >2=missing
#   For other insurance vars: 1 or 2 = Yes, 3 = No
#
# Post-2019: 1=Yes, 2=No, >2=missing
#   For notcov_a: 1=Not covered, 2=Covered

cat("Cleaning health insurance...\n")

# --- Uninsured ---
# notcov coding is the same across eras: 1=Not covered, 2=Covered
if ("notcov_a" %in% names(nhis)) {
  nhis <- nhis %>%
    mutate(
      uninsured = case_when(
        notcov_a == 1 ~ 1L,
        notcov_a == 2 ~ 0L,
        TRUE ~ NA_integer_
      )
    )
}

# --- Medicare (era-aware) ---
if ("medicare_a" %in% names(nhis)) {
  nhis <- nhis %>%
    mutate(
      has_medicare = case_when(
        # Pre-2019: 1 or 2 = Yes, 3 = No
        medicare_a %in% c(1, 2) & era_post2019 == 0 ~ 1L,
        medicare_a == 3 & era_post2019 == 0          ~ 0L,
        # Post-2019: 1 = Yes, 2 = No
        medicare_a == 1 & era_post2019 == 1           ~ 1L,
        medicare_a == 2 & era_post2019 == 1           ~ 0L,
        TRUE ~ NA_integer_
      )
    )
}

# --- Medicaid (era-aware) ---
if ("medicaid_a" %in% names(nhis)) {
  nhis <- nhis %>%
    mutate(
      has_medicaid = case_when(
        medicaid_a %in% c(1, 2) & era_post2019 == 0 ~ 1L,
        medicaid_a == 3 & era_post2019 == 0          ~ 0L,
        medicaid_a == 1 & era_post2019 == 1           ~ 1L,
        medicaid_a == 2 & era_post2019 == 1           ~ 0L,
        TRUE ~ NA_integer_
      )
    )
}

# --- Private (era-aware) ---
if ("private_a" %in% names(nhis)) {
  nhis <- nhis %>%
    mutate(
      has_private = case_when(
        private_a %in% c(1, 2) & era_post2019 == 0 ~ 1L,
        private_a == 3 & era_post2019 == 0          ~ 0L,
        private_a == 1 & era_post2019 == 1           ~ 1L,
        private_a == 2 & era_post2019 == 1           ~ 0L,
        TRUE ~ NA_integer_
      )
    )
}

# --- Insurance hierarchy (mutually exclusive) ---
nhis <- nhis %>%
  mutate(
    insur_type = case_when(
      has_medicare == 1                   ~ "Medicare",
      has_private == 1                    ~ "Private",
      has_medicaid == 1                   ~ "Medicaid",
      uninsured == 1                      ~ "Uninsured",
      !is.na(uninsured)                   ~ "Other public",
      TRUE ~ NA_character_
    )
  )

# ============================================================================
# 5. HEALTH STATUS
# ============================================================================
# phstat_a: Self-rated health (both eras)
#   1=Excellent, 2=Very good, 3=Good, 4=Fair, 5=Poor
#   Same coding across eras — no adjustment needed.

cat("Cleaning health status...\n")

if ("phstat_a" %in% names(nhis)) {
  nhis <- nhis %>%
    mutate(
      health_status = ifelse(phstat_a >= 1 & phstat_a <= 5, phstat_a, NA_real_),
      fair_poor_health = case_when(
        health_status >= 4 ~ 1L,
        health_status <= 3 ~ 0L,
        TRUE ~ NA_integer_
      ),
      excellent_vgood = case_when(
        health_status <= 2 ~ 1L,
        health_status >= 3 ~ 0L,
        TRUE ~ NA_integer_
      )
    )
}

# ============================================================================
# 6. CHRONIC CONDITIONS (ERA-AWARE)
# ============================================================================
# Pre-2019 (from samadult): 1=Yes, 2=No, >2=missing
# Post-2019: 1=Yes, 2=No, 7/8/9=missing
# Same Yes/No coding — just different missing codes.
# Recode: 1 -> 1, 2 -> 0, everything else -> NA

cat("Cleaning chronic conditions...\n")

chronic_vars <- c("hypev", "chlev", "chdev", "angev", "miev", "strev",
                  "asev", "canev", "dibev", "copdev", "arthev", "depev", "anxev")

for (v in chronic_vars) {
  raw_name <- paste0(v, "_a")
  if (raw_name %in% names(nhis)) {
    nhis[[v]] <- case_when(
      nhis[[raw_name]] == 1 ~ 1L,
      nhis[[raw_name]] == 2 ~ 0L,
      TRUE ~ NA_integer_
    )
  }
}

# ============================================================================
# 7. HEALTH CARE UTILIZATION
# ============================================================================
# pdmed12m_a: Delayed medical care, past 12 months
# pnmed12m_a: Needed but did not get medical care
# Same coding across eras: 1=Yes, 2=No

cat("Cleaning utilization...\n")

if ("pdmed12m_a" %in% names(nhis)) {
  nhis <- nhis %>%
    mutate(delayed_care = case_when(
      pdmed12m_a == 1 ~ 1L,
      pdmed12m_a == 2 ~ 0L,
      TRUE ~ NA_integer_
    ))
}

if ("pnmed12m_a" %in% names(nhis)) {
  nhis <- nhis %>%
    mutate(foregone_care = case_when(
      pnmed12m_a == 1 ~ 1L,
      pnmed12m_a == 2 ~ 0L,
      TRUE ~ NA_integer_
    ))
}

# ============================================================================
# 8. MENTAL HEALTH (2019+ ONLY)
# ============================================================================
# PHQ-8 and GAD-7 are only available in 2019+ (post-redesign).
# These variables will be missing for pre-2019 observations.

cat("Cleaning mental health screeners...\n")

if ("phqcat_a" %in% names(nhis)) {
  nhis <- nhis %>%
    mutate(depression_moderate = case_when(
      phqcat_a >= 2 & phqcat_a <= 4 ~ 1L,
      phqcat_a >= 0 & phqcat_a <= 1 ~ 0L,
      TRUE ~ NA_integer_
    ))
}

if ("gadcat_a" %in% names(nhis)) {
  nhis <- nhis %>%
    mutate(anxiety_moderate = case_when(
      gadcat_a >= 2 & gadcat_a <= 4 ~ 1L,
      gadcat_a >= 0 & gadcat_a <= 1 ~ 0L,
      TRUE ~ NA_integer_
    ))
}

# ============================================================================
# 9. BMI (2019+ ONLY)
# ============================================================================

if ("bmicat_a" %in% names(nhis)) {
  nhis <- nhis %>%
    mutate(
      bmi_cat = case_when(
        bmicat_a == 1 ~ "Underweight",
        bmicat_a == 2 ~ "Normal",
        bmicat_a == 3 ~ "Overweight",
        bmicat_a == 4 ~ "Obese",
        TRUE ~ NA_character_
      ),
      obese = case_when(
        bmicat_a == 4 ~ 1L,
        bmicat_a %in% 1:3 ~ 0L,
        TRUE ~ NA_integer_
      )
    )
}

# ============================================================================
# 10. INCOME / POVERTY RATIO
# ============================================================================
# ratcat_a: Ratio of family income to poverty threshold (14 categories)
#   Same coding in both eras (harmonized in 01_load_and_append):
#     01=Under 0.50, 02=0.50-0.74, ..., 14=5.00+
#   Pre-2019 also has 15-17 (NFS) and 96/99.
#   Post-2019 has 98=Not ascertained.
#
# incgrp_a: Total combined family income (grouped, 5 categories)
#   Available in all pre-2019 years + 2019-2020 only (dropped 2021+).
#
# ernyr_a: Total personal earnings last year (pre-2019 only, 11 categories)
#
# povrattc_a: Continuous poverty ratio (post-2019 only, from main file)

cat("Cleaning income / poverty...\n")

# --- Poverty ratio categories (broad groups, comparable across eras) ---
if ("ratcat_a" %in% names(nhis)) {
  nhis <- nhis %>%
    mutate(
      pov_cat = case_when(
        # Below poverty (FPL ratio < 1.00): codes 01-03
        ratcat_a >= 1 & ratcat_a <= 3   ~ "Below poverty (<100% FPL)",
        # 100-199% FPL: codes 04-07
        ratcat_a >= 4 & ratcat_a <= 7   ~ "100-199% FPL",
        # 200-399% FPL: codes 08-11
        ratcat_a >= 8 & ratcat_a <= 11  ~ "200-399% FPL",
        # 400%+ FPL: codes 12-14
        ratcat_a >= 12 & ratcat_a <= 14 ~ "400%+ FPL",
        # NFS codes (pre-2019: 15-17) and 96/98/99 -> missing
        TRUE ~ NA_character_
      ),
      below_poverty = case_when(
        ratcat_a >= 1 & ratcat_a <= 3   ~ 1L,
        ratcat_a >= 4 & ratcat_a <= 14  ~ 0L,
        TRUE ~ NA_integer_
      ),
      low_income = case_when(
        ratcat_a >= 1 & ratcat_a <= 7   ~ 1L,
        ratcat_a >= 8 & ratcat_a <= 14  ~ 0L,
        TRUE ~ NA_integer_
      )
    )
}

# --- Income group (5 categories) ---
if ("incgrp_a" %in% names(nhis)) {
  nhis <- nhis %>%
    mutate(
      income_cat = case_when(
        incgrp_a == 1 ~ "$0-$34,999",
        incgrp_a == 2 ~ "$35,000-$49,999",
        incgrp_a == 3 ~ "$50,000-$74,999",
        incgrp_a == 4 ~ "$75,000-$99,999",
        incgrp_a == 5 ~ "$100,000+",
        # NFS codes (pre-2019: 6-7), 96/99 -> missing
        TRUE ~ NA_character_
      )
    )
}

# --- Personal earnings (pre-2019 only) ---
if ("ernyr_a" %in% names(nhis)) {
  nhis <- nhis %>%
    mutate(
      earn_cat = case_when(
        ernyr_a >= 1 & ernyr_a <= 3   ~ "Under $15,000",
        ernyr_a >= 4 & ernyr_a <= 5   ~ "$15,000-$24,999",
        ernyr_a >= 6 & ernyr_a <= 7   ~ "$25,000-$44,999",
        ernyr_a >= 8 & ernyr_a <= 9   ~ "$45,000-$64,999",
        ernyr_a >= 10 & ernyr_a <= 11 ~ "$65,000+",
        TRUE ~ NA_character_
      )
    )
}

# ============================================================================
# 11. SURVEY DESIGN
# ============================================================================

cat("\n============================================\n")
cat("   SETTING SURVEY DESIGN\n")
cat("============================================\n\n")

# Create pooled weight: divide by number of years
n_years <- length(unique(nhis$srvy_yr))
nhis$wtfa_adj <- nhis$wtfa_a / n_years
cat(paste0("Pooled weight: wtfa_a / ", n_years, " years\n"))

# ============================================================================
# 12. SAVE CLEANED DATASET
# ============================================================================

cat("\n============================================\n")
cat("   SAVING CLEANED DATASET\n")
cat("============================================\n\n")

nhis <- nhis %>% arrange(srvy_yr, hhx)

saveRDS(nhis, out_rds)
cat(paste0("Saved: ", out_rds, "\n"))

tryCatch({
  write_dta(nhis, out_dta)
  cat(paste0("Saved: ", out_dta, "\n"))
}, error = function(e) {
  cat(paste0("Could not save .dta: ", e$message, "\n"))
})

cat(paste0("Observations: ", nrow(nhis), "\n"))
cat(paste0("Variables: ", ncol(nhis), "\n"))

# ============================================================================
# 13. DESCRIPTIVE STATISTICS
# ============================================================================

cat("\n============================================\n")
cat("   DESCRIPTIVE STATISTICS\n")
cat("============================================\n\n")

# 13a. Year distribution
cat("--- Observations by year ---\n")
print(as.data.frame(nhis %>% count(srvy_yr)), row.names = FALSE)

# 13b. Era distribution
cat("\n--- Observations by era ---\n")
print(as.data.frame(nhis %>%
  count(era_post2019) %>%
  mutate(era = ifelse(era_post2019 == 0, "Pre-2019", "Post-2019"))),
  row.names = FALSE)

# 13c. Demographics
cat("\n--- Demographics ---\n")
cat(paste0("  Female: ", round(100 * mean(nhis$female, na.rm = TRUE), 1), "%\n"))
cat(paste0("  Mean age: ", round(mean(nhis$agep_a, na.rm = TRUE), 1), "\n"))
cat("\n  Race/ethnicity:\n")
print(as.data.frame(nhis %>% filter(!is.na(race_eth)) %>%
                      count(race_eth) %>%
                      mutate(pct = round(n / sum(n) * 100, 1))),
      row.names = FALSE)

# 13d. Insurance by era
cat("\n--- Health insurance by era ---\n")
if ("insur_type" %in% names(nhis)) {
  cat("  Pre-2019:\n")
  print(as.data.frame(nhis %>%
    filter(!is.na(insur_type), era_post2019 == 0) %>%
    count(insur_type) %>%
    mutate(pct = round(n / sum(n) * 100, 1))),
    row.names = FALSE)

  cat("\n  Post-2019:\n")
  print(as.data.frame(nhis %>%
    filter(!is.na(insur_type), era_post2019 == 1) %>%
    count(insur_type) %>%
    mutate(pct = round(n / sum(n) * 100, 1))),
    row.names = FALSE)
}

# 13e. Uninsured trends
cat("\n--- Uninsured rate by year ---\n")
if ("uninsured" %in% names(nhis)) {
  trend <- nhis %>%
    group_by(srvy_yr) %>%
    summarize(
      n = sum(!is.na(uninsured)),
      uninsured_pct = round(100 * mean(uninsured, na.rm = TRUE), 1),
      .groups = "drop"
    )
  print(as.data.frame(trend), row.names = FALSE)
}

# 13f. Uninsured by race/ethnicity
cat("\n--- Uninsured rate by race/ethnicity ---\n")
if ("uninsured" %in% names(nhis)) {
  race_insur <- nhis %>%
    filter(!is.na(race_eth), !is.na(uninsured)) %>%
    group_by(race_eth) %>%
    summarize(
      n = n(),
      uninsured_pct = round(100 * mean(uninsured), 1),
      .groups = "drop"
    )
  print(as.data.frame(race_insur), row.names = FALSE)
}

# 13g. Health status
cat("\n--- Self-rated health ---\n")
if ("health_status" %in% names(nhis)) {
  hs_labels <- c("1" = "Excellent", "2" = "Very good", "3" = "Good",
                 "4" = "Fair", "5" = "Poor")
  hs_table <- nhis %>%
    filter(!is.na(health_status)) %>%
    count(health_status) %>%
    mutate(label = hs_labels[as.character(health_status)],
           pct = round(n / sum(n) * 100, 1))
  print(as.data.frame(hs_table), row.names = FALSE)
}

# 13h. Chronic conditions
cat("\n--- Chronic conditions (ever diagnosed) ---\n")
for (v in chronic_vars) {
  if (v %in% names(nhis)) {
    n_valid <- sum(!is.na(nhis[[v]]))
    pct <- round(100 * mean(nhis[[v]], na.rm = TRUE), 1)
    cat(sprintf("  %-10s  N=%s  Rate=%.1f%%\n",
                v, format(n_valid, big.mark = ","), pct))
  }
}

# 13i. Income / poverty
cat("\n--- Income / poverty ---\n")
if ("pov_cat" %in% names(nhis)) {
  cat("  Poverty category (all years):\n")
  print(as.data.frame(nhis %>% filter(!is.na(pov_cat)) %>%
    count(pov_cat) %>%
    mutate(pct = round(n / sum(n) * 100, 1))),
    row.names = FALSE)

  cat(paste0("\n  Below poverty: ",
    round(100 * mean(nhis$below_poverty, na.rm = TRUE), 1), "%\n"))
  cat(paste0("  Low income (<200% FPL): ",
    round(100 * mean(nhis$low_income, na.rm = TRUE), 1), "%\n"))

  # By era
  pov_era <- nhis %>%
    filter(!is.na(below_poverty)) %>%
    group_by(era_post2019) %>%
    summarize(
      n = n(),
      below_poverty_pct = round(100 * mean(below_poverty), 1),
      low_income_pct = round(100 * mean(low_income), 1),
      .groups = "drop"
    ) %>%
    mutate(era = ifelse(era_post2019 == 0, "Pre-2019", "Post-2019"))
  print(as.data.frame(pov_era), row.names = FALSE)
}

if ("income_cat" %in% names(nhis)) {
  cat("\n  Family income group:\n")
  print(as.data.frame(nhis %>% filter(!is.na(income_cat)) %>%
    count(income_cat) %>%
    mutate(pct = round(n / sum(n) * 100, 1))),
    row.names = FALSE)
}

# ============================================================================
# 14. EXAMPLE REGRESSIONS
# ============================================================================

cat("\n============================================\n")
cat("   EXAMPLE REGRESSIONS\n")
cat("============================================\n\n")

# 14a. OLS: Uninsured ~ demographics (unweighted)
cat("--- OLS: Uninsured ~ demographics (unweighted) ---\n")
if ("uninsured" %in% names(nhis)) {
  ols <- lm(uninsured ~ female + agep_a + factor(race_eth) + factor(educ_cat)
            + factor(pov_cat) + factor(srvy_yr),
            data = nhis)
  print(tidy(ols) %>% head(15))
}

# 14b. Weighted OLS
cat("\n--- Weighted OLS: Uninsured ~ demographics ---\n")
if ("uninsured" %in% names(nhis)) {
  wols <- lm(uninsured ~ female + agep_a + factor(race_eth) + factor(educ_cat)
             + factor(pov_cat) + factor(srvy_yr),
             data = nhis, weights = wtfa_adj)
  print(tidy(wols) %>% head(15))
}

# 14c. Survey-weighted: Fair/poor health ~ demographics
cat("\n--- Survey-weighted: Fair/poor health ~ demographics ---\n")
if (all(c("fair_poor_health", "pstrat", "ppsu") %in% names(nhis))) {
  des <- svydesign(ids = ~ppsu, strata = ~pstrat,
                   weights = ~wtfa_adj, data = nhis, nest = TRUE)
  svy_reg <- svyglm(fair_poor_health ~ female + agep_a + factor(race_eth)
                     + factor(pov_cat),
                     design = des, family = quasibinomial())
  print(tidy(svy_reg) %>% head(12))
}

cat("\n============================================\n")
cat("   DONE\n")
cat("============================================\n")

################################################################################
# NOTES:
#
# 1. ERA-SPECIFIC CODING:
#    The most critical difference between eras is insurance variable coding:
#      Pre-2019: 1=mentioned, 2=probed yes, 3=no (both 1 and 2 mean Yes)
#      Post-2019: 1=yes, 2=no
#    The era_post2019 indicator is used throughout to apply correct recoding.
#
# 2. VARIABLE AVAILABILITY:
#    Some variables are only available in certain years:
#      PHQ-8 / GAD-7: 2019+ only
#      BMI category: 2019+ only
#      Chronic conditions: available in most years (from samadult)
#      SNAP (fsnap): 2011+ (ffdstyn in 2004-2010)
#      Personal earnings (ernyr_a): pre-2019 only
#      Income group (incgrp_a): all pre-2019 + 2019-2020 only
#      Poverty ratio category (ratcat_a): all years
#      Continuous poverty ratio (povrattc_a): 2019+ main file
#
# 2b. INCOME/POVERTY:
#    The poverty ratio category (ratcat_a -> pov_cat) is the most
#    harmonizable income measure across all years. It uses the same
#    14-category coding in both eras.
#    For continuous family income or more detailed poverty ratios,
#    use the multiple imputation files (INCMIMP pre-2019, adultinc
#    post-2019) with proper MI techniques (Rubin's rules).
#
# 3. RACE HARMONIZATION:
#    Pre-2019 has more detailed Asian race codes (4-15 in racerpi2).
#    Post-2019 collapses to a single Asian category (4 in raceallp_a).
#    Our race_eth variable uses 5 broad categories that are comparable
#    across eras (White NH, Black NH, Hispanic, Asian NH, Other NH).
#
# 4. WEIGHTS:
#    wtfa_a = final annual sample adult weight (renamed from wtfa_sa pre-2019)
#    wtfa_adj = wtfa_a / N_years (for pooled analysis)
#    For proper variance estimation, use survey::svydesign with
#    pstrat (pseudo-stratum) and ppsu (pseudo-PSU).
#
# 5. 2020 COVID DISRUPTION:
#    Consider sensitivity analyses excluding 2020.
#
# 6. CHILD FILE:
#    To clean the child file, adapt this script using:
#      - input: output/nhis_child.rds
#      - variable suffix: _c instead of _a (for post-2019)
#      - weight: wtfa_c instead of wtfa_a
#      - child-specific health variables from samchild
#    The original RDC research scripts provide a template for child
#    health outcomes (access, utilization, school days lost, etc.)
#
# 7. CITATION:
#    National Center for Health Statistics. National Health Interview
#    Survey, [year]. Hyattsville, Maryland.
#    https://www.cdc.gov/nchs/nhis/index.htm
################################################################################
