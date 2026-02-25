################################################################################
# 01_load_and_prepare.R
#
# Purpose: Build the YRBS combined dataset from raw CDC SAS files (if needed),
#          then load it, verify its structure, and save a working copy.
#
#          Step 1: If sadc_2023_combined_all.dta does not yet exist in
#                  data/raw/, this script imports the 9 separate CDC SAS
#                  files from data/raw/ and appends them into one combined file.
#          Step 2: Loads the combined file, validates, and saves to output/.
#
# Input:   data/raw/sadc_2023_*.sas7bdat
#          (9 files: 1 national + 1 district + 7 state chunks)
# Output:  data/raw/sadc_2023_combined_all.dta   (~837 MB, created once)
#          output/yrbs_combined.rds
#          output/yrbs_combined.dta
#
# Data:    Youth Risk Behavior Surveillance System (YRBSS / YRBS).
#          Biennial school-based survey of US high school students (grades
#          9-12) conducted by the CDC since 1991. Covers health behaviors
#          including mental health, substance use, sexual behavior, nutrition,
#          physical activity, and unintentional injury. The combined dataset
#          pools national, state, and district surveys across all available
#          years (1991-2023, biennial).
#
#          Source: CDC Division of Adolescent and School Health (DASH).
#          Downloaded from: https://www.cdc.gov/yrbs/data/index.html
#
# Author:  Austin Denteh (legacy code and Claude Code)
# Date:    February 2026
################################################################################

library(haven)
library(dplyr)

# ============================================================================
# 1. DEFINE PATHS
# ============================================================================

yrbs_root <- "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/yrbs"

raw_sas_dir <- file.path(yrbs_root, "data", "raw")
raw_dta     <- file.path(yrbs_root, "data", "raw", "sadc_2023_combined_all.dta")
out_rds     <- file.path(yrbs_root, "output", "yrbs_combined.rds")
out_dta     <- file.path(yrbs_root, "output", "yrbs_combined.dta")

# ============================================================================
# 2. BUILD COMBINED FILE FROM RAW SAS FILES (if not already built)
# ============================================================================
# The CDC distributes the YRBS combined high school data as 9 separate SAS
# files: 1 national, 1 district, and 7 state chunks (alphabetical ranges).
# This section imports each SAS file, appends them all, and saves the
# combined .dta. It only runs if the combined file does not already exist.

if (!file.exists(raw_dta)) {
  cat("============================================\n")
  cat("   BUILDING COMBINED FILE FROM RAW SAS DATA\n")
  cat("============================================\n\n")
  cat("Combined file not found. Importing from SAS files...\n\n")

  # Define the 9 source files
  sas_files <- c(
    "sadc_2023_national.sas7bdat",
    "sadc_2023_district.sas7bdat",
    "sadc_2023_state_a_d.sas7bdat",
    "sadc_2023_state_e_h.sas7bdat",
    "sadc_2023_state_i_l.sas7bdat",
    "sadc_2023_state_m.sas7bdat",
    "sadc_2023_state_n_p.sas7bdat",
    "sadc_2023_state_q_t.sas7bdat",
    "sadc_2023_state_u_z.sas7bdat"
  )

  # Import and append each file
  all_data <- list()
  for (f in sas_files) {
    fpath <- file.path(raw_sas_dir, f)
    cat(paste0("Importing: ", f, "..."))
    df <- read_sas(fpath)
    cat(paste0(" ", nrow(df), " rows\n"))
    all_data[[f]] <- df
  }

  # Bind all into one data frame
  cat("\nAppending all files...\n")
  yrbs_combined <- bind_rows(all_data)
  cat(paste0("Total observations: ", nrow(yrbs_combined), "\n"))

  # Save the combined file
  cat(paste0("Saving combined file: ", raw_dta, "\n"))
  write_dta(yrbs_combined, raw_dta)
  cat("Combined file created successfully.\n")

  rm(all_data, yrbs_combined)
  gc()
} else {
  cat("[INFO] Combined file already exists: ", raw_dta, "\n")
  cat("       Skipping SAS import. Delete this file to rebuild.\n")
}

# ============================================================================
# 3. LOAD COMBINED DATA
# ============================================================================
# The combined file includes national, state, and district survey data
# from 1991-2023 (biennial). Each row is one student respondent.

cat("\n============================================\n")
cat("   LOADING YRBS COMBINED DATA\n")
cat("============================================\n\n")

yrbs <- read_dta(raw_dta)
cat(paste0("Loaded: ", nrow(yrbs), " observations, ", ncol(yrbs), " variables\n"))

# ============================================================================
# 4. STANDARDIZE VARIABLE NAMES
# ============================================================================
# Lowercase all column names for consistency.

names(yrbs) <- tolower(names(yrbs))

# ============================================================================
# 5. FIX KNOWN STATE CODE ISSUES
# ============================================================================
# Some state codes have alternate versions:
#   AZB = Arizona (alternate coding)
#   NYA = New York (alternate coding)

yrbs <- yrbs %>%
  mutate(sitecode = case_when(
    sitecode == "AZB" ~ "AZ",
    sitecode == "NYA" ~ "NY",
    TRUE ~ sitecode
  ))

# ============================================================================
# 6. SORT AND SAVE
# ============================================================================

cat("\n============================================\n")
cat("   SAVING WORKING DATASET\n")
cat("============================================\n\n")

yrbs <- yrbs %>% arrange(year, sitetype, sitecode)

saveRDS(yrbs, out_rds)
cat(paste0("Saved: ", out_rds, "\n"))

tryCatch({
  write_dta(yrbs, out_dta)
  cat(paste0("Saved: ", out_dta, "\n"))
}, error = function(e) {
  cat(paste0("Could not save .dta: ", e$message, "\n"))
})

cat(paste0("Observations: ", nrow(yrbs), "\n"))
cat(paste0("Variables: ", ncol(yrbs), "\n"))

# ============================================================================
# 7. VALIDATION CHECKS
# ============================================================================

cat("\n============================================\n")
cat("   VALIDATION CHECKS\n")
cat("============================================\n\n")

# --- 7a. Check year range ---
yr_range <- range(yrbs$year, na.rm = TRUE)
if (yr_range[1] == 1991 & yr_range[2] == 2023) {
  cat(paste0("[PASS] Year range: ", yr_range[1], " to ", yr_range[2], "\n"))
} else {
  cat(paste0("[WARN] Expected 1991-2023, found ", yr_range[1], " to ", yr_range[2], "\n"))
}

# --- 7b. Check biennial pattern ---
survey_years <- sort(unique(yrbs$year))
all_odd <- all(survey_years %% 2 == 1)
if (all_odd) {
  cat("[PASS] All survey years are odd (biennial pattern)\n")
} else {
  even_years <- survey_years[survey_years %% 2 == 0]
  cat(paste0("[WARN] Even years found: ", paste(even_years, collapse = ", "), "\n"))
}

# --- 7c. Check site types ---
cat(paste0("[INFO] Site types: ", paste(unique(yrbs$sitetype), collapse = ", "), "\n"))

# --- 7d. Check total is plausible ---
n_total <- nrow(yrbs)
if (n_total > 1000000 & n_total < 10000000) {
  cat(paste0("[PASS] Total observations (", n_total, ") is plausible\n"))
} else {
  cat(paste0("[WARN] Total observations (", n_total, ") seems unusual\n"))
}

# --- 7e. Check key variables exist ---
key_vars <- c("year", "sitetype", "sitecode", "sitename", "sex", "age",
              "race4", "grade", "weight", "q26", "q27", "q28", "q29", "q30")
present <- key_vars %in% names(yrbs)
if (all(present)) {
  cat("[PASS] All key variables present\n")
} else {
  cat(paste0("[FAIL] Missing: ", paste(key_vars[!present], collapse = ", "), "\n"))
}

# --- 7f. Check weight variable ---
wt_summary <- summary(yrbs$weight[!is.na(yrbs$weight)])
cat(paste0("[INFO] Weight: N=", sum(!is.na(yrbs$weight)),
           ", mean=", round(mean(yrbs$weight, na.rm = TRUE), 4),
           ", min=", round(min(yrbs$weight, na.rm = TRUE), 4),
           ", max=", round(max(yrbs$weight, na.rm = TRUE), 4), "\n"))

# --- 7g. Observations by site type ---
cat("\n--- Observations by site type ---\n")
sitetype_table <- yrbs %>%
  count(sitetype) %>%
  mutate(pct = round(n / sum(n) * 100, 1))
print(as.data.frame(sitetype_table), row.names = FALSE)

# --- 7h. Observations by year ---
cat("\n--- Observations by year ---\n")
year_table <- yrbs %>% count(year)
print(as.data.frame(year_table), row.names = FALSE)

# --- 7i. States in state-level data ---
state_data <- yrbs %>% filter(sitetype == "State")
states <- sort(unique(state_data$sitecode))
cat(paste0("\n[INFO] Number of unique state codes: ", length(states), "\n"))
cat(paste0("[INFO] States: ", paste(states, collapse = ", "), "\n"))

# --- 7j. Key demographics ---
cat("\n--- Sex distribution ---\n")
print(as.data.frame(yrbs %>% count(sex)), row.names = FALSE)

cat("\n--- Age distribution ---\n")
age_labels <- c("1" = "<=12", "2" = "13", "3" = "14", "4" = "15",
                "5" = "16", "6" = "17", "7" = "18+")
age_table <- yrbs %>%
  filter(!is.na(age)) %>%
  count(age) %>%
  mutate(age_label = age_labels[as.character(age)],
         pct = round(n / sum(n) * 100, 1))
print(as.data.frame(age_table), row.names = FALSE)

cat("\n--- Grade distribution ---\n")
grade_labels <- c("1" = "9th", "2" = "10th", "3" = "11th", "4" = "12th")
grade_table <- yrbs %>%
  filter(!is.na(grade)) %>%
  count(grade) %>%
  mutate(grade_label = grade_labels[as.character(grade)],
         pct = round(n / sum(n) * 100, 1))
print(as.data.frame(grade_table), row.names = FALSE)

cat("\n--- Race/ethnicity distribution (race4) ---\n")
race_labels <- c("1" = "White", "2" = "Black", "3" = "Hispanic", "4" = "Other")
race_table <- yrbs %>%
  filter(!is.na(race4)) %>%
  count(race4) %>%
  mutate(race_label = race_labels[as.character(race4)],
         pct = round(n / sum(n) * 100, 1))
print(as.data.frame(race_table), row.names = FALSE)

cat("\n============================================\n")
cat("   VALIDATION COMPLETE\n")
cat("============================================\n")
cat("\nNext step: run 02_clean_and_analyze.R\n")

################################################################################
# NOTES ON THE COMBINED DATASET:
#
# 1. SITE TYPES:
#    - "National" = nationally representative sample (~15,000-17,000 per year)
#    - "State" = state-level representative samples (not all states every year)
#    - "District" = large urban school district samples (optional participation)
#
#    For most analyses, filter by sitetype. Use "National" for nationally
#    representative estimates. Use "State" for state-level analyses.
#
# 2. SURVEY TIMING:
#    Biennial (every 2 years), conducted in odd years: 1991, 1993, ..., 2023.
#    There was NO 2020 survey due to COVID-19.
#
# 3. QUESTION NUMBERS:
#    Variables q1, q2, ..., q99 correspond to questionnaire items.
#    Variables qn1, qn2, ..., qn99 are CDC-computed binary indicators
#    (1 = response of interest, 2 = otherwise).
#    Question numbers can shift across years — always check the questionnaire
#    content document.
#
# 4. STRING VARIABLES:
#    In the .dta file, many q-variables are character strings ("1", "2", etc.)
#    while qn-variables are numeric. The 02_clean script handles both.
#
# 5. WEIGHTS:
#    The `weight` variable provides survey weights. Use with survey design:
#      library(survey)
#      des <- svydesign(ids = ~1, weights = ~weight, data = yrbs)
#
# 6. AGE AND GRADE:
#    age:  1=<=12, 2=13, 3=14, 4=15, 5=16, 6=17, 7=18+
#    grade: 1=9th, 2=10th, 3=11th, 4=12th
#
# 7. DOWNLOADING THE DATA:
#    https://www.cdc.gov/yrbs/data/index.html
#    Select "Combined Datasets" for the national+state+district file.
################################################################################
