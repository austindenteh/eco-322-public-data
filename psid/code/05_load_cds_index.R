################################################################################
# 05_load_cds_index.R
#
# Purpose: Load the PSID Child Development Supplement (CDS) cumulative ID map
#          and build a compact long-format CDS wave index.
#
# Inputs:  data/supplemental_studies/child_development_supplement/cdsind2021/
#          CDSIND2021.txt + CDSIND2021.do
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
#   psid_output_dir <- "/private/tmp/psid_cds_index_smoke"
#   psid_cds_waves <- c(2014, 2019, 2021)
#   psid_cds_waves <- NULL
#   psid_cds_keep_all_cumulative <- FALSE
#   psid_cds_extra_vars <- c("PCGHH_19")

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

# CDSIND2021 has standalone wave-index fields for these CDS waves. The 2020
# COVID-era follow-up has component flags in CDSIND2021 but not a full
# standalone wave-index block.
if (!exists("psid_cds_waves", inherits = TRUE)) {
  psid_cds_waves <- c(1997, 2002, 2007, 2014, 2019, 2021)
}
if (!exists("psid_cds_keep_all_cumulative", inherits = TRUE)) {
  psid_cds_keep_all_cumulative <- TRUE
}
if (!exists("psid_cds_extra_vars", inherits = TRUE)) {
  psid_cds_extra_vars <- character(0)
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

psid_root <- resolve_psid_root("05_load_cds_index.R")
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

rename_known_vars <- function(data, rename_map) {
  from <- intersect(names(rename_map), names(data))
  if (length(from) == 0) return(data)
  names(data)[match(from, names(data))] <- unname(rename_map[from])
  data
}

write_cds_output <- function(data, suffix) {
  out_rds <- file.path(psid_output_dir, paste0(psid_output_basename, "_", suffix, ".rds"))
  saveRDS(data, out_rds)
  cat(paste0("Saved ", suffix, ": ", out_rds, " (", nrow(data), " rows)\n"))
  if (isTRUE(psid_write_dta_export)) {
    out_dta <- file.path(psid_output_dir, paste0(psid_output_basename, "_", suffix, "_from_r.dta"))
    write_dta(data, out_dta)
    cat(paste0("Saved optional Stata export: ", out_dta, "\n"))
  }
}

available_cds_index_waves <- c(1997, 2002, 2007, 2014, 2019, 2021)
normalize_cds_waves <- function(waves) {
  if (is.null(waves) || identical(tolower(waves), "all")) {
    return(available_cds_index_waves)
  }
  waves <- as.integer(waves)
  invalid <- setdiff(waves, available_cds_index_waves)
  if (length(invalid) > 0) {
    stop(
      "Invalid CDS index wave(s): ", paste(invalid, collapse = ", "), "\n",
      "CDSIND2021 has standalone index blocks for: ",
      paste(available_cds_index_waves, collapse = ", "), ".\n",
      "The 2020 COVID-era CDS files have component flags but no full index block here.",
      call. = FALSE
    )
  }
  unique(waves)
}

cds_suffix <- function(year) substr(as.character(year), 3, 4)

wave_vars <- function(year) {
  suffix <- cds_suffix(year)
  c(
    paste0(c(
      "cdstype", "crfid", "crsn", "cds_hid", "cds_sn", "id68pcg",
      "pnpcg", "crpcgfid", "crpcgsn", "id68ocg", "pnocg",
      "crocgfid", "crocgsn", "cdspcgsn", "pcghhno"
    ), suffix),
    paste0(c("demog_", "pcghh_", "pcgch_", "child_"), suffix)
  )
}

col_or_missing <- function(data, name) {
  if (name %in% names(data)) data[[name]] else rep(NA_real_, nrow(data))
}

make_wave_index <- function(cumulative, year) {
  suffix <- cds_suffix(year)
  data <- tibble(
    source_module = "child_development_supplement",
    source_file = "CDSIND2021",
    survey_year = year,
    psid_1968_family_id = cumulative$psid_1968_family_id,
    person_number = cumulative$person_number,
    cds_person_type = col_or_missing(cumulative, paste0("cdstype", suffix)),
    core_family_interview_id = col_or_missing(cumulative, paste0("crfid", suffix)),
    core_sequence_number = col_or_missing(cumulative, paste0("crsn", suffix)),
    cds_household_interview_id = col_or_missing(cumulative, paste0("cds_hid", suffix)),
    cds_sequence_number = col_or_missing(cumulative, paste0("cds_sn", suffix)),
    pcg_1968_family_id = col_or_missing(cumulative, paste0("id68pcg", suffix)),
    pcg_person_number = col_or_missing(cumulative, paste0("pnpcg", suffix)),
    pcg_core_family_interview_id = col_or_missing(cumulative, paste0("crpcgfid", suffix)),
    pcg_core_sequence_number = col_or_missing(cumulative, paste0("crpcgsn", suffix)),
    ocg_1968_family_id = col_or_missing(cumulative, paste0("id68ocg", suffix)),
    ocg_person_number = col_or_missing(cumulative, paste0("pnocg", suffix)),
    ocg_core_family_interview_id = col_or_missing(cumulative, paste0("crocgfid", suffix)),
    ocg_core_sequence_number = col_or_missing(cumulative, paste0("crocgsn", suffix)),
    pcg_cds_sequence_number = col_or_missing(cumulative, paste0("cdspcgsn", suffix)),
    household_pcg_indicator = col_or_missing(cumulative, paste0("pcghhno", suffix)),
    demog_file = col_or_missing(cumulative, paste0("demog_", suffix)),
    pcg_household_file = col_or_missing(cumulative, paste0("pcghh_", suffix)),
    pcg_child_file = col_or_missing(cumulative, paste0("pcgch_", suffix)),
    child_file = col_or_missing(cumulative, paste0("child_", suffix))
  )
  filter(data, !is.na(cds_person_type), cds_person_type != 0)
}

selected_cds_waves <- normalize_cds_waves(psid_cds_waves)
cat(paste0("Selected CDS index waves: ", paste(selected_cds_waves, collapse = ", "), "\n"))

raw_dir <- file.path(
  psid_root, "data", "supplemental_studies",
  "child_development_supplement", "cdsind2021"
)
do_path <- file.path(raw_dir, "CDSIND2021.do")
txt_path <- file.path(raw_dir, "CDSIND2021.txt")
if (!file.exists(do_path) || !file.exists(txt_path)) {
  stop("Missing CDS cumulative ID map files.", call. = FALSE)
}

cds_spec <- parse_stata_infix_spec(do_path)
core_vars <- c("cdscumrel", "cdscumid68", "cdscumpn")
selected_wave_vars <- unique(unlist(lapply(selected_cds_waves, wave_vars), use.names = FALSE))
component_2020_flags <- c("pcghh_20", "pcgch_20")
if (isTRUE(psid_cds_keep_all_cumulative)) {
  keep_vars <- NULL
} else {
  expected_vars <- normalize_var_names(c(core_vars, selected_wave_vars, component_2020_flags))
  keep_vars <- c(intersect(expected_vars, cds_spec$name_lower), psid_cds_extra_vars)
}

cat("Reading PSID supplement: CDS cumulative ID map\n")
cumulative <- read_psid_fwf(txt_path, cds_spec, vars = keep_vars)
cumulative <- rename_known_vars(
  cumulative,
  c(
    cdscumrel = "release_number",
    cdscumid68 = "psid_1968_family_id",
    cdscumpn = "person_number"
  )
)
cumulative <- mutate(
  cumulative,
  source_module = "child_development_supplement",
  source_file = "CDSIND2021",
  .before = 1
)

wave_index <- bind_rows(lapply(selected_cds_waves, function(year) {
  make_wave_index(cumulative, year)
})) %>%
  arrange(psid_1968_family_id, person_number, survey_year)

write_cds_output(cumulative, "cds_cumulative_id_map")
write_cds_output(wave_index, "cds_wave_index")
