# =============================================================================
# 02_clean_1988.R — Clean and Analyze Ghana DHS 1988
# =============================================================================
# This script loads the harmonized 1988 working dataset, creates analysis
# variables for demographics, education, religion, ethnicity, and region,
# and produces descriptive statistics.
#
# Ghana DHS 1988 (DHS Phase II)
# - 10 administrative regions
# - Women only (no men's recode)
# - NO literacy (v155), wealth index (v190), or health insurance (v481/v481c)
#
# Input:  output/ghana_dhs_1988_working.rds (or .dta from Stata)
# Output: output/ghana_dhs_1988_analysis.rds
#         output/ghana_dhs_1988_analysis_from_R.dta
# =============================================================================

library(haven)
library(dplyr)

# --- Paths ----------------------------------------------------------------
dhs_root <- file.path(dirname(getwd()))
if (!dir.exists(file.path(dhs_root, "output"))) dhs_root <- getwd()
out_dir  <- file.path(dhs_root, "output")

sink(file.path(out_dir, "02_clean_1988_R_log.txt"), split = TRUE)
cat("============================================================\n")
cat("Ghana DHS 1988 -- Clean and Analyze (R)\n")
cat("============================================================\n\n")

# Load data (prefer .rds from R, fall back to .dta from Stata)
rds_file <- file.path(out_dir, "ghana_dhs_1988_working.rds")
dta_file <- file.path(out_dir, "ghana_dhs_1988_working.dta")

if (file.exists(rds_file)) {
  dhs <- readRDS(rds_file)
  cat(sprintf("Loaded %d observations from .rds\n", nrow(dhs)))
} else if (file.exists(dta_file)) {
  dhs <- read_dta(dta_file) %>% mutate(across(where(is.labelled), as.integer))
  cat(sprintf("Loaded %d observations from .dta\n", nrow(dhs)))
} else {
  stop("Working dataset not found. Run 01_load_1988 first.")
}

# ==========================================================================
# SECTION 1: Demographics
# ==========================================================================

cat("\n--- Section 1: Demographics ---\n")

dhs <- dhs %>%
  mutate(
    urban = as.integer(residence == 1),

    # Women only: 15-49 (no men's 50-59 group)
    age_group = case_when(
      age_years >= 15 & age_years <= 19 ~ 1L,
      age_years >= 20 & age_years <= 24 ~ 2L,
      age_years >= 25 & age_years <= 29 ~ 3L,
      age_years >= 30 & age_years <= 34 ~ 4L,
      age_years >= 35 & age_years <= 39 ~ 5L,
      age_years >= 40 & age_years <= 44 ~ 6L,
      age_years >= 45 & age_years <= 49 ~ 7L
    ),

    married       = ifelse(is.na(marital_status), NA_integer_, as.integer(marital_status == 1)),
    cohabiting    = ifelse(is.na(marital_status), NA_integer_, as.integer(marital_status == 2)),
    in_union      = ifelse(is.na(marital_status), NA_integer_, as.integer(marital_status %in% c(1, 2))),
    never_married = ifelse(is.na(marital_status), NA_integer_, as.integer(marital_status == 0)),
    widowed       = ifelse(is.na(marital_status), NA_integer_, as.integer(marital_status == 3)),
    divorced_sep  = ifelse(is.na(marital_status), NA_integer_, as.integer(marital_status %in% c(4, 5))),

    employed = case_when(
      working_now == 1 ~ 1L,
      working_now == 0 ~ 0L,
      TRUE             ~ NA_integer_
    )
  )

# ==========================================================================
# SECTION 2: Education
# ==========================================================================

cat("--- Section 2: Education ---\n")

dhs <- dhs %>%
  mutate(
    educ_none    = ifelse(is.na(educ_level), NA_integer_, as.integer(educ_level == 0)),
    educ_primary = ifelse(is.na(educ_level), NA_integer_, as.integer(educ_level == 1)),
    educ_second  = ifelse(is.na(educ_level), NA_integer_, as.integer(educ_level == 2)),
    educ_higher  = ifelse(is.na(educ_level), NA_integer_, as.integer(educ_level == 3))
  )

# NOTE: Literacy (v155) does not exist in the 1988 DHS. The "literate"
# variable cannot be constructed for this wave. The literacy variable
# remains NA as set in 01_load_1988.

# ==========================================================================
# SECTION 3: Religion
# ==========================================================================

cat("--- Section 3: Religion ---\n")

dhs <- dhs %>%
  mutate(
    # Guard: treat missing and 99 as NA for religion indicators
    .rel_valid = !is.na(religion) & religion != 99,

    christian      = ifelse(.rel_valid, as.integer(religion %in% 1:6), NA_integer_),
    muslim         = ifelse(.rel_valid, as.integer(religion == 7), NA_integer_),
    traditional    = ifelse(.rel_valid, as.integer(religion == 8), NA_integer_),
    no_religion    = ifelse(.rel_valid, as.integer(religion == 9), NA_integer_),
    other_religion = ifelse(.rel_valid, as.integer(religion == 96), NA_integer_),

    catholic        = ifelse(.rel_valid, as.integer(religion == 1), NA_integer_),
    protestant      = ifelse(.rel_valid, as.integer(religion %in% c(2, 3, 4)), NA_integer_),
    pentecostal     = ifelse(.rel_valid, as.integer(religion == 5), NA_integer_),
    other_christian = ifelse(.rel_valid, as.integer(religion == 6), NA_integer_)
  ) %>%
  select(-.rel_valid)

# ==========================================================================
# SECTION 4: Ethnicity
# ==========================================================================

cat("--- Section 4: Ethnicity ---\n")

dhs <- dhs %>%
  mutate(
    .eth_valid = !is.na(ethnicity) & ethnicity != 99,

    akan         = ifelse(.eth_valid, as.integer(ethnicity == 1), NA_integer_),
    ga_dangme    = ifelse(.eth_valid, as.integer(ethnicity == 2), NA_integer_),
    ewe          = ifelse(.eth_valid, as.integer(ethnicity == 3), NA_integer_),
    guan         = ifelse(.eth_valid, as.integer(ethnicity == 4), NA_integer_),
    mole_dagbani = ifelse(.eth_valid, as.integer(ethnicity == 5), NA_integer_),
    grusi        = ifelse(.eth_valid, as.integer(ethnicity == 6), NA_integer_),
    gurma        = ifelse(.eth_valid, as.integer(ethnicity == 7), NA_integer_),
    mande        = ifelse(.eth_valid, as.integer(ethnicity == 8), NA_integer_),
    other_eth    = ifelse(.eth_valid, as.integer(ethnicity == 9), NA_integer_)
  ) %>%
  select(-.eth_valid)

# ==========================================================================
# SECTION 5: Health Insurance — SKIPPED
# ==========================================================================

cat("--- Section 5: Health Insurance -- SKIPPED ---\n")
cat("  v481 (any insurance) and v481c (NHIS) do not exist in 1988.\n")
cat("  Ghana's NHIS was not established until 2003.\n")
cat("  Insurance variables remain NA from 01_load_1988.\n")

# ==========================================================================
# SECTION 6: Region (10 regions in 1988)
# ==========================================================================

cat("--- Section 6: Region ---\n")

region_labels_1988 <- c(
  "1" = "Western", "2" = "Central", "3" = "Greater Accra", "4" = "Volta",
  "5" = "Eastern", "6" = "Ashanti", "7" = "Brong Ahafo", "8" = "Northern",
  "9" = "Upper East", "10" = "Upper West"
)

dhs <- dhs %>%
  mutate(
    region_name = region_labels_1988[as.character(region)],
    northern    = as.integer(region %in% c(8, 9, 10))
  )

# ==========================================================================
# SECTION 7: Wealth — SKIPPED
# ==========================================================================

cat("--- Section 7: Wealth -- SKIPPED ---\n")
cat("  v190 (wealth index) does not exist in the 1988 DHS.\n")
cat("  The wealth index was introduced in DHS Phase IV.\n")
cat("  Wealth variable remains NA from 01_load_1988.\n")

# ==========================================================================
# SECTION 8: Descriptive Statistics
# ==========================================================================

cat("\n============================================================\n")
cat("DESCRIPTIVE STATISTICS -- Ghana DHS 1988\n")
cat("============================================================\n")

cat("\n--- 8a. Sample Composition ---\n")
print(table(dhs$female, useNA = "ifany"))
cat("\n")
print(table(Urban = dhs$urban, useNA = "ifany"))
cat("\n")
print(table(AgeGroup = dhs$age_group, useNA = "ifany"))

cat("\n--- 8b. Education ---\n")
print(table(EducLevel = dhs$educ_level, useNA = "ifany"))

cat("\n--- 8c. Marital Status ---\n")
print(table(Marital = dhs$marital_status, useNA = "ifany"))
cat("\n")
print(table(InUnion = dhs$in_union, useNA = "ifany"))

cat("\n--- 8d. Employment ---\n")
print(table(Employed = dhs$employed, useNA = "ifany"))

cat("\n--- 8e. Religion ---\n")
print(table(Religion = dhs$religion, useNA = "ifany"))

cat("\n--- 8f. Ethnicity ---\n")
print(table(Ethnicity = dhs$ethnicity, useNA = "ifany"))

# 8g. Health insurance -- SKIPPED (not available in 1988)

cat("\n--- 8h. Region Distribution ---\n")
print(table(Region = dhs$region, useNA = "ifany"))

# 8i-8j. NHIS/wealth cross-tabs -- SKIPPED (not available in 1988)

cat("\n--- 8k. Summary Means ---\n")
summary_vars <- c("female", "urban", "age_years", "educ_none", "educ_primary",
                   "educ_second", "educ_higher", "in_union", "employed")
print(summary(dhs[, summary_vars]))

cat("\n--- 8l. Summary Means (Women Only) ---\n")
summ_vars <- c("urban", "age_years", "educ_none", "educ_primary", "educ_second",
               "educ_higher", "in_union", "employed")

cat("=== Women ===\n")
women_means <- dhs %>% filter(female == 1) %>%
  summarize(across(all_of(summ_vars), ~mean(.x, na.rm = TRUE)))
print(as.data.frame(women_means), digits = 7)

# ==========================================================================
# SECTION 9: Save Analysis Dataset
# ==========================================================================

saveRDS(dhs, file.path(out_dir, "ghana_dhs_1988_analysis.rds"))
write_dta(dhs %>% select(-region_name), file.path(out_dir, "ghana_dhs_1988_analysis_from_R.dta"))

cat(sprintf("\n============================================================\n"))
cat(sprintf("Saved: %s\n", file.path(out_dir, "ghana_dhs_1988_analysis.rds")))
cat(sprintf("  N = %d\n", nrow(dhs)))
cat("============================================================\n")

sink()
