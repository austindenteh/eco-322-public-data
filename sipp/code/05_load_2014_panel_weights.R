################################################################################
# 05_load_2014_panel_weights.R
#
# Purpose: Load selected 2014 SIPP panel weight files, keeping cross-sectional
#          replicate, longitudinal final, and longitudinal replicate families
#          separate.
#
# Inputs:
#   data/2014/panel_wave{wave}/rw14w{wave}_v13.dta.gz
#   data/2014/panel_wave{wave}/lgtwgt2014pnl{wave}_v13.dta.gz
#   data/2014/panel_wave{wave}/lrw2014pnl{wave}_v13.dta.gz
################################################################################

library(dplyr)
library(haven)
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
if (!exists("sipp_2014_weight_waves", inherits = TRUE)) {
  sipp_2014_weight_waves <- c(4)
}
if (!exists("sipp_2014_weight_families", inherits = TRUE)) {
  sipp_2014_weight_families <- c("replicate")
}
# The 2014 panel files use repwt1-repwt240; there is no repwt0.
if (!exists("sipp_2014_replicate_numbers", inherits = TRUE)) {
  sipp_2014_replicate_numbers <- 1:4
}
if (!exists("sipp_2014_longitudinal_panels", inherits = TRUE)) {
  sipp_2014_longitudinal_panels <- NULL
}
if (!exists("sipp_2014_weight_n_max", inherits = TRUE)) {
  sipp_2014_weight_n_max <- Inf
}
if (!exists("sipp_2014_weight_skip_unreadable", inherits = TRUE)) {
  sipp_2014_weight_skip_unreadable <- FALSE
}
if (!exists("sipp_2014_weight_write_dta_export", inherits = TRUE)) {
  sipp_2014_weight_write_dta_export <- FALSE
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

decompress_gzip_to_temp <- function(path, suffix = ".dta") {
  out <- tempfile(fileext = suffix)
  in_con <- gzfile(path, "rb")
  out_con <- file(out, "wb")
  ok <- FALSE
  on.exit({
    try(close(in_con), silent = TRUE)
    try(close(out_con), silent = TRUE)
    if (!ok && file.exists(out)) unlink(out)
  }, add = TRUE)
  repeat {
    block <- readBin(in_con, "raw", n = 1024 * 1024)
    if (length(block) == 0) break
    writeBin(block, out_con)
  }
  close(in_con)
  close(out_con)
  ok <- TRUE
  out
}

normalize_waves <- function(waves) {
  if (is.null(waves) || identical(tolower(waves), "all")) return(1:4)
  waves <- as.integer(waves)
  invalid <- setdiff(waves, 1:4)
  if (length(invalid) > 0) {
    stop("Invalid 2014 SIPP panel wave(s): ", paste(invalid, collapse = ", "), call. = FALSE)
  }
  unique(waves)
}

normalize_families <- function(families) {
  allowed <- c("replicate", "longitudinal", "longitudinal_replicate")
  if (is.null(families) || identical(tolower(families), "all")) return(allowed)
  families <- tolower(families)
  invalid <- setdiff(families, allowed)
  if (length(invalid) > 0) {
    stop("Invalid 2014 SIPP weight family: ", paste(invalid, collapse = ", "), call. = FALSE)
  }
  unique(families)
}

normalize_replicates <- function(x, prefix) {
  if (is.null(x) || identical(tolower(x), "all")) return(NULL)
  x <- as.integer(x)
  invalid <- unique(x[!is.na(x) & x < 1])
  if (length(invalid) > 0) {
    warning(
      "2014 SIPP replicate weights start at 1; skipping invalid replicate number(s): ",
      paste(invalid, collapse = ", "),
      call. = FALSE
    )
  }
  x <- x[!is.na(x) & x >= 1]
  paste0(prefix, unique(x))
}

select_present <- function(header_vars, requested) {
  header_upper <- toupper(header_vars)
  requested <- toupper(requested)
  present <- requested[requested %in% header_upper]
  header_vars[match(present, header_upper)]
}

read_selected_dta <- function(path, keep_vars) {
  temp_dta <- decompress_gzip_to_temp(path)
  on.exit(unlink(temp_dta), add = TRUE)
  if (is.finite(sipp_2014_weight_n_max)) {
    return(read_dta(
      temp_dta,
      col_select = tidyselect::all_of(keep_vars),
      n_max = as.integer(sipp_2014_weight_n_max)
    ))
  }
  read_dta(temp_dta, col_select = tidyselect::all_of(keep_vars))
}

header_vars <- function(path) {
  temp_dta <- decompress_gzip_to_temp(path)
  on.exit(unlink(temp_dta), add = TRUE)
  names(read_dta(temp_dta, n_max = 0))
}

handle_missing <- function(message) {
  if (isTRUE(sipp_2014_weight_skip_unreadable)) {
    warning(message, call. = FALSE)
    return(NULL)
  }
  stop(message, call. = FALSE)
}

sipp_root <- resolve_sipp_root("05_load_2014_panel_weights.R")
if (is.null(sipp_output_dir)) {
  sipp_output_dir <- file.path(sipp_root, "output")
}
dir.create(sipp_output_dir, recursive = TRUE, showWarnings = FALSE)

weight_path <- function(wave, family) {
  wave_dir <- file.path(sipp_root, "data", "2014", paste0("panel_wave", wave))
  if (family == "replicate") return(file.path(wave_dir, paste0("rw14w", wave, "_v13.dta.gz")))
  if (family == "longitudinal") return(file.path(wave_dir, paste0("lgtwgt2014pnl", wave, "_v13.dta.gz")))
  if (family == "longitudinal_replicate") return(file.path(wave_dir, paste0("lrw2014pnl", wave, "_v13.dta.gz")))
  stop("Unknown 2014 SIPP weight family: ", family, call. = FALSE)
}

load_replicate_wave <- function(wave) {
  path <- weight_path(wave, "replicate")
  if (!file.exists(path)) return(handle_missing(paste0("No 2014 wave ", wave, " replicate-weight file found.")))
  hv <- header_vars(path)
  keys <- select_present(hv, c("SSUID", "PNUM", "SPANEL", "SWAVE", "MONTHCODE"))
  rep_wanted <- normalize_replicates(sipp_2014_replicate_numbers, "repwt")
  rep_vars <- hv[grepl("^repwt[0-9]+$", tolower(hv))]
  if (!is.null(rep_wanted)) rep_vars <- select_present(hv, rep_wanted)
  keep_vars <- unique(c(keys, rep_vars))
  cat(paste0("Reading 2014 SIPP wave ", wave, " replicate weights\n"))
  data <- read_selected_dta(path, keep_vars)
  names(data) <- tolower(names(data))
  bind_cols(
    tibble(
      source_file = paste0("rw14w", wave, "_v13.dta"),
      weight_family = "replicate",
      sipp_file_year = 2014L,
      panel_wave = wave
    ),
    data
  )
}

panels_for_wave <- function(wave, hv) {
  present <- as.integer(sub("^finpnl", "", grep("^finpnl[0-9]+$", tolower(hv), value = TRUE)))
  if (is.null(sipp_2014_longitudinal_panels)) return(sort(present))
  intersect(as.integer(sipp_2014_longitudinal_panels), present)
}

load_longitudinal_wave <- function(wave, family) {
  path <- weight_path(wave, family)
  if (!file.exists(path)) return(handle_missing(paste0("No 2014 wave ", wave, " ", family, " file found.")))
  hv <- header_vars(path)
  if (family == "longitudinal") {
    panels <- panels_for_wave(wave, hv)
    keys <- select_present(hv, c("SSUID", "PNUM", "SPANEL"))
    weight_vars <- select_present(hv, paste0("FINPNL", panels))
  } else {
    keys <- select_present(hv, c("SSUID", "PNUM", "SPANEL", "CTL_DATE", "LGTWTTYP", "PNLLENGTH"))
    rep_wanted <- normalize_replicates(sipp_2014_replicate_numbers, "repwgt")
    weight_vars <- hv[grepl("^repwgt[0-9]+$", tolower(hv))]
    if (!is.null(rep_wanted)) weight_vars <- select_present(hv, rep_wanted)
  }
  keep_vars <- unique(c(keys, weight_vars))
  if (length(keep_vars) == 0) return(handle_missing(paste0("No variables selected from 2014 wave ", wave, " ", family, " file.")))
  cat(paste0("Reading 2014 SIPP wave ", wave, " ", family, " weights\n"))
  data <- read_selected_dta(path, keep_vars)
  names(data) <- tolower(names(data))
  bind_cols(
    tibble(
      source_file = basename(sub("[.]gz$", "", path)),
      weight_family = family,
      sipp_file_year = 2014L,
      panel_wave = wave
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
  if (isTRUE(sipp_2014_weight_write_dta_export)) {
    out_dta <- file.path(sipp_output_dir, paste0(sipp_output_basename, suffix, "_from_r.dta"))
    write_dta(data, out_dta)
    cat(paste0("Saved optional Stata export: ", out_dta, "\n"))
  }
}

selected_waves <- normalize_waves(sipp_2014_weight_waves)
selected_families <- normalize_families(sipp_2014_weight_families)
cat(paste0("Selected 2014 SIPP weight waves: ", paste(selected_waves, collapse = ", "), "\n"))
cat(paste0("Selected 2014 SIPP weight families: ", paste(selected_families, collapse = ", "), "\n"))

if ("replicate" %in% selected_families) {
  pieces <- lapply(selected_waves, load_replicate_wave)
  pieces <- pieces[!vapply(pieces, is.null, logical(1))]
  if (length(pieces) > 0) {
    write_output(bind_rows(pieces), "sipp_2014_replicate_weights", "_2014_replicate_weights_person_month")
  }
}

if ("longitudinal" %in% selected_families) {
  pieces <- lapply(selected_waves, load_longitudinal_wave, family = "longitudinal")
  pieces <- pieces[!vapply(pieces, is.null, logical(1))]
  if (length(pieces) > 0) {
    write_output(bind_rows(pieces), "sipp_2014_longitudinal_weights", "_2014_longitudinal_weights_person")
  }
}

if ("longitudinal_replicate" %in% selected_families) {
  pieces <- lapply(selected_waves, load_longitudinal_wave, family = "longitudinal_replicate")
  pieces <- pieces[!vapply(pieces, is.null, logical(1))]
  if (length(pieces) > 0) {
    write_output(bind_rows(pieces), "sipp_2014_longitudinal_replicate_weights", "_2014_longitudinal_replicate_weights_person")
  }
}
