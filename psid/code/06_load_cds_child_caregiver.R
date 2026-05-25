################################################################################
# 06_load_cds_child_caregiver.R
#
# Purpose: Load selected PSID Child Development Supplement (CDS) child,
#          caregiver, roster, demographic, and support files as separate outputs.
#
# Inputs:  data/supplemental_studies/child_development_supplement/{wave}/
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
#   psid_output_dir <- "/private/tmp/psid_cds_cc_smoke"
#   psid_cds_child_caregiver_waves <- c(2019, 2020)
#   psid_cds_child_caregiver_waves <- NULL
#   psid_cds_child_caregiver_files <- c("child", "pcg_child")

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
if (!exists("psid_cds_child_caregiver_waves", inherits = TRUE)) {
  psid_cds_child_caregiver_waves <- c(2019, 2020, 2021)
}
if (!exists("psid_cds_child_caregiver_files", inherits = TRUE)) {
  psid_cds_child_caregiver_files <- "all"
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

psid_root <- resolve_psid_root("06_load_cds_child_caregiver.R")
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
  unique(tolower(gsub("-", "_", x)))
}

cds_child_caregiver_inventory <- tibble::tribble(
  ~wave, ~folder, ~base, ~file_key, ~file_group,
  1997, "1997", "DEMOG1997", "demog", "demographic",
  1997, "1997", "IDMAP97", "id_map", "support",
  1997, "1997", "PCG97_CHLD", "pcg_child", "primary_caregiver_child",
  1997, "1997", "PCG97_HH", "pcg_household", "primary_caregiver_household",
  1997, "1997", "OCG_CHLD97", "ocg_child", "other_caregiver_child",
  1997, "1997", "OCG_HHLD97", "ocg_household", "other_caregiver_household",
  1997, "1997", "FOH_CHLD97", "foh_child", "father_outside_home_child",
  1997, "1997", "FOH_HHLD97", "foh_household", "father_outside_home_household",
  2002, "2002", "DEMOG", "demog", "demographic",
  2002, "2002", "GEN_MAP", "generational_map", "support",
  2002, "2002", "IDMAP02", "id_map", "support",
  2002, "2002", "CHILD", "child", "child_interview",
  2002, "2002", "PCG_CHLD", "pcg_child", "primary_caregiver_child",
  2002, "2002", "PCG_HHLD", "pcg_household", "primary_caregiver_household",
  2002, "2002", "OCG_CHLD", "ocg_child", "other_caregiver_child",
  2002, "2002", "OCG_HHLD", "ocg_household", "other_caregiver_household",
  2007, "2007", "DEMOG07", "demog", "demographic",
  2007, "2007", "GENMAP07", "generational_map", "support",
  2007, "2007", "IDMAP07", "id_map", "support",
  2007, "2007", "CHILD07", "child", "child_interview",
  2007, "2007", "PCG_CHILD07", "pcg_child", "primary_caregiver_child",
  2007, "2007", "PCG_HH07", "pcg_household", "primary_caregiver_household",
  2007, "2007", "OCG_CHILD07", "ocg_child", "other_caregiver_child",
  2007, "2007", "OCG_HH07", "ocg_household", "other_caregiver_household",
  2014, "2014", "DEMOG14", "demog", "demographic",
  2014, "2014", "HHROSTER14", "household_roster", "household_roster",
  2014, "2014", "IDMAP14", "id_map", "support",
  2014, "2014", "CHILD14", "child", "child_interview",
  2014, "2014", "PCGCHILD14", "pcg_child", "primary_caregiver_child",
  2014, "2014", "PCGHH14", "pcg_household", "primary_caregiver_household",
  2019, "2019", "DEMOG2019", "demog", "demographic",
  2019, "2019", "HHROSTER2019", "household_roster", "household_roster",
  2019, "2019", "CHILD2019", "child", "child_interview",
  2019, "2019", "PCGCHILD2019", "pcg_child", "primary_caregiver_child",
  2019, "2019", "PCGHH2019", "pcg_household", "primary_caregiver_household",
  2020, "2020", "DEMOG2019", "demog_2019_carryover", "demographic",
  2020, "2020", "HHROSTER2019", "household_roster_2019_carryover", "household_roster",
  2020, "2020", "CVH2020", "covid_health", "covid_health",
  2020, "2020", "PCGCHILD2020", "pcg_child", "primary_caregiver_child",
  2020, "2020", "PCGHH2020", "pcg_household", "primary_caregiver_household",
  2021, "2021", "DEMOG2021", "demog", "demographic",
  2021, "2021", "HHROSTER2021", "household_roster", "household_roster",
  2021, "2021", "CHILD2021", "child", "child_interview",
  2021, "2021", "PCGCHILD2021", "pcg_child", "primary_caregiver_child",
  2021, "2021", "PCGHH2021", "pcg_household", "primary_caregiver_household"
)

available_cds_child_caregiver_waves <- unique(cds_child_caregiver_inventory$wave)

normalize_cds_waves <- function(waves) {
  choices <- split_choices(waves)
  if (is.null(waves) || length(choices) == 0 || any(choices == "all")) {
    return(available_cds_child_caregiver_waves)
  }
  waves <- as.integer(choices)
  invalid <- setdiff(waves, available_cds_child_caregiver_waves)
  if (length(invalid) > 0) {
    stop(
      "Invalid CDS child/caregiver wave(s): ", paste(invalid, collapse = ", "), "\n",
      "Choose from: ", paste(available_cds_child_caregiver_waves, collapse = ", "), ".",
      call. = FALSE
    )
  }
  unique(waves)
}

filter_cds_files <- function(inventory, files) {
  choices <- split_choices(files)
  if (is.null(files) || length(choices) == 0 || any(choices == "all")) {
    return(inventory)
  }
  matches <- inventory$file_key %in% choices | inventory$file_group %in% choices
  invalid <- setdiff(choices, c(inventory$file_key, inventory$file_group))
  if (length(invalid) > 0) {
    stop(
      "Invalid CDS child/caregiver file selection(s): ", paste(invalid, collapse = ", "), "\n",
      "Select file keys or groups from the loader inventory.",
      call. = FALSE
    )
  }
  inventory[matches, ]
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

load_cds_component_file <- function(info) {
  raw_dir <- file.path(
    psid_root, "data", "supplemental_studies",
    "child_development_supplement", info$folder
  )
  do_path <- file.path(raw_dir, paste0(info$base, ".do"))
  txt_path <- file.path(raw_dir, paste0(info$base, ".txt"))
  if (!file.exists(do_path) || !file.exists(txt_path)) {
    stop("Missing CDS child/caregiver files for ", info$base, ".", call. = FALSE)
  }

  cat(paste0("Reading PSID CDS ", info$wave, " ", info$file_key, "\n"))
  spec <- parse_stata_infix_spec(do_path)
  raw <- read_psid_fwf(txt_path, spec)
  out <- bind_cols(
    tibble(
      source_module = "child_development_supplement",
      source_file = info$base,
      survey_year = info$wave,
      file_key = info$file_key,
      file_group = info$file_group
    ),
    raw
  )
  write_cds_output(out, paste0("cds_child_caregiver_", info$wave, "_", info$file_key))
  invisible(out)
}

selected_waves <- normalize_cds_waves(psid_cds_child_caregiver_waves)
selected_inventory <- filter(
  cds_child_caregiver_inventory,
  .data$wave %in% selected_waves
)
selected_inventory <- filter_cds_files(selected_inventory, psid_cds_child_caregiver_files)

if (nrow(selected_inventory) == 0) {
  stop("No CDS child/caregiver files match the requested waves and file selection.", call. = FALSE)
}

cat(paste0("Selected CDS child/caregiver waves: ", paste(selected_waves, collapse = ", "), "\n"))
cat(paste0("Selected CDS child/caregiver files: ", paste(unique(selected_inventory$file_key), collapse = ", "), "\n"))

invisible(lapply(seq_len(nrow(selected_inventory)), function(i) {
  load_cds_component_file(selected_inventory[i, ])
}))
