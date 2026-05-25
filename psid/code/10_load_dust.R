################################################################################
# 10_load_dust.R
#
# Purpose: Load selected PSID Disability and Use of Time Supplement (DUST)
#          public-use files as separate file-group outputs.
#
# Inputs:  data/supplemental_studies/disability_and_time_use/dust09/
#          data/supplemental_studies/disability_and_time_use/dust13/
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
#   psid_output_dir <- "/private/tmp/psid_dust_smoke"
#   psid_dust_years <- c(2013)
#   psid_dust_years <- NULL
#   psid_dust_files <- c("household", "activity")

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
if (!exists("psid_dust_years", inherits = TRUE)) {
  psid_dust_years <- c(2009, 2013)
}
if (!exists("psid_dust_files", inherits = TRUE)) {
  psid_dust_files <- c("household", "flat", "observations", "activity", "parent_child")
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

psid_root <- resolve_psid_root("10_load_dust.R")
if (is.null(psid_output_dir)) {
  psid_output_dir <- file.path(psid_root, "output")
}
dir.create(psid_output_dir, recursive = TRUE, showWarnings = FALSE)

parse_stata_infix_spec <- function(do_path) {
  txt_lines <- readLines(do_path, warn = FALSE)
  infix_start <- grep("^\\s*infix\\b", txt_lines, ignore.case = TRUE)[1]
  using_line <- grep("^\\s*using\\s+\\[path\\]", txt_lines, ignore.case = TRUE)
  using_line <- using_line[using_line > infix_start][1]
  if (!is.na(infix_start) && !is.na(using_line) && using_line > infix_start) {
    txt_lines <- txt_lines[infix_start:(using_line - 1)]
  }
  txt <- paste(txt_lines, collapse = "\n")
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

read_psid_fwf <- function(txt_path, spec) {
  read_fwf(
    txt_path,
    fwf_positions(spec$start, spec$end, spec$name_lower),
    col_types = cols(.default = col_double()),
    progress = FALSE,
    show_col_types = FALSE
  )
}

split_choices <- function(x) {
  x <- unlist(strsplit(as.character(x), "[,[:space:]]+"), use.names = FALSE)
  x <- x[nzchar(x)]
  unique(x)
}

dust_inventory <- tibble(
  year = c(2009, 2009, 2009, 2009, 2013, 2013, 2013, 2013, 2013),
  file_group = c(
    "household", "flat", "observations", "activity",
    "household", "flat", "observations", "activity", "parent_child"
  ),
  folder = c(
    rep("dust09", 4),
    rep("dust13", 5)
  ),
  base = c(
    "DUST09_HH", "DUST09_FLAT", "DUST09_OBS", "DUST09_ACT",
    "DUST13_HH", "DUST13_FLAT", "DUST13_OBS", "DUST13_ACT", "DUST13_WHO"
  ),
  output_suffix = c(
    "dust_2009_household", "dust_2009_flat", "dust_2009_observations",
    "dust_2009_activity", "dust_2013_household", "dust_2013_flat",
    "dust_2013_observations", "dust_2013_activity", "dust_2013_parent_child"
  )
)

available_dust_years <- unique(dust_inventory$year)
available_dust_files <- unique(dust_inventory$file_group)

normalize_dust_years <- function(years) {
  choices <- split_choices(years)
  if (is.null(years) || length(choices) == 0 || identical(tolower(choices), "all")) {
    return(available_dust_years)
  }
  years <- as.integer(choices)
  invalid <- setdiff(years, available_dust_years)
  if (length(invalid) > 0) {
    stop(
      "Invalid DUST year(s): ", paste(invalid, collapse = ", "), "\n",
      "Choose from: ", paste(available_dust_years, collapse = ", "), ".",
      call. = FALSE
    )
  }
  unique(years)
}

normalize_dust_files <- function(files) {
  choices <- split_choices(files)
  if (is.null(files) || length(choices) == 0 || identical(tolower(choices), "all")) {
    return(available_dust_files)
  }
  choices <- tolower(gsub("-", "_", choices))
  aliases <- c(
    hh = "household",
    obs = "observations",
    observation = "observations",
    act = "activity",
    who = "parent_child",
    parentchild = "parent_child",
    parent_child = "parent_child"
  )
  choices <- ifelse(choices %in% names(aliases), aliases[choices], choices)
  invalid <- setdiff(choices, available_dust_files)
  if (length(invalid) > 0) {
    stop(
      "Invalid DUST file group(s): ", paste(invalid, collapse = ", "), "\n",
      "Choose from: ", paste(available_dust_files, collapse = ", "), ".",
      call. = FALSE
    )
  }
  unique(unname(choices))
}

write_dust_output <- function(data, suffix) {
  out_rds <- file.path(psid_output_dir, paste0(psid_output_basename, "_", suffix, ".rds"))
  saveRDS(data, out_rds)
  cat(paste0("Saved ", suffix, ": ", out_rds, " (", nrow(data), " rows)\n"))
  if (isTRUE(psid_write_dta_export)) {
    out_dta <- file.path(psid_output_dir, paste0(psid_output_basename, "_", suffix, "_from_r.dta"))
    write_dta(data, out_dta)
    cat(paste0("Saved optional Stata export: ", out_dta, "\n"))
  }
}

load_dust_file <- function(info) {
  raw_dir <- file.path(
    psid_root, "data", "supplemental_studies",
    "disability_and_time_use", info$folder
  )
  do_path <- file.path(raw_dir, paste0(info$base, ".do"))
  txt_path <- file.path(raw_dir, paste0(info$base, ".txt"))
  if (!file.exists(do_path) || !file.exists(txt_path)) {
    stop("Missing DUST files for ", info$base, ".", call. = FALSE)
  }

  cat(paste0("Reading PSID DUST ", info$year, " ", info$file_group, "\n"))
  spec <- parse_stata_infix_spec(do_path)
  raw <- read_psid_fwf(txt_path, spec)
  out <- bind_cols(
    tibble(
      source_module = "disability_and_time_use",
      source_file = info$base,
      supplement_year = info$year,
      file_group = info$file_group
    ),
    raw
  )
  write_dust_output(out, info$output_suffix)
  invisible(out)
}

selected_years <- normalize_dust_years(psid_dust_years)
selected_files <- normalize_dust_files(psid_dust_files)
selected_inventory <- filter(
  dust_inventory,
  .data$year %in% selected_years,
  .data$file_group %in% selected_files
)

if (nrow(selected_inventory) == 0) {
  stop(
    "No DUST files match the requested years and file groups. ",
    "The parent_child file is available only in 2013.",
    call. = FALSE
  )
}

cat(paste0("Selected DUST years: ", paste(selected_years, collapse = ", "), "\n"))
cat(paste0("Selected DUST file groups: ", paste(selected_files, collapse = ", "), "\n"))

invisible(lapply(seq_len(nrow(selected_inventory)), function(i) {
  load_dust_file(selected_inventory[i, ])
}))
