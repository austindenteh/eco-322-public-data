################################################################################
# 02_clean_demographics.R
#
# Purpose: Load the ACS working dataset and demonstrate cleaning of:
#          (1) Demographics: race/ethnicity, sex, age, marital status
#          (2) Education: years of education, degree indicators
#          (3) Employment and income
#          (4) Health insurance (if available; 2008+ only)
#          (5) Immigration and citizenship (if available)
#          (6) Optional descriptive statistics and simple weighted regressions
#
# Input:   [acs_root]/output/acs_working.rds  (from 01_load_and_subset.R)
# Output:  Cleaned variables in memory; optional example output to console
#
# Usage:   Run from ipums_acs_1_year_sample/, ipums_acs_1_year_sample/code/,
#          or the repo root:
#            source("code/02_clean_demographics.R")
#          You can also set Sys.setenv(ACS_ROOT = "/path/to/ipums_acs_1_year_sample")
#
# Required packages: haven, dplyr
#   Install with: install.packages(c("haven", "dplyr"))
#
# Notes:   This is a STARTER script. It demonstrates how to clean key
#          variables. Users should extend this for their own analysis.
#          Health insurance and immigration are optional sections.
#          Core sections are skipped if their source variables are absent.
#
# Author:  Austin Denteh (adapted from Kuka et al. 2020 replication code)
# Date:    February 2026
################################################################################

library(haven)
library(dplyr)

# ============================================================================
# 1. DEFINE PATHS AND LOAD DATA
# ============================================================================
# Auto-detect the dataset root from ACS_ROOT, the dataset folder, the code/
# folder, or the repo root.
#
# Optional manual override if auto-detection fails:
# Sys.setenv(ACS_ROOT = "/path/to/ipums_acs_1_year_sample")

resolve_acs_root <- function() {
  env_root <- Sys.getenv("ACS_ROOT", unset = "")

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
  candidates <- c(
    if (nzchar(env_root)) env_root,
    search_paths,
    file.path(search_paths, "ipums_acs_1_year_sample")
  )
  candidates <- unique(candidates[nzchar(candidates)])

  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "code", "02_clean_demographics.R")) &&
        file.exists(file.path(candidate, "README.md"))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }

  stop(
    "Could not locate the ipums_acs_1_year_sample/ directory.\n",
    "Run this script from ipums_acs_1_year_sample/, ipums_acs_1_year_sample/code/, ",
    "or the repo root, or set ACS_ROOT first.\n",
    "Current working directory: ", getwd(), "\n",
    'Manual override: Sys.setenv(ACS_ROOT = "/path/to/ipums_acs_1_year_sample")'
  )
}

coerce_labelled_numeric <- function(data, vars) {
  for (var_name in intersect(vars, names(data))) {
    if (inherits(data[[var_name]], "haven_labelled")) {
      data[[var_name]] <- as.numeric(haven::zap_labels(data[[var_name]]))
    }
  }
  data
}

has_vars <- function(data, vars) {
  all(vars %in% names(data))
}

existing_vars <- function(data, vars) {
  vars[vars %in% names(data)]
}

print_summary_if_present <- function(data, vars, title) {
  vars <- existing_vars(data, vars)
  if (length(vars) == 0) {
    cat(sprintf("\n[SKIP] %s: required variables not available.\n", title))
    return(invisible(NULL))
  }
  cat(sprintf("\n--- %s ---\n", title))
  print(summary(data[vars]))
}

build_weighted_formula <- function(data, outcome) {
  terms <- c("female", "age")
  filter_vars <- c(outcome, "female", "age", "perwt")

  if ("race_eth" %in% names(data) && dplyr::n_distinct(stats::na.omit(data$race_eth)) > 1) {
    terms <- c(terms, "factor(race_eth)")
    filter_vars <- c(filter_vars, "race_eth")
  }
  if ("hs" %in% names(data) && dplyr::n_distinct(stats::na.omit(data$hs)) > 1) {
    terms <- c(terms, "hs")
    filter_vars <- c(filter_vars, "hs")
  }
  if ("college" %in% names(data) && dplyr::n_distinct(stats::na.omit(data$college)) > 1) {
    terms <- c(terms, "college")
    filter_vars <- c(filter_vars, "college")
  }
  if ("year" %in% names(data) && dplyr::n_distinct(stats::na.omit(data$year)) > 1) {
    terms <- c(terms, "factor(year)")
    filter_vars <- c(filter_vars, "year")
  }

  list(
    formula = stats::as.formula(paste(outcome, "~", paste(terms, collapse = " + "))),
    filter_vars = unique(filter_vars)
  )
}

acs_root <- resolve_acs_root()
cat("Using ACS root:", acs_root, "\n")

acs <- readRDS(file.path(acs_root, "output", "acs_working.rds"))
acs <- coerce_labelled_numeric(
  acs,
  c(
    "year", "sample", "perwt", "age", "sex", "race", "hispan", "marst",
    "educ", "educd", "empstat", "poverty", "incwage", "hcovany",
    "hcovpriv", "hcovpub", "hinscaid", "hinscare", "citizen", "bpl"
  )
)
cat(sprintf("Loaded %s observations.\n", format(nrow(acs), big.mark = ",")))

# --- Quick check: common starter variables ---
core_vars <- c("year", "age", "sex", "race", "hispan", "empstat", "incwage", "poverty")
missing_core <- core_vars[!core_vars %in% names(acs)]
if (!("educd" %in% names(acs) || "educ" %in% names(acs))) {
  missing_core <- c(missing_core, "educd/educ")
}
if (length(missing_core) > 0) {
  warning(
    "The following common starter variables are not in your extract: ",
    paste(missing_core, collapse = ", "),
    "\nAffected sections will be skipped."
  )
}

# ============================================================================
# 2. DEMOGRAPHICS: RACE AND ETHNICITY
# ============================================================================
# Create mutually exclusive race/ethnicity categories.
# Hispanic ethnicity takes precedence over race.

if (has_vars(acs, c("race", "hispan"))) {
  acs <- acs %>%
    mutate(
      hisp  = if_else(is.na(hispan), NA_integer_, as.integer(hispan != 0)),
      white = if_else(is.na(race) | is.na(hisp), NA_integer_,
                      as.integer(race == 1 & hisp == 0)),
      black = if_else(is.na(race) | is.na(hisp), NA_integer_,
                      as.integer(race == 2 & hisp == 0)),
      asian = if_else(is.na(race) | is.na(hisp), NA_integer_,
                      as.integer(race %in% c(4, 5, 6) & hisp == 0)),
      other = if_else(
        is.na(hisp) | is.na(white) | is.na(black) | is.na(asian),
        NA_integer_,
        as.integer(hisp == 0 & white == 0 & black == 0 & asian == 0)
      ),
      race_eth = case_when(
        white == 1 ~ "White NH",
        black == 1 ~ "Black NH",
        hisp == 1  ~ "Hispanic",
        asian == 1 ~ "Asian/PI NH",
        other == 1 ~ "Other NH",
        TRUE       ~ NA_character_
      )
    )

  cat("\n--- Race/ethnicity ---\n")
  race_tab <- acs %>%
    count(race_eth, sort = FALSE) %>%
    mutate(pct = round(n / sum(n, na.rm = TRUE) * 100, 1))
  print(as.data.frame(race_tab), row.names = FALSE)
} else {
  cat("\n[SKIP] Race/ethnicity: requires race and hispan.\n")
}

# ============================================================================
# 3. DEMOGRAPHICS: SEX, AGE, MARITAL STATUS
# ============================================================================

if (has_vars(acs, c("sex", "age"))) {
  acs <- acs %>%
    mutate(
      female    = if_else(is.na(sex), NA_integer_, as.integer(sex == 2)),
      age_18_24 = if_else(is.na(age), NA_integer_, as.integer(age >= 18 & age <= 24)),
      age_25_34 = if_else(is.na(age), NA_integer_, as.integer(age >= 25 & age <= 34)),
      age_35_44 = if_else(is.na(age), NA_integer_, as.integer(age >= 35 & age <= 44)),
      age_45_54 = if_else(is.na(age), NA_integer_, as.integer(age >= 45 & age <= 54)),
      age_55_64 = if_else(is.na(age), NA_integer_, as.integer(age >= 55 & age <= 64)),
      age_65plus = if_else(is.na(age), NA_integer_, as.integer(age >= 65))
    )

  if ("marst" %in% names(acs)) {
    acs <- acs %>%
      mutate(married = if_else(is.na(marst), NA_integer_, as.integer(marst %in% c(1, 2))))
  }

  cat("\n--- Age distribution ---\n")
  print(summary(acs$age))

  cat("\n--- Sex ---\n")
  print(table(Female = acs$female, useNA = "ifany"))
} else {
  cat("\n[SKIP] Sex/age: requires sex and age.\n")
}

# ============================================================================
# 4. EDUCATION
# ============================================================================
# Use the detailed EDUCd codes when available. Grouped lower-schooling
# categories are mapped to rounded midpoint years. If only EDUC is available,
# fall back to the coarser general version.

if ("educd" %in% names(acs)) {
  acs <- acs %>%
    mutate(
      yrsed = case_when(
        educd %in% c(0, 2) ~ 0,
        educd == 1 ~ NA_real_,
        educd == 10 ~ 2,
        educd %in% c(11, 12) ~ 0,
        educd == 13 ~ 3,
        educd == 14 ~ 1,
        educd == 15 ~ 2,
        educd == 16 ~ 3,
        educd == 17 ~ 4,
        educd == 20 ~ 7,
        educd == 21 ~ 6,
        educd == 22 ~ 5,
        educd == 23 ~ 6,
        educd == 24 ~ 8,
        educd == 25 ~ 7,
        educd == 26 ~ 8,
        educd == 30 ~ 9,
        educd == 40 ~ 10,
        educd == 50 ~ 11,
        educd %in% c(60, 61, 62, 63, 64) ~ 12,
        educd %in% c(65, 70, 71) ~ 13,
        educd %in% c(80, 81, 82, 83) ~ 14,
        educd == 90 ~ 15,
        educd %in% c(100, 101) ~ 16,
        educd == 110 ~ 17,
        educd %in% c(111, 114) ~ 18,
        educd %in% c(112, 115) ~ 19,
        educd == 113 ~ 20,
        educd == 116 ~ 21,
        educd == 999 ~ NA_real_,
        TRUE ~ NA_real_
      ),
      hs = if_else(
        is.na(educd) | educd %in% c(1, 999),
        NA_integer_,
        as.integer(
          educd %in% c(62, 63, 64, 65, 70, 71, 80, 81, 82, 83, 90, 100, 101) |
            educd %in% 110:116
        )
      ),
      some_college = if_else(
        is.na(educd) | educd %in% c(1, 999),
        NA_integer_,
        as.integer(
          educd %in% c(65, 70, 71, 80, 81, 82, 83, 90, 100, 101) |
            educd %in% 110:116
        )
      ),
      college = if_else(
        is.na(educd) | educd %in% c(1, 999),
        NA_integer_,
        as.integer(educd == 101 | educd %in% 110:116)
      )
    )
} else if ("educ" %in% names(acs)) {
  acs <- acs %>%
    mutate(
      yrsed = case_when(
        educ == 0 ~ 0,
        educ == 1 ~ 2,
        educ == 2 ~ 7,
        educ == 3 ~ 9,
        educ == 4 ~ 10,
        educ == 5 ~ 11,
        educ == 6 ~ 12,
        educ == 7 ~ 13,
        educ == 8 ~ 14,
        educ == 9 ~ 15,
        educ == 10 ~ 16,
        educ == 11 ~ 18,
        TRUE ~ NA_real_
      ),
      hs = if_else(is.na(educ) | educ == 99, NA_integer_, as.integer(educ >= 6)),
      some_college = if_else(is.na(educ) | educ == 99, NA_integer_, as.integer(educ >= 7)),
      college = if_else(is.na(educ) | educ == 99, NA_integer_, as.integer(educ >= 10))
    )

  cat("\n[INFO] educd not found. Education indicators use the coarser educ variable.\n")
} else {
  cat("\n[SKIP] Education: requires educd or educ.\n")
}

if (all(c("yrsed", "hs", "some_college", "college") %in% names(acs))) {
  cat("\n--- Years of education ---\n")
  print(table(acs$yrsed, useNA = "ifany"))

  cat("\n--- Education attainment ---\n")
  cat(sprintf("  HS or more:      %.1f%%\n", mean(acs$hs, na.rm = TRUE) * 100))
  cat(sprintf("  Some college:    %.1f%%\n", mean(acs$some_college, na.rm = TRUE) * 100))
  cat(sprintf("  College degree:  %.1f%%\n", mean(acs$college, na.rm = TRUE) * 100))
}

# ============================================================================
# 5. EMPLOYMENT
# ============================================================================

if ("empstat" %in% names(acs)) {
  acs <- acs %>%
    mutate(
      employed = if_else(is.na(empstat) | empstat == 0, NA_integer_, as.integer(empstat == 1)),
      unemployed = if_else(is.na(empstat) | empstat == 0, NA_integer_, as.integer(empstat == 2)),
      in_lf = if_else(is.na(empstat) | empstat == 0, NA_integer_, as.integer(empstat %in% c(1, 2)))
    )

  cat("\n--- Employment status ---\n")
  if ("age" %in% names(acs)) {
    emp_tab <- acs %>%
      filter(age >= 16) %>%
      summarize(
        employed = mean(employed, na.rm = TRUE),
        unemployed = mean(unemployed, na.rm = TRUE),
        lfp = mean(in_lf, na.rm = TRUE),
        n = dplyr::n()
      )
  } else {
    emp_tab <- acs %>%
      summarize(
        employed = mean(employed, na.rm = TRUE),
        unemployed = mean(unemployed, na.rm = TRUE),
        lfp = mean(in_lf, na.rm = TRUE),
        n = dplyr::n()
      )
  }
  print(as.data.frame(emp_tab), row.names = FALSE)
} else {
  cat("\n[SKIP] Employment: requires empstat.\n")
}

# ============================================================================
# 6. INCOME AND POVERTY
# ============================================================================

if ("poverty" %in% names(acs)) {
  acs <- acs %>%
    mutate(
      inpov = if_else(is.na(poverty) | poverty == 0, NA_integer_, as.integer(poverty <= 100)),
      finc_to_pov = if_else(is.na(poverty) | poverty == 0, NA_real_, poverty / 100)
    )

  cat("\n--- Poverty status ---\n")
  cat(sprintf("  In poverty: %.1f%%\n", mean(acs$inpov, na.rm = TRUE) * 100))
} else {
  cat("\n[SKIP] Poverty: requires poverty.\n")
}

if ("incwage" %in% names(acs)) {
  acs <- acs %>%
    mutate(wage = if_else(is.na(incwage) | incwage >= 999998, NA_real_, incwage))

  cat("\n--- Wage income (conditional on positive) ---\n")
  print(summary(acs$wage[acs$wage > 0]))
} else {
  cat("\n[SKIP] Wage income: requires incwage.\n")
}

# ============================================================================
# 7. HEALTH INSURANCE (if available)
# ============================================================================
# hcovany: 1 = no coverage, 2 = with coverage (available 2008+)

if ("hcovany" %in% names(acs)) {
  acs <- acs %>%
    mutate(
      any_insurance = if_else(is.na(hcovany), NA_integer_, as.integer(hcovany == 2)),
      uninsured = if_else(is.na(hcovany), NA_integer_, as.integer(hcovany == 1))
    )

  if ("hcovpriv" %in% names(acs)) {
    acs$priv_ins <- if_else(is.na(acs$hcovpriv), NA_integer_, as.integer(acs$hcovpriv == 2))
  }
  if ("hcovpub" %in% names(acs)) {
    acs$pub_ins <- if_else(is.na(acs$hcovpub), NA_integer_, as.integer(acs$hcovpub == 2))
  }
  if ("hinscaid" %in% names(acs)) {
    acs$medicaid <- if_else(is.na(acs$hinscaid), NA_integer_, as.integer(acs$hinscaid == 2))
  }
  if ("hinscare" %in% names(acs)) {
    acs$medicare <- if_else(is.na(acs$hinscare), NA_integer_, as.integer(acs$hinscare == 2))
  }

  cat("\n--- Health insurance (2008+) ---\n")
  ins_tab <- acs %>%
    filter(year >= 2008) %>%
    summarize(
      any_ins = mean(any_insurance, na.rm = TRUE),
      unins = mean(uninsured, na.rm = TRUE),
      n = n()
    )
  print(as.data.frame(ins_tab), row.names = FALSE)
} else {
  cat("\n[SKIP] Health insurance: hcovany not in extract.\n")
}

# ============================================================================
# 8. IMMIGRATION AND CITIZENSHIP (if available)
# ============================================================================

if ("citizen" %in% names(acs)) {
  acs <- acs %>%
    mutate(
      noncitizen = if_else(is.na(citizen) | citizen == 0, NA_integer_, as.integer(citizen == 3)),
      usborn = if_else(is.na(citizen) | citizen == 0, NA_integer_, as.integer(citizen %in% c(4, 5))),
      naturalized = if_else(is.na(citizen) | citizen == 0, NA_integer_, as.integer(citizen == 2))
    )

  cat("\n--- Citizenship ---\n")
  cit_tab <- acs %>%
    summarize(
      usborn = mean(usborn, na.rm = TRUE),
      naturalized = mean(naturalized, na.rm = TRUE),
      noncitizen = mean(noncitizen, na.rm = TRUE),
      n = dplyr::n()
    )
  print(as.data.frame(cit_tab), row.names = FALSE)
} else {
  cat("\n[SKIP] Citizenship: citizen not in extract.\n")
}

if ("bpl" %in% names(acs)) {
  acs <- acs %>%
    mutate(
      bpl_us = if_else(is.na(bpl), NA_integer_, as.integer(bpl >= 1 & bpl <= 120)),
      bpl_mexico = if_else(is.na(bpl), NA_integer_, as.integer(bpl == 200)),
      bpl_centam = if_else(is.na(bpl), NA_integer_, as.integer(bpl >= 210 & bpl <= 300)),
      bpl_asia = if_else(is.na(bpl), NA_integer_, as.integer(bpl >= 500 & bpl < 600)),
      bpl_europe = if_else(is.na(bpl), NA_integer_, as.integer(bpl >= 400 & bpl < 500))
    )
}

# ============================================================================
# 9. DESCRIPTIVE STATISTICS
# ============================================================================

cat("\n============================================\n")
cat("   DESCRIPTIVE STATISTICS (optional; not run by default)\n")
cat("============================================\n")

# Uncomment this block if you want example descriptive statistics and regressions.
if (FALSE) {

print_summary_if_present(acs, c("female", "age", "hisp", "white", "black", "asian"),
                         "Key demographic variables")
print_summary_if_present(acs, c("yrsed", "hs", "some_college", "college"),
                         "Education variables")
print_summary_if_present(acs, c("employed", "in_lf", "wage", "inpov", "finc_to_pov"),
                         "Employment and income")

if (all(c("uninsured", "year") %in% names(acs))) {
  cat("\n--- Uninsured rate by year (2008+) ---\n")
  if ("perwt" %in% names(acs)) {
    ins_trend <- acs %>%
      filter(year >= 2008, !is.na(uninsured), !is.na(perwt), perwt > 0) %>%
      group_by(year) %>%
      summarize(
        uninsured_rate = weighted.mean(uninsured, perwt),
        n = n(),
        .groups = "drop"
      )
  } else {
    ins_trend <- acs %>%
      filter(year >= 2008) %>%
      group_by(year) %>%
      summarize(uninsured_rate = mean(uninsured, na.rm = TRUE), n = n(), .groups = "drop")
  }
  print(as.data.frame(ins_trend), row.names = FALSE)

  if ("race_eth" %in% names(acs)) {
    cat("\n--- Uninsured rate by race/ethnicity (2008+) ---\n")
    if ("perwt" %in% names(acs)) {
      ins_race <- acs %>%
        filter(year >= 2008, !is.na(uninsured), !is.na(race_eth), !is.na(perwt), perwt > 0) %>%
        group_by(race_eth) %>%
        summarize(
          uninsured_rate = weighted.mean(uninsured, perwt),
          n = n(),
          .groups = "drop"
        )
    } else {
      ins_race <- acs %>%
        filter(year >= 2008) %>%
        group_by(race_eth) %>%
        summarize(uninsured_rate = mean(uninsured, na.rm = TRUE), n = n(), .groups = "drop")
    }
    print(as.data.frame(ins_race), row.names = FALSE)
  }
}

# ============================================================================
# 10. EXAMPLE REGRESSION
# ============================================================================
# Simple weighted regressions for starter use.

cat("\n============================================\n")
cat("   EXAMPLE REGRESSION\n")
cat("============================================\n")

if (all(c("uninsured", "female", "age", "race_eth", "hs", "college", "year", "perwt") %in% names(acs))) {
  cat("\n--- Weighted OLS: Uninsured on demographics (2008+, ages 18-64) ---\n")

  model_spec <- build_weighted_formula(acs, "uninsured")
  reg_data <- acs %>%
    filter(year >= 2008, age >= 18, age <= 64, perwt > 0)
  reg_data <- reg_data[stats::complete.cases(reg_data[model_spec$filter_vars]), , drop = FALSE]

  if (nrow(reg_data) >= 2) {
    fit <- lm(model_spec$formula, data = reg_data, weights = perwt)
    print(summary(fit))
  } else {
    cat("[SKIP] Weighted uninsured regression: not enough complete observations after filtering.\n")
  }
} else if (all(c("wage", "female", "age", "race_eth", "hs", "college", "perwt") %in% names(acs))) {
  cat("\n--- Weighted OLS: Wage income on demographics ---\n")

  model_spec <- build_weighted_formula(acs, "wage")
  reg_data <- acs %>%
    filter(!is.na(wage), wage > 0, perwt > 0)
  reg_data <- reg_data[stats::complete.cases(reg_data[model_spec$filter_vars]), , drop = FALSE]

  if (nrow(reg_data) >= 2) {
    fit <- lm(model_spec$formula, data = reg_data, weights = perwt)
    print(summary(fit))
  } else {
    cat("[SKIP] Weighted wage regression: not enough complete observations after filtering.\n")
  }
} else {
  cat("\n[SKIP] Weighted regression: required variables not available.\n")
}
}

cat("\n============================================\n")
cat("   CLEANING COMPLETE\n")
cat("============================================\n")
cat("Variables created when source data are available: race_eth, female,\n")
cat("  yrsed, hs, college, employed, in_lf, wage, inpov, and more.\n")
cat("\nThis is a starter script -- extend for your own analysis.\n")

################################################################################
# NOTES:
#
# 1. CUSTOM EXTRACTS:
#    Core sections are skipped if their source variables are absent.
#    Optional sections (health insurance, immigration) are also skipped when
#    those source variables are not in the extract.
#
# 2. SAMPLE RESTRICTIONS:
#    This script does not restrict the sample further. For specific analyses:
#    - Working-age adults: filter(age >= 18, age <= 64)
#    - Children: filter(age < 18)
#    - Non-institutionalized: filter(!gq %in% c(3, 4))
#
# 3. SURVEY WEIGHTS:
#    The starter regression examples use person weights directly:
#      lm(..., weights = perwt)
#    For design-based standard errors, use the survey package or replicate
#    weights when your application needs them.
#
# 4. EDUCATION CODING:
#    When educd is available, grouped lower-schooling categories are mapped to
#    rounded midpoint years. Degree indicators rely on educd directly so that
#    bachelor's and postgraduate degrees remain distinct. If educd is absent,
#    the script falls back to the coarser educ variable.
#
# 5. RACE LABELS:
#    The starter's asian indicator uses IPUMS race codes 4, 5, and 6, where
#    code 6 includes other Asian or Pacific Islander.
#
# 6. INSURANCE VARIABLES:
#    Health insurance variables (hcovany, hcovpriv, hcovpub, etc.) are only
#    available from 2008 onwards.
#
# 7. IMMIGRATION:
#    - citizen == 3 identifies non-citizens
#    - bpl gives detailed birthplace codes
################################################################################
