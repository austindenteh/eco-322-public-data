################################################################################
# 01_load_main.R
#
# Purpose: Load selected main PSID family files and the cross-year individual
#          file, then create compact family-year and person-year starter files.
#
# Inputs:  data/family_files/fam*/FAM*.txt + FAM*.do
#          data/cross_year_individual/ind2023er/IND2023ER.txt + IND2023ER.do
# Outputs: output/psid_family_year.rds
#          output/psid_person_year.rds
#
# Usage:   Run from psid/, psid/code/, repo root, or set psid_root_manual /
#          PSID_ROOT.
################################################################################

library(readr)
library(dplyr)
library(tibble)
library(haven)

# ============================================================================
# 1. USER SETTINGS
# ============================================================================
#
# Edit these defaults here, or set the same objects before calling source().
# Examples:
#   psid_years <- c(2019, 2021, 2023)
#   psid_years <- NULL
#   psid_output_dir <- "/private/tmp/psid_smoke"
#   psid_family_extra_vars <- c("ER85812")
#   psid_individual_extra_vars <- c("ER32000")
#   psid_family_extra_var_families <- list(
#     total_family_income_custom = c("ER16462", "ER46935", "ER85629")
#   )
#   psid_individual_extra_var_families <- list(
#     births_custom = c("ER32022")
#   )
#
# The default starter concepts are listed in the README. They cover common
# demographics, family composition, income, work, housing, weights, and
# generalized public-use geography when those labels exist in a selected wave.

if (!exists("psid_root_manual", inherits = TRUE)) {
  psid_root_manual <- NULL
}

# Default to a quick modern build. Set psid_years <- NULL to load all waves.
if (!exists("psid_years", inherits = TRUE)) {
  psid_years <- c(2019, 2021, 2023)
}

if (!exists("psid_output_dir", inherits = TRUE)) {
  psid_output_dir <- NULL
}
if (!exists("psid_output_basename", inherits = TRUE)) {
  psid_output_basename <- "psid"
}
if (!exists("psid_write_dta_export", inherits = TRUE)) {
  psid_write_dta_export <- FALSE
}
if (!exists("psid_keep_nonresponse_person_years", inherits = TRUE)) {
  psid_keep_nonresponse_person_years <- FALSE
}
if (!exists("psid_include_default_family_concepts", inherits = TRUE)) {
  psid_include_default_family_concepts <- TRUE
}

# Stable raw-name extras. Use uppercase or lowercase raw PSID variable names.
if (!exists("psid_family_extra_vars", inherits = TRUE)) {
  psid_family_extra_vars <- character(0)
}
if (!exists("psid_individual_extra_vars", inherits = TRUE)) {
  psid_individual_extra_vars <- character(0)
}

# Alias families. The loader uses the first listed raw variable that exists in
# each selected file and renames it to the family name.
if (!exists("psid_family_extra_var_families", inherits = TRUE)) {
  psid_family_extra_var_families <- list()
}
if (!exists("psid_individual_extra_var_families", inherits = TRUE)) {
  psid_individual_extra_var_families <- list()
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

resolve_psid_root <- function(script_name) {
  env_root <- Sys.getenv("PSID_ROOT", unset = "")

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
  candidates <- c(psid_root_manual, env_root, search_paths, file.path(search_paths, "psid"))
  candidates <- unique(candidates[!is.na(candidates) & nzchar(candidates)])

  for (path in candidates) {
    path_norm <- normalizePath(path, winslash = "/", mustWork = FALSE)
    if (file.exists(file.path(path_norm, "README.md")) &&
        file.exists(file.path(path_norm, "code", script_name))) {
      return(path_norm)
    }
  }

  stop(
    "Could not locate the psid/ directory.\n",
    "Run from psid/, psid/code/, from the repo root, or set ",
    "psid_root_manual / PSID_ROOT.\n",
    paste0("Current working directory: ", getwd(), "\n"),
    'Manual override: psid_root_manual <- "/path/to/psid"\n',
    'Environment override: Sys.setenv(PSID_ROOT = "/path/to/psid")',
    call. = FALSE
  )
}

psid_root <- resolve_psid_root("01_load_main.R")
cat(paste0("Using PSID root: ", psid_root, "\n"))

if (is.null(psid_output_dir)) {
  psid_output_dir <- file.path(psid_root, "output")
}
dir.create(psid_output_dir, recursive = TRUE, showWarnings = FALSE)

family_out_rds <- file.path(psid_output_dir, paste0(psid_output_basename, "_family_year.rds"))
person_out_rds <- file.path(psid_output_dir, paste0(psid_output_basename, "_person_year.rds"))
family_out_dta <- file.path(psid_output_dir, paste0(psid_output_basename, "_family_year_from_r.dta"))
person_out_dta <- file.path(psid_output_dir, paste0(psid_output_basename, "_person_year_from_r.dta"))

# ============================================================================
# 2. HELPERS
# ============================================================================

available_psid_years <- c(1968:1997, seq(1999, 2023, by = 2))

normalize_var_names <- function(x) {
  x <- unname(x)
  x <- x[!is.na(x) & nzchar(x)]
  unique(tolower(x))
}

resolve_years <- function(years) {
  if (is.null(years) || (length(years) == 1 && is.na(years))) {
    return(available_psid_years)
  }

  years <- as.integer(years)
  invalid <- setdiff(years, available_psid_years)
  if (length(invalid) > 0) {
    stop(
      "Invalid PSID years requested: ", paste(invalid, collapse = ", "), "\n",
      "Valid main PSID years are 1968-1997 annually and 1999-2023 biennially.",
      call. = FALSE
    )
  }

  sort(unique(years))
}

family_base <- function(year) {
  paste0("FAM", year, if (year >= 1994) "ER" else "")
}

family_dir <- function(year) {
  paste0("fam", year, if (year >= 1994) "er" else "")
}

parse_stata_infix_spec <- function(do_path) {
  txt <- paste(readLines(do_path, warn = FALSE), collapse = "\n")
  pattern <- "\\b(?:(?:byte|int|long|float|double|str[0-9]+)\\s+)?([A-Za-z][A-Za-z0-9_]*)\\s+([0-9]+)\\s*-\\s*([0-9]+)"
  raw_matches <- regmatches(txt, gregexpr(pattern, txt, perl = TRUE))[[1]]
  if (length(raw_matches) == 0) {
    stop("No fixed-width infix specifications found in ", do_path, call. = FALSE)
  }
  parsed <- do.call(rbind, lapply(raw_matches, function(match) {
    regmatches(match, regexec(pattern, match, perl = TRUE))[[1]][-1]
  }))
  out <- tibble(
    name = parsed[, 1],
    name_lower = tolower(parsed[, 1]),
    start = as.integer(parsed[, 2]),
    end = as.integer(parsed[, 3])
  )
  distinct(out, name_lower, .keep_all = TRUE)
}

parse_stata_labels <- function(do_path) {
  txt <- paste(readLines(do_path, warn = FALSE), collapse = "\n")
  pattern <- "label variable\\s+([A-Za-z][A-Za-z0-9_]*)\\s+\"([^\"]*)\""
  raw_matches <- regmatches(txt, gregexpr(pattern, txt, perl = TRUE))[[1]]
  if (length(raw_matches) == 0) {
    return(tibble(name = character(), name_lower = character(), label = character(), label_upper = character()))
  }
  parsed <- do.call(rbind, lapply(raw_matches, function(match) {
    regmatches(match, regexec(pattern, match, perl = TRUE))[[1]][-1]
  }))
  tibble(
    name = parsed[, 1],
    name_lower = tolower(parsed[, 1]),
    label = trimws(parsed[, 2]),
    label_upper = toupper(trimws(parsed[, 2]))
  )
}

read_psid_fwf <- function(txt_path, spec, vars) {
  requested <- normalize_var_names(vars)
  selected <- spec[match(requested, spec$name_lower), ]
  selected <- selected[!is.na(selected$name_lower), ]
  selected <- distinct(selected, name_lower, .keep_all = TRUE)

  missing_vars <- setdiff(requested, selected$name_lower)
  if (length(missing_vars) > 0) {
    warning(
      "These requested variables were not found and will be skipped: ",
      paste(missing_vars, collapse = ", "),
      call. = FALSE
    )
  }
  if (nrow(selected) == 0) {
    stop("No requested variables were found in ", txt_path, call. = FALSE)
  }

  positions <- fwf_positions(
    start = selected$start,
    end = selected$end,
    col_names = selected$name_lower
  )
  read_fwf(
    file = txt_path,
    col_positions = positions,
    col_types = cols(.default = col_double()),
    progress = FALSE,
    show_col_types = FALSE
  )
}

first_label_match <- function(labels, patterns) {
  for (pattern in patterns) {
    hit <- labels$name_lower[grepl(pattern, labels$label_upper, perl = TRUE)]
    if (length(hit) > 0) return(hit[[1]])
  }
  NA_character_
}

last_label_match <- function(labels, patterns) {
  for (pattern in patterns) {
    hit <- labels$name_lower[grepl(pattern, labels$label_upper, perl = TRUE)]
    if (length(hit) > 0) return(tail(hit, 1))
  }
  NA_character_
}

annual_label_match <- function(labels, year, patterns) {
  yy <- sprintf("%02d", year %% 100)
  year_patterns <- lapply(patterns, function(pattern) {
    c(
      paste0(pattern, ".*", year, "$"),
      paste0(pattern, ".*", yy, "$")
    )
  })
  first_label_match(labels, unlist(year_patterns, use.names = FALSE))
}

existing_alias_vars <- function(labels, alias_list) {
  labels_present <- labels$name_lower
  out <- list()
  for (concept in names(alias_list)) {
    aliases <- normalize_var_names(alias_list[[concept]])
    chosen <- aliases[aliases %in% labels_present]
    if (length(chosen) > 0) {
      out[[concept]] <- chosen[[1]]
    }
  }
  out
}

default_family_concepts <- list(
  family_size = c("^# IN FU$", "^TOTAL # IN FU$", "^FAMILY SIZE$", "^[0-9]{4} FAMILY SIZE$"),
  head_age = c("^AGE OF( [0-9]{4})? HEAD$", "^AGE OF HEAD$", "^AGE OF REFERENCE PERSON$"),
  head_sex = c("^SEX OF( [0-9]{4})? HEAD$", "^SEX OF HEAD$", "^SEX OF REFERENCE PERSON$"),
  marital_status = c(
    "^MARITAL STATUS-GENERATED$",
    "^[0-9]{4} MARITAL STATUS$",
    "^REFERENCE PERSON MARITAL STATUS$",
    "^A3 MARITAL STATUS$",
    "^MARITAL STATUS$"
  ),
  children_in_fu = c("^# CHILDREN IN FU$", "^# CHILDREN IN FAMILY UNIT$"),
  age_youngest_child = c("^AGE YOUNGEST CHILD$"),
  housing_tenure = c("OWN/RENT OR WHAT$"),
  current_state = c(
    "^CURRENT STATE$",
    "^STATE NOW$",
    "^STATE \\([0-9]{2}\\)$",
    "^PSID STATE OF RESIDENCE CODE$",
    "^FIPS STATE CODE$"
  ),
  current_region = c("^CURRENT REGION$", "^REGION OF [0-9]{4} INTERVIEW$", "^REGION NOW$"),
  metro_nonmetro = c("^METRO/NONMETRO INDICATOR$"),
  beale_rural_urban = c("^BEALE RURAL-URBAN CODE$", "^RURAL-URBAN CODE \\(BEALE-COLLAPSED\\)$"),
  head_total_work_hours = c("^REF PERSON TOTAL HOURS OF WORK-[0-9]{4}$", "^HD [0-9]{4} TOTAL WORK HOURS$"),
  head_labor_income = c("^LABOR INCOME OF REF PERSON-[0-9]{4}$", "^HD [0-9]{4} TOTAL LABOR INCOME$"),
  food_expenditure = c("^FOOD EXPENDITURE [0-9]{4}$"),
  total_family_income = c(
    "^TOTAL FAMILY INCOME",
    "^TOTAL [0-9]{4} FAMILY MONEY INCOME",
    "^TOT FAM MONEY",
    "^FAM MONEY INC"
  ),
  family_weight = c(
    "CORE/IMMIGRANT FAM WEIGHT NUMBER 1$",
    "CORE/IMMIGRANT FAMILY WEIGHT$",
    "LONGITUDINAL CORE FAMILY WEIGHT$",
    "FAMILY WEIGHT$"
  )
)

family_interview_patterns <- function(year) {
  yy <- sprintf("%02d", year %% 100)
  c(
    paste0("^", year, " FAMILY INTERVIEW \\(ID\\) NUMBER$"),
    paste0("^", year, " INTERVIEW NUMBER$"),
    paste0("^", year, " INTERVEW NUMBER$"),
    paste0("^", year, " INTERVIEW #$"),
    paste0("^", year, " INT NUMBER$"),
    paste0("^", year, " INT #$"),
    paste0("^INTERVIEW NUMBER ", yy, "$"),
    paste0("^", yy, " ID NO\\.$")
  )
}

read_family_year <- function(year) {
  base <- family_base(year)
  raw_dir <- file.path(psid_root, "data", "family_files", family_dir(year))
  do_path <- file.path(raw_dir, paste0(base, ".do"))
  txt_path <- file.path(raw_dir, paste0(base, ".txt"))

  if (!file.exists(do_path) || !file.exists(txt_path)) {
    stop(
      "Missing PSID family setup or text file for ", year, ":\n",
      do_path, "\n", txt_path,
      call. = FALSE
    )
  }

  spec <- parse_stata_infix_spec(do_path)
  labels <- parse_stata_labels(do_path)
  family_id_var <- if (year == 1968) "v3" else first_label_match(labels, family_interview_patterns(year))
  # In 1968, FAM V3, not V2, matches ER30001 in the cross-year individual file.
  if (is.na(family_id_var)) {
    stop("Could not find the ", year, " family interview number in ", do_path, call. = FALSE)
  }

  concept_vars <- list()
  if (isTRUE(psid_include_default_family_concepts)) {
    for (concept in names(default_family_concepts)) {
      hit <- if (identical(concept, "family_size")) {
        last_label_match(labels, default_family_concepts[[concept]])
      } else {
        first_label_match(labels, default_family_concepts[[concept]])
      }
      if (!is.na(hit)) {
        concept_vars[[concept]] <- hit
      } else {
        message("PSID ", year, ": no label-detected default family concept found for ", concept, ".")
      }
    }
  }

  alias_vars <- existing_alias_vars(labels, psid_family_extra_var_families)
  concept_vars <- c(concept_vars, alias_vars)

  keep_vars <- c(family_id_var, psid_family_extra_vars, unlist(concept_vars, use.names = FALSE))
  data <- read_psid_fwf(txt_path, spec, keep_vars)

  data <- data %>%
    rename(family_interview_id = all_of(family_id_var)) %>%
    mutate(
      survey_year = year,
      source_family_file = base,
      source_family_id_var = toupper(family_id_var),
      .before = 1
    )

  for (concept in names(concept_vars)) {
    raw_var <- concept_vars[[concept]]
    if (raw_var %in% names(data) && !(concept %in% names(data))) {
      data <- rename(data, !!concept := all_of(raw_var))
    }
  }

  data
}

individual_file_paths <- function() {
  raw_dir <- file.path(psid_root, "data", "cross_year_individual", "ind2023er")
  list(
    raw_dir = raw_dir,
    do_path = file.path(raw_dir, "IND2023ER.do"),
    txt_path = file.path(raw_dir, "IND2023ER.txt")
  )
}

build_individual_var_map <- function(labels, years) {
  static_patterns <- list(
    sex = c("^SEX OF INDIVIDUAL$"),
    sample_status = c("^WHETHER SAMPLE OR NONSAMPLE$", "^WTR ORIGINAL SAMPLE/BORN IN/MOVED IN$")
  )

  static <- list()
  for (concept in names(static_patterns)) {
    hit <- first_label_match(labels, static_patterns[[concept]])
    if (!is.na(hit)) static[[concept]] <- hit
  }
  static <- c(static, existing_alias_vars(labels, psid_individual_extra_var_families))

  annual_patterns <- list(
    family_interview_id = c("^YEAR_REPLACED INTERVIEW NUMBER$"),
    sequence_number = c("^SEQUENCE NUMBER"),
    relation_to_head = c("^RELATIONSHIP TO HEAD", "^RELATION TO HEAD", "^RELATION TO REFERENCE PERSON"),
    age_individual = c("^AGE OF INDIVIDUAL", "^AGE FROM BIRTH DATE"),
    month_individual_born = c("^MONTH IND BORN", "^MONTH INDIVIDUAL BORN"),
    year_individual_born = c("^YEAR IND BORN", "^YEAR INDIVIDUAL BORN"),
    marital_pairs_indicator = c("^MARR PAIRS INDICATOR", "^MARITAL PAIRS INDICATOR"),
    moved_in_out = c("^WHETHER MOVED IN/OUT", "^WHETHER MOVED IN"),
    month_moved_in_out = c("^MONTH MOVED IN/OUT", "^MONTH MOVED IN"),
    year_moved_in_out = c("^YEAR MOVED IN/OUT", "^YEAR MOVED IN"),
    respondent_status = c("^RESPONDENT\\?"),
    employment_status = c("^EMPLOYMENT STAT", "^EMPLOYMENT STATUS"),
    years_completed_education = c("^YEARS? COMPLETED EDUC", "^YRS COMPLETED EDUC", "^COMPLETED EDUC"),
    individual_weight = c(
      "^CORE/IMM INDIVIDUAL LONGITUDINAL WT",
      "^CORE INDIVIDUAL LONGITUDINAL WEIGHT",
      "^CORE IND WEIGHT",
      "^COMBINED IND WEIGHT",
      "^COMBO IND WEIGHT",
      "^INDIVIDUAL WEIGHT"
    )
  )

  rows <- list()
  for (year in years) {
    interview_var <- first_label_match(labels, paste0("^", year, " INTERVIEW NUMBER$"))
    if (is.na(interview_var)) {
      stop("Could not find ", year, " interview number in the cross-year individual file.", call. = FALSE)
    }
    rows[[length(rows) + 1]] <- tibble(
      survey_year = year,
      concept = "family_interview_id",
      raw_var = interview_var
    )

    for (concept in setdiff(names(annual_patterns), "family_interview_id")) {
      hit <- annual_label_match(labels, year, annual_patterns[[concept]])
      if (!is.na(hit)) {
        rows[[length(rows) + 1]] <- tibble(
          survey_year = year,
          concept = concept,
          raw_var = hit
        )
      }
    }
  }

  list(
    static = static,
    annual = bind_rows(rows)
  )
}

read_person_years <- function(years, family_year) {
  paths <- individual_file_paths()
  if (!file.exists(paths$do_path) || !file.exists(paths$txt_path)) {
    stop(
      "Missing PSID cross-year individual setup or text file:\n",
      paths$do_path, "\n", paths$txt_path,
      call. = FALSE
    )
  }

  spec <- parse_stata_infix_spec(paths$do_path)
  labels <- parse_stata_labels(paths$do_path)
  var_map <- build_individual_var_map(labels, years)

  id_vars <- c("er30001", "er30002")
  static_vars <- unlist(var_map$static, use.names = FALSE)
  annual_vars <- var_map$annual$raw_var
  keep_vars <- c(id_vars, static_vars, annual_vars, psid_individual_extra_vars)

  cat(paste0(
    "Reading cross-year individual file: ",
    length(unique(normalize_var_names(keep_vars))), " selected columns\n"
  ))
  raw_ind <- read_psid_fwf(paths$txt_path, spec, keep_vars)

  base <- tibble(
    psid_1968_family_id = raw_ind$er30001,
    person_number = raw_ind$er30002
  )

  for (concept in names(var_map$static)) {
    raw_var <- var_map$static[[concept]]
    if (raw_var %in% names(raw_ind)) {
      base[[concept]] <- raw_ind[[raw_var]]
    }
  }

  for (extra in normalize_var_names(psid_individual_extra_vars)) {
    if (extra %in% names(raw_ind) && !(extra %in% names(base))) {
      base[[extra]] <- raw_ind[[extra]]
    }
  }

  person_years <- lapply(years, function(year) {
    year_map <- filter(var_map$annual, survey_year == year)
    out <- base
    out$survey_year <- year
    for (i in seq_len(nrow(year_map))) {
      concept <- year_map$concept[[i]]
      raw_var <- year_map$raw_var[[i]]
      if (raw_var %in% names(raw_ind)) {
        out[[concept]] <- raw_ind[[raw_var]]
      }
    }
    out
  }) %>%
    bind_rows() %>%
    relocate(survey_year, .after = person_number)

  if (!isTRUE(psid_keep_nonresponse_person_years)) {
    person_years <- filter(
      person_years,
      !is.na(family_interview_id),
      family_interview_id != 0
    )
  }

  merged <- left_join(
    person_years,
    family_year,
    by = c("survey_year", "family_interview_id")
  ) %>%
    mutate(
      has_family_record = !is.na(source_family_file),
      .after = family_interview_id
    )

  unmatched <- sum(!merged$has_family_record & !is.na(merged$family_interview_id) & merged$family_interview_id != 0)
  if (unmatched > 0) {
    warning(
      unmatched, " person-year rows had nonzero family interview numbers but did not match a selected family file.",
      call. = FALSE
    )
  }

  merged
}

# ============================================================================
# 3. BUILD OUTPUTS
# ============================================================================

selected_years <- resolve_years(psid_years)
cat(paste0("Selected PSID years: ", paste(selected_years, collapse = ", "), "\n"))

family_year <- bind_rows(lapply(selected_years, function(year) {
  cat(paste0("Reading family file for ", year, "\n"))
  read_family_year(year)
}))

person_year <- read_person_years(selected_years, family_year)

saveRDS(family_year, family_out_rds)
saveRDS(person_year, person_out_rds)

cat(paste0("Saved family-year file: ", family_out_rds, "\n"))
cat(paste0("Saved person-year file: ", person_out_rds, "\n"))
cat(paste0("Family-year rows: ", nrow(family_year), "\n"))
cat(paste0("Person-year rows: ", nrow(person_year), "\n"))

if (isTRUE(psid_write_dta_export)) {
  write_dta(family_year, family_out_dta)
  write_dta(person_year, person_out_dta)
  cat(paste0("Saved optional Stata export: ", family_out_dta, "\n"))
  cat(paste0("Saved optional Stata export: ", person_out_dta, "\n"))
}
