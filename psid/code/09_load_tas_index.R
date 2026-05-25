################################################################################
# 09_load_tas_index.R
#
# Purpose: Load selected Transition into Adulthood Supplement (TAS) waves into a
#          compact index file with merge keys and interview metadata.
#
# Inputs:  data/supplemental_studies/transition_into_adulthood/*/TA*.txt + .do
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
#   psid_output_dir <- "/private/tmp/psid_tas_smoke"
#   psid_tas_years <- c(2019, 2021, 2023)
#   psid_tas_years <- NULL
#   psid_tas_extra_vars <- c("TA190001")

if (!exists("psid_root_manual", inherits = TRUE)) {
  psid_root_manual <- NULL
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
if (!exists("psid_tas_years", inherits = TRUE)) {
  psid_tas_years <- c(2019, 2021, 2023)
}
if (!exists("psid_tas_extra_vars", inherits = TRUE)) {
  psid_tas_extra_vars <- character(0)
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
  search_roots <- c(getwd(), get_current_script_dir())
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
    "Could not locate the psid/ directory. Run from psid/, psid/code/, ",
    "repo root, or set psid_root_manual / PSID_ROOT.",
    call. = FALSE
  )
}

psid_root <- resolve_psid_root("09_load_tas_index.R")
if (is.null(psid_output_dir)) {
  psid_output_dir <- file.path(psid_root, "output")
}
dir.create(psid_output_dir, recursive = TRUE, showWarnings = FALSE)

normalize_var_names <- function(x) {
  x <- unname(x)
  x <- x[!is.na(x) & nzchar(x)]
  unique(tolower(x))
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
  distinct(
    tibble(
      name = parsed[, 1],
      name_lower = tolower(parsed[, 1]),
      start = as.integer(parsed[, 2]),
      end = as.integer(parsed[, 3])
    ),
    name_lower,
    .keep_all = TRUE
  )
}

parse_stata_labels <- function(do_path) {
  txt <- readLines(do_path, warn = FALSE)
  label_lines <- grep("^label variable", trimws(txt), value = TRUE)
  matches <- regmatches(
    label_lines,
    regexec('label variable\\s+([A-Za-z][A-Za-z0-9_]*)\\s+"([^"]*)"', label_lines)
  )
  parsed <- do.call(rbind, lapply(matches[lengths(matches) > 0], function(x) x[-1]))
  if (is.null(parsed)) {
    return(tibble(name_lower = character(0), label = character(0)))
  }
  tibble(name_lower = tolower(parsed[, 1]), label = parsed[, 2])
}

read_psid_fwf <- function(txt_path, spec, vars = NULL) {
  if (is.null(vars)) {
    selected <- spec
  } else {
    requested <- normalize_var_names(vars)
    selected <- spec[match(requested, spec$name_lower), ]
    selected <- selected[!is.na(selected$name_lower), ]
    missing_vars <- setdiff(requested, selected$name_lower)
    if (length(missing_vars) > 0) {
      warning(
        "These requested variables were not found and will be skipped: ",
        paste(missing_vars, collapse = ", "),
        call. = FALSE
      )
    }
  }
  if (nrow(selected) == 0) {
    stop("No variables selected from ", txt_path, call. = FALSE)
  }
  read_fwf(
    txt_path,
    fwf_positions(selected$start, selected$end, selected$name_lower),
    col_types = cols(.default = col_double()),
    progress = FALSE,
    show_col_types = FALSE
  )
}

write_tas_output <- function(data, suffix) {
  out_rds <- file.path(psid_output_dir, paste0(psid_output_basename, "_", suffix, ".rds"))
  saveRDS(data, out_rds)
  cat(paste0("Saved ", suffix, ": ", out_rds, " (", nrow(data), " rows)\n"))
  if (isTRUE(psid_write_dta_export)) {
    out_dta <- file.path(psid_output_dir, paste0(psid_output_basename, "_", suffix, "_from_r.dta"))
    write_dta(data, out_dta)
    cat(paste0("Saved optional Stata export: ", out_dta, "\n"))
  }
}

tas_inventory <- tibble(
  year = c(2005, 2007, 2009, 2011, 2013, 2015, 2017, 2019, 2021, 2023),
  folder = c("ta2005", "ta2007", "ta2009", "ta2011", "ta2013", "ta2015",
             "TA2017", "TA2019", "TA2021", "TA2023"),
  base = paste0("TA", c("2005", "2007", "2009", "2011", "2013", "2015", "2017", "2019", "2021", "2023")),
  prefix = paste0("ta", c("05", "07", "09", "11", "13", "15", "17", "19", "21", "23"))
)

available_tas_years <- tas_inventory$year
normalize_tas_years <- function(years) {
  if (is.null(years) || identical(tolower(years), "all")) {
    return(available_tas_years)
  }
  years <- as.integer(years)
  invalid <- setdiff(years, available_tas_years)
  if (length(invalid) > 0) {
    stop(
      "Invalid TAS year(s): ", paste(invalid, collapse = ", "), "\n",
      "Choose from: ", paste(available_tas_years, collapse = ", "), ".",
      call. = FALSE
    )
  }
  unique(years)
}

raw_var <- function(prefix, number) paste0(prefix, sprintf("%04d", number))

tas_var_map <- function(year, prefix) {
  if (year <= 2015) {
    nums <- c(1, 2, 3, 4, 5, 11, 10, 6, 7, 8, 9, 12, 13, 14)
  } else if (year == 2017) {
    nums <- c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14)
  } else if (year == 2019) {
    nums <- c(1, 2, 3, 4, NA, 5, 7, 9, 10, 11, 12, 13, 14, 15)
  } else {
    nums <- c(1, 2, 3, 4, NA, 5, 6, 8, 9, 10, 11, 12, 13, 14)
  }
  names(nums) <- c(
    "release_number", "tas_interview_id", "family_interview_id",
    "sequence_number", "current_state", "reference_status",
    "interview_mode", "interview_length_minutes",
    "tas_interview_month", "tas_interview_day", "tas_interview_year",
    "psid_interview_month", "psid_interview_day", "psid_interview_year"
  )
  vapply(nums, function(num) if (is.na(num)) NA_character_ else raw_var(prefix, num), character(1))
}

col_or_missing <- function(data, name) {
  if (!is.na(name) && name %in% names(data)) data[[name]] else rep(NA_real_, nrow(data))
}

load_tas_year <- function(year) {
  selected_year <- year
  info <- filter(tas_inventory, .data$year == selected_year)
  raw_dir <- file.path(psid_root, "data", "supplemental_studies", "transition_into_adulthood", info$folder)
  do_path <- file.path(raw_dir, paste0(info$base, ".do"))
  txt_path <- file.path(raw_dir, paste0(info$base, ".txt"))
  if (!file.exists(do_path) || !file.exists(txt_path)) {
    stop("Missing TAS files for ", year, ".", call. = FALSE)
  }

  spec <- parse_stata_infix_spec(do_path)
  labels <- parse_stata_labels(do_path)
  label_upper <- toupper(trimws(labels$label))
  cross_weight_var <- labels$name_lower[label_upper == "CROSS SECTIONAL WEIGHT"][1]
  legacy_weight_var <- labels$name_lower[label_upper == "WEIGHT"][1]
  weight_var <- if (!is.na(cross_weight_var)) cross_weight_var else legacy_weight_var
  long_weight_var <- labels$name_lower[grepl("^LONG WEIGHT", label_upper)][1]
  # For 2019+, this keeps the realized interview mode rather than the initial assignment mode.
  map <- tas_var_map(year, info$prefix)
  keep_vars <- c(unname(map[!is.na(map)]), weight_var, long_weight_var, psid_tas_extra_vars)

  cat(paste0("Reading PSID TAS ", year, "\n"))
  raw <- read_psid_fwf(txt_path, spec, vars = keep_vars)
  out <- tibble(
    source_module = "transition_into_adulthood",
    source_file = info$base,
    survey_year = year,
    release_number = col_or_missing(raw, map[["release_number"]]),
    tas_interview_id = col_or_missing(raw, map[["tas_interview_id"]]),
    family_interview_id = col_or_missing(raw, map[["family_interview_id"]]),
    sequence_number = col_or_missing(raw, map[["sequence_number"]]),
    current_state = col_or_missing(raw, map[["current_state"]]),
    reference_status = col_or_missing(raw, map[["reference_status"]]),
    interview_mode = col_or_missing(raw, map[["interview_mode"]]),
    interview_length_minutes = col_or_missing(raw, map[["interview_length_minutes"]]),
    tas_interview_month = col_or_missing(raw, map[["tas_interview_month"]]),
    tas_interview_day = col_or_missing(raw, map[["tas_interview_day"]]),
    tas_interview_year = col_or_missing(raw, map[["tas_interview_year"]]),
    psid_interview_month = col_or_missing(raw, map[["psid_interview_month"]]),
    psid_interview_day = col_or_missing(raw, map[["psid_interview_day"]]),
    psid_interview_year = col_or_missing(raw, map[["psid_interview_year"]]),
    tas_weight = col_or_missing(raw, weight_var),
    tas_long_weight = col_or_missing(raw, long_weight_var)
  )
  used_vars <- normalize_var_names(c(unname(map), weight_var, long_weight_var))
  extra_cols <- setdiff(names(raw), used_vars)
  if (length(extra_cols) > 0) {
    out <- bind_cols(out, raw[extra_cols])
  }
  out
}

selected_tas_years <- normalize_tas_years(psid_tas_years)
cat(paste0("Selected TAS years: ", paste(selected_tas_years, collapse = ", "), "\n"))

tas_index <- bind_rows(lapply(selected_tas_years, load_tas_year)) %>%
  arrange(survey_year, family_interview_id, sequence_number)

write_tas_output(tas_index, "tas_wave_index")
