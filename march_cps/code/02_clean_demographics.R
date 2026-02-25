################################################################################
# 02_clean_demographics.R
#
# Purpose: Clean and create analysis-ready variables from CPS ASEC data.
#          Covers demographics, income, employment, health insurance,
#          education, immigration, and transfer programs.
#
# Input:   output/cps_asec.rds  (from 01_load_and_subset.R)
# Output:  output/cps_clean.rds
#          output/cps_clean.dta
#
# Author:  Austin Denteh (legacy code and Claude Code)
# Date:    February 2026
################################################################################

library(haven)
library(dplyr)
library(broom)

# ============================================================================
# 1. DEFINE PATHS
# ============================================================================

cps_root <- "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/march_cps"

in_rds  <- file.path(cps_root, "output", "cps_asec.rds")
out_rds <- file.path(cps_root, "output", "cps_clean.rds")
out_dta <- file.path(cps_root, "output", "cps_clean.dta")

# ============================================================================
# 2. LOAD DATA
# ============================================================================

cat("Loading CPS ASEC data...\n")
cps <- readRDS(in_rds)
names(cps) <- tolower(names(cps))
cat(paste0("Loaded: ", nrow(cps), " observations, ", ncol(cps), " variables\n"))

# ============================================================================
# 3. DEMOGRAPHICS
# ============================================================================

cat("\nCleaning demographics...\n")

cps <- cps %>%
  mutate(
    # Age groups
    age_cat = case_when(
      age <= 17 ~ 1L, age <= 25 ~ 2L, age <= 34 ~ 3L,
      age <= 44 ~ 4L, age <= 54 ~ 5L, age <= 64 ~ 6L,
      TRUE ~ 7L
    ),
    working_age = as.integer(age >= 18 & age <= 64),

    # Sex
    female = as.integer(sex == 2),

    # Race/ethnicity (Hispanic first, then by race among non-Hispanic)
    race_eth = case_when(
      hispan >= 100 & hispan <= 412 ~ 3L,   # Hispanic
      race == 100 & hispan == 0 ~ 1L,        # White NH
      race == 200 & hispan == 0 ~ 2L,        # Black NH
      hispan == 0 ~ 4L,                       # Other NH
      TRUE ~ NA_integer_
    ),
    white    = as.integer(race_eth == 1),
    black    = as.integer(race_eth == 2),
    hispanic = as.integer(race_eth == 3),
    raceother = as.integer(race_eth == 4),

    # Marital status
    marital_cat = case_when(
      marst %in% c(1, 2) ~ 1L,   # Married
      marst %in% c(3, 4) ~ 2L,   # Divorced/separated
      marst == 5 ~ 3L,            # Widowed
      marst == 6 ~ 4L,            # Never married
      TRUE ~ NA_integer_
    ),
    married = as.integer(marital_cat == 1)
  )

# ============================================================================
# 4. EDUCATION
# ============================================================================

cps <- cps %>%
  mutate(
    educ_cat = case_when(
      educ >= 2 & educ <= 71 ~ 1L,     # Less than HS
      educ == 73 ~ 2L,                   # HS grad/GED
      educ >= 80 & educ <= 92 ~ 3L,     # Some college/Associate
      educ >= 111 & educ < 999 ~ 4L,    # Bachelor's+
      TRUE ~ NA_integer_
    ),
    hsdropout   = as.integer(educ_cat == 1),
    hsgraduate  = as.integer(educ_cat == 2),
    somecollege = as.integer(educ_cat == 3),
    college     = as.integer(educ_cat == 4),

    enrolled = if ("schlcoll" %in% names(.)) {
      as.integer(schlcoll >= 1 & schlcoll <= 4)
    } else NA_integer_
  )

# ============================================================================
# 5. EMPLOYMENT AND LABOR FORCE
# ============================================================================

cps <- cps %>%
  mutate(
    employed = case_when(
      empstat >= 10 & empstat <= 12 ~ 1L,
      empstat >= 20 & empstat <= 36 ~ 0L,
      TRUE ~ NA_integer_
    ),
    unemployed = case_when(
      empstat >= 20 & empstat <= 22 ~ 1L,
      empstat >= 10 & empstat <= 12 ~ 0L,
      TRUE ~ NA_integer_
    ),
    in_labor_force = case_when(
      labforce == 2 ~ 1L,
      labforce == 1 ~ 0L,
      TRUE ~ NA_integer_
    ),
    nilf = case_when(
      labforce == 1 ~ 1L,
      labforce == 2 ~ 0L,
      TRUE ~ NA_integer_
    )
  )

# ============================================================================
# 6. INCOME
# ============================================================================

cps <- cps %>%
  mutate(
    totalinc    = ifelse(inctot < 9999998, inctot, NA_real_),
    wageinc     = ifelse(incwage > 0 & incwage < 9999998, incwage, NA_real_),
    has_wageinc = as.integer(incwage > 0 & incwage < 9999998),
    lnwage      = ifelse(!is.na(wageinc) & wageinc > 0, log(wageinc), NA_real_),

    ssinc       = ifelse(incss > 0 & incss < 99999, incss, NA_real_),
    receives_ss = as.integer(incss > 0 & incss < 99999),

    ssiinc        = ifelse(incssi > 0 & incssi < 99999, incssi, NA_real_),
    receives_ssi  = as.integer(incssi > 0 & incssi < 99999),

    welfareinc       = ifelse(incwelfr > 0 & incwelfr < 99999, incwelfr, NA_real_),
    receives_welfare = as.integer(incwelfr > 0 & incwelfr < 99999),

    uiinc       = ifelse(incunemp > 0 & incunemp < 99999, incunemp, NA_real_),
    receives_ui = as.integer(incunemp > 0 & incunemp < 99999)
  )

# ============================================================================
# 7. SNAP
# ============================================================================

cps <- cps %>%
  mutate(snap = case_when(
    foodstmp == 2 ~ 1L,
    foodstmp == 1 ~ 0L,
    TRUE ~ NA_integer_
  ))

# ============================================================================
# 8. HEALTH INSURANCE
# ============================================================================

cps <- cps %>%
  mutate(
    has_private_ins = if ("phinsur" %in% names(.)) {
      as.integer(phinsur == 1)
    } else NA_integer_,

    medicaid = if ("himcaidly" %in% names(.)) {
      as.integer(himcaidly == 2)
    } else NA_integer_,

    medicare = if ("himcarely" %in% names(.)) {
      as.integer(himcarely == 2)
    } else NA_integer_
  )

# Uninsured indicator
if ("anycovly" %in% names(cps)) {
  cps <- cps %>%
    mutate(uninsured = case_when(
      anycovly == 1 ~ 1L,
      anycovly == 2 ~ 0L,
      # Fallback for years without anycovly
      is.na(anycovly) & phinsur == 2 & himcaidly == 1 & himcarely == 1 ~ 1L,
      is.na(anycovly) & (phinsur == 1 | himcaidly == 2 | himcarely == 2) ~ 0L,
      TRUE ~ NA_integer_
    ))
} else {
  cps <- cps %>%
    mutate(uninsured = case_when(
      phinsur == 2 & himcaidly == 1 & himcarely == 1 ~ 1L,
      phinsur == 1 | himcaidly == 2 | himcarely == 2 ~ 0L,
      TRUE ~ NA_integer_
    ))
}

# ============================================================================
# 9. IMMIGRATION
# ============================================================================

if ("nativity" %in% names(cps)) {
  cps <- cps %>%
    mutate(
      foreign_born = as.integer(nativity == 5),
      noncitizen   = as.integer(citizen >= 4 & citizen <= 5),
      naturalized  = as.integer(citizen == 3),
      bpl_foreign  = as.integer(bpl >= 15000)
    )
}

# ============================================================================
# 10. POVERTY
# ============================================================================

if ("poverty" %in% names(cps)) {
  cps <- cps %>%
    mutate(
      poverty_ratio = ifelse(poverty > 0 & poverty < 999, poverty / 100, NA_real_),
      below_poverty = as.integer(poverty > 0 & poverty < 100),
      below_138fpl  = as.integer(poverty > 0 & poverty < 138),
      below_200fpl  = as.integer(poverty > 0 & poverty < 200),
      below_400fpl  = as.integer(poverty > 0 & poverty < 400)
    )
}

# ============================================================================
# 11. SAVE
# ============================================================================

cat("\nSaving cleaned dataset...\n")
cps <- cps %>% arrange(year, serial, pernum)

saveRDS(cps, out_rds)
cat(paste0("Saved: ", out_rds, "\n"))

tryCatch({
  write_dta(cps, out_dta)
  cat(paste0("Saved: ", out_dta, "\n"))
}, error = function(e) {
  cat(paste0("Could not save .dta: ", e$message, "\n"))
})

cat(paste0("Observations: ", nrow(cps), "\n"))
cat(paste0("Variables: ", ncol(cps), "\n"))

# ============================================================================
# 12. DESCRIPTIVE STATISTICS
# ============================================================================

cat("\n============================================\n")
cat("   DESCRIPTIVE STATISTICS\n")
cat("============================================\n\n")

cat("--- Sample sizes by year ---\n")
print(as.data.frame(cps %>% count(year)), row.names = FALSE)

cat("\n--- Age (working-age adults) ---\n")
print(summary(cps$age[cps$working_age == 1]))

cat("\n--- Race/ethnicity ---\n")
race_labels <- c("1" = "White NH", "2" = "Black NH",
                 "3" = "Hispanic", "4" = "Other NH")
race_table <- cps %>%
  filter(!is.na(race_eth)) %>%
  count(race_eth) %>%
  mutate(pct = round(n / sum(n) * 100, 1),
         label = race_labels[as.character(race_eth)])
print(as.data.frame(race_table), row.names = FALSE)

cat("\n--- Education ---\n")
print(as.data.frame(cps %>% filter(!is.na(educ_cat)) %>% count(educ_cat)),
      row.names = FALSE)

# ============================================================================
# 13. EXAMPLE REGRESSIONS
# ============================================================================

cat("\n============================================\n")
cat("   EXAMPLE REGRESSIONS\n")
cat("============================================\n\n")

# OLS: log wages ~ demographics (working-age adults)
cat("--- OLS: Log wage income (unweighted, working-age adults) ---\n")
ols <- lm(lnwage ~ female + age + factor(race_eth) + factor(educ_cat) + factor(year),
           data = cps %>% filter(working_age == 1))
print(tidy(ols) %>% head(10))
cat("  (showing first 10 coefficients)\n")

# Weighted OLS
cat("\n--- Weighted OLS: Log wage income ---\n")
wols <- lm(lnwage ~ female + age + factor(race_eth) + factor(educ_cat) + factor(year),
            data = cps %>% filter(working_age == 1),
            weights = asecwt)
print(tidy(wols) %>% head(10))

cat("\n============================================\n")
cat("   DONE\n")
cat("============================================\n")

################################################################################
# NOTES: See Stata version (02_clean_demographics.do) for detailed notes on
# weights, income reference period, insurance redesign, and IPUMS citation.
#
# For survey-weighted analysis in R, use:
#   library(survey)
#   des <- svydesign(ids = ~1, weights = ~asecwt, data = cps)
#   svyglm(uninsured ~ female + age + factor(race_eth), design = des)
#
# For replicate weight variance estimation (2005+):
#   library(survey)
#   repwt_cols <- paste0("repwtp", 1:160)
#   des <- svrepdesign(weights = ~asecwt, repweights = cps[repwt_cols],
#                      type = "successive-difference", data = cps)
################################################################################
