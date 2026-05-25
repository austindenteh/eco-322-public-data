################################################################################
# 03_clean_modern_primary.R
#
# Purpose: Create a starter analysis-ready person-month file from the modern
#          SIPP annual primary public-use loader.
#
# Input:  output/sipp_modern_primary_person_month.rds
# Output: output/sipp_modern_primary_clean_person_month.rds
################################################################################

library(dplyr)
library(haven)

################################################################################
# USER SETTINGS
################################################################################

# Optional manual path override. Leave NULL when running from the repo root,
# sipp/, or sipp/code/. You can also set Sys.setenv(SIPP_ROOT = "...").
if (!exists("sipp_root_manual", inherits = TRUE)) {
  sipp_root_manual <- NULL
}

# Optional output override. Defaults to sipp/output/.
if (!exists("sipp_output_dir", inherits = TRUE)) {
  sipp_output_dir <- NULL
}
if (!exists("sipp_output_basename", inherits = TRUE)) {
  sipp_output_basename <- "sipp"
}

# The default runs 01_load_modern_primary.R first, using any loader settings
# already defined in your R session.
if (!exists("sipp_clean_run_loader", inherits = TRUE)) {
  sipp_clean_run_loader <- TRUE
}

# Used only when sipp_clean_run_loader is FALSE.
if (!exists("sipp_clean_input_path", inherits = TRUE)) {
  sipp_clean_input_path <- NULL
}

# Set TRUE if you also want a Stata copy from the R cleaner.
if (!exists("sipp_clean_write_dta_export", inherits = TRUE)) {
  sipp_clean_write_dta_export <- FALSE
}

################################################################################
# HELPERS
################################################################################

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

resolve_sipp_root <- function(script_name) {
  env_root <- Sys.getenv("SIPP_ROOT", unset = "")
  search_roots <- c(getwd(), get_current_script_dir())
  search_paths <- unique(unlist(lapply(search_roots, parent_paths), use.names = FALSE))
  candidates <- c(sipp_root_manual, env_root, search_paths, file.path(search_paths, "sipp"))
  candidates <- unique(candidates[!is.na(candidates) & nzchar(candidates)])

  for (path in candidates) {
    path_norm <- normalizePath(path, winslash = "/", mustWork = FALSE)
    if (file.exists(file.path(path_norm, "README.md")) &&
        file.exists(file.path(path_norm, "code", script_name))) {
      return(path_norm)
    }
  }

  stop(
    "Could not locate the sipp/ directory. Run from sipp/, sipp/code/, ",
    "repo root, or set sipp_root_manual / SIPP_ROOT.",
    call. = FALSE
  )
}

clean_numeric <- function(x) {
  x <- as.numeric(x)
  x[x < 0] <- NA_real_
  x
}

clean_binary_yes <- function(x) {
  x <- clean_numeric(x)
  ifelse(is.na(x), NA, x == 1)
}

state_fips_clean <- function(x) {
  if (is.numeric(x)) {
    out <- ifelse(is.na(x), NA_character_, sprintf("%02.0f", x))
  } else {
    out <- trimws(as.character(x))
    out[out == ""] <- NA_character_
  }
  out
}

has_var <- function(data, var) var %in% names(data)

sipp_root <- resolve_sipp_root("03_clean_modern_primary.R")
if (is.null(sipp_output_dir)) {
  sipp_output_dir <- file.path(sipp_root, "output")
}
dir.create(sipp_output_dir, recursive = TRUE, showWarnings = FALSE)

if (isTRUE(sipp_clean_run_loader)) {
  source(file.path(sipp_root, "code", "01_load_modern_primary.R"))
} else {
  if (is.null(sipp_clean_input_path)) {
    sipp_clean_input_path <- file.path(
      sipp_output_dir,
      paste0(sipp_output_basename, "_modern_primary_person_month.rds")
    )
  }
  if (!file.exists(sipp_clean_input_path)) {
    stop(
      "Could not find modern SIPP primary input: ", sipp_clean_input_path, "\n",
      "Run 01_load_modern_primary.R first or set sipp_clean_run_loader <- TRUE.",
      call. = FALSE
    )
  }
  sipp_modern_primary <- readRDS(sipp_clean_input_path)
}

sipp_modern_clean <- sipp_modern_primary |>
  mutate(
    person_id = ifelse(
      !is.na(ssuid) & !is.na(pnum),
      paste(ssuid, pnum, sep = "_"),
      NA_character_
    ),
    person_month_id = ifelse(
      !is.na(ssuid) & !is.na(pnum) & !is.na(monthcode),
      paste(ssuid, pnum, monthcode, sep = "_"),
      NA_character_
    )
  )

if (has_var(sipp_modern_clean, "tage")) {
  sipp_modern_clean$age <- clean_numeric(sipp_modern_clean$tage)
  sipp_modern_clean$adult <- ifelse(is.na(sipp_modern_clean$age), NA, sipp_modern_clean$age >= 18)
}
if (has_var(sipp_modern_clean, "esex")) {
  sipp_modern_clean$female <- clean_numeric(sipp_modern_clean$esex) == 2
}
if (has_var(sipp_modern_clean, "eorigin")) {
  sipp_modern_clean$hispanic <- clean_binary_yes(sipp_modern_clean$eorigin)
}
if (has_var(sipp_modern_clean, "erace")) {
  sipp_modern_clean$race_code <- clean_numeric(sipp_modern_clean$erace)
}
if (has_var(sipp_modern_clean, "eeduc")) {
  sipp_modern_clean$education_code <- clean_numeric(sipp_modern_clean$eeduc)
  sipp_modern_clean$high_school_or_more <- ifelse(
    is.na(sipp_modern_clean$education_code),
    NA,
    sipp_modern_clean$education_code >= 38
  )
  sipp_modern_clean$bachelor_or_more <- ifelse(
    is.na(sipp_modern_clean$education_code),
    NA,
    sipp_modern_clean$education_code >= 43
  )
}
if (has_var(sipp_modern_clean, "ems")) {
  sipp_modern_clean$marital_status_code <- clean_numeric(sipp_modern_clean$ems)
  sipp_modern_clean$married <- ifelse(is.na(sipp_modern_clean$marital_status_code), NA, sipp_modern_clean$marital_status_code == 1)
  sipp_modern_clean$never_married <- ifelse(is.na(sipp_modern_clean$marital_status_code), NA, sipp_modern_clean$marital_status_code == 6)
}
if (has_var(sipp_modern_clean, "rmesr")) {
  sipp_modern_clean$monthly_employment_status_code <- clean_numeric(sipp_modern_clean$rmesr)
  sipp_modern_clean$employed_some_or_all_month <- ifelse(
    is.na(sipp_modern_clean$monthly_employment_status_code),
    NA,
    sipp_modern_clean$monthly_employment_status_code %in% 1:3
  )
}
if (has_var(sipp_modern_clean, "etenure")) {
  tenure <- clean_numeric(sipp_modern_clean$etenure)
  sipp_modern_clean$housing_tenure_code <- tenure
  sipp_modern_clean$owner_occupied <- ifelse(is.na(tenure), NA, tenure == 1)
  sipp_modern_clean$renter_occupied <- ifelse(is.na(tenure), NA, tenure == 2)
  sipp_modern_clean$occupied_without_cash_rent <- ifelse(is.na(tenure), NA, tenure == 3)
}

numeric_copies <- c(
  age_at_interview = "tage",
  household_persons = "rhnumper",
  household_children = "rhnumu18",
  household_older_adults = "rhnum65over",
  family_persons = "rfpersons",
  family_children = "rfrelu18",
  person_earnings = "tpearn",
  person_earnings_alt = "tpearn_alt",
  person_total_income = "tptotinc",
  household_total_income = "thtotinc",
  family_total_income = "tftotinc",
  family_poverty_threshold = "rfpov",
  social_security_income = "tsssamt",
  ssi_income = "tssi_amt",
  tanf_amount = "ttanf_amt",
  snap_amount = "tsnap_amt",
  wic_amount = "twic_amt",
  general_assistance_amount = "tga_amt",
  household_home_value = "thval_home",
  person_net_worth = "tnetworth",
  household_net_worth = "thnetworth",
  person_credit_card_debt = "tdebt_cc",
  household_credit_card_debt = "thdebt_cc",
  person_monthly_work_hours = "tmwkhrs",
  monthly_weeks_with_job = "rmwkwjb",
  monthly_number_jobs = "rmnumjobs"
)

for (new_name in names(numeric_copies)) {
  old_name <- unname(numeric_copies[[new_name]])
  if (has_var(sipp_modern_clean, old_name)) {
    sipp_modern_clean[[new_name]] <- clean_numeric(sipp_modern_clean[[old_name]])
  }
}

if (all(c("family_total_income", "family_poverty_threshold") %in% names(sipp_modern_clean))) {
  sipp_modern_clean$family_income_to_poverty <- ifelse(
    !is.na(sipp_modern_clean$family_poverty_threshold) &
      sipp_modern_clean$family_poverty_threshold > 0,
    sipp_modern_clean$family_total_income / sipp_modern_clean$family_poverty_threshold,
    NA_real_
  )
  sipp_modern_clean$family_below_poverty <- ifelse(
    is.na(sipp_modern_clean$family_income_to_poverty),
    NA,
    sipp_modern_clean$family_income_to_poverty < 1
  )
}

binary_copies <- c(
  any_health_insurance_month = "rhlthmth",
  any_health_insurance_annual = "rhicovann",
  private_health_insurance_annual = "rprivann",
  public_health_insurance_annual = "rpubann",
  medicare_annual = "rmedcareann",
  medicaid_annual = "rmcaidann",
  va_health_care_annual = "rvacareann",
  snap_month = "rsnap_mnyn",
  tanf_month = "rtanf_mnyn",
  ssi_month = "rssi_mnyn",
  wic_month = "rwic_mnyn"
)

for (new_name in names(binary_copies)) {
  old_name <- unname(binary_copies[[new_name]])
  if (has_var(sipp_modern_clean, old_name)) {
    sipp_modern_clean[[new_name]] <- clean_binary_yes(sipp_modern_clean[[old_name]])
  }
}

if (has_var(sipp_modern_clean, "tst_intv")) {
  sipp_modern_clean$state_fips_interview <- state_fips_clean(sipp_modern_clean$tst_intv)
}
if (has_var(sipp_modern_clean, "tehc_st")) {
  sipp_modern_clean$state_fips_residence_ehc <- state_fips_clean(sipp_modern_clean$tehc_st)
}
if (has_var(sipp_modern_clean, "rregion_intv")) {
  sipp_modern_clean$region_interview_code <- clean_numeric(sipp_modern_clean$rregion_intv)
}
if (has_var(sipp_modern_clean, "tmetro_intv")) {
  sipp_modern_clean$metro_interview_code <- clean_numeric(sipp_modern_clean$tmetro_intv)
}
if (has_var(sipp_modern_clean, "tehc_metro")) {
  sipp_modern_clean$metro_residence_ehc_code <- clean_numeric(sipp_modern_clean$tehc_metro)
}

sipp_modern_clean <- sipp_modern_clean |>
  arrange(sipp_file_year, ssuid, pnum, monthcode)

out_rds <- file.path(sipp_output_dir, paste0(sipp_output_basename, "_modern_primary_clean_person_month.rds"))
saveRDS(sipp_modern_clean, out_rds)
cat(paste0("Saved cleaned modern SIPP primary person-month file: ", out_rds, " (", nrow(sipp_modern_clean), " rows)\n"))

if (isTRUE(sipp_clean_write_dta_export)) {
  out_dta <- file.path(sipp_output_dir, paste0(sipp_output_basename, "_modern_primary_clean_person_month_from_r.dta"))
  write_dta(sipp_modern_clean, out_dta)
  cat(paste0("Saved optional Stata export: ", out_dta, "\n"))
}
