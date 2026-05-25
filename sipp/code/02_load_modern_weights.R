################################################################################
# 02_load_modern_weights.R
#
# Purpose: Load selected modern SIPP public-use weight files
#          (2018-2024 design era), keeping weight families separate.
#
# Inputs:
#   data/{year}/rw{year}_dta.zip
#   data/{year}/lgtwgt{year}*_dta.zip
#   data/{year}/lgtrw{year}*_dta.zip
################################################################################

library(dplyr)
library(haven)
library(tibble)

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

# Set TRUE if you also want Stata copies from the R loader.
if (!exists("sipp_weight_write_dta_export", inherits = TRUE)) {
  sipp_weight_write_dta_export <- FALSE
}

# Main file choices. Use NULL or "all" to try every supported modern year.
if (!exists("sipp_weight_years", inherits = TRUE)) {
  sipp_weight_years <- c(2024)
}

# Supported families:
#   "replicate"              cross-sectional replicate weights
#   "longitudinal"           person-level longitudinal final weights
#   "longitudinal_replicate" person-level longitudinal replicate weights
if (!exists("sipp_weight_families", inherits = TRUE)) {
  sipp_weight_families <- c("replicate")
}

# Longitudinal horizons. NULL means every local horizon for each selected year.
if (!exists("sipp_longitudinal_horizons", inherits = TRUE)) {
  sipp_longitudinal_horizons <- NULL
}

# Replicate columns. Use "all" when you need the full replicate-weight set.
if (!exists("sipp_replicate_numbers", inherits = TRUE)) {
  sipp_replicate_numbers <- 0:4
}

# Optional row limit for smoke tests or small examples. Leave Inf for full files.
if (!exists("sipp_weight_n_max", inherits = TRUE)) {
  sipp_weight_n_max <- Inf
}

if (!exists("sipp_weight_skip_unreadable", inherits = TRUE)) {
  sipp_weight_skip_unreadable <- FALSE
}

# Optional extra raw variables from weight files, if present.
if (!exists("sipp_weight_extra_vars", inherits = TRUE)) {
  sipp_weight_extra_vars <- character(0)
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

sipp_root <- resolve_sipp_root("02_load_modern_weights.R")
if (is.null(sipp_output_dir)) {
  sipp_output_dir <- file.path(sipp_root, "output")
}
dir.create(sipp_output_dir, recursive = TRUE, showWarnings = FALSE)

available_modern_years <- 2018:2024
allowed_families <- c("replicate", "longitudinal", "longitudinal_replicate")

normalize_years <- function(years) {
  if (is.null(years) || identical(tolower(years), "all")) {
    return(available_modern_years)
  }
  years <- as.integer(years)
  invalid <- setdiff(years, available_modern_years)
  if (length(invalid) > 0) {
    stop(
      "Invalid modern SIPP year(s): ", paste(invalid, collapse = ", "), "\n",
      "Choose from: ", paste(available_modern_years, collapse = ", "), ".",
      call. = FALSE
    )
  }
  unique(years)
}

normalize_families <- function(families) {
  if (is.null(families) || identical(tolower(families), "all")) {
    return(allowed_families)
  }
  families <- tolower(families)
  invalid <- setdiff(families, allowed_families)
  if (length(invalid) > 0) {
    stop(
      "Invalid SIPP weight family: ", paste(invalid, collapse = ", "), "\n",
      "Choose from: ", paste(allowed_families, collapse = ", "), ".",
      call. = FALSE
    )
  }
  unique(families)
}

normalize_vars <- function(x) {
  x <- unname(x)
  x <- x[!is.na(x) & nzchar(x)]
  unique(toupper(x))
}

normalize_replicates <- function(x) {
  if (is.null(x) || identical(tolower(x), "all")) return(NULL)
  x <- as.integer(x)
  x <- x[!is.na(x) & x >= 0]
  unique(x)
}

read_sipp_dta <- function(zip_path, keep_vars) {
  if (is.finite(sipp_weight_n_max)) {
    return(read_dta(
      zip_path,
      col_select = tidyselect::all_of(keep_vars),
      n_max = as.integer(sipp_weight_n_max)
    ))
  }
  read_dta(zip_path, col_select = tidyselect::all_of(keep_vars))
}

zip_header <- function(zip_path) {
  header <- try(read_dta(zip_path, n_max = 0), silent = TRUE)
  if (inherits(header, "try-error")) {
    stop(
      "Could not read Stata metadata from ", basename(zip_path), ": ",
      attr(header, "condition")$message,
      call. = FALSE
    )
  }
  names(header)
}

select_present <- function(header_vars, requested) {
  header_upper <- toupper(header_vars)
  requested <- normalize_vars(requested)
  present <- requested[requested %in% header_upper]
  header_vars[match(present, header_upper)]
}

select_replicate_vars <- function(header_vars) {
  header_lower <- tolower(header_vars)
  all_reps <- header_vars[grepl("^repwgt[0-9]+$", header_lower)]
  reps <- normalize_replicates(sipp_replicate_numbers)
  if (is.null(reps)) return(all_reps)
  wanted <- paste0("repwgt", reps)
  rep_lower <- tolower(all_reps)
  all_reps[match(wanted[wanted %in% rep_lower], rep_lower)]
}

candidate_zip <- function(year, family, horizon = NULL) {
  year_dir <- file.path(sipp_root, "data", as.character(year))
  if (family == "replicate") {
    return(file.path(year_dir, paste0("rw", year, "_dta.zip")))
  }
  if (family == "longitudinal") {
    if (identical(year, 2019L) && identical(as.integer(horizon), 2L)) {
      old_path <- file.path(year_dir, paste0("lgtwgt", year, "_dta.zip"))
      if (file.exists(old_path)) return(old_path)
    }
    return(file.path(year_dir, paste0("lgtwgt", year, "yr", horizon, "_dta.zip")))
  }
  if (family == "longitudinal_replicate") {
    return(file.path(year_dir, paste0("lgtrw", year, "yr", horizon, "_dta.zip")))
  }
  stop("Unknown family: ", family, call. = FALSE)
}

local_longitudinal_horizons <- function(year, family) {
  year_dir <- file.path(sipp_root, "data", as.character(year))
  if (!dir.exists(year_dir)) return(integer(0))

  if (family == "longitudinal") {
    files <- list.files(
      year_dir,
      pattern = paste0("^lgtwgt", year, "(yr[0-9]+)?_dta[.]zip$"),
      full.names = FALSE
    )
  } else {
    files <- list.files(
      year_dir,
      pattern = paste0("^lgtrw", year, "yr[0-9]+_dta[.]zip$"),
      full.names = FALSE
    )
  }

  if (length(files) == 0) return(integer(0))
  horizons <- sub(".*yr([0-9]+)_dta[.]zip$", "\\1", files)
  horizons[!grepl("^[0-9]+$", horizons)] <- "2"
  sort(unique(as.integer(horizons)))
}

selected_horizons <- function(year, family) {
  local_horizons <- local_longitudinal_horizons(year, family)
  if (is.null(sipp_longitudinal_horizons)) return(local_horizons)
  wanted <- as.integer(sipp_longitudinal_horizons)
  intersect(wanted, local_horizons)
}

standardize_panel_name <- function(data) {
  names(data) <- tolower(names(data))
  if ("panel" %in% names(data) && !"spanel" %in% names(data)) {
    names(data)[names(data) == "panel"] <- "spanel"
  }
  data
}

handle_missing <- function(message) {
  if (isTRUE(sipp_weight_skip_unreadable)) {
    warning(message, call. = FALSE)
    return(NULL)
  }
  stop(message, call. = FALSE)
}

load_replicate_year <- function(year) {
  zip_path <- candidate_zip(year, "replicate")
  if (!file.exists(zip_path)) {
    return(handle_missing(paste0("No local cross-sectional replicate-weight zip found for SIPP ", year, ".")))
  }

  header_vars <- zip_header(zip_path)
  key_vars <- select_present(header_vars, c("SSUID", "PNUM", "SPANEL", "SWAVE", "MONTHCODE"))
  rep_vars <- select_replicate_vars(header_vars)
  extra_vars <- select_present(header_vars, sipp_weight_extra_vars)
  keep_vars <- unique(c(key_vars, rep_vars, extra_vars))
  if (length(keep_vars) == 0) {
    return(handle_missing(paste0("No variables selected from SIPP ", year, " replicate-weight file.")))
  }

  cat(paste0("Reading SIPP ", year, " cross-sectional replicate weights: ", basename(zip_path), "\n"))
  data <- read_sipp_dta(zip_path, keep_vars) |>
    standardize_panel_name()
  bind_cols(
    tibble(
      source_file = paste0("rw", year, ".dta"),
      weight_family = "replicate",
      sipp_file_year = year,
      reference_year = year - 1
    ),
    data
  )
}

load_longitudinal_year <- function(year, family, horizon) {
  zip_path <- candidate_zip(year, family, horizon)
  if (!file.exists(zip_path)) {
    return(handle_missing(paste0("No local ", family, " zip found for SIPP ", year, " horizon ", horizon, ".")))
  }

  header_vars <- zip_header(zip_path)
  key_vars <- select_present(header_vars, c("SSUID", "PNUM", "SPANEL", "PANEL", "CTL_DATE", "LGTWTTYP", "INITIAL_YEAR", "FINAL_YEAR"))
  if (family == "longitudinal") {
    weight_vars <- select_present(header_vars, paste0("FINYR", horizon))
  } else {
    weight_vars <- select_replicate_vars(header_vars)
  }
  extra_vars <- select_present(header_vars, sipp_weight_extra_vars)
  keep_vars <- unique(c(key_vars, weight_vars, extra_vars))
  if (length(keep_vars) == 0) {
    return(handle_missing(paste0("No variables selected from SIPP ", year, " ", family, " file.")))
  }

  cat(paste0("Reading SIPP ", year, " ", family, " weights, horizon ", horizon, ": ", basename(zip_path), "\n"))
  data <- read_sipp_dta(zip_path, keep_vars) |>
    standardize_panel_name()
  bind_cols(
    tibble(
      source_file = basename(zip_path),
      weight_family = family,
      sipp_file_year = year,
      longitudinal_horizon = horizon
    ),
    data
  )
}

write_output <- function(data, object_name, suffix) {
  if (is.null(data) || nrow(data) == 0) return(invisible(NULL))
  assign(object_name, data, envir = .GlobalEnv)

  out_rds <- file.path(sipp_output_dir, paste0(sipp_output_basename, suffix, ".rds"))
  saveRDS(data, out_rds)
  cat(paste0("Saved ", object_name, ": ", out_rds, " (", nrow(data), " rows)\n"))

  if (isTRUE(sipp_weight_write_dta_export)) {
    out_dta <- file.path(sipp_output_dir, paste0(sipp_output_basename, suffix, "_from_r.dta"))
    write_dta(data, out_dta)
    cat(paste0("Saved optional Stata export: ", out_dta, "\n"))
  }
}

selected_years <- normalize_years(sipp_weight_years)
selected_families <- normalize_families(sipp_weight_families)
cat(paste0("Selected modern SIPP weight years: ", paste(selected_years, collapse = ", "), "\n"))
cat(paste0("Selected weight families: ", paste(selected_families, collapse = ", "), "\n"))

if ("replicate" %in% selected_families) {
  pieces <- lapply(selected_years, load_replicate_year)
  pieces <- pieces[!vapply(pieces, is.null, logical(1))]
  if (length(pieces) > 0) {
    write_output(
      bind_rows(pieces),
      "sipp_modern_replicate_weights",
      "_modern_replicate_weights_person_month"
    )
  }
}

if ("longitudinal" %in% selected_families) {
  pieces <- list()
  for (year in selected_years) {
    horizons <- selected_horizons(year, "longitudinal")
    if (length(horizons) == 0) {
      handle_missing(paste0("No local longitudinal-weight horizons found for SIPP ", year, "."))
      next
    }
    pieces <- c(pieces, lapply(horizons, function(h) load_longitudinal_year(year, "longitudinal", h)))
  }
  pieces <- pieces[!vapply(pieces, is.null, logical(1))]
  if (length(pieces) > 0) {
    write_output(
      bind_rows(pieces),
      "sipp_modern_longitudinal_weights",
      "_modern_longitudinal_weights_person"
    )
  }
}

if ("longitudinal_replicate" %in% selected_families) {
  pieces <- list()
  for (year in selected_years) {
    horizons <- selected_horizons(year, "longitudinal_replicate")
    if (length(horizons) == 0) {
      handle_missing(paste0("No local longitudinal replicate-weight horizons found for SIPP ", year, "."))
      next
    }
    pieces <- c(pieces, lapply(horizons, function(h) load_longitudinal_year(year, "longitudinal_replicate", h)))
  }
  pieces <- pieces[!vapply(pieces, is.null, logical(1))]
  if (length(pieces) > 0) {
    write_output(
      bind_rows(pieces),
      "sipp_modern_longitudinal_replicate_weights",
      "_modern_longitudinal_replicate_weights_person"
    )
  }
}
