################################################################################
# 12_load_web_mixed_mode.R
#
# Purpose: Load selected PSID web/mixed-mode supplement public-use files as
#          separate outputs.
#
# Inputs:  data/supplemental_studies/web_mixed_mode_supplement/CRCS14/
#          data/supplemental_studies/web_mixed_mode_supplement/WB2016/
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
#   psid_output_dir <- "/private/tmp/psid_web_smoke"
#   psid_web_supplements <- c("crcs14")
#   psid_web_supplements <- "all"

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
if (!exists("psid_web_supplements", inherits = TRUE)) {
  psid_web_supplements <- c("crcs14", "wb2016")
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

psid_root <- resolve_psid_root("12_load_web_mixed_mode.R")
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

web_inventory <- tibble(
  supplement_key = c("crcs14", "wb2016"),
  supplement_year = c(2014, 2016),
  folder = c("CRCS14", "WB2016"),
  base = c("CRCS14", "WB2016"),
  file_group = c("childhood_retrospective_circumstances", "wellbeing_daily_life"),
  output_suffix = c("web_crcs14", "web_wb2016")
)

available_web_supplements <- web_inventory$supplement_key

normalize_web_supplements <- function(supplements) {
  choices <- split_choices(supplements)
  if (is.null(supplements) || length(choices) == 0 || identical(tolower(choices), "all")) {
    return(available_web_supplements)
  }
  choices <- tolower(gsub("-", "_", choices))
  aliases <- c(
    crcs = "crcs14",
    childhood_retrospective = "crcs14",
    childhood_retrospective_circumstances = "crcs14",
    wb = "wb2016",
    wellbeing = "wb2016",
    wellbeing_daily_life = "wb2016"
  )
  choices <- ifelse(choices %in% names(aliases), aliases[choices], choices)
  invalid <- setdiff(choices, available_web_supplements)
  if (length(invalid) > 0) {
    stop(
      "Invalid web/mixed-mode supplement(s): ", paste(invalid, collapse = ", "), "\n",
      "Choose from: ", paste(available_web_supplements, collapse = ", "), ".",
      call. = FALSE
    )
  }
  unique(unname(choices))
}

write_web_output <- function(data, suffix) {
  out_rds <- file.path(psid_output_dir, paste0(psid_output_basename, "_", suffix, ".rds"))
  saveRDS(data, out_rds)
  cat(paste0("Saved ", suffix, ": ", out_rds, " (", nrow(data), " rows)\n"))
  if (isTRUE(psid_write_dta_export)) {
    out_dta <- file.path(psid_output_dir, paste0(psid_output_basename, "_", suffix, "_from_r.dta"))
    write_dta(data, out_dta)
    cat(paste0("Saved optional Stata export: ", out_dta, "\n"))
  }
}

load_web_supplement <- function(info) {
  raw_dir <- file.path(
    psid_root, "data", "supplemental_studies",
    "web_mixed_mode_supplement", info$folder
  )
  do_path <- file.path(raw_dir, paste0(info$base, ".do"))
  txt_path <- file.path(raw_dir, paste0(info$base, ".txt"))
  if (!file.exists(do_path) || !file.exists(txt_path)) {
    stop("Missing web/mixed-mode supplement files for ", info$base, ".", call. = FALSE)
  }

  cat(paste0("Reading PSID web/mixed-mode supplement: ", info$supplement_key, "\n"))
  spec <- parse_stata_infix_spec(do_path)
  raw <- read_psid_fwf(txt_path, spec)
  out <- bind_cols(
    tibble(
      source_module = "web_mixed_mode_supplement",
      source_file = info$base,
      supplement_year = info$supplement_year,
      file_group = info$file_group
    ),
    raw
  )
  write_web_output(out, info$output_suffix)
  invisible(out)
}

selected_supplements <- normalize_web_supplements(psid_web_supplements)
selected_inventory <- filter(web_inventory, .data$supplement_key %in% selected_supplements)

cat(paste0("Selected web/mixed-mode supplements: ", paste(selected_supplements, collapse = ", "), "\n"))

invisible(lapply(seq_len(nrow(selected_inventory)), function(i) {
  load_web_supplement(selected_inventory[i, ])
}))
