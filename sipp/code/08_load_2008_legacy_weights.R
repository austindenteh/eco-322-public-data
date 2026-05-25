################################################################################
# 08_load_2008_legacy_weights.R
#
# Purpose: Load selected 2008 SIPP legacy fixed-width weight files.
#
# Inputs:
#   data/2008/wave{wave}/rw08w{wave}.dat.gz
#   data/2008/lgtwgt2008w16.dat.gz
#   data/2008/longitudinal_replicate_weight_for_panel_year/lrw08pn{index}.dat.gz
#   data/2008/longitudinal_replicate_weight/lrw08cy{index}.dat.gz
################################################################################

library(dplyr)
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
if (!exists("sipp_2008_weight_families", inherits = TRUE)) {
  sipp_2008_weight_families <- c("replicate")
}
if (!exists("sipp_2008_weight_waves", inherits = TRUE)) {
  sipp_2008_weight_waves <- c(16)
}
if (!exists("sipp_2008_lrw_type", inherits = TRUE)) {
  sipp_2008_lrw_type <- if (exists("sipp_2008_longitudinal_replicate_type", inherits = TRUE)) {
    sipp_2008_longitudinal_replicate_type
  } else {
    "panel_year"
  }
}
if (!exists("sipp_2008_lrw_indices", inherits = TRUE)) {
  sipp_2008_lrw_indices <- if (exists("sipp_2008_longitudinal_replicate_indices", inherits = TRUE)) {
    sipp_2008_longitudinal_replicate_indices
  } else {
    c(5)
  }
}
if (!exists("sipp_2008_replicate_numbers", inherits = TRUE)) {
  sipp_2008_replicate_numbers <- 1:4
}
if (!exists("sipp_2008_weight_n_max", inherits = TRUE)) {
  sipp_2008_weight_n_max <- Inf
}
if (!exists("sipp_2008_weight_skip_unreadable", inherits = TRUE)) {
  sipp_2008_weight_skip_unreadable <- FALSE
}
if (!exists("sipp_2008_weight_write_dta_export", inherits = TRUE)) {
  sipp_2008_weight_write_dta_export <- FALSE
}

################################################################################
# HELPERS
################################################################################

get_current_script_dir <- function() {
  command_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", command_args, value = TRUE)
  if (length(file_arg) > 0) return(dirname(normalizePath(sub("^--file=", "", file_arg[[1]]), winslash = "/", mustWork = FALSE)))
  frame_paths <- vapply(sys.frames(), function(frame) if (!is.null(frame$ofile)) frame$ofile else "", character(1))
  frame_paths <- frame_paths[nzchar(frame_paths)]
  if (length(frame_paths) > 0) return(dirname(normalizePath(tail(frame_paths, 1), winslash = "/", mustWork = FALSE)))
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
        file.exists(file.path(path_norm, "code", script_name))) return(path_norm)
  }
  stop("Could not locate the sipp/ directory.", call. = FALSE)
}

normalize_families <- function(families) {
  allowed <- c("replicate", "longitudinal", "longitudinal_replicate")
  if (is.null(families) || identical(tolower(families), "all")) return(allowed)
  families <- tolower(families)
  invalid <- setdiff(families, allowed)
  if (length(invalid) > 0) stop("Invalid 2008 weight family: ", paste(invalid, collapse = ", "), call. = FALSE)
  unique(families)
}

normalize_waves <- function(waves) {
  if (is.null(waves) || identical(tolower(waves), "all")) return(1:16)
  unique(as.integer(waves))
}

replicate_numbers <- function(max_rep = 120) {
  if (is.null(sipp_2008_replicate_numbers) || identical(tolower(sipp_2008_replicate_numbers), "all")) return(1:max_rep)
  reps <- as.integer(sipp_2008_replicate_numbers)
  reps[!is.na(reps) & reps >= 1 & reps <= max_rep]
}

read_fwf_chars <- function(path, spec) {
  read_fwf(
    path,
    fwf_positions(spec$start, spec$end, spec$name),
    n_max = if (is.finite(sipp_2008_weight_n_max)) as.integer(sipp_2008_weight_n_max) else Inf,
    col_types = cols(.default = col_character()),
    progress = FALSE
  )
}

to_number <- function(x) suppressWarnings(as.numeric(trimws(x)))

convert_weight_data <- function(data, character_vars = "ssuid") {
  for (nm in setdiff(names(data), character_vars)) data[[nm]] <- to_number(data[[nm]])
  data
}

handle_missing <- function(message) {
  if (isTRUE(sipp_2008_weight_skip_unreadable)) {
    warning(message, call. = FALSE)
    return(NULL)
  }
  stop(message, call. = FALSE)
}

sipp_root <- resolve_sipp_root("08_load_2008_legacy_weights.R")
if (is.null(sipp_output_dir)) sipp_output_dir <- file.path(sipp_root, "output")
dir.create(sipp_output_dir, recursive = TRUE, showWarnings = FALSE)

cross_section_rep_spec <- function() {
  base <- tibble(
    name = c("ssuid", "spanel", "swave", "srefmon", "epppnum"),
    start = c(1, 13, 17, 19, 20),
    end = c(12, 16, 18, 19, 23)
  )
  reps <- replicate_numbers(120)
  bind_rows(base, tibble(name = paste0("repwgt", reps), start = 24 + (reps - 1) * 10, end = 33 + (reps - 1) * 10))
}

longitudinal_final_spec <- tibble(
  name = c("lgtkey", "spanel", "ssuid", "epppnum", paste0("lgtpn", 1:5, "wt"), paste0("lgtcy", 1:5, "wt")),
  start = c(1, 9, 13, 25, 29, 39, 49, 59, 69, 79, 89, 99, 109, 119),
  end = c(8, 12, 24, 28, 38, 48, 58, 68, 78, 88, 98, 108, 118, 128)
)

longitudinal_rep_spec <- function() {
  base <- tibble(
    name = c("ssuid", "spanel", "ctl_date", "lgtwttyp", "pnllength", "epppnum"),
    start = c(1, 13, 17, 24, 27, 29),
    end = c(12, 16, 23, 26, 28, 32)
  )
  reps <- replicate_numbers(120)
  bind_rows(base, tibble(name = paste0("repwgt", reps), start = 33 + (reps - 1) * 10, end = 42 + (reps - 1) * 10))
}

load_replicate_wave <- function(wave) {
  path <- file.path(sipp_root, "data", "2008", paste0("wave", wave), paste0("rw08w", wave, ".dat.gz"))
  if (!file.exists(path)) return(handle_missing(paste0("No 2008 replicate-weight file found for wave ", wave, ".")))
  cat(paste0("Reading 2008 SIPP replicate weights wave ", wave, "\n"))
  data <- read_fwf_chars(path, cross_section_rep_spec()) |> convert_weight_data()
  data$pnum <- data$epppnum
  bind_cols(tibble(source_file = paste0("rw08w", wave, ".dat"), weight_family = "replicate", sipp_file_year = 2008L, panel_wave = wave), data)
}

load_longitudinal_final <- function() {
  path <- file.path(sipp_root, "data", "2008", "lgtwgt2008w16.dat.gz")
  if (!file.exists(path)) return(handle_missing("No 2008 longitudinal final weight file found."))
  cat("Reading 2008 SIPP longitudinal final weights\n")
  data <- read_fwf_chars(path, longitudinal_final_spec) |> convert_weight_data()
  data$pnum <- data$epppnum
  bind_cols(tibble(source_file = "lgtwgt2008w16.dat", weight_family = "longitudinal", sipp_file_year = 2008L), data)
}

load_longitudinal_replicate <- function(index) {
  type <- match.arg(tolower(sipp_2008_lrw_type), c("panel_year", "calendar_year"))
  if (type == "panel_year") {
    path <- file.path(sipp_root, "data", "2008", "longitudinal_replicate_weight_for_panel_year", paste0("lrw08pn", index, ".dat.gz"))
    source <- paste0("lrw08pn", index, ".dat")
  } else {
    path <- file.path(sipp_root, "data", "2008", "longitudinal_replicate_weight", paste0("lrw08cy", index, ".dat.gz"))
    source <- paste0("lrw08cy", index, ".dat")
  }
  if (!file.exists(path)) return(handle_missing(paste0("No 2008 longitudinal replicate file found: ", source)))
  cat(paste0("Reading 2008 SIPP longitudinal replicate weights: ", source, "\n"))
  data <- read_fwf_chars(path, longitudinal_rep_spec()) |> convert_weight_data(character_vars = c("ssuid", "ctl_date", "lgtwttyp"))
  data$pnum <- data$epppnum
  bind_cols(
    tibble(
      source_file = source,
      weight_family = "longitudinal_replicate",
      sipp_file_year = 2008L,
      longitudinal_replicate_type = type,
      longitudinal_index = index
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
  if (isTRUE(sipp_2008_weight_write_dta_export) && requireNamespace("haven", quietly = TRUE)) {
    haven::write_dta(data, file.path(sipp_output_dir, paste0(sipp_output_basename, suffix, "_from_r.dta")))
  }
}

families <- normalize_families(sipp_2008_weight_families)
cat(paste0("Selected 2008 SIPP weight families: ", paste(families, collapse = ", "), "\n"))

if ("replicate" %in% families) {
  pieces <- lapply(normalize_waves(sipp_2008_weight_waves), load_replicate_wave)
  pieces <- pieces[!vapply(pieces, is.null, logical(1))]
  if (length(pieces) > 0) write_output(bind_rows(pieces), "sipp_2008_replicate_weights", "_2008_replicate_weights_person_month")
}

if ("longitudinal" %in% families) {
  write_output(load_longitudinal_final(), "sipp_2008_longitudinal_weights", "_2008_longitudinal_weights_person")
}

if ("longitudinal_replicate" %in% families) {
  pieces <- lapply(as.integer(sipp_2008_lrw_indices), load_longitudinal_replicate)
  pieces <- pieces[!vapply(pieces, is.null, logical(1))]
  if (length(pieces) > 0) write_output(bind_rows(pieces), "sipp_2008_longitudinal_replicate_weights", "_2008_longitudinal_replicate_weights_person")
}
