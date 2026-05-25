################################################################################
# 12_load_2008_welfare_retirement_pension.R
#
# Purpose: Load 2008 SIPP topical waves with welfare reform and retirement or
#          pension-plan coverage content.
#
# Inputs: data/2008/wave3/ and data/2008/wave11/ topical files
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

# Wave 3 includes welfare reform and pensions; wave 11 is pensions only.
if (!exists("sipp_2008_welfare_retirement_pension_waves", inherits = TRUE)) {
  sipp_2008_welfare_retirement_pension_waves <- c(3, 11)
}
if (!exists("sipp_2008_welfare_retirement_pension_n_max", inherits = TRUE)) {
  sipp_2008_welfare_retirement_pension_n_max <- Inf
}
if (!exists("sipp_2008_welfare_retirement_pension_keep_all", inherits = TRUE)) {
  sipp_2008_welfare_retirement_pension_keep_all <- FALSE
}
if (!exists("sipp_2008_welfare_retirement_pension_allocs", inherits = TRUE)) {
  sipp_2008_welfare_retirement_pension_allocs <- FALSE
}
if (!exists("sipp_2008_welfare_retirement_pension_extra_vars", inherits = TRUE)) {
  sipp_2008_welfare_retirement_pension_extra_vars <- character()
}
if (!exists("sipp_2008_welfare_retirement_pension_write_dta_export", inherits = TRUE)) {
  sipp_2008_welfare_retirement_pension_write_dta_export <- FALSE
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

sipp_2008_tm_waves <- sipp_2008_welfare_retirement_pension_waves
sipp_2008_tm_n_max <- sipp_2008_welfare_retirement_pension_n_max
sipp_2008_tm_keep_all <- sipp_2008_welfare_retirement_pension_keep_all
sipp_2008_tm_allocs <- sipp_2008_welfare_retirement_pension_allocs
sipp_2008_tm_extra_vars <- sipp_2008_welfare_retirement_pension_extra_vars
sipp_2008_tm_write_dta_export <- sipp_2008_welfare_retirement_pension_write_dta_export
sipp_2008_tm_family_tag <- "welfare_retirement_pension"
sipp_2008_tm_family_label <- "Welfare reform and retirement or pension-plan coverage"
sipp_2008_tm_family_note <- "Family-tagged topical extract for waves 3 and 11; wave 3 includes welfare reform content, and neither wave is a harmonized cleaner."

source(find_sipp_loader("09_load_2008_topical_modules.R"))
sipp_2008_welfare_retirement_pension <- sipp_2008_topical_modules
