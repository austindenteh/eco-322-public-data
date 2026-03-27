# =============================================================================
# 02_clean_1998.R — Clean and Analyze Ghana DHS 1998
# =============================================================================
# This script loads the harmonized 1998 working dataset, creates analysis
# variables for demographics, education, religion, ethnicity, and region,
# and produces descriptive statistics.
#
# Ghana DHS 1998 (DHS Phase IV)
# - 10 administrative regions
# - No literacy variable (v155 not available)
# - No wealth index (v190 not available)
# - No health insurance questions (v481/v481c not available; NHIS not yet created)
#
# Input:  output/ghana_dhs_1998_working.rds (or .dta from Stata)
# Output: output/ghana_dhs_1998_analysis.rds
#         output/ghana_dhs_1998_analysis_from_R.dta
# =============================================================================

library(haven)
library(dplyr)

# --- Paths ----------------------------------------------------------------
dhs_root <- file.path(dirname(getwd()))
if (!dir.exists(file.path(dhs_root, "output"))) dhs_root <- getwd()
out_dir  <- file.path(dhs_root, "output")

sink(file.path(out_dir, "02_clean_1998_R_log.txt"), split = TRUE)
cat("============================================================\n")
cat("Ghana DHS 1998 -- Clean and Analyze (R)\n")
cat("============================================================\n\n")

# Load data (prefer .rds from R, fall back to .dta from Stata)
rds_file <- file.path(out_dir, "ghana_dhs_1998_working.rds")
dta_file <- file.path(out_dir, "ghana_dhs_1998_working.dta")

if (file.exists(rds_file)) {
  dhs <- readRDS(rds_file)
  cat(sprintf("Loaded %d observations from .rds\n", nrow(dhs)))
} else if (file.exists(dta_file)) {
  dhs <- read_dta(dta_file) %>% mutate(across(where(is.labelled), as.integer))
  cat(sprintf("Loaded %d observations from .dta\n", nrow(dhs)))
} else {
  stop("Working dataset not found. Run 01_load_1998 first.")
}

# ==========================================================================
# SECTION 1: Demographics
# ==========================================================================

cat("\n--- Section 1: Demographics ---\n")

dhs <- dhs %>%
  mutate(
    urban = as.integer(residence == 1),

    age_group = case_when(
      age_years >= 15 & age_years <= 19 ~ 1L,
      age_years >= 20 & age_years <= 24 ~ 2L,
      age_years >= 25 & age_years <= 29 ~ 3L,
      age_years >= 30 & age_years <= 34 ~ 4L,
      age_years >= 35 & age_years <= 39 ~ 5L,
      age_years >= 40 & age_years <= 44 ~ 6L,
      age_years >= 45 & age_years <= 49 ~ 7L,
      age_years >= 50 & age_years <= 59 ~ 8L
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

# NOTE: Literacy (v155) is NOT available in 1998.
# The literate variable cannot be constructed for this wave.
cat("  NOTE: Literacy variable (v155) not available in 1998 -- skipping.\n")

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
# SECTION 5: Health Insurance — NOT AVAILABLE
# ==========================================================================

cat("--- Section 5: Health Insurance ---\n")
cat("  NOTE: Health insurance (v481/v481c) not available in 1998.\n")
cat("  NHIS was not created until 2003. Skipping insurance section.\n")

# ==========================================================================
# SECTION 6: Region (10 regions in 1998)
# ==========================================================================

cat("--- Section 6: Region ---\n")

region_labels_1998 <- c(
  "1" = "Western", "2" = "Central", "3" = "Greater Accra", "4" = "Volta",
  "5" = "Eastern", "6" = "Ashanti", "7" = "Brong Ahafo", "8" = "Northern",
  "9" = "Upper East", "10" = "Upper West"
)

dhs <- dhs %>%
  mutate(
    region_name = region_labels_1998[as.character(region)],
    northern    = as.integer(region %in% c(8, 9, 10))
  )

# ==========================================================================
# SECTION 7: Wealth — NOT AVAILABLE
# ==========================================================================

cat("--- Section 7: Wealth ---\n")
cat("  NOTE: Wealth index (v190) not available in 1998. Skipping wealth section.\n")

# ==========================================================================
# SECTION 8: Descriptive Statistics
# ==========================================================================

cat("\n============================================================\n")
cat("DESCRIPTIVE STATISTICS -- Ghana DHS 1998\n")
cat("============================================================\n")

cat("\n--- 8a. Sample Composition ---\n")
print(table(dhs$female, useNA = "ifany"))
cat("\n")
print(table(Urban = dhs$urban, Female = dhs$female, useNA = "ifany"))
cat("\n")
print(table(AgeGroup = dhs$age_group, Female = dhs$female, useNA = "ifany"))

cat("\n--- 8b. Education ---\n")
print(table(EducLevel = dhs$educ_level, Female = dhs$female, useNA = "ifany"))

cat("\n--- 8c. Marital Status ---\n")
print(table(Marital = dhs$marital_status, Female = dhs$female, useNA = "ifany"))
cat("\n")
print(table(InUnion = dhs$in_union, Female = dhs$female, useNA = "ifany"))

cat("\n--- 8d. Employment ---\n")
print(table(Employed = dhs$employed, Female = dhs$female, useNA = "ifany"))

cat("\n--- 8e. Religion ---\n")
print(table(Religion = dhs$religion, Female = dhs$female, useNA = "ifany"))

cat("\n--- 8f. Ethnicity ---\n")
print(table(Ethnicity = dhs$ethnicity, Female = dhs$female, useNA = "ifany"))

cat("\n--- 8g. Region ---\n")
print(table(Region = dhs$region, Female = dhs$female, useNA = "ifany"))

# Summary means (excluding literate, poor, insurance — not available in 1998)
cat("\n--- 8h. Summary Means ---\n")
summary_vars <- c("female", "urban", "age_years", "educ_none", "educ_primary",
                   "educ_second", "educ_higher", "in_union", "employed")
print(summary(dhs[, summary_vars]))

cat("\n--- 8i. Summary Means by Sex ---\n")
summ_vars <- c("urban", "age_years", "educ_none", "educ_primary", "educ_second",
               "educ_higher", "in_union", "employed")

cat("=== Women ===\n")
women_means <- dhs %>% filter(female == 1) %>%
  summarize(across(all_of(summ_vars), ~mean(.x, na.rm = TRUE)))
print(as.data.frame(women_means), digits = 7)

cat("\n=== Men ===\n")
men_means <- dhs %>% filter(female == 0) %>%
  summarize(across(all_of(summ_vars), ~mean(.x, na.rm = TRUE)))
print(as.data.frame(men_means), digits = 7)

# ==========================================================================
# SECTION 9: Save Analysis Dataset
# ==========================================================================

saveRDS(dhs, file.path(out_dir, "ghana_dhs_1998_analysis.rds"))
write_dta(dhs %>% select(-region_name), file.path(out_dir, "ghana_dhs_1998_analysis_from_R.dta"))

cat(sprintf("\n============================================================\n"))
cat(sprintf("Saved: %s\n", file.path(out_dir, "ghana_dhs_1998_analysis.rds")))
cat(sprintf("  N = %d\n", nrow(dhs)))
cat("============================================================\n")

sink()
