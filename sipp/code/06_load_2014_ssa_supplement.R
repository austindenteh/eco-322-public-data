################################################################################
# 06_load_2014_ssa_supplement.R
#
# Purpose: Load the 2014 SIPP SSA Supplement primary file and, optionally, its
#          fixed-width replicate-weight file.
#
# Inputs:
#   data/2014/ssa_supplement/pu2014ssa.dta.gz
#   data/2014/ssa_supplement/rw14SSA.dat.gz
################################################################################

library(dplyr)
library(haven)
library(readr)
library(tibble)

################################################################################
# USER SETTINGS
################################################################################

if (!exists("sipp_root_manual", inherits = TRUE)) {
  sipp_root_manual <- NULL
}
if (!exists("sipp_output_dir", inherits = TRUE)) {
  sipp_output_dir <- NULL
}
if (!exists("sipp_output_basename", inherits = TRUE)) {
  sipp_output_basename <- "sipp"
}
if (!exists("sipp_ssa_families", inherits = TRUE)) {
  sipp_ssa_families <- c("primary")
}
if (!exists("sipp_ssa_n_max", inherits = TRUE)) {
  sipp_ssa_n_max <- Inf
}
if (!exists("sipp_ssa_replicate_numbers", inherits = TRUE)) {
  sipp_ssa_replicate_numbers <- 1:4
}
if (!exists("sipp_ssa_write_dta_export", inherits = TRUE)) {
  sipp_ssa_write_dta_export <- FALSE
}
if (!exists("sipp_ssa_extra_vars", inherits = TRUE)) {
  sipp_ssa_extra_vars <- character(0)
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

normalize_families <- function(families) {
  allowed <- c("primary", "replicate")
  if (is.null(families) || identical(tolower(families), "all")) return(allowed)
  families <- tolower(families)
  invalid <- setdiff(families, allowed)
  if (length(invalid) > 0) stop("Invalid SSA family: ", paste(invalid, collapse = ", "), call. = FALSE)
  unique(families)
}

select_present <- function(header_vars, requested) {
  header_lower <- tolower(header_vars)
  requested <- tolower(requested)
  present <- requested[requested %in% header_lower]
  header_vars[match(present, header_lower)]
}

extract_ssa_primary <- function(path) {
  temp_dir <- tempfile()
  dir.create(temp_dir)
  files <- try(utils::unzip(path, exdir = temp_dir), silent = TRUE)
  if (inherits(files, "try-error")) {
    stop("Could not unzip 2014 SSA primary file. The local file uses a zip container despite its .gz suffix.", call. = FALSE)
  }
  dta_files <- list.files(temp_dir, pattern = "[.]dta$", full.names = TRUE, recursive = TRUE)
  if (length(dta_files) == 0) stop("No .dta found inside 2014 SSA primary archive.", call. = FALSE)
  dta_files[[1]]
}

sipp_root <- resolve_sipp_root("06_load_2014_ssa_supplement.R")
if (is.null(sipp_output_dir)) {
  sipp_output_dir <- file.path(sipp_root, "output")
}
dir.create(sipp_output_dir, recursive = TRUE, showWarnings = FALSE)

ssa_primary_vars <- c(
  "ssuid", "pnum", "spanel", "swave", "monthcode", "ssa_pfinwgt",
  "ghlfsam", "gvarstr", "rfamnum", "tmetro_intv", "tst_intv",
  "aage_s", "tage_s", "esex_s", "eorigin", "erace", "eeduc", "ems_s",
  "eintype", "ssaintstat", "rssmc", "emainjobid", "ermnjbbs", "tjobhrs",
  "t1yrsinc", "epensnyn", "eincpens", "tpayamt", "tiraamt", "tthftamt",
  "tlumptot", "tpenamt1", "tpensamt", "rdisab", "rkdisab"
)

load_ssa_primary <- function() {
  path <- file.path(sipp_root, "data", "2014", "ssa_supplement", "pu2014ssa.dta.gz")
  if (!file.exists(path)) stop("No local 2014 SSA primary file found: ", path, call. = FALSE)
  temp_dta <- extract_ssa_primary(path)
  hv <- names(read_dta(temp_dta, n_max = 0))
  keep_vars <- unique(c(select_present(hv, ssa_primary_vars), select_present(hv, sipp_ssa_extra_vars)))
  if (length(keep_vars) == 0) stop("No variables selected from 2014 SSA primary file.", call. = FALSE)
  cat("Reading 2014 SIPP SSA Supplement primary file\n")
  if (is.finite(sipp_ssa_n_max)) {
    data <- read_dta(temp_dta, col_select = tidyselect::all_of(keep_vars), n_max = as.integer(sipp_ssa_n_max))
  } else {
    data <- read_dta(temp_dta, col_select = tidyselect::all_of(keep_vars))
  }
  names(data) <- tolower(names(data))
  bind_cols(
    tibble(
      source_file = "pu2014ssa.dta",
      file_family = "ssa_primary",
      sipp_file_year = 2014L
    ),
    data
  )
}

ssa_rep_spec <- function() {
  base <- tibble(
    name = c("ssuid", "swave", "spanel", "monthcode", "pnum"),
    start = c(1, 13, 16, 20, 22),
    end = c(12, 15, 19, 21, 25)
  )
  reps <- if (is.null(sipp_ssa_replicate_numbers) || identical(tolower(sipp_ssa_replicate_numbers), "all")) {
    1:240
  } else {
    as.integer(sipp_ssa_replicate_numbers)
  }
  reps <- reps[!is.na(reps) & reps >= 1 & reps <= 240]
  rep_starts <- 26 + (reps - 1) * 12
  bind_rows(base, tibble(name = paste0("repwgt", reps), start = rep_starts, end = rep_starts + 11))
}

load_ssa_replicates <- function() {
  path <- file.path(sipp_root, "data", "2014", "ssa_supplement", "rw14SSA.dat.gz")
  if (!file.exists(path)) stop("No local 2014 SSA replicate-weight file found: ", path, call. = FALSE)
  spec <- ssa_rep_spec()
  cat("Reading 2014 SIPP SSA Supplement replicate weights\n")
  data <- read_fwf(
    path,
    fwf_positions(spec$start, spec$end, spec$name),
    n_max = if (is.finite(sipp_ssa_n_max)) as.integer(sipp_ssa_n_max) else Inf,
    col_types = cols(.default = col_character()),
    progress = FALSE
  )
  for (nm in setdiff(names(data), "ssuid")) {
    data[[nm]] <- suppressWarnings(as.numeric(trimws(data[[nm]])))
  }
  bind_cols(
    tibble(
      source_file = "rw14SSA.dat",
      file_family = "ssa_replicate",
      sipp_file_year = 2014L
    ),
    data
  )
}

selected_families <- normalize_families(sipp_ssa_families)
cat(paste0("Selected 2014 SSA families: ", paste(selected_families, collapse = ", "), "\n"))

if ("primary" %in% selected_families) {
  sipp_2014_ssa_primary <- load_ssa_primary()
  out_rds <- file.path(sipp_output_dir, paste0(sipp_output_basename, "_2014_ssa_primary.rds"))
  saveRDS(sipp_2014_ssa_primary, out_rds)
  cat(paste0("Saved 2014 SIPP SSA primary file: ", out_rds, " (", nrow(sipp_2014_ssa_primary), " rows)\n"))
  if (isTRUE(sipp_ssa_write_dta_export)) {
    out_dta <- file.path(sipp_output_dir, paste0(sipp_output_basename, "_2014_ssa_primary_from_r.dta"))
    write_dta(sipp_2014_ssa_primary, out_dta)
  }
}

if ("replicate" %in% selected_families) {
  sipp_2014_ssa_replicate_weights <- load_ssa_replicates()
  out_rds <- file.path(sipp_output_dir, paste0(sipp_output_basename, "_2014_ssa_replicate_weights.rds"))
  saveRDS(sipp_2014_ssa_replicate_weights, out_rds)
  cat(paste0("Saved 2014 SIPP SSA replicate weights: ", out_rds, " (", nrow(sipp_2014_ssa_replicate_weights), " rows)\n"))
  if (isTRUE(sipp_ssa_write_dta_export)) {
    out_dta <- file.path(sipp_output_dir, paste0(sipp_output_basename, "_2014_ssa_replicate_weights_from_r.dta"))
    write_dta(sipp_2014_ssa_replicate_weights, out_dta)
  }
}
