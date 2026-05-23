################################################################################
# 01_load_and_append_optional_low_memory.R
#
# Purpose: Optional low-memory entry point for the NHIS starter.
#          Runs 01_load_and_append.R with starter-variable mode enabled, so
#          full 2004-2024 builds keep only the columns needed by
#          02_clean_and_analyze.R plus user-requested extras.
#
# Important: This script reuses the main NHIS loader and harmonization logic.
#            It does NOT import every raw variable. If you need most raw NHIS
#            columns, use 01_load_and_append.R without low-memory mode.
#
# Input:   data/NHIS YYYY/ folders
# Output:  output/nhis_adult.rds
#          output/nhis_child.rds
#          optional output/nhis_adult_from_r.dta / nhis_child_from_r.dta
#
# Usage:   Run from nhis/, from nhis/code/, from the repo root, or set
#          nhis_root_manual / NHIS_ROOT.
#
# Author:  Austin Denteh (legacy code), Claude Code, and Codex
# Date:    May 2026
################################################################################

# Optional manual path override. Leave as NULL for auto-detection.
# Example:
# nhis_root_manual <- "/Users/yourname/path/to/econ-data-starters/nhis"
if (!exists("nhis_root_manual", inherits = TRUE)) {
  nhis_root_manual <- NULL
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

resolve_nhis_root <- function(script_name) {
  env_root <- Sys.getenv("NHIS_ROOT", unset = "")

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
  candidates <- c(nhis_root_manual, env_root, search_paths, file.path(search_paths, "nhis"))
  candidates <- unique(candidates[!is.na(candidates) & nzchar(candidates)])

  for (path in candidates) {
    path_norm <- normalizePath(path, winslash = "/", mustWork = FALSE)
    if (file.exists(file.path(path_norm, "README.md")) &&
        file.exists(file.path(path_norm, "code", script_name))) {
      return(path_norm)
    }
  }

  stop(
    "Could not locate the nhis/ directory.\n",
    "Run this script from nhis/, nhis/code/, from the repo root, ",
    "or set nhis_root_manual / NHIS_ROOT to the nhis path.\n",
    paste0("Current working directory: ", getwd(), "\n"),
    'Manual override in this script: nhis_root_manual <- "/path/to/nhis"\n',
    'Manual override before sourcing: Sys.setenv(NHIS_ROOT = "/path/to/nhis")',
    call. = FALSE
  )
}

nhis_root <- resolve_nhis_root("01_load_and_append_optional_low_memory.R")
nhis_root_manual <- nhis_root

# Default to the full NHIS span in the optional low-memory entry point.
# Override these before sourcing this script if you want a smaller test run.
if (!exists("pre2019_years", inherits = TRUE)) {
  pre2019_years <- 2004:2018
}
if (!exists("post2019_years", inherits = TRUE)) {
  post2019_years <- 2019:2024
}

# Enable low-memory mode in the main loader. Add stable-name extras or alias
# families before sourcing this script.
keep_starter_vars_only <- TRUE
if (!exists("extra_vars", inherits = TRUE)) {
  extra_vars <- character(0)
}
if (!exists("extra_var_families", inherits = TRUE)) {
  extra_var_families <- list()
}
if (!exists("write_dta_export", inherits = TRUE)) {
  write_dta_export <- FALSE
}

source(file.path(nhis_root, "code", "01_load_and_append.R"))
