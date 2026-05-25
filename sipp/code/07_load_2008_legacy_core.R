################################################################################
# 07_load_2008_legacy_core.R
#
# Purpose: Load selected 2008 SIPP legacy fixed-width core waves into a compact
#          person-month starter file.
#
# Inputs: data/2008/wave{wave}/l08puw{wave}.dat.gz
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
if (!exists("sipp_2008_waves", inherits = TRUE)) {
  sipp_2008_waves <- c(16)
}
if (!exists("sipp_2008_n_max", inherits = TRUE)) {
  sipp_2008_n_max <- Inf
}
if (!exists("sipp_2008_skip_unreadable", inherits = TRUE)) {
  sipp_2008_skip_unreadable <- FALSE
}
if (!exists("sipp_2008_write_dta_export", inherits = TRUE)) {
  sipp_2008_write_dta_export <- FALSE
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

normalize_waves <- function(waves) {
  if (is.null(waves) || identical(tolower(waves), "all")) return(1:16)
  waves <- as.integer(waves)
  invalid <- setdiff(waves, 1:16)
  if (length(invalid) > 0) {
    stop("Invalid 2008 SIPP wave(s): ", paste(invalid, collapse = ", "), call. = FALSE)
  }
  unique(waves)
}

to_number <- function(x) suppressWarnings(as.numeric(trimws(x)))

core_spec <- tibble(
  name = c(
    "ssuid", "spanel", "swave", "srefmon", "rhcalmn", "rhcalyr",
    "shhadid", "gvarstr", "ghlfsam", "tfipsst", "tmovrflg",
    "ehhnumpp", "whfnwgt", "tmetro", "etenure", "thtotinc",
    "rhnbrf", "thsocsec", "thssi", "thunemp", "thfdstp",
    "rfid", "rfnkids", "wffinwgt", "tftotinc", "rfpov",
    "tfsocsec", "tfssi", "tfunemp", "tffdstp", "epppnum",
    "epopstat", "esex", "erace", "eorigin", "ebornus", "ecitizen",
    "wpfinwgt", "tage", "errp", "ems", "tpearn", "tptotinc",
    "eeducate", "rmesr", "ehimth", "ehiallcv"
  ),
  start = c(
    6, 18, 22, 25, 26, 28,
    32, 35, 38, 42, 44,
    59, 63, 73, 77, 166,
    174, 206, 212, 218, 236,
    242, 263, 271, 310, 318,
    338, 344, 350, 368, 503,
    509, 518, 520, 522, 525, 528,
    567, 579, 582, 585, 619, 648,
    786, 859, 2230, 2306
  ),
  end = c(
    17, 21, 23, 25, 27, 31,
    34, 37, 38, 43, 45,
    61, 72, 73, 77, 173,
    175, 211, 217, 223, 241,
    244, 264, 280, 317, 322,
    343, 349, 355, 373, 506,
    509, 518, 520, 523, 526, 529,
    576, 580, 583, 585, 625, 655,
    787, 860, 2231, 2307
  )
)

sipp_root <- resolve_sipp_root("07_load_2008_legacy_core.R")
if (is.null(sipp_output_dir)) {
  sipp_output_dir <- file.path(sipp_root, "output")
}
dir.create(sipp_output_dir, recursive = TRUE, showWarnings = FALSE)

core_path <- function(wave) {
  file.path(sipp_root, "data", "2008", paste0("wave", wave), paste0("l08puw", wave, ".dat.gz"))
}

load_2008_wave <- function(wave) {
  path <- core_path(wave)
  if (!file.exists(path)) {
    msg <- paste0("No local 2008 SIPP core wave ", wave, " file found.")
    if (isTRUE(sipp_2008_skip_unreadable)) {
      warning(msg, call. = FALSE)
      return(NULL)
    }
    stop(msg, call. = FALSE)
  }
  cat(paste0("Reading 2008 SIPP legacy core wave ", wave, "\n"))
  data <- read_fwf(
    path,
    fwf_positions(core_spec$start, core_spec$end, core_spec$name),
    n_max = if (is.finite(sipp_2008_n_max)) as.integer(sipp_2008_n_max) else Inf,
    col_types = cols(.default = col_character()),
    progress = FALSE
  )
  character_vars <- c("ssuid", "shhadid", "gvarstr", "ghlfsam")
  for (nm in setdiff(names(data), character_vars)) {
    data[[nm]] <- to_number(data[[nm]])
  }
  data$pnum <- data$epppnum
  data$eeduc <- data$eeducate
  bind_cols(
    tibble(
      source_file = paste0("l08puw", wave, ".dat"),
      design_era = "2008_legacy",
      sipp_file_year = 2008L,
      panel_wave = wave
    ),
    data
  )
}

selected_waves <- normalize_waves(sipp_2008_waves)
cat(paste0("Selected 2008 SIPP legacy waves: ", paste(selected_waves, collapse = ", "), "\n"))

pieces <- lapply(selected_waves, load_2008_wave)
pieces <- pieces[!vapply(pieces, is.null, logical(1))]
if (length(pieces) == 0) {
  stop("No 2008 SIPP legacy core files were loaded.", call. = FALSE)
}

sipp_2008_legacy_core <- bind_rows(pieces)
out_rds <- file.path(sipp_output_dir, paste0(sipp_output_basename, "_2008_legacy_core_person_month.rds"))
saveRDS(sipp_2008_legacy_core, out_rds)
cat(paste0("Saved 2008 SIPP legacy core person-month file: ", out_rds, " (", nrow(sipp_2008_legacy_core), " rows)\n"))

if (isTRUE(sipp_2008_write_dta_export)) {
  if (!requireNamespace("haven", quietly = TRUE)) {
    warning("Package haven is required for optional Stata export.", call. = FALSE)
  } else {
    out_dta <- file.path(sipp_output_dir, paste0(sipp_output_basename, "_2008_legacy_core_person_month_from_r.dta"))
    haven::write_dta(sipp_2008_legacy_core, out_dta)
    cat(paste0("Saved optional Stata export: ", out_dta, "\n"))
  }
}
