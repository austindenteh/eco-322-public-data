################################################################################
# 01_load_pre2011_optional_low_memory.R
#
# Purpose: Optional low-memory BRFSS pre-2011 loader for 2000-2010.
#          Reads one year at a time, keeps only the starter variables needed by
#          02_clean_pre2011.R plus user-requested extras, and appends
#          selected years into the canonical pre-2011 output file.
#
# Input:   data/raw/CDBRFSYYXPT.zip or data/raw/CDBRFSYY.XPT
#          Default years: 2009-2010
# Output:  output/brfss_pre2011_appended.rds
#          output/brfss_pre2011_appended_low_memory_from_r.dta (optional)
#
# Usage:   Run from brfss/, from brfss/code/, from the repo root, or set
#          BRFSS_ROOT explicitly.
################################################################################

library(haven)
library(dplyr)
library(purrr)

resolve_brfss_root <- function(script_name) {
  env_root <- Sys.getenv("BRFSS_ROOT", unset = "")

  parent_paths <- function(path) {
    if (!nzchar(path) || !dir.exists(path)) {
      return(character())
    }

    path <- normalizePath(path, winslash = "/", mustWork = TRUE)
    paths <- path

    repeat {
      parent <- dirname(path)
      if (identical(parent, path)) {
        break
      }
      paths <- c(paths, parent)
      path <- parent
    }

    paths
  }

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

  search_paths <- unique(unlist(lapply(c(getwd(), rstudio_script_dir), parent_paths), use.names = FALSE))
  candidates <- c(env_root, search_paths, file.path(search_paths, "brfss"))
  candidates <- unique(candidates[nzchar(candidates)])

  for (path in candidates) {
    if (dir.exists(path) &&
        file.exists(file.path(path, "README.md")) &&
        file.exists(file.path(path, "code", script_name))) {
      return(normalizePath(path, winslash = "/", mustWork = TRUE))
    }
  }

  stop(
    paste(
      "Could not locate the brfss/ directory.",
      "Run this script from brfss/, brfss/code/, from the repo root,",
      "or set BRFSS_ROOT to the brfss path.",
      paste0("Current working directory: ", getwd()),
      'Manual override: Sys.setenv(BRFSS_ROOT = "/path/to/brfss")'
    )
  )
}

normalize_var_names <- function(x) {
  x <- unname(x)
  x <- x[nzchar(x)]
  unique(tolower(x))
}

parse_env_var_list <- function(x) {
  if (!nzchar(x)) {
    return(character())
  }
  out <- unlist(strsplit(x, "[,[:space:]]+"), use.names = FALSE)
  out[nzchar(out)]
}

parse_env_families <- function(x) {
  if (!nzchar(x)) {
    return(list())
  }

  entries <- unlist(strsplit(x, ";"), use.names = FALSE)
  entries <- trimws(entries[nzchar(trimws(entries))])
  families <- list()

  for (entry in entries) {
    pieces <- strsplit(entry, "[:=]", fixed = FALSE)[[1]]
    if (length(pieces) < 2) {
      stop(
        paste0(
          "Invalid BRFSS_PRE2011_EXTRA_VAR_FAMILIES entry: ", entry,
          ". Use forms like flu_shot:flushot2,flushot3,flushot4"
        )
      )
    }
    family_name <- trimws(pieces[[1]])
    candidates <- parse_env_var_list(paste(pieces[-1], collapse = ":"))
    if (!nzchar(family_name) || length(candidates) == 0) {
      stop(paste0("Invalid BRFSS_PRE2011_EXTRA_VAR_FAMILIES entry: ", entry))
    }
    families[[family_name]] <- candidates
  }

  families
}

coalesce_family_columns <- function(df, output_name, candidate_vars) {
  present <- candidate_vars[candidate_vars %in% names(df)]
  if (length(present) == 0) {
    return(df)
  }

  if (output_name %in% names(df) && !(output_name %in% present)) {
    stop(
      paste0(
        "extra_var_families output name '", output_name,
        "' already exists in the data. Choose a different family name."
      )
    )
  }

  merged <- df[[present[[1]]]]
  if (length(present) > 1) {
    for (var_name in present[-1]) {
      merged <- dplyr::coalesce(merged, df[[var_name]])
    }
  }

  df[[output_name]] <- merged
  df
}

make_year_label <- function(years) {
  years <- sort(unique(as.integer(years)))
  if (length(years) == 0 || any(is.na(years))) {
    return("no years")
  }
  if (length(years) == 1) {
    return(as.character(years))
  }
  if (identical(years, seq.int(min(years), max(years)))) {
    return(paste0(min(years), "-", max(years)))
  }
  paste(years, collapse = ", ")
}

find_pre2011_source <- function(raw_dir, yr) {
  suffix <- sprintf("%02d", yr %% 100)
  xpt_name <- paste0("CDBRFS", suffix, ".XPT")
  xpt_candidates <- list.files(
    raw_dir,
    pattern = paste0("^CDBRFS", suffix, "[.]XPT$"),
    full.names = TRUE,
    ignore.case = TRUE
  )

  if (length(xpt_candidates) > 0) {
    return(list(type = "xpt", path = xpt_candidates[[1]], member = basename(xpt_candidates[[1]])))
  }

  zip_candidates <- list.files(
    raw_dir,
    pattern = paste0("^CDBRFS", suffix, "XPT[.]zip$"),
    full.names = TRUE,
    ignore.case = TRUE
  )

  if (length(zip_candidates) > 0) {
    zip_path <- zip_candidates[[1]]
    zip_members <- utils::unzip(zip_path, list = TRUE)$Name
    matching_members <- zip_members[
      tolower(basename(zip_members)) == tolower(xpt_name)
    ]
    if (length(matching_members) != 1) {
      stop(
        paste0(
          "Could not identify exactly one ", xpt_name, " member inside ",
          basename(zip_path), ". Found: ",
          if (length(matching_members) == 0) "none" else paste(matching_members, collapse = ", ")
        )
      )
    }
    return(list(type = "zip", path = zip_path, member = matching_members[[1]]))
  }

  stop(
    paste0(
      "No BRFSS pre-2011 file found for ", yr, ". Expected ",
      xpt_name, " or CDBRFS", suffix, "XPT.zip in ", raw_dir
    )
  )
}

extract_pre2011_xpt <- function(source, temp_dir) {
  if (identical(source$type, "xpt")) {
    return(source$path)
  }

  extracted <- utils::unzip(source$path, files = source$member, exdir = temp_dir)
  if (length(extracted) == 0 || !file.exists(extracted[[1]])) {
    stop(paste0("Could not extract ", source$member, " from ", source$path))
  }

  extracted[[1]]
}

# ============================================================================
# USER SETTINGS
# ============================================================================
# Recommended for most student projects. Use the full pre-2011 loader only when
# the project needs a broad raw-variable surface beyond the starter and extras.
#
# What this script does:
#   1. Reads one pre-2011 year at a time
#   2. Imports only the core columns needed by 02_clean_pre2011.R
#   3. Keeps user-requested stable variables and alias families
#   4. Saves output/brfss_pre2011_appended.rds

# Optional manual root override:
# Sys.setenv(BRFSS_ROOT = "/path/to/econ-data-starters/brfss")

# Optional output directory override for smoke tests or scratch builds.
pre2011_output_dir_manual <- NULL
# pre2011_output_dir_manual <- "/private/tmp/brfss_pre2011_output"

# Choose either a consecutive year range or an explicit year list.
# If years_to_load is not NULL, it overrides first_year/last_year.
# Example:
# years_to_load <- c(2000, 2004, 2010)
years_to_load <- NULL
first_year <- 2009
last_year  <- 2010

# Optional non-editing overrides for smoke tests:
# Sys.setenv(BRFSS_PRE2011_OUTPUT_DIR = "/private/tmp/brfss_pre2011_output")
# Sys.setenv(BRFSS_PRE2011_YEARS = "2000 2004 2010")
env_output_dir <- Sys.getenv("BRFSS_PRE2011_OUTPUT_DIR", unset = "")
if (nzchar(env_output_dir)) {
  pre2011_output_dir_manual <- env_output_dir
}

env_years <- Sys.getenv("BRFSS_PRE2011_YEARS", unset = "")
if (nzchar(env_years)) {
  years_to_load <- as.integer(strsplit(env_years, "[,[:space:]]+")[[1]])
}

# If TRUE, also write a Stata export of the reduced appended dataset.
write_dta_export <- FALSE

# Add stable raw variable names here if you want extra columns carried forward.
# Example:
# extra_keep_vars <- c("flushot3", "cholchk")
extra_keep_vars <- c()

# Add cross-year raw variable families here when names differ by year.
# The list name becomes the merged output column name.
# IMPORTANT: This only merges raw aliases into one column. If coding or meaning
# changes across years, harmonize the variable later.
# Example:
# extra_var_families <- list(
#   flu_shot = c("flushot2", "flushot3", "flushot4"),
#   checkup_raw = c("checkup", "checkup1")
# )
extra_var_families <- list()

# Optional non-editing overrides for smoke tests:
# Sys.setenv(BRFSS_PRE2011_EXTRA_KEEP_VARS = "flushot3 cholchk")
# Sys.setenv(BRFSS_PRE2011_EXTRA_VAR_FAMILIES = "flu_shot:flushot2,flushot3,flushot4")
env_extra_keep <- Sys.getenv("BRFSS_PRE2011_EXTRA_KEEP_VARS", unset = "")
if (nzchar(env_extra_keep)) {
  extra_keep_vars <- parse_env_var_list(env_extra_keep)
}

env_extra_families <- Sys.getenv("BRFSS_PRE2011_EXTRA_VAR_FAMILIES", unset = "")
if (nzchar(env_extra_families)) {
  extra_var_families <- parse_env_families(env_extra_families)
}

# ============================================================================
# 1. DEFINE PATHS AND YEARS
# ============================================================================

brfss_root <- resolve_brfss_root("01_load_pre2011_optional_low_memory.R")
cat(paste0("Using BRFSS root: ", brfss_root, "\n"))

raw_dir <- file.path(brfss_root, "data", "raw")
out_dir <- if (!is.null(pre2011_output_dir_manual)) {
  pre2011_output_dir_manual
} else {
  file.path(brfss_root, "output")
}

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

out_rds <- file.path(out_dir, "brfss_pre2011_appended.rds")
out_dta <- file.path(out_dir, "brfss_pre2011_appended_low_memory_from_r.dta")

if (!is.null(years_to_load)) {
  years <- sort(unique(as.integer(years_to_load)))
  if (length(years) == 0 || any(is.na(years))) {
    stop("years_to_load must contain one or more valid numeric years.")
  }
} else {
  years <- first_year:last_year
}

valid_years <- 2000:2010
bad_years <- setdiff(years, valid_years)
if (length(bad_years) > 0) {
  stop(
    paste0(
      "This pre-2011 loader supports 2000-2010 only. Invalid year(s): ",
      paste(bad_years, collapse = ", ")
    )
  )
}

year_label <- make_year_label(years)

# ============================================================================
# 2. DEFINE CORE KEEP LIST
# ============================================================================

core_keep_families <- list(
  survey_design = c("_psu", "_ststr", "_finalwt", "_poststr"),
  state_id = c("_state"),
  county = c("ctycode", "_impcty", "cpcounty"),
  record_id = c("seqno", "dispcode"),
  interview_timing = c("imonth", "iyear"),
  demographics = c(
    "age", "_impage", "_ageg5yr",
    "sex",
    "_racegr", "_racegr2", "_raceg2", "_raceg3_", "_prace", "_mrace",
    "race2", "hispanc2",
    "educa", "marital", "income2", "employ"
  ),
  health = c(
    "genhlth", "menthlth", "physhlth",
    "hlthplan", "persdoc", "persdoc2", "medcost", "checkup", "checkup1",
    "diabetes", "diabete2",
    "asthma", "asthma2", "asthnow",
    "cvdinfar", "cvdcorhd", "cvdstrok",
    "cvdinfr2", "cvdinfr3", "cvdinfr4",
    "cvdcrhd2", "cvdcrhd3", "cvdcrhd4",
    "cvdstrk2", "cvdstrk3",
    "_bmi2", "_bmi2cat", "_rfbmi2",
    "_bmi3", "_bmi3cat", "_rfbmi3",
    "_bmi4", "_bmi4cat", "_rfbmi4",
    "_smoker2", "_smoker3", "smoke100", "smokeday"
  )
)

extra_keep_vars <- normalize_var_names(extra_keep_vars)
extra_var_families <- lapply(extra_var_families, normalize_var_names)

if (length(extra_var_families) > 0) {
  family_names <- names(extra_var_families)
  if (is.null(family_names) || any(!nzchar(family_names))) {
    stop("Each entry in extra_var_families must have a descriptive name.")
  }
}

core_keep_vars <- unique(unlist(core_keep_families, use.names = FALSE))
family_candidate_vars <- unique(unlist(extra_var_families, use.names = FALSE))
vars_to_request <- unique(c(core_keep_vars, extra_keep_vars, family_candidate_vars))

# ============================================================================
# 3. LOAD EACH YEAR
# ============================================================================

cat("============================================\n")
cat(paste0("   LOADING BRFSS PRE-2011 LOW-MEMORY DATA (", year_label, ")\n"))
cat("============================================\n\n")

temp_dir <- tempfile("brfss_pre2011_xpt_")
dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(temp_dir, recursive = TRUE, force = TRUE), add = TRUE)

load_one_year <- function(yr) {
  source <- find_pre2011_source(raw_dir, yr)
  xpt_file <- extract_pre2011_xpt(source, temp_dir)
  header_names <- names(read_xpt(xpt_file, n_max = 0))
  header_lookup <- stats::setNames(header_names, tolower(header_names))
  present_lower <- intersect(vars_to_request, names(header_lookup))
  read_names <- unname(header_lookup[present_lower])

  if (length(read_names) == 0) {
    stop(paste0("No requested variables found for ", yr, ". Check the keep list."))
  }

  cat(paste0("--- Year ", yr, " ---\n"))
  cat(paste0("  Source: ", basename(source$path), "\n"))
  cat(paste0("  Keeping ", length(read_names), " of ", length(header_names), " raw variables\n"))

  df <- read_xpt(xpt_file, col_select = any_of(read_names))
  names(df) <- tolower(names(df))

  if (length(extra_var_families) > 0) {
    for (family_name in names(extra_var_families)) {
      df <- coalesce_family_columns(df, family_name, extra_var_families[[family_name]])
    }
  }

  df$surveyyear <- yr

  cat(
    paste0(
      "  Imported ", yr, ": ", nrow(df), " observations, ",
      ncol(df), " variables\n"
    )
  )

  df
}

all_years <- map(years, load_one_year)

cat("\nBinding selected pre-2011 years together...\n")
brfss <- bind_rows(all_years) %>% arrange(surveyyear)
rm(all_years)
gc()

cat(paste0("Total observations: ", nrow(brfss), "\n"))
cat(paste0("Total variables: ", ncol(brfss), "\n"))

# ============================================================================
# 4. SAVE AND VALIDATE
# ============================================================================

cat("\n============================================\n")
cat("   SAVING PRE-2011 LOW-MEMORY APPENDED DATASET\n")
cat("============================================\n\n")

saveRDS(brfss, out_rds)
cat(paste0("Saved: ", out_rds, "\n"))

if (isTRUE(write_dta_export)) {
  tryCatch(
    {
      write_dta(brfss, out_dta)
      cat(paste0("Saved: ", out_dta, "\n"))
    },
    error = function(e) {
      cat(paste0("Could not save .dta export: ", e$message, "\n"))
      cat("The .rds file was saved successfully.\n")
    }
  )
}

cat("\n============================================\n")
cat("   VALIDATION CHECKS\n")
cat("============================================\n\n")

loaded_years <- sort(unique(brfss$surveyyear))
if (identical(loaded_years, sort(years))) {
  cat(paste0("[PASS] Loaded years match request: ", paste(loaded_years, collapse = ", "), "\n"))
} else {
  stop(
    paste0(
      "[FAIL] Expected years ", paste(years, collapse = ", "),
      " but found ", paste(loaded_years, collapse = ", ")
    )
  )
}

cat("\n[INFO] Observations per survey year:\n")
print(table(brfss$surveyyear))

required_vars <- c("_state", "_psu", "_ststr", "_finalwt", "surveyyear")
missing_required <- setdiff(required_vars, names(brfss))
if (length(missing_required) == 0) {
  cat(paste0("[PASS] Required design variables present: ", paste(required_vars, collapse = ", "), "\n"))
} else {
  stop(paste0("[FAIL] Missing required variable(s): ", paste(missing_required, collapse = ", ")))
}

county_vars <- intersect(c("ctycode", "_impcty", "cpcounty"), names(brfss))
if (length(county_vars) > 0) {
  cat(paste0("[PASS] County source variable(s) present: ", paste(county_vars, collapse = ", "), "\n"))
} else {
  cat("[WARN] No county source variables found in selected years.\n")
}

if (length(extra_var_families) > 0) {
  family_outputs <- names(extra_var_families)
  present_outputs <- intersect(family_outputs, names(brfss))
  cat(paste0("[INFO] Added alias-family output(s): ", paste(present_outputs, collapse = ", "), "\n"))
}

cat("\n============================================\n")
cat("   COMPLETE\n")
cat("============================================\n")
cat(paste0("pre-2011 appended file: ", out_rds, "\n"))
