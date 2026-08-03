################################################################################
# 01_load_pre2011.R
#
# Purpose: Import BRFSS pre-2011 landline-era SAS Transport files for 2000-2010,
#          add a survey year identifier, and bind selected years into one
#          stacked full-width dataset.
#
# Input:   data/raw/CDBRFSYYXPT.zip or data/raw/CDBRFSYY.XPT
#          Default years: 2009-2010
# Output:  output/brfss_pre2011_appended.rds
#          output/brfss_pre2011_appended_from_r.dta (optional)
#
# Usage:   Run from brfss/, from brfss/code/, from the repo root, or set
#          BRFSS_ROOT explicitly.
#
# Note:    These files predate the 2011 BRFSS dual-frame/raking redesign.
#          Keep this workflow separate from the 2011-plus workflow
#          unless you have a project-specific bridge design.
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

# Optional manual root override:
# Sys.setenv(BRFSS_ROOT = "/path/to/econ-data-starters/brfss")

# Optional output directory override for smoke tests or scratch builds.
pre2011_output_dir_manual <- NULL
# pre2011_output_dir_manual <- "/private/tmp/brfss_pre2011_output"

# Choose either a consecutive year range or an explicit year list.
# If years_to_load is not NULL, it overrides first_year/last_year.
# Examples:
# years_to_load <- c(2000, 2004, 2010)
# first_year <- 2000
# last_year  <- 2010
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

# If TRUE, also write a Stata export from R. The Stata loader writes its own
# native .dta output, so this is off by default.
write_dta_export <- FALSE

# ============================================================================
# 1. DEFINE PATHS AND YEARS
# ============================================================================

brfss_root <- resolve_brfss_root("01_load_pre2011.R")
cat(paste0("Using BRFSS root: ", brfss_root, "\n"))

raw_dir <- file.path(brfss_root, "data", "raw")
out_dir <- if (!is.null(pre2011_output_dir_manual)) {
  pre2011_output_dir_manual
} else {
  file.path(brfss_root, "output")
}

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

out_rds <- file.path(out_dir, "brfss_pre2011_appended.rds")
out_dta <- file.path(out_dir, "brfss_pre2011_appended_from_r.dta")

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
# 2. LOAD EACH YEAR
# ============================================================================

cat("============================================\n")
cat(paste0("   LOADING BRFSS PRE-2011 DATA (", year_label, ")\n"))
cat("============================================\n\n")

temp_dir <- tempfile("brfss_pre2011_xpt_")
dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(temp_dir, recursive = TRUE, force = TRUE), add = TRUE)

load_one_year <- function(yr) {
  source <- find_pre2011_source(raw_dir, yr)
  xpt_file <- extract_pre2011_xpt(source, temp_dir)

  cat(paste0("--- Year ", yr, " ---\n"))
  cat(paste0("  Source: ", basename(source$path), "\n"))

  df <- read_xpt(xpt_file)
  names(df) <- tolower(names(df))
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
# Some legacy XPT layouts store the same raw field as numeric in one year and
# character in another (for example, _MSACODE in 2000-2001). Preserve every
# raw value by promoting those mixed-type columns to character before binding.
all_names <- unique(unlist(lapply(all_years, names), use.names = FALSE))
mixed_character_names <- all_names[vapply(all_names, function(var_name) {
  present <- lapply(all_years, function(df) {
    if (var_name %in% names(df)) df[[var_name]] else NULL
  })
  present <- Filter(Negate(is.null), present)
  any(vapply(present, is.character, logical(1))) &&
    any(!vapply(present, is.character, logical(1)))
}, logical(1))]

if (length(mixed_character_names) > 0) {
  cat(
    paste0(
      "[INFO] Promoting mixed numeric/character raw columns before append: ",
      paste(mixed_character_names, collapse = ", "), "\n"
    )
  )
  all_years <- lapply(all_years, function(df) {
    for (var_name in intersect(mixed_character_names, names(df))) {
      df[[var_name]] <- as.character(df[[var_name]])
    }
    df
  })
}

brfss <- bind_rows(all_years) %>% arrange(surveyyear)
rm(all_years)
gc()

cat(paste0("Total observations: ", nrow(brfss), "\n"))
cat(paste0("Total variables: ", ncol(brfss), "\n"))

# ============================================================================
# 3. SAVE AND VALIDATE
# ============================================================================

cat("\n============================================\n")
cat("   SAVING PRE-2011 APPENDED DATASET\n")
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

cat("\n============================================\n")
cat("   COMPLETE\n")
cat("============================================\n")
cat(paste0("pre-2011 appended file: ", out_rds, "\n"))
