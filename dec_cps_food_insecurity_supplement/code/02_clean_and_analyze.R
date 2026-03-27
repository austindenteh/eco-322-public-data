# =============================================================================
# 02_clean_and_analyze.R
# December CPS Food Security Supplement — Clean Demographics & Analyze
# =============================================================================
#
# Author:  Austin Denteh
# Date:    March 2026
#
# Purpose: Clean demographic variables and construct food security outcomes
#          from the December CPS Food Security Supplement (IPUMS CPS extract).
#
# Input:   output/dec_cps_working.rds  (from 01_load_and_subset.R)
# Output:  output/dec_cps_clean.rds
#
# Required packages: haven, dplyr
# =============================================================================

# -----------------------------------------------------------------------------
# Section 1: Setup
# -----------------------------------------------------------------------------

library(haven)
library(dplyr)

cat("\n")
cat("=================================================================\n")
cat("  December CPS Food Security Supplement — Clean & Analyze\n")
cat("=================================================================\n\n")

# --- Paths ---
dec_cps_root <- "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/dec_cps_food_insecurity_supplement"

input_file  <- file.path(dec_cps_root, "output", "dec_cps_working.rds")
output_file <- file.path(dec_cps_root, "output", "dec_cps_clean.rds")

# --- Load data ---
cat("Loading working dataset...\n")
cps <- readRDS(input_file)

cat(sprintf("  Observations: %s\n", format(nrow(cps), big.mark = ",")))
cat(sprintf("  Variables:    %d\n", ncol(cps)))
cat(sprintf("  Years:        %d to %d\n", min(cps$year), max(cps$year)))
cat("\n")

# --- Lowercase variable names ---
names(cps) <- tolower(names(cps))


# -----------------------------------------------------------------------------
# Section 2: Demographics — Sex and Race/Ethnicity
# -----------------------------------------------------------------------------

cat("-----------------------------------------------------------------\n")
cat("  Section 2: Sex and Race/Ethnicity\n")
cat("-----------------------------------------------------------------\n\n")

cps <- cps %>%
  mutate(
    # Female indicator
    female = as.integer(sex == 2),

    # Hispanic indicator (IPUMS CPS: 0 = not Hispanic, 901/902 = unknown/NA)
    hisp = as.integer(!hispan %in% c(0, 901, 902)),

    # Race indicators (non-Hispanic only)
    white = as.integer(race == 100 & hisp == 0),
    black = as.integer(race == 200 & hisp == 0),
    asian = as.integer(race %in% c(650, 651, 652) & hisp == 0),
    other = as.integer(hisp == 0 & white == 0 & black == 0 & asian == 0),

    # Combined race/ethnicity variable
    race_eth = case_when(
      hisp == 1           ~ "Hispanic",
      race == 100         ~ "White NH",
      race == 200         ~ "Black NH",
      race %in% c(650, 651, 652) ~ "Asian NH",
      TRUE                ~ "Other NH"
    )
  )

cat("Race/ethnicity distribution:\n")
print(table(cps$race_eth, useNA = "ifany"))
cat("\n")

cat(sprintf("  Female:   %s (%.1f%%)\n",
            format(sum(cps$female, na.rm = TRUE), big.mark = ","),
            100 * mean(cps$female, na.rm = TRUE)))
cat("\n")


# -----------------------------------------------------------------------------
# Section 3: Age, Marital Status, Nativity
# -----------------------------------------------------------------------------

cat("-----------------------------------------------------------------\n")
cat("  Section 3: Age, Marital Status, Nativity\n")
cat("-----------------------------------------------------------------\n\n")

cps <- cps %>%
  mutate(
    # Age groups
    age_group = case_when(
      age >= 18 & age <= 24 ~ "18-24",
      age >= 25 & age <= 34 ~ "25-34",
      age >= 35 & age <= 44 ~ "35-44",
      age >= 45 & age <= 54 ~ "45-54",
      age >= 55 & age <= 64 ~ "55-64",
      age >= 65             ~ "65plus",
      TRUE                  ~ NA_character_
    ),

    # Senior indicator (60+ per FSS convention)
    senior = as.integer(age >= 60),

    # Married indicator (IPUMS CPS: 1 = married spouse present, 2 = married spouse absent)
    married = as.integer(marst %in% c(1, 2))
  )

# Foreign-born indicator — guard on nativity column existence
if ("nativity" %in% names(cps)) {
  cps <- cps %>%
    mutate(foreignborn = as.integer(nativity == 5))
  cat(sprintf("  Foreign-born: %s (%.1f%%)\n",
              format(sum(cps$foreignborn, na.rm = TRUE), big.mark = ","),
              100 * mean(cps$foreignborn, na.rm = TRUE)))
} else {
  cps$foreignborn <- NA_integer_
  cat("  NOTE: nativity variable not found — foreignborn set to NA.\n")
}

cat("\nAge group distribution:\n")
print(table(cps$age_group, useNA = "ifany"))
cat("\n")

cat(sprintf("  Senior (60+): %s (%.1f%%)\n",
            format(sum(cps$senior, na.rm = TRUE), big.mark = ","),
            100 * mean(cps$senior, na.rm = TRUE)))
cat(sprintf("  Married:      %s (%.1f%%)\n",
            format(sum(cps$married, na.rm = TRUE), big.mark = ","),
            100 * mean(cps$married, na.rm = TRUE)))
cat("\n")


# -----------------------------------------------------------------------------
# Section 4: Education
# -----------------------------------------------------------------------------

cat("-----------------------------------------------------------------\n")
cat("  Section 4: Education\n")
cat("-----------------------------------------------------------------\n\n")

if ("educ99" %in% names(cps)) {
  cps <- cps %>%
    mutate(
      educ_lths   = as.integer(educ99 < 10),
      educ_hs     = as.integer(educ99 %in% c(10, 11)),
      educ_assoc  = as.integer(educ99 %in% c(12, 13, 14)),
      educ_bach   = as.integer(educ99 == 15),
      educ_advdeg = as.integer(educ99 %in% c(16, 17, 18))
    )

  cat("Education distribution:\n")
  cat(sprintf("  Less than HS:   %s (%.1f%%)\n",
              format(sum(cps$educ_lths, na.rm = TRUE), big.mark = ","),
              100 * mean(cps$educ_lths, na.rm = TRUE)))
  cat(sprintf("  HS / GED:       %s (%.1f%%)\n",
              format(sum(cps$educ_hs, na.rm = TRUE), big.mark = ","),
              100 * mean(cps$educ_hs, na.rm = TRUE)))
  cat(sprintf("  Some college:   %s (%.1f%%)\n",
              format(sum(cps$educ_assoc, na.rm = TRUE), big.mark = ","),
              100 * mean(cps$educ_assoc, na.rm = TRUE)))
  cat(sprintf("  Bachelor's:     %s (%.1f%%)\n",
              format(sum(cps$educ_bach, na.rm = TRUE), big.mark = ","),
              100 * mean(cps$educ_bach, na.rm = TRUE)))
  cat(sprintf("  Advanced deg:   %s (%.1f%%)\n",
              format(sum(cps$educ_advdeg, na.rm = TRUE), big.mark = ","),
              100 * mean(cps$educ_advdeg, na.rm = TRUE)))
} else {
  cat("  NOTE: educ99 variable not found — education indicators not created.\n")
  cps$educ_lths   <- NA_integer_
  cps$educ_hs     <- NA_integer_
  cps$educ_assoc  <- NA_integer_
  cps$educ_bach   <- NA_integer_
  cps$educ_advdeg <- NA_integer_
}
cat("\n")


# -----------------------------------------------------------------------------
# Section 5: Employment
# -----------------------------------------------------------------------------

cat("-----------------------------------------------------------------\n")
cat("  Section 5: Employment\n")
cat("-----------------------------------------------------------------\n\n")

if ("empstat" %in% names(cps)) {
  # empstat == 0 is NIU (children, etc.) — set to NA
  cps <- cps %>%
    mutate(
      employed   = ifelse(empstat == 0, NA, as.integer(empstat %in% c(1, 10, 12))),
      unemployed = ifelse(empstat == 0, NA, as.integer(empstat %in% c(20, 21, 22))),
      not_in_lf  = ifelse(empstat == 0, NA, as.integer(empstat %in% c(30, 31, 32, 33, 34, 35, 36)))
    )

  cat("Employment distribution:\n")
  cat(sprintf("  Employed:       %s (%.1f%%)\n",
              format(sum(cps$employed, na.rm = TRUE), big.mark = ","),
              100 * mean(cps$employed, na.rm = TRUE)))
  cat(sprintf("  Unemployed:     %s (%.1f%%)\n",
              format(sum(cps$unemployed, na.rm = TRUE), big.mark = ","),
              100 * mean(cps$unemployed, na.rm = TRUE)))
  cat(sprintf("  Not in LF:      %s (%.1f%%)\n",
              format(sum(cps$not_in_lf, na.rm = TRUE), big.mark = ","),
              100 * mean(cps$not_in_lf, na.rm = TRUE)))
} else {
  cat("  NOTE: empstat variable not found — employment indicators not created.\n")
  cps$employed   <- NA_integer_
  cps$unemployed <- NA_integer_
  cps$not_in_lf  <- NA_integer_
}
cat("\n")


# -----------------------------------------------------------------------------
# Section 6: Household Composition
# -----------------------------------------------------------------------------

cat("-----------------------------------------------------------------\n")
cat("  Section 6: Household Composition\n")
cat("-----------------------------------------------------------------\n\n")

# Children in household
if ("nchild" %in% names(cps)) {
  cps <- cps %>%
    mutate(any_child = as.integer(nchild > 0))
  cat(sprintf("  Any children in HH: %s (%.1f%%)\n",
              format(sum(cps$any_child, na.rm = TRUE), big.mark = ","),
              100 * mean(cps$any_child, na.rm = TRUE)))
} else {
  cps$any_child <- NA_integer_
  cat("  NOTE: nchild variable not found — any_child set to NA.\n")
}

# Senior composition at household level
if ("hhid" %in% names(cps)) {
  hh_senior <- cps %>%
    group_by(hhid, year) %>%
    summarise(
      hh_anysenior = as.integer(any(senior == 1, na.rm = TRUE)),
      hh_allsenior = as.integer(all(senior == 1, na.rm = TRUE)),
      .groups = "drop"
    )

  cps <- cps %>%
    left_join(hh_senior, by = c("hhid", "year"))

  cat(sprintf("  HH with any senior: %.1f%%\n",
              100 * mean(cps$hh_anysenior, na.rm = TRUE)))
  cat(sprintf("  HH all seniors:     %.1f%%\n",
              100 * mean(cps$hh_allsenior, na.rm = TRUE)))
} else {
  cps$hh_anysenior <- NA_integer_
  cps$hh_allsenior <- NA_integer_
  cat("  NOTE: hhid variable not found — household senior indicators set to NA.\n")
}
cat("\n")


# -----------------------------------------------------------------------------
# Section 7: Food Security Outcomes
# -----------------------------------------------------------------------------

cat("-----------------------------------------------------------------\n")
cat("  Section 7: Food Security Outcomes\n")
cat("-----------------------------------------------------------------\n\n")

# --- Household food security (fsstatusd) ---
# Coding: 1 = high, 2 = marginal, 3 = low, 4 = very low
#         98 = no response, 99 = NIU
if ("fsstatusd" %in% names(cps)) {
  cps <- cps %>%
    mutate(
      fs_high       = ifelse(fsstatusd %in% c(98, 99), NA, as.integer(fsstatusd == 1)),
      fs_marginal   = ifelse(fsstatusd %in% c(98, 99), NA, as.integer(fsstatusd == 2)),
      fs_low        = ifelse(fsstatusd %in% c(98, 99), NA, as.integer(fsstatusd == 3)),
      fs_verylow    = ifelse(fsstatusd %in% c(98, 99), NA, as.integer(fsstatusd == 4)),
      food_insecure = ifelse(fsstatusd %in% c(98, 99), NA, as.integer(fsstatusd %in% c(3, 4)))
    )

  n_valid_hh <- sum(!is.na(cps$food_insecure))
  cat("Household food security (fsstatusd):\n")
  cat(sprintf("  Valid obs:      %s\n", format(n_valid_hh, big.mark = ",")))
  cat(sprintf("  High:           %.1f%%\n", 100 * mean(cps$fs_high, na.rm = TRUE)))
  cat(sprintf("  Marginal:       %.1f%%\n", 100 * mean(cps$fs_marginal, na.rm = TRUE)))
  cat(sprintf("  Low:            %.1f%%\n", 100 * mean(cps$fs_low, na.rm = TRUE)))
  cat(sprintf("  Very low:       %.1f%%\n", 100 * mean(cps$fs_verylow, na.rm = TRUE)))
  cat(sprintf("  Food insecure:  %.1f%%\n", 100 * mean(cps$food_insecure, na.rm = TRUE)))
  cat("\n")
} else {
  cat("  NOTE: fsstatusd not found — household food security indicators not created.\n\n")
  cps$fs_high       <- NA_integer_
  cps$fs_marginal   <- NA_integer_
  cps$fs_low        <- NA_integer_
  cps$fs_verylow    <- NA_integer_
  cps$food_insecure <- NA_integer_
}

# --- Adult food security (fsstatusa) ---
# Same coding as household: 1=high, 2=marginal, 3=low, 4=very low, 98/99=NA
if ("fsstatusa" %in% names(cps)) {
  cps <- cps %>%
    mutate(
      fsa_high    = ifelse(fsstatusa %in% c(98, 99), NA, as.integer(fsstatusa == 1)),
      fsa_low     = ifelse(fsstatusa %in% c(98, 99), NA, as.integer(fsstatusa == 3)),
      fsa_verylow = ifelse(fsstatusa %in% c(98, 99), NA, as.integer(fsstatusa == 4)),
      adult_food_insecure = ifelse(fsstatusa %in% c(98, 99), NA, as.integer(fsstatusa %in% c(3, 4)))
    )

  cat("Adult food security (fsstatusa):\n")
  cat(sprintf("  Food insecure (adult): %.1f%%\n",
              100 * mean(cps$adult_food_insecure, na.rm = TRUE)))
  cat("\n")
} else {
  cat("  NOTE: fsstatusa not found — adult food security indicators not created.\n\n")
}

# --- Child food security (fsstatusc) — guarded ---
# NOTE: Child scale coding DIFFERS from household/adult:
#   1 = High/marginal food security
#   2 = Low food security
#   3 = Very low food security
#   98 = No response, 99 = NIU
if ("fsstatusc" %in% names(cps)) {
  cps <- cps %>%
    mutate(
      fsc_low     = ifelse(fsstatusc %in% c(98, 99), NA, as.integer(fsstatusc == 2)),
      fsc_verylow = ifelse(fsstatusc %in% c(98, 99), NA, as.integer(fsstatusc == 3)),
      child_food_insecure = ifelse(fsstatusc %in% c(98, 99), NA, as.integer(fsstatusc %in% c(2, 3)))
    )

  cat("Child food security (fsstatusc):\n")
  cat(sprintf("  Food insecure (child): %.1f%%\n",
              100 * mean(cps$child_food_insecure, na.rm = TRUE)))
  cat("\n")
} else {
  cat("  NOTE: fsstatusc not found — child food security indicators not created.\n\n")
}

# --- Food security rates by year ---
cat("Household food insecurity rate by year:\n")
if ("food_insecure" %in% names(cps)) {
  fs_by_year <- cps %>%
    filter(!is.na(food_insecure)) %>%
    group_by(year) %>%
    summarise(
      n         = n(),
      fi_rate   = mean(food_insecure, na.rm = TRUE),
      .groups   = "drop"
    )
  for (i in seq_len(nrow(fs_by_year))) {
    cat(sprintf("  %d:  %.1f%%  (n = %s)\n",
                fs_by_year$year[i],
                100 * fs_by_year$fi_rate[i],
                format(fs_by_year$n[i], big.mark = ",")))
  }
}
cat("\n")


# -----------------------------------------------------------------------------
# Section 8: SNAP Participation
# -----------------------------------------------------------------------------

cat("-----------------------------------------------------------------\n")
cat("  Section 8: SNAP Participation\n")
cat("-----------------------------------------------------------------\n\n")

if ("fsfdstmp" %in% names(cps)) {
  cps <- cps %>%
    mutate(
      snap_participant = ifelse(fsfdstmp %in% c(0, 98, 99), NA, as.integer(fsfdstmp == 1))
    )

  cat(sprintf("  SNAP participants: %s (%.1f%% of valid responses)\n",
              format(sum(cps$snap_participant == 1, na.rm = TRUE), big.mark = ","),
              100 * mean(cps$snap_participant, na.rm = TRUE)))
  cat("\n")

  # SNAP by year
  cat("SNAP participation rate by year:\n")
  snap_by_year <- cps %>%
    filter(!is.na(snap_participant)) %>%
    group_by(year) %>%
    summarise(
      n         = n(),
      snap_rate = mean(snap_participant, na.rm = TRUE),
      .groups   = "drop"
    )
  for (i in seq_len(nrow(snap_by_year))) {
    cat(sprintf("  %d:  %.1f%%  (n = %s)\n",
                snap_by_year$year[i],
                100 * snap_by_year$snap_rate[i],
                format(snap_by_year$n[i], big.mark = ",")))
  }
} else {
  cps$snap_participant <- NA_integer_
  cat("  NOTE: fsfdstmp not found — snap_participant set to NA.\n")
}
cat("\n")


# -----------------------------------------------------------------------------
# Section 9: Other Food Assistance Programs
# -----------------------------------------------------------------------------

cat("-----------------------------------------------------------------\n")
cat("  Section 9: Other Food Assistance Programs\n")
cat("-----------------------------------------------------------------\n\n")

# Helper: create binary indicator from FSS yes/no variable
# Coding: 0 = NIU, 1 = Yes, 2 = No → binary (== 1), NA if 0/98/99
make_fss_binary <- function(x) {
  ifelse(x %in% c(0, 98, 99), NA, as.integer(x == 1))
}

# School lunch (free/reduced price)
if ("fslnchfrc" %in% names(cps)) {
  cps$school_lunch <- make_fss_binary(cps$fslnchfrc)
  cat(sprintf("  School lunch (free/reduced): %.1f%% of valid\n",
              100 * mean(cps$school_lunch, na.rm = TRUE)))
} else {
  cps$school_lunch <- NA_integer_
  cat("  NOTE: fslnchfrc not found — school_lunch set to NA.\n")
}

# WIC
if ("fswic" %in% names(cps)) {
  cps$wic <- make_fss_binary(cps$fswic)
  cat(sprintf("  WIC participation:           %.1f%% of valid\n",
              100 * mean(cps$wic, na.rm = TRUE)))
} else {
  cps$wic <- NA_integer_
  cat("  NOTE: fswic not found — wic set to NA.\n")
}

# Food bank
if ("fsfdbnk" %in% names(cps)) {
  cps$food_bank <- make_fss_binary(cps$fsfdbnk)
  cat(sprintf("  Food bank use:               %.1f%% of valid\n",
              100 * mean(cps$food_bank, na.rm = TRUE)))
} else {
  cps$food_bank <- NA_integer_
  cat("  NOTE: fsfdbnk not found — food_bank set to NA.\n")
}

# Soup kitchen
if ("fssoupk" %in% names(cps)) {
  cps$soup_kitchen <- make_fss_binary(cps$fssoupk)
  cat(sprintf("  Soup kitchen use:            %.1f%% of valid\n",
              100 * mean(cps$soup_kitchen, na.rm = TRUE)))
} else {
  cps$soup_kitchen <- NA_integer_
  cat("  NOTE: fssoupk not found — soup_kitchen set to NA.\n")
}
cat("\n")


# -----------------------------------------------------------------------------
# Section 10: Descriptive Statistics
# -----------------------------------------------------------------------------

cat("-----------------------------------------------------------------\n")
cat("  Section 10: Descriptive Statistics\n")
cat("-----------------------------------------------------------------\n\n")

# --- Demographics summary ---
cat("Demographic summary (full sample):\n")
cat(sprintf("  N:             %s\n", format(nrow(cps), big.mark = ",")))
cat(sprintf("  Female:        %.1f%%\n", 100 * mean(cps$female, na.rm = TRUE)))
cat(sprintf("  Mean age:      %.1f\n", mean(cps$age, na.rm = TRUE)))
cat(sprintf("  Married:       %.1f%%\n", 100 * mean(cps$married, na.rm = TRUE)))
cat(sprintf("  Employed:      %.1f%%\n", 100 * mean(cps$employed, na.rm = TRUE)))
cat("\n")

# --- Food security by year ---
cat("Food security rates by year (household):\n")
if ("food_insecure" %in% names(cps)) {
  fs_year_tab <- cps %>%
    filter(!is.na(food_insecure)) %>%
    group_by(year) %>%
    summarise(
      n       = n(),
      fi_pct  = 100 * mean(food_insecure, na.rm = TRUE),
      low_pct = 100 * mean(fs_low, na.rm = TRUE),
      vlow_pct = 100 * mean(fs_verylow, na.rm = TRUE),
      .groups = "drop"
    )
  print(as.data.frame(fs_year_tab), row.names = FALSE)
}
cat("\n")

# --- SNAP by year ---
cat("SNAP participation by year:\n")
if ("snap_participant" %in% names(cps)) {
  snap_year_tab <- cps %>%
    filter(!is.na(snap_participant)) %>%
    group_by(year) %>%
    summarise(
      n         = n(),
      snap_pct  = 100 * mean(snap_participant, na.rm = TRUE),
      .groups   = "drop"
    )
  print(as.data.frame(snap_year_tab), row.names = FALSE)
}
cat("\n")

# --- Food security by race/ethnicity ---
cat("Food insecurity rate by race/ethnicity:\n")
if ("food_insecure" %in% names(cps)) {
  fs_race_tab <- cps %>%
    filter(!is.na(food_insecure)) %>%
    group_by(race_eth) %>%
    summarise(
      n       = n(),
      fi_pct  = 100 * mean(food_insecure, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(desc(fi_pct))
  print(as.data.frame(fs_race_tab), row.names = FALSE)
}
cat("\n")


# -----------------------------------------------------------------------------
# Section 11: Example Regression
# -----------------------------------------------------------------------------

cat("-----------------------------------------------------------------\n")
cat("  Section 11: Example Regression\n")
cat("-----------------------------------------------------------------\n\n")

cat("Running OLS regression: food_insecure ~ demographics + SNAP + year FE\n")
cat("  (using FSS supplement weight: fshwtscale)\n\n")

# Restrict to non-missing outcome
reg_data <- cps %>%
  filter(!is.na(food_insecure),
         !is.na(fshwtscale),
         fshwtscale > 0)

if (nrow(reg_data) > 0) {
  fit <- lm(food_insecure ~ female + age + factor(race_eth) + educ_hs +
              educ_bach + married + snap_participant + factor(year),
            data = reg_data,
            weights = fshwtscale)

  cat("Regression results (linear probability model):\n\n")
  print(summary(fit))
  cat("\n")
}

cat("NOTE: These standard errors are NOT survey-corrected. For proper\n")
cat("  inference with the CPS complex survey design, use the survey\n")
cat("  package with svydesign() and svyglm(). The FSS supplement weight\n")
cat("  is fshwtscale (or fssuppwth for household-level analyses).\n")
cat("\n")


# -----------------------------------------------------------------------------
# Section 12: Save Clean Dataset
# -----------------------------------------------------------------------------

cat("-----------------------------------------------------------------\n")
cat("  Section 12: Save Clean Dataset\n")
cat("-----------------------------------------------------------------\n\n")

saveRDS(cps, output_file)
cat(sprintf("Saved: %s\n", output_file))
cat(sprintf("  Observations: %s\n", format(nrow(cps), big.mark = ",")))
cat(sprintf("  Variables:    %d\n", ncol(cps)))
cat("\n")


# =============================================================================
# Notes
# =============================================================================
#
# WEIGHTS:
#   - fshwtscale: Person-level FSS supplement weight (scaled). Use for
#     person-level analyses of food security outcomes.
#   - fssuppwth: Household-level supplement weight. Use for household-level
#     tabulations (e.g., household food security prevalence).
#   - For proper survey estimation, use the survey package:
#       library(survey)
#       des <- svydesign(ids = ~1, weights = ~fshwtscale, data = cps)
#       svymean(~food_insecure, des, na.rm = TRUE)
#
# FOOD SECURITY CODING:
#   - fsstatusd (household detailed): 1=high, 2=marginal, 3=low, 4=very low
#   - fsstatusa (adult): same coding as household
#   - fsstatusc (child): same coding; only defined for HH with children
#   - "Food insecure" = low or very low food security (categories 3-4)
#   - 98 = no response, 99 = NIU (not in universe) → set to NA
#
# HOUSEHOLD vs PERSON:
#   - Food security status is measured at the HOUSEHOLD level but appears
#     on every person record within the household. When computing household-
#     level prevalence rates, either use household weights (fssuppwth) or
#     restrict to one record per household (e.g., the reference person).
#   - Person-level demographic analyses (e.g., individual correlates of
#     living in a food-insecure household) use person weights (fshwtscale).
#
# =============================================================================

cat("=================================================================\n")
cat("  Done. December CPS FSS cleaning complete.\n")
cat("=================================================================\n\n")
