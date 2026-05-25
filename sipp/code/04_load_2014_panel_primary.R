################################################################################
# 04_load_2014_panel_primary.R
#
# Purpose: Load selected 2014 SIPP panel public-use primary files
#          into a compact person-month starter file.
#
# Inputs: data/2014/panel_wave{wave}/pu2014w{wave}.dta.gz
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
if (!exists("sipp_2014_waves", inherits = TRUE)) {
  sipp_2014_waves <- c(4)
}
if (!exists("sipp_2014_skip_unreadable", inherits = TRUE)) {
  sipp_2014_skip_unreadable <- FALSE
}
if (!exists("sipp_2014_n_max", inherits = TRUE)) {
  sipp_2014_n_max <- Inf
}
if (!exists("sipp_2014_write_dta_export", inherits = TRUE)) {
  sipp_2014_write_dta_export <- FALSE
}
if (!exists("sipp_2014_extra_vars", inherits = TRUE)) {
  sipp_2014_extra_vars <- character(0)
}
if (!exists("sipp_2014_extra_var_families", inherits = TRUE)) {
  sipp_2014_extra_var_families <- list()
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

normalize_vars <- function(x) {
  x <- unname(x)
  x <- x[!is.na(x) & nzchar(x)]
  unique(toupper(x))
}

select_alias_vars <- function(header_vars, families) {
  selected <- character(0)
  rename_map <- character(0)
  if (length(families) == 0) return(list(vars = selected, rename_map = rename_map))
  header_upper <- toupper(header_vars)
  for (family_name in names(families)) {
    candidates <- normalize_vars(families[[family_name]])
    matched <- candidates[candidates %in% header_upper][1]
    if (!is.na(matched)) {
      original <- header_vars[match(matched, header_upper)]
      selected <- c(selected, original)
      rename_map[tolower(original)] <- family_name
    } else {
      warning(
        "No alias found for SIPP 2014 family '", family_name, "'. Candidates: ",
        paste(candidates, collapse = ", "),
        call. = FALSE
      )
    }
  }
  list(vars = selected, rename_map = rename_map)
}

apply_alias_map <- function(data, rename_map) {
  if (length(rename_map) == 0) return(data)
  for (old in names(rename_map)) {
    new <- unname(rename_map[[old]])
    if (old %in% names(data) && !new %in% names(data)) {
      data[[new]] <- data[[old]]
    }
  }
  data
}

sipp_root <- resolve_sipp_root("04_load_2014_panel_primary.R")
if (is.null(sipp_output_dir)) {
  sipp_output_dir <- file.path(sipp_root, "output")
}
dir.create(sipp_output_dir, recursive = TRUE, showWarnings = FALSE)

starter_vars <- c(
  "SSUID", "PNUM", "MONTHCODE", "SHHADID", "SPANEL", "SWAVE",
  "GHLFSAM", "GVARSTR", "WPFINWGT",
  "RREGION_INTV", "TMETRO_INTV", "TST_INTV", "TEHC_ST", "TEHC_METRO",
  "RHNUMPER", "RHNUMU18", "RHNUM65OVER",
  "RFAMNUM", "RFAMREF", "RFPERSONS", "RFRELU18", "RFAMKIND",
  "ETENURE", "ERENTSUB", "EVOUCHER",
  "TAGE", "TDOB_BYEAR", "ESEX", "EORIGIN", "EHISPAN", "ERACE", "TRACE",
  "EEDUC", "EMS", "ERELRPE", "EBORNUS", "ECITIZEN",
  "RMESR", "RWKSPERM", "RMWKWJB", "RMNUMJOBS", "TMWKHRS",
  "TPEARN", "TPEARN_ALT",
  "TPTOTINC", "THTOTINC", "TFTOTINC", "TFTOTINCT2", "THTOTINCT2",
  "RFPOV", "RHPOV", "TFINCPOV", "THINCPOV",
  "TSSSAMT", "TSSI_AMT", "TTANF_AMT", "TSNAP_AMT", "TWIC_AMT",
  "TGA_AMT", "TVA1AMT", "TUC1AMT",
  "RSNAP_MNYN", "RTANF_MNYN", "RSSI_MNYN", "RWIC_MNYN",
  "RHLTHMTH", "RHICOVANN", "RPRIVANN", "RPUBANN", "RMEDCAREANN",
  "RMCAIDANN", "RVACAREANN",
  "TVAL_HOME", "THVAL_HOME", "TNETWORTH", "THNETWORTH",
  "TDEBT_CC", "THDEBT_CC"
)

panel_dta_file <- function(wave) {
  file.path(sipp_root, "data", "2014", paste0("panel_wave", wave), paste0("pu2014w", wave, ".dta.gz"))
}

panel_csv_file <- function(wave) {
  file.path(sipp_root, "data", "2014", paste0("panel_wave", wave), paste0("pu2014w", wave, ".csv.gz"))
}

read_dta_header <- function(path) {
  temp_dta <- decompress_gzip_to_temp(path)
  on.exit(unlink(temp_dta), add = TRUE)
  names(read_dta(temp_dta, n_max = 0))
}

read_csv_header <- function(path) {
  names(read_delim(
    path,
    delim = "|",
    n_max = 0,
    show_col_types = FALSE,
    progress = FALSE
  ))
}

resolve_2014_source <- function(wave) {
  dta_path <- panel_dta_file(wave)
  if (file.exists(dta_path)) {
    header <- try(read_dta_header(dta_path), silent = TRUE)
    if (!inherits(header, "try-error")) {
      return(list(path = dta_path, format = "dta", header_vars = header, source_file = paste0("pu2014w", wave, ".dta")))
    }
    warning(
      "Could not read 2014 SIPP wave ", wave, " Stata gzip; trying pipe-delimited CSV fallback.",
      call. = FALSE
    )
  }

  csv_path <- panel_csv_file(wave)
  if (file.exists(csv_path)) {
    header <- try(read_csv_header(csv_path), silent = TRUE)
    if (!inherits(header, "try-error")) {
      return(list(path = csv_path, format = "csv", header_vars = header, source_file = paste0("pu2014w", wave, ".csv.gz")))
    }
  }

  list(path = dta_path, format = "missing", header_vars = character(), source_file = paste0("pu2014w", wave, ".dta"))
}

read_selected_dta <- function(path, keep_vars) {
  temp_dta <- decompress_gzip_to_temp(path)
  on.exit(unlink(temp_dta), add = TRUE)
  if (is.finite(sipp_2014_n_max)) {
    return(read_dta(
      temp_dta,
      col_select = tidyselect::all_of(keep_vars),
      n_max = as.integer(sipp_2014_n_max)
    ))
  }
  read_dta(temp_dta, col_select = tidyselect::all_of(keep_vars))
}

read_selected_csv <- function(path, keep_vars) {
  read_delim(
    path,
    delim = "|",
    col_select = tidyselect::all_of(keep_vars),
    n_max = if (is.finite(sipp_2014_n_max)) as.integer(sipp_2014_n_max) else Inf,
    col_types = cols(.default = col_character()),
    show_col_types = FALSE,
    progress = FALSE
  )
}

read_selected_2014 <- function(source, keep_vars) {
  if (identical(source$format, "dta")) return(read_selected_dta(source$path, keep_vars))
  if (identical(source$format, "csv")) return(read_selected_csv(source$path, keep_vars))
  stop("Unsupported 2014 SIPP source format: ", source$format, call. = FALSE)
}

load_2014_wave <- function(wave) {
  source <- resolve_2014_source(wave)
  if (identical(source$format, "missing")) {
    msg <- paste0("No readable local 2014 SIPP panel wave ", wave, " primary file found.")
    if (isTRUE(sipp_2014_skip_unreadable)) {
      warning(msg, call. = FALSE)
      return(NULL)
    }
    stop(msg, call. = FALSE)
  }

  header_vars <- source$header_vars
  header_upper <- toupper(header_vars)
  default_vars <- starter_vars[starter_vars %in% header_upper]
  extras <- normalize_vars(sipp_2014_extra_vars)
  extras_present <- extras[extras %in% header_upper]
  extras_missing <- setdiff(extras, extras_present)
  if (length(extras_missing) > 0) {
    warning(
      "2014 SIPP wave ", wave, " does not contain requested extra variable(s): ",
      paste(extras_missing, collapse = ", "),
      call. = FALSE
    )
  }

  alias <- select_alias_vars(header_vars, sipp_2014_extra_var_families)
  keep_upper <- unique(c(default_vars, extras_present, toupper(alias$vars)))
  keep_vars <- header_vars[match(keep_upper, header_upper)]
  keep_vars <- keep_vars[!is.na(keep_vars)]
  if (length(keep_vars) == 0) {
    stop("No variables selected for 2014 SIPP wave ", wave, ".", call. = FALSE)
  }

  cat(paste0("Reading 2014 SIPP panel wave ", wave, ": ", basename(source$path), "\n"))
  data <- read_selected_2014(source, keep_vars)
  names(data) <- tolower(names(data))
  if (identical(source$format, "csv")) {
    string_vars <- c("ssuid", "shhadid", "ghlfsam", "gvarstr", "tst_intv")
    for (nm in setdiff(names(data), string_vars)) {
      data[[nm]] <- suppressWarnings(as.numeric(data[[nm]]))
    }
  }
  data <- apply_alias_map(data, alias$rename_map)
  bind_cols(
    tibble(
      source_file = source$source_file,
      design_era = "2014_panel",
      sipp_file_year = 2014L,
      panel_wave = wave
    ),
    data
  )
}

selected_waves <- normalize_waves(sipp_2014_waves)
cat(paste0("Selected 2014 SIPP panel waves: ", paste(selected_waves, collapse = ", "), "\n"))

pieces <- lapply(selected_waves, load_2014_wave)
pieces <- pieces[!vapply(pieces, is.null, logical(1))]
if (length(pieces) == 0) {
  stop("No 2014 SIPP panel primary files were loaded.", call. = FALSE)
}

sipp_2014_panel_primary <- bind_rows(pieces)

out_rds <- file.path(sipp_output_dir, paste0(sipp_output_basename, "_2014_panel_primary_person_month.rds"))
saveRDS(sipp_2014_panel_primary, out_rds)
cat(paste0("Saved 2014 SIPP panel primary person-month file: ", out_rds, " (", nrow(sipp_2014_panel_primary), " rows)\n"))

if (isTRUE(sipp_2014_write_dta_export)) {
  out_dta <- file.path(sipp_output_dir, paste0(sipp_output_basename, "_2014_panel_primary_person_month_from_r.dta"))
  write_dta(sipp_2014_panel_primary, out_dta)
  cat(paste0("Saved optional Stata export: ", out_dta, "\n"))
}
