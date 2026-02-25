################################################################################
# 02_clean_and_analyze.R
#
# Purpose: Clean and create analysis-ready variables from the YRBS combined
#          dataset. Covers demographics, mental health outcomes, substance
#          use, and other health behaviors. Includes descriptive statistics
#          and example regressions.
#
# Input:   output/yrbs_combined.rds  (from 01_load_and_prepare.R)
# Output:  output/yrbs_clean.rds
#          output/yrbs_clean.dta
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

yrbs_root <- "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/yrbs"

in_rds  <- file.path(yrbs_root, "output", "yrbs_combined.rds")
out_rds <- file.path(yrbs_root, "output", "yrbs_clean.rds")
out_dta <- file.path(yrbs_root, "output", "yrbs_clean.dta")

# ============================================================================
# 2. LOAD DATA
# ============================================================================

cat("Loading YRBS combined data...\n")
yrbs <- readRDS(in_rds)
names(yrbs) <- tolower(names(yrbs))
cat(paste0("Loaded: ", nrow(yrbs), " observations, ", ncol(yrbs), " variables\n"))

# ============================================================================
# 3. DEMOGRAPHICS
# ============================================================================
# YRBS coding:
#   sex:   1 = Female, 2 = Male
#   age:   1 = <=12, 2 = 13, 3 = 14, 4 = 15, 5 = 16, 6 = 17, 7 = 18+
#   grade: 1 = 9th, 2 = 10th, 3 = 11th, 4 = 12th
#   race4: 1 = White, 2 = Black, 3 = Hispanic, 4 = Other

cat("\nCleaning demographics...\n")

yrbs <- yrbs %>%
  mutate(
    # Sex
    female = case_when(
      sex == 1 ~ 1L,
      sex == 2 ~ 0L,
      TRUE ~ NA_integer_
    ),

    # Age dummies
    age12 = as.integer(age == 1),
    age13 = as.integer(age == 2),
    age14 = as.integer(age == 3),
    age15 = as.integer(age == 4),
    age16 = as.integer(age == 5),
    age17 = as.integer(age == 6),
    age18 = as.integer(age == 7),

    # Age in years (approximate)
    age_years = case_when(
      age == 1 ~ 12L, age == 2 ~ 13L, age == 3 ~ 14L, age == 4 ~ 15L,
      age == 5 ~ 16L, age == 6 ~ 17L, age == 7 ~ 18L,
      TRUE ~ NA_integer_
    ),

    # Race/ethnicity dummies
    white    = as.integer(race4 == 1),
    black    = as.integer(race4 == 2),
    hispanic = as.integer(race4 == 3),
    otherrace = as.integer(race4 == 4),

    # Grade dummies
    grade9  = as.integer(grade == 1),
    grade10 = as.integer(grade == 2),
    grade11 = as.integer(grade == 3),
    grade12 = as.integer(grade == 4)
  )

# Set dummies to NA where source variable is NA
for (v in c("age12", "age13", "age14", "age15", "age16", "age17", "age18", "age_years")) {
  yrbs[[v]][is.na(yrbs$age)] <- NA
}
for (v in c("white", "black", "hispanic", "otherrace")) {
  yrbs[[v]][is.na(yrbs$race4)] <- NA
}
for (v in c("grade9", "grade10", "grade11", "grade12")) {
  yrbs[[v]][is.na(yrbs$grade)] <- NA
}

# ============================================================================
# 4. MENTAL HEALTH OUTCOMES
# ============================================================================
# Question variables (q26-q30) are character/string in the combined file.
# Values: "1", "2", "3", etc. map to response options A, B, C, etc.
#
# Q26: Felt sad/hopeless (1=Yes, 2=No) — available 1999-2023
# Q27: Considered suicide (1=Yes, 2=No) — available 1991-2023
# Q28: Made suicide plan (1=Yes, 2=No) — available 1991-2023
# Q29: Attempted suicide (1=0 times, 2=1 time, 3=2-3, 4=4-5, 5=6+)
# Q30: Injury from attempt (1=Did not attempt, 2=Yes, 3=No)

cat("Creating mental health outcomes...\n")

yrbs <- yrbs %>%
  mutate(
    # Q26: Felt sad or hopeless
    felt_sad = case_when(
      q26 == "1" ~ 1L,
      q26 == "2" ~ 0L,
      TRUE ~ NA_integer_
    ),

    # Q27: Considered suicide
    considered_suicide = case_when(
      q27 == "1" ~ 1L,
      q27 == "2" ~ 0L,
      TRUE ~ NA_integer_
    ),

    # Q28: Made suicide plan
    made_suicide_plan = case_when(
      q28 == "1" ~ 1L,
      q28 == "2" ~ 0L,
      TRUE ~ NA_integer_
    ),

    # Q29: Attempted suicide (binary: any attempt vs. none)
    attempted_suicide = case_when(
      q29 == "1" ~ 0L,                           # 0 times
      q29 %in% c("2", "3", "4", "5") ~ 1L,       # 1+ times
      TRUE ~ NA_integer_
    ),

    # Q30: Injury from suicide attempt (among attempters only)
    injury_suicide_attempt = case_when(
      q30 == "2" ~ 1L,   # Yes, injury
      q30 == "3" ~ 0L,   # No injury
      TRUE ~ NA_integer_  # "1" = did not attempt → not in denominator
    )
  )

# ============================================================================
# 5. SUBSTANCE USE
# ============================================================================
# Q33: Cigarette smoking (past 30 days): 1=0 days, 2-7=1+ days
# Q42: Alcohol use (past 30 days): 1=0 days, 2-7=1+ days
# Q48: Marijuana use (past 30 days): 1=0 times, 2-6=1+ times

cat("Creating substance use outcomes...\n")

yrbs <- yrbs %>%
  mutate(
    current_cigarettes = case_when(
      q33 == "1" ~ 0L,
      q33 %in% c("2", "3", "4", "5", "6", "7") ~ 1L,
      TRUE ~ NA_integer_
    ),

    current_alcohol = case_when(
      q42 == "1" ~ 0L,
      q42 %in% c("2", "3", "4", "5", "6", "7") ~ 1L,
      TRUE ~ NA_integer_
    ),

    current_marijuana = case_when(
      q48 == "1" ~ 0L,
      q48 %in% c("2", "3", "4", "5", "6") ~ 1L,
      TRUE ~ NA_integer_
    )
  )

# ============================================================================
# 6. ADDITIONAL HEALTH BEHAVIORS
# ============================================================================
# Q14: Missed school due to feeling unsafe (past 30 days)
# "1" = 0 days, "2"-"6" = 1+ days

cat("Creating additional health behavior outcomes...\n")

yrbs <- yrbs %>%
  mutate(
    unsafe_at_school = case_when(
      q14 == "1" ~ 0L,
      q14 %in% c("2", "3", "4", "5", "6") ~ 1L,
      TRUE ~ NA_integer_
    )
  )

# ============================================================================
# 7. CDC QN-PREFIX CROSS-VALIDATION
# ============================================================================
# The CDC provides pre-computed binary indicators (qn26, qn27, etc.)
# coded as: 1 = response of interest, 2 = otherwise.
# We cross-check our hand-coded variables against these.

cat("\nCross-validating against CDC QN variables...\n")

qn_mapping <- list(
  felt_sad           = "qn26",
  considered_suicide = "qn27",
  made_suicide_plan  = "qn28"
)

for (our_var in names(qn_mapping)) {
  qn_var <- qn_mapping[[our_var]]

  if (!(qn_var %in% names(yrbs))) {
    cat(paste0("  ", our_var, ": QN variable '", qn_var, "' not found\n"))
    next
  }

  # Recode QN: 1 → 1, 2 → 0, else NA
  qn_recoded <- case_when(
    yrbs[[qn_var]] == 1 ~ 1L,
    yrbs[[qn_var]] == 2 ~ 0L,
    TRUE ~ NA_integer_
  )

  both_valid <- !is.na(yrbs[[our_var]]) & !is.na(qn_recoded)
  n_compare  <- sum(both_valid)
  n_match    <- sum(yrbs[[our_var]][both_valid] == qn_recoded[both_valid])
  n_mismatch <- n_compare - n_match
  match_pct  <- ifelse(n_compare > 0, round(100 * n_match / n_compare, 4), NA)

  cat(sprintf("  %-25s  Compared: %s  Match: %.4f%%  Mismatch: %d\n",
              our_var, format(n_compare, big.mark = ","), match_pct, n_mismatch))
}

# ============================================================================
# 8. SAVE CLEANED DATASET
# ============================================================================

cat("\nSaving cleaned dataset...\n")
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
# 9. DESCRIPTIVE STATISTICS
# ============================================================================

cat("\n============================================\n")
cat("   DESCRIPTIVE STATISTICS\n")
cat("============================================\n\n")

# --- 9a. Sample sizes by year ---
cat("--- Sample sizes by year ---\n")
print(as.data.frame(yrbs %>% count(year)), row.names = FALSE)

# --- 9b. Sample sizes by site type ---
cat("\n--- Sample sizes by site type ---\n")
print(as.data.frame(yrbs %>% count(sitetype)), row.names = FALSE)

# --- 9c. Demographics ---
cat("\n--- Demographics ---\n")
demo_vars <- c("female", "age_years", "white", "black", "hispanic", "otherrace")
demo_stats <- yrbs %>%
  summarize(across(all_of(demo_vars),
                   list(n = ~sum(!is.na(.)),
                        mean = ~round(mean(., na.rm = TRUE), 3),
                        sd = ~round(sd(., na.rm = TRUE), 3)),
                   .names = "{.col}__{.fn}"))
# Reshape for display
for (v in demo_vars) {
  cat(sprintf("  %-12s  N=%s  Mean=%.3f  SD=%.3f\n",
              v,
              format(demo_stats[[paste0(v, "__n")]], big.mark = ","),
              demo_stats[[paste0(v, "__mean")]],
              demo_stats[[paste0(v, "__sd")]]))
}

# --- 9d. Mental health outcomes ---
cat("\n--- Mental health outcomes ---\n")
mh_vars <- c("felt_sad", "considered_suicide", "made_suicide_plan",
             "attempted_suicide", "injury_suicide_attempt")
for (v in mh_vars) {
  n_valid <- sum(!is.na(yrbs[[v]]))
  mean_val <- round(mean(yrbs[[v]], na.rm = TRUE), 4)
  cat(sprintf("  %-25s  N=%s  Mean=%.4f\n",
              v, format(n_valid, big.mark = ","), mean_val))
}

# --- 9e. Substance use ---
cat("\n--- Substance use outcomes ---\n")
sub_vars <- c("current_cigarettes", "current_alcohol", "current_marijuana")
for (v in sub_vars) {
  n_valid <- sum(!is.na(yrbs[[v]]))
  mean_val <- round(mean(yrbs[[v]], na.rm = TRUE), 4)
  cat(sprintf("  %-25s  N=%s  Mean=%.4f\n",
              v, format(n_valid, big.mark = ","), mean_val))
}

# --- 9f. Mental health trends over time (national data) ---
cat("\n--- Mental health trends (national data) ---\n")
national <- yrbs %>% filter(sitetype == "National")
trends <- national %>%
  group_by(year) %>%
  summarize(
    n = n(),
    felt_sad = round(mean(felt_sad, na.rm = TRUE), 3),
    considered_suicide = round(mean(considered_suicide, na.rm = TRUE), 3),
    attempted_suicide = round(mean(attempted_suicide, na.rm = TRUE), 3),
    .groups = "drop"
  )
print(as.data.frame(trends), row.names = FALSE)

# --- 9g. Mental health by sex (national data) ---
cat("\n--- Mental health by sex (national data) ---\n")
by_sex <- national %>%
  filter(!is.na(female)) %>%
  group_by(female) %>%
  summarize(
    n = n(),
    felt_sad = round(mean(felt_sad, na.rm = TRUE), 3),
    considered_suicide = round(mean(considered_suicide, na.rm = TRUE), 3),
    attempted_suicide = round(mean(attempted_suicide, na.rm = TRUE), 3),
    .groups = "drop"
  ) %>%
  mutate(sex_label = ifelse(female == 1, "Female", "Male"))
print(as.data.frame(by_sex), row.names = FALSE)

# --- 9h. State participation ---
cat("\n--- State-level data: unique states ---\n")
state_data <- yrbs %>% filter(sitetype == "State")
states <- sort(unique(state_data$sitecode))
cat(paste0("  Number of unique state codes: ", length(states), "\n"))
cat(paste0("  States: ", paste(states, collapse = ", "), "\n"))

# ============================================================================
# 10. EXAMPLE REGRESSIONS
# ============================================================================

cat("\n============================================\n")
cat("   EXAMPLE REGRESSIONS\n")
cat("============================================\n\n")

# --- 10a. OLS: Considered suicide ~ demographics (national, unweighted) ---
cat("--- OLS: Considered suicide ~ demographics (national, unweighted) ---\n")
ols <- lm(considered_suicide ~ female + age_years + black + hispanic + otherrace
           + factor(year),
           data = national)
print(tidy(ols) %>% head(10))
cat("  (showing first 10 coefficients)\n")

# --- 10b. Weighted OLS (national) ---
cat("\n--- Weighted OLS: Considered suicide ~ demographics (national) ---\n")
wols <- lm(considered_suicide ~ female + age_years + black + hispanic + otherrace
            + factor(year),
            data = national,
            weights = weight)
print(tidy(wols) %>% head(10))

# --- 10c. Weighted OLS: Felt sad (1999+ only) ---
cat("\n--- Weighted OLS: Felt sad ~ demographics (national, 1999+) ---\n")
wols_sad <- lm(felt_sad ~ female + age_years + black + hispanic + otherrace
               + factor(year),
               data = national %>% filter(year >= 1999),
               weights = weight)
print(tidy(wols_sad) %>% head(10))

cat("\n============================================\n")
cat("   DONE\n")
cat("============================================\n")

################################################################################
# NOTES:
#
# 1. For proper survey-weighted analysis with complex sampling:
#      library(survey)
#      des <- svydesign(ids = ~1, weights = ~weight, data = yrbs)
#      svyglm(considered_suicide ~ female + age_years + black + hispanic,
#             design = des, family = quasibinomial())
#
# 2. For state-level analyses (e.g., difference-in-differences):
#      state_data <- yrbs %>% filter(sitetype == "State")
#      # Note: not all states participate every year (unbalanced panel)
#
# 3. QUESTION NUMBERS can shift across survey years. Always verify using
#    the questionnaire content document in docs/.
#
# 4. The 2021 survey was the first post-COVID administration. Be cautious
#    comparing 2019 and 2021+ data.
#
# 5. CITATION:
#    Centers for Disease Control and Prevention (CDC). Youth Risk Behavior
#    Surveillance System (YRBSS). https://www.cdc.gov/yrbs/
################################################################################
