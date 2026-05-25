################################################################################
# 01_load_modern_primary.R
#
# Purpose: Load selected modern SIPP annual primary public-use files
#          (2018-2024 design era) into a compact person-month starter file.
#
# Inputs:  data/{year}/pu{year}_dta.zip
################################################################################

library(dplyr)
library(haven)
library(tibble)

################################################################################
# USER SETTINGS
################################################################################

# Optional manual path override. Leave NULL when running from the repo root,
# sipp/, or sipp/code/. You can also set Sys.setenv(SIPP_ROOT = "...").
if (!exists("sipp_root_manual", inherits = TRUE)) {
  sipp_root_manual <- NULL
}

# Optional output override. Defaults to sipp/output/.
if (!exists("sipp_output_dir", inherits = TRUE)) {
  sipp_output_dir <- NULL
}
if (!exists("sipp_output_basename", inherits = TRUE)) {
  sipp_output_basename <- "sipp"
}

# Set TRUE if you also want a Stata copy from the R loader.
if (!exists("sipp_write_dta_export", inherits = TRUE)) {
  sipp_write_dta_export <- FALSE
}

# Main file choices. Use NULL or "all" to try every supported modern year.
if (!exists("sipp_modern_years", inherits = TRUE)) {
  sipp_modern_years <- c(2024)
}
if (!exists("sipp_modern_skip_unreadable", inherits = TRUE)) {
  sipp_modern_skip_unreadable <- FALSE
}

# Optional row limit for smoke tests or small examples. Leave Inf for full files.
if (!exists("sipp_modern_n_max", inherits = TRUE)) {
  sipp_modern_n_max <- Inf
}

# Optional extra raw variables and alias families for concepts whose names differ.
if (!exists("sipp_modern_extra_vars", inherits = TRUE)) {
  sipp_modern_extra_vars <- character(0)
}
if (!exists("sipp_modern_extra_var_families", inherits = TRUE)) {
  sipp_modern_extra_var_families <- list()
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

sipp_root <- resolve_sipp_root("01_load_modern_primary.R")
if (is.null(sipp_output_dir)) {
  sipp_output_dir <- file.path(sipp_root, "output")
}
dir.create(sipp_output_dir, recursive = TRUE, showWarnings = FALSE)

available_modern_years <- 2018:2024

normalize_years <- function(years) {
  if (is.null(years) || identical(tolower(years), "all")) {
    return(available_modern_years)
  }
  years <- as.integer(years)
  invalid <- setdiff(years, available_modern_years)
  if (length(invalid) > 0) {
    stop(
      "Invalid modern SIPP year(s): ", paste(invalid, collapse = ", "), "\n",
      "Choose from: ", paste(available_modern_years, collapse = ", "), ".",
      call. = FALSE
    )
  }
  unique(years)
}

normalize_vars <- function(x) {
  x <- unname(x)
  x <- x[!is.na(x) & nzchar(x)]
  unique(toupper(x))
}

candidate_primary_zips <- function(year) {
  c(
    file.path(sipp_root, "data", as.character(year), paste0("pu", year, "_dta.zip")),
    file.path(sipp_root, "data", as.character(year), paste0("pu", year, "_dta.zip.download"), paste0("pu", year, "_dta.zip"))
  )
}

resolve_primary_zip <- function(year) {
  candidates <- candidate_primary_zips(year)
  candidates[file.exists(candidates)][1]
}

validate_primary_zip <- function(zip_path, year) {
  if (is.na(zip_path) || !file.exists(zip_path)) {
    return(list(ok = FALSE, message = paste0("No local primary Stata zip found for ", year, ".")))
  }
  member <- paste0("pu", year, ".dta")
  listing <- try(utils::unzip(zip_path, list = TRUE), silent = TRUE)
  if (inherits(listing, "try-error")) {
    return(list(
      ok = FALSE,
      message = paste0("Could not list ", basename(zip_path), ". The local zip may be incomplete or still downloading.")
    ))
  }
  if (!member %in% listing$Name) {
    return(list(
      ok = FALSE,
      message = paste0("Expected ", member, " inside ", basename(zip_path), " but did not find it.")
    ))
  }
  list(ok = TRUE, member = member)
}

extract_primary_member <- function(zip_path, member, extract_dir) {
  extracted_path <- file.path(extract_dir, member)

  extracted <- suppressWarnings(
    try(utils::unzip(zip_path, files = member, exdir = extract_dir, overwrite = TRUE), silent = TRUE)
  )
  if (!inherits(extracted, "try-error") && file.exists(extracted_path)) {
    return(list(ok = TRUE, path = extracted_path, method = "utils::unzip"))
  }

  unzip_bin <- Sys.which("unzip")
  if (!nzchar(unzip_bin)) {
    msg <- if (inherits(extracted, "try-error")) attr(extracted, "condition")$message else "member was not extracted"
    return(list(ok = FALSE, message = paste0("R unzip failed (", msg, "), and no system unzip command was found.")))
  }

  unlink(extracted_path, force = TRUE)
  system_out <- try(
    system2(unzip_bin, c("-j", "-o", zip_path, member, "-d", extract_dir), stdout = TRUE, stderr = TRUE),
    silent = TRUE
  )
  status <- attr(system_out, "status")
  if (is.null(status)) status <- 0L
  if (!inherits(system_out, "try-error") && identical(status, 0L) && file.exists(extracted_path)) {
    return(list(ok = TRUE, path = extracted_path, method = "system unzip"))
  }

  msg <- if (inherits(system_out, "try-error")) attr(system_out, "condition")$message else paste(system_out, collapse = " ")
  list(ok = FALSE, message = paste0("R unzip and system unzip both failed. System unzip output: ", msg))
}

prepare_primary_dta <- function(zip_path, member, year) {
  direct_header <- try(read_dta(zip_path, n_max = 0), silent = TRUE)
  if (!inherits(direct_header, "try-error")) {
    return(list(ok = TRUE, path = zip_path, header = direct_header, temp_dir = NULL, extracted = FALSE))
  }

  extract_dir <- file.path(tempdir(), paste0("sipp_modern_", year, "_", Sys.getpid()))
  if (dir.exists(extract_dir)) unlink(extract_dir, recursive = TRUE, force = TRUE)
  dir.create(extract_dir, recursive = TRUE, showWarnings = FALSE)
  extracted <- extract_primary_member(zip_path, member, extract_dir)
  if (!isTRUE(extracted$ok)) {
    return(list(
      ok = FALSE,
      message = paste0(
        "Could not read Stata metadata from ", basename(zip_path),
        " directly, and temporary extraction failed: ",
        extracted$message
      )
    ))
  }
  extracted_path <- extracted$path
  header <- try(read_dta(extracted_path, n_max = 0), silent = TRUE)
  if (inherits(header, "try-error")) {
    return(list(
      ok = FALSE,
      message = paste0("Could not read Stata metadata from extracted ", member, ": ", attr(header, "condition")$message)
    ))
  }
  list(ok = TRUE, path = extracted_path, header = header, temp_dir = extract_dir, extracted = TRUE, extract_method = extracted$method)
}

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

read_sipp_dta <- function(dta_path, keep_vars) {
  if (is.finite(sipp_modern_n_max)) {
    return(read_dta(
      dta_path,
      col_select = tidyselect::all_of(keep_vars),
      n_max = as.integer(sipp_modern_n_max)
    ))
  }
  read_dta(dta_path, col_select = tidyselect::all_of(keep_vars))
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
        "No alias found for SIPP family '", family_name, "' in this year. Candidates: ",
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

load_modern_year <- function(year) {
  zip_path <- resolve_primary_zip(year)
  validation <- validate_primary_zip(zip_path, year)
  if (!isTRUE(validation$ok)) {
    msg <- paste0("Skipping SIPP ", year, ": ", validation$message)
    if (isTRUE(sipp_modern_skip_unreadable)) {
      warning(msg, call. = FALSE)
      return(NULL)
    }
    stop(msg, call. = FALSE)
  }

  prepared <- prepare_primary_dta(zip_path, validation$member, year)
  if (!isTRUE(prepared$ok)) {
    msg <- paste0("Skipping SIPP ", year, ": ", prepared$message)
    if (isTRUE(sipp_modern_skip_unreadable)) {
      warning(msg, call. = FALSE)
      return(NULL)
    }
    stop(msg, call. = FALSE)
  }
  if (!is.null(prepared$temp_dir)) {
    on.exit(unlink(prepared$temp_dir, recursive = TRUE, force = TRUE), add = TRUE)
  }

  header_vars <- names(prepared$header)
  header_upper <- toupper(header_vars)
  default_vars <- starter_vars[starter_vars %in% header_upper]
  missing_defaults <- setdiff(starter_vars, default_vars)
  if (length(missing_defaults) > 0) {
    warning(
      "SIPP ", year, " is missing these starter variables: ",
      paste(missing_defaults, collapse = ", "),
      call. = FALSE
    )
  }

  extras <- normalize_vars(sipp_modern_extra_vars)
  extras_present <- extras[extras %in% header_upper]
  extras_missing <- setdiff(extras, extras_present)
  if (length(extras_missing) > 0) {
    warning(
      "SIPP ", year, " does not contain requested extra variable(s): ",
      paste(extras_missing, collapse = ", "),
      call. = FALSE
    )
  }

  alias <- select_alias_vars(header_vars, sipp_modern_extra_var_families)
  keep_upper <- unique(c(default_vars, extras_present, toupper(alias$vars)))
  keep_vars <- header_vars[match(keep_upper, header_upper)]
  keep_vars <- keep_vars[!is.na(keep_vars)]
  if (length(keep_vars) == 0) {
    stop("No variables selected for SIPP ", year, ".", call. = FALSE)
  }

  if (isTRUE(prepared$extracted)) {
    cat(paste0("Reading SIPP ", year, " primary file from temporary extracted ", validation$member, "\n"))
  } else {
    cat(paste0("Reading SIPP ", year, " primary file: ", basename(zip_path), "\n"))
  }
  data <- read_sipp_dta(prepared$path, keep_vars)
  names(data) <- tolower(names(data))
  data <- apply_alias_map(data, alias$rename_map)
  bind_cols(
    tibble(
      source_file = paste0("pu", year, ".dta"),
      sipp_file_year = year,
      reference_year = year - 1
    ),
    data
  )
}

selected_years <- normalize_years(sipp_modern_years)
cat(paste0("Selected modern SIPP years: ", paste(selected_years, collapse = ", "), "\n"))

pieces <- lapply(selected_years, load_modern_year)
pieces <- pieces[!vapply(pieces, is.null, logical(1))]
if (length(pieces) == 0) {
  stop("No SIPP modern primary files were loaded.", call. = FALSE)
}

sipp_modern_primary <- bind_rows(pieces)

out_rds <- file.path(sipp_output_dir, paste0(sipp_output_basename, "_modern_primary_person_month.rds"))
saveRDS(sipp_modern_primary, out_rds)
cat(paste0("Saved modern SIPP primary person-month file: ", out_rds, " (", nrow(sipp_modern_primary), " rows)\n"))

if (isTRUE(sipp_write_dta_export)) {
  out_dta <- file.path(sipp_output_dir, paste0(sipp_output_basename, "_modern_primary_person_month_from_r.dta"))
  write_dta(sipp_modern_primary, out_dta)
  cat(paste0("Saved optional Stata export: ", out_dta, "\n"))
}
