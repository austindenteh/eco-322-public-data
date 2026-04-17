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
#          output/yrbs_clean_from_r.dta  (optional R export for Stata users)
#
# Usage:   Run from yrbs/, yrbs/code/, from the repo root, or set YRBS_ROOT.
#
# Author:  Austin Denteh (legacy code and Claude Code)
# Date:    February 2026
################################################################################

library(haven)
library(dplyr)
library(broom)

resolve_yrbs_root <- function(script_name) {
  env_root <- Sys.getenv("YRBS_ROOT", unset = "")

  parent_paths <- function(path) {
    if (!nzchar(path) || !dir.exists(path)) {
      return(character())
    }

    path <- normalizePath(path, winslash = "/", mustWork = TRUE)
    paths <- path

    repeat {
      parent <- dirname(path)
      if (identical(parent, path)) {
        break
      }
      paths <- c(paths, parent)
      path <- parent
    }

    paths
  }

  rstudio_script_dir <- ""
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    rstudio_script <- tryCatch(
      rstudioapi::getSourceEditorContext()$path,
      error = function(e) ""
    )
    if (nzchar(rstudio_script)) {
      rstudio_script_dir <- dirname(rstudio_script)
    }
  }

  search_paths <- unique(unlist(lapply(c(getwd(), rstudio_script_dir), parent_paths), use.names = FALSE))
  candidates <- c(env_root, search_paths, file.path(search_paths, "yrbs"))
  candidates <- unique(candidates[nzchar(candidates)])

  for (path in candidates) {
    if (dir.exists(path) &&
        file.exists(file.path(path, "README.md")) &&
        file.exists(file.path(path, "code", script_name))) {
      return(normalizePath(path, winslash = "/", mustWork = TRUE))
    }
  }

  stop(
    paste(
      "Could not locate the yrbs/ directory.",
      "Run this script from yrbs/, yrbs/code/, from the repo root,",
      "or set YRBS_ROOT to the yrbs path.",
      paste0("Current working directory: ", getwd()),
      'Manual override: Sys.setenv(YRBS_ROOT = "/path/to/yrbs")'
    )
  )
}

# ============================================================================
# 1. DEFINE PATHS
# ============================================================================
# Auto-detect the dataset root from the current working directory.
#
# Optional manual override if auto-detection fails:
# Sys.setenv(YRBS_ROOT = "/path/to/yrbs")

yrbs_root <- resolve_yrbs_root("02_clean_and_analyze.R")
cat(paste0("Using YRBS root: ", yrbs_root, "\n"))

in_rds  <- file.path(yrbs_root, "output", "yrbs_combined.rds")
out_rds <- file.path(yrbs_root, "output", "yrbs_clean.rds")
out_dta <- file.path(yrbs_root, "output", "yrbs_clean_from_r.dta")

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
# The combined CDC file keeps stable q-variable names for many concepts, but
# actual questionnaire numbering shifts across years. We therefore impose the
# documented availability windows when creating starter variables.
#
# Q26: Felt sad/hopeless (1=Yes, 2=No) — code only for 1999-2023
# Q27: Considered suicide (1=Yes, 2=No) — available 1991-2023
# Q28: Made suicide plan (1=Yes, 2=No) — available 1991-2023
# Q29: Attempted suicide (1=0 times, 2=1 time, 3=2-3, 4=4-5, 5=6+)
# Q30: Injury from attempt (1=Did not attempt, 2=Yes, 3=No)

cat("Creating mental health outcomes...\n")

yrbs <- yrbs %>%
  mutate(
    # Q26: Felt sad or hopeless
    felt_sad = case_when(
      year < 1999 ~ NA_integer_,
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
# Q14: Missed school due to feeling unsafe (past 30 days), coded for 1993-2023
# "1" = 0 days, "2"-"6" = 1+ days

cat("Creating additional health behavior outcomes...\n")

yrbs <- yrbs %>%
  mutate(
    unsafe_at_school = case_when(
      year < 1993 ~ NA_integer_,
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
  unsafe_at_school   = "qn14",
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

# --- 9f. Mental health trends over time (state sample) ---
cat("\n--- Mental health trends (state sample) ---\n")
state_data <- yrbs %>% filter(sitetype == "State")
analysis_sample <- state_data
if (nrow(analysis_sample) == 0) {
  cat("  [WARN] No State rows are loaded; using all loaded rows for examples.\n")
  analysis_sample <- yrbs
}

trends <- analysis_sample %>%
  group_by(year) %>%
  summarize(
    n = n(),
    felt_sad = round(mean(felt_sad, na.rm = TRUE), 3),
    considered_suicide = round(mean(considered_suicide, na.rm = TRUE), 3),
    attempted_suicide = round(mean(attempted_suicide, na.rm = TRUE), 3),
    .groups = "drop"
  )
print(as.data.frame(trends), row.names = FALSE)

# --- 9g. Mental health by sex (state sample) ---
cat("\n--- Mental health by sex (state sample) ---\n")
by_sex <- analysis_sample %>%
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
states <- sort(unique(state_data$sitecode))
cat(paste0("  Number of unique state codes: ", length(states), "\n"))
cat(paste0("  States: ", paste(states, collapse = ", "), "\n"))

# ============================================================================
# 10. EXAMPLE REGRESSIONS
# ============================================================================

cat("\n============================================\n")
cat("   EXAMPLE REGRESSIONS\n")
cat("============================================\n\n")

run_example_lm <- function(data, outcome, label, use_weights = FALSE,
                           include_state_fe = FALSE) {
  cat(paste0(label, "\n"))

  needed <- c(outcome, "female", "age_years", "black", "hispanic", "otherrace")
  if (use_weights) {
    needed <- c(needed, "weight")
  }
  if (include_state_fe) {
    needed <- c(needed, "sitecode")
  }

  model_data <- data %>%
    filter(if_all(all_of(needed), ~ !is.na(.)))

  if (nrow(model_data) == 0 || length(unique(model_data[[outcome]])) < 2) {
    cat("  [SKIP] Not enough nonmissing variation for this example model.\n")
    return(invisible(NULL))
  }

  rhs <- "female + age_years + black + hispanic + otherrace"
  if (n_distinct(model_data$year) > 1) {
    rhs <- paste(rhs, "+ factor(year)")
  } else {
    cat("  [INFO] Only one year is loaded, so year fixed effects are omitted.\n")
  }
  if (include_state_fe && n_distinct(model_data$sitecode) > 1) {
    rhs <- paste(rhs, "+ factor(sitecode)")
  } else if (include_state_fe) {
    cat("  [INFO] Only one state/site code is loaded, so state fixed effects are omitted.\n")
  }

  formula <- as.formula(paste(outcome, "~", rhs))
  if (use_weights) {
    model <- lm(formula, data = model_data, weights = weight)
  } else {
    model <- lm(formula, data = model_data)
  }

  print(tidy(model) %>% head(10))
  cat("  (showing first 10 coefficients)\n")
}

# --- 10a. OLS: Considered suicide ~ demographics (state sample, unweighted) ---
run_example_lm(
  analysis_sample,
  outcome = "considered_suicide",
  label = "--- OLS: Considered suicide ~ demographics (state sample, unweighted) ---",
  use_weights = FALSE
)

# --- 10b. Weighted OLS (state sample) ---
run_example_lm(
  analysis_sample,
  outcome = "considered_suicide",
  label = "\n--- Weighted OLS: Considered suicide ~ demographics (state sample) ---",
  use_weights = TRUE
)

# --- 10c. Weighted OLS: Felt sad (1999+ only) ---
run_example_lm(
  analysis_sample %>% filter(year >= 1999),
  outcome = "felt_sad",
  label = "\n--- Weighted OLS: Felt sad ~ demographics (state sample, 1999+) ---",
  use_weights = TRUE
)

# --- 10d. Weighted OLS with state fixed effects ---
run_example_lm(
  analysis_sample,
  outcome = "considered_suicide",
  label = "\n--- Weighted OLS: Considered suicide ~ demographics + state FE ---",
  use_weights = TRUE,
  include_state_fe = TRUE
)

cat("\n============================================\n")
cat("   DONE\n")
cat("============================================\n")

################################################################################
# NOTES:
#
# 1. The starter regressions use simple analytic weights:
#      lm(considered_suicide ~ female + age_years + black + hispanic,
#         data = yrbs, weights = weight)
#    For design-based inference with the survey package, you can still use:
#      library(survey)
#      des <- svydesign(ids = ~1, weights = ~weight, data = yrbs)
#      svyglm(considered_suicide ~ female + age_years + black + hispanic,
#             design = des, family = quasibinomial())
#
# 2. The default 01_load script saves State rows because the public-use
#    National sample does not include state identifiers. If you broaden the
#    loader to keep National or District rows, keep site types separate unless
#    your research design explicitly justifies combining them.
#
# 3. The combined CDC file uses stable q-variable names for many concepts, but
#    the questionnaire's printed question numbers shift across years. We code
#    felt_sad for 1999+ and unsafe_at_school for 1993+ to match the documented
#    availability windows. Always verify new variables in docs/.
#
# 4. The 2021 survey was the first post-COVID administration. Be cautious
#    comparing 2019 and 2021+ data.
#
# 5. CITATION:
#    Centers for Disease Control and Prevention (CDC). Youth Risk Behavior
#    Surveillance System (YRBSS). https://www.cdc.gov/yrbs/
################################################################################
