################################################################################
# 10_load_2008_recipiency_employment_history.R
#
# Purpose: Load the 2008 SIPP topical wave for recipiency history, employment
#          history, and tax rebates as a family-tagged topical extract.
#
# Inputs: data/2008/wave1/p08putm1.dat.gz and p08putm1.sas
################################################################################

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

# Wave 1 contains recipiency history, employment history, and tax rebates.
if (!exists("sipp_2008_recipiency_employment_history_waves", inherits = TRUE)) {
  sipp_2008_recipiency_employment_history_waves <- c(1)
}

# Optional row limit for smoke tests or examples. Leave Inf for full files.
if (!exists("sipp_2008_recipiency_employment_history_n_max", inherits = TRUE)) {
  sipp_2008_recipiency_employment_history_n_max <- Inf
}

# Defaults keep non-allocation variables and skip FILLER fields.
if (!exists("sipp_2008_recipiency_employment_history_keep_all", inherits = TRUE)) {
  sipp_2008_recipiency_employment_history_keep_all <- FALSE
}
if (!exists("sipp_2008_recipiency_employment_history_allocs", inherits = TRUE)) {
  sipp_2008_recipiency_employment_history_allocs <- FALSE
}
if (!exists("sipp_2008_recipiency_employment_history_extra_vars", inherits = TRUE)) {
  sipp_2008_recipiency_employment_history_extra_vars <- character()
}
if (!exists("sipp_2008_recipiency_employment_history_write_dta_export", inherits = TRUE)) {
  sipp_2008_recipiency_employment_history_write_dta_export <- FALSE
}

################################################################################
# RUN FAMILY EXTRACT
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

find_sipp_loader <- function(file) {
  script_dir <- get_current_script_dir()
  candidates <- c(
    if (!is.null(sipp_root_manual)) file.path(sipp_root_manual, "code", file),
    file.path(getwd(), "code", file),
    file.path(getwd(), file),
    file.path(getwd(), "sipp", "code", file),
    file.path(script_dir, file),
    file.path(dirname(script_dir), "code", file)
  )
  candidates <- unique(candidates[!is.na(candidates) & nzchar(candidates)])
  hit <- candidates[file.exists(candidates)]
  if (length(hit) == 0) stop("Could not locate ", file, ". Run from sipp/, sipp/code/, repo root, or set sipp_root_manual.", call. = FALSE)
  normalizePath(hit[[1]], winslash = "/", mustWork = TRUE)
}

sipp_2008_tm_waves <- sipp_2008_recipiency_employment_history_waves
sipp_2008_tm_n_max <- sipp_2008_recipiency_employment_history_n_max
sipp_2008_tm_keep_all <- sipp_2008_recipiency_employment_history_keep_all
sipp_2008_tm_allocs <- sipp_2008_recipiency_employment_history_allocs
sipp_2008_tm_extra_vars <- sipp_2008_recipiency_employment_history_extra_vars
sipp_2008_tm_write_dta_export <- sipp_2008_recipiency_employment_history_write_dta_export
sipp_2008_tm_family_tag <- "recipiency_employment_history"
sipp_2008_tm_family_label <- "Recipiency history, employment history, and tax rebates"
sipp_2008_tm_family_note <- "Family-tagged topical extract for wave 1; it is not a harmonized cleaner."

source(find_sipp_loader("09_load_2008_topical_modules.R"))
sipp_2008_recipiency_employment_history <- sipp_2008_topical_modules
