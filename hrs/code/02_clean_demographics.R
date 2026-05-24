################################################################################
# 02_clean_demographics.R
#
# Purpose: Load the reshaped RAND HRS long-format dataset, create starter
#          demographic variables, save an analysis-ready file, and optionally
#          run descriptive tables/regression examples.
#
# Input:   output/hrs_long.rds  (from 01_reshape_and_save.R)
# Output:  output/hrs_demographics_clean.rds
#          output/hrs_demographics_clean_from_r.dta (optional)
#
# Usage:   Run from hrs/, hrs/code/, from the repo root, or set
#          hrs_root_manual / HRS_ROOT.
################################################################################

library(haven)
library(dplyr)
library(tidyr)

# ============================================================================
# 1. DEFINE PATHS AND OPTIONS
# ============================================================================

# Optional manual path override. Leave as NULL for auto-detection.
# Example:
# hrs_root_manual <- "/Users/yourname/path/to/econ-data-starters/hrs"
if (!exists("hrs_root_manual", inherits = TRUE)) {
  hrs_root_manual <- NULL
}

get_current_script_dir <- function() {
  command_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", command_args, value = TRUE)
  if (length(file_arg) > 0) {
    script_path <- sub("^--file=", "", file_arg[[1]])
    return(dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE)))
  }

  frame_paths <- vapply(sys.frames(), function(frame) {
    if (!is.null(frame$ofile)) frame$ofile else ""
  }, character(1))
  frame_paths <- frame_paths[nzchar(frame_paths)]
  if (length(frame_paths) > 0) {
    return(dirname(normalizePath(tail(frame_paths, 1), winslash = "/", mustWork = FALSE)))
  }

  ""
}

parent_paths <- function(path) {
  if (!nzchar(path) || !dir.exists(path)) return(character())
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  paths <- path

  repeat {
    parent <- dirname(path)
    if (identical(parent, path)) break
    paths <- c(paths, parent)
    path <- parent
  }

  paths
}

resolve_hrs_root <- function(script_name) {
  env_root <- Sys.getenv("HRS_ROOT", unset = "")

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

  search_roots <- c(getwd(), get_current_script_dir(), rstudio_script_dir)
  search_paths <- unique(unlist(lapply(search_roots, parent_paths), use.names = FALSE))
  candidates <- c(hrs_root_manual, env_root, search_paths, file.path(search_paths, "hrs"))
  candidates <- unique(candidates[!is.na(candidates) & nzchar(candidates)])

  for (path in candidates) {
    path_norm <- normalizePath(path, winslash = "/", mustWork = FALSE)
    if (file.exists(file.path(path_norm, "README.md")) &&
        file.exists(file.path(path_norm, "code", script_name))) {
      return(path_norm)
    }
  }

  stop(
    "Could not locate the hrs/ directory.\n",
    "Run this script from hrs/, hrs/code/, from the repo root, ",
    "or set hrs_root_manual / HRS_ROOT to the hrs path.\n",
    paste0("Current working directory: ", getwd(), "\n"),
    'Manual override in this script: hrs_root_manual <- "/path/to/hrs"\n',
    'Manual override before sourcing: Sys.setenv(HRS_ROOT = "/path/to/hrs")',
    call. = FALSE
  )
}

hrs_root <- resolve_hrs_root("02_clean_demographics.R")
cat(paste0("Using HRS root: ", hrs_root, "\n"))

if (!exists("hrs_input_basename", inherits = TRUE)) {
  hrs_input_basename <- "hrs_long"
}
if (!exists("run_examples", inherits = TRUE)) {
  run_examples <- FALSE
}
if (!exists("write_dta_export", inherits = TRUE)) {
  write_dta_export <- FALSE
}
if (!exists("hrs_input_dir", inherits = TRUE)) {
  hrs_input_dir <- file.path(hrs_root, "output")
}
if (!exists("hrs_output_dir", inherits = TRUE)) {
  hrs_output_dir <- file.path(hrs_root, "output")
}

in_rds <- file.path(hrs_input_dir, paste0(hrs_input_basename, ".rds"))
in_dta <- file.path(hrs_input_dir, paste0(hrs_input_basename, ".dta"))
out_rds <- file.path(hrs_output_dir, "hrs_demographics_clean.rds")
out_dta <- file.path(hrs_output_dir, "hrs_demographics_clean_from_r.dta")
dir.create(hrs_output_dir, showWarnings = FALSE, recursive = TRUE)

# ============================================================================
# 2. LOAD DATA
# ============================================================================

if (file.exists(in_rds)) {
  hrs <- readRDS(in_rds)
  cat(sprintf("Loaded %d person-wave observations from %s.\n", nrow(hrs), in_rds))
} else if (file.exists(in_dta)) {
  hrs <- read_dta(in_dta)
  cat(sprintf("Loaded %d person-wave observations from %s.\n", nrow(hrs), in_dta))
} else {
  stop(
    "Could not find a reshaped HRS file. Run 01_reshape_and_save first.\n",
    "Expected one of:\n", in_rds, "\n", in_dta,
    call. = FALSE
  )
}

names(hrs) <- tolower(names(hrs))

required_vars <- c(
  "hhidpn", "wave", "year", "inw", "ragender", "raeduc", "raracem",
  "rahispan", "rmstat", "hacohort"
)
missing_required <- setdiff(required_vars, names(hrs))
if (length(missing_required) > 0) {
  stop(
    "The reshaped HRS file is missing variables required by this cleaner: ",
    paste(missing_required, collapse = ", "),
    call. = FALSE
  )
}

# ============================================================================
# 3. CLEAN DEMOGRAPHIC VARIABLES
# ============================================================================

cat("Cleaning HRS demographic variables...\n")

hrs <- hrs %>%
  mutate(
    female = case_when(
      ragender == 1 ~ 0L,
      ragender == 2 ~ 1L,
      TRUE ~ NA_integer_
    ),

    educ_cat = case_when(
      raeduc == 1 ~ "Less than HS",
      raeduc %in% c(2, 3) ~ "HS/GED",
      raeduc == 4 ~ "Some college",
      raeduc == 5 ~ "College+",
      TRUE ~ NA_character_
    ),
    educ_cat = factor(
      educ_cat,
      levels = c("Less than HS", "HS/GED", "Some college", "College+")
    ),

    race_eth = case_when(
      rahispan == 1 ~ "Hispanic",
      rahispan == 0 & raracem == 1 ~ "White NH",
      rahispan == 0 & raracem == 2 ~ "Black NH",
      rahispan == 0 & raracem == 3 ~ "Other NH",
      TRUE ~ NA_character_
    ),
    race_eth = factor(
      race_eth,
      levels = c("White NH", "Black NH", "Hispanic", "Other NH")
    ),

    marital = case_when(
      rmstat %in% 1:3 ~ "Married/Partnered",
      rmstat %in% 4:6 ~ "Sep/Divorced",
      rmstat == 7 ~ "Widowed",
      rmstat == 8 ~ "Never married",
      TRUE ~ NA_character_
    ),
    marital = factor(
      marital,
      levels = c("Married/Partnered", "Sep/Divorced", "Widowed", "Never married")
    ),

    cohort_label = case_when(
      hacohort %in% c(0, 1) ~ "AHEAD",
      hacohort == 2 ~ "CODA",
      hacohort == 3 ~ "HRS",
      hacohort == 4 ~ "War Baby",
      hacohort == 5 ~ "Early Boomer",
      hacohort == 6 ~ "Mid Boomer",
      hacohort == 7 ~ "Late Boomer",
      hacohort == 8 ~ "Early Gen X",
      TRUE ~ NA_character_
    ),
    cohort_label = factor(
      cohort_label,
      levels = c("HRS", "AHEAD", "CODA", "War Baby", "Early Boomer",
                 "Mid Boomer", "Late Boomer", "Early Gen X")
    )
  ) %>%
  group_by(hhidpn) %>%
  mutate(total_waves = sum(inw == 1, na.rm = TRUE)) %>%
  ungroup()

cat("Created: female, educ_cat, race_eth, marital, cohort_label, total_waves\n")

# ============================================================================
# 4. SAVE CLEANED DATA
# ============================================================================

saveRDS(hrs, out_rds)
cat(sprintf("Saved: %s\n", out_rds))

if (write_dta_export) {
  tryCatch({
    write_dta(hrs, out_dta)
    cat(sprintf("Saved optional Stata export: %s\n", out_dta))
  }, error = function(e) {
    cat(sprintf("Warning: Could not save .dta file: %s\n", e$message))
  })
} else {
  cat("Skipped optional Stata export. Set write_dta_export <- TRUE to create output/hrs_demographics_clean_from_r.dta.\n")
}

# ============================================================================
# 5. OPTIONAL DESCRIPTIVE TABLES AND REGRESSIONS
# ============================================================================

if (run_examples) {
  cat("\n--- Response rates by wave ---\n")
  response_by_wave <- hrs %>%
    group_by(wave) %>%
    summarise(
      n_total = n(),
      n_interviewed = sum(inw == 1, na.rm = TRUE),
      pct_interviewed = mean(inw == 1, na.rm = TRUE) * 100,
      .groups = "drop"
    )
  print(response_by_wave, n = 16)

  cat("\n--- Distribution of waves responded ---\n")
  waves_per_person <- hrs %>% distinct(hhidpn, total_waves)
  print(table(waves_per_person$total_waves))

  if ("rshlt" %in% names(hrs)) {
    cat("\n--- Missing value patterns for self-rated health (rshlt) ---\n")
    shlt_missing <- hrs %>%
      filter(wave >= 4) %>%
      group_by(wave) %>%
      summarise(
        n_total = n(),
        n_valid = sum(!is.na(rshlt)),
        n_missing = sum(is.na(rshlt)),
        pct_missing = round(mean(is.na(rshlt)) * 100, 1),
        .groups = "drop"
      )
    print(shlt_missing, n = 16)
  }

  interviewed <- hrs %>% filter(inw == 1)

  cat("\n==========================================\n")
  cat("   DESCRIPTIVE STATISTICS (interviewed only)\n")
  cat("==========================================\n")

  key_vars <- intersect(
    c("ragey_b", "female", "rshlt", "rcesd", "rbmi", "rconde",
      "rhosp", "radl5a", "riadl5a", "rmobila", "hitot", "hatotb"),
    names(interviewed)
  )

  if (length(key_vars) > 0) {
    summary_stats <- interviewed %>%
      summarise(across(
        all_of(key_vars),
        list(
          n = ~ sum(!is.na(.)),
          mean = ~ mean(., na.rm = TRUE),
          sd = ~ sd(., na.rm = TRUE),
          min = ~ suppressWarnings(min(., na.rm = TRUE)),
          max = ~ suppressWarnings(max(., na.rm = TRUE))
        ),
        .names = "{.col}__{.fn}"
      )) %>%
      pivot_longer(everything(), names_to = c("variable", "stat"), names_sep = "__") %>%
      pivot_wider(names_from = stat, values_from = value)
    print(summary_stats, n = 20)
  }

  if ("rshlt" %in% names(interviewed)) {
    cat("\n--- Self-rated health by wave ---\n")
    shlt_by_wave <- interviewed %>%
      group_by(wave, year) %>%
      summarise(
        n = sum(!is.na(rshlt)),
        mean_shlt = round(mean(rshlt, na.rm = TRUE), 2),
        sd_shlt = round(sd(rshlt, na.rm = TRUE), 2),
        .groups = "drop"
      )
    print(shlt_by_wave, n = 16)
  }

  cat("\n--- Cohort distribution in Wave 16 (2022) ---\n")
  interviewed %>%
    filter(wave == 16) %>%
    count(cohort_label) %>%
    mutate(pct = round(n / sum(n) * 100, 1)) %>%
    print()

  if (all(c("rshlt", "ragey_b", "female", "educ_cat", "race_eth", "rwtresp") %in% names(interviewed))) {
    if (!requireNamespace("broom", quietly = TRUE)) {
      stop("Install the broom package or set run_examples <- FALSE.", call. = FALSE)
    }

    cat("\n==========================================\n")
    cat("   SIMPLE REGRESSION EXAMPLE\n")
    cat("==========================================\n")

    ols_model <- lm(rshlt ~ ragey_b + female + educ_cat + race_eth,
                    data = interviewed)
    print(summary(ols_model))

    cat("\n--- Tidy coefficient table ---\n")
    print(broom::tidy(ols_model, conf.int = TRUE) %>%
            mutate(across(where(is.numeric), ~ round(., 4))))

    cat("\n--- Weighted OLS: Self-rated health on demographics ---\n")
    wols_model <- lm(rshlt ~ ragey_b + female + educ_cat + race_eth,
                     data = interviewed,
                     weights = rwtresp)
    print(broom::tidy(wols_model, conf.int = TRUE) %>%
            mutate(across(where(is.numeric), ~ round(., 4))))
  } else {
    cat("\nSkipping regression example because one or more example variables are missing.\n")
  }
} else {
  cat("Example tables and regressions are off by default. Set run_examples <- TRUE near the top of this script to run them.\n")
}

cat("\nStarter HRS cleaning complete.\n")
