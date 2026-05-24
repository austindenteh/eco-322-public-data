################################################################################
# 01_reshape_and_save_optional_low_memory.R
#
# Purpose: Standalone low-memory HRS loader. Reads only selected RAND HRS raw
#          columns, reshapes selected waves from wide to long, and saves the
#          compact long starter dataset.
#
# Input:   data/raw/randhrs1992_2022v1.dta
# Output:  output/hrs_long.rds
#          optional output/hrs_long_from_r.dta / hrs_long_from_r.csv
#
# Usage:   Run from hrs/, hrs/code/, from the repo root, or set
#          hrs_root_manual / HRS_ROOT.
################################################################################

library(haven)
library(dplyr)
library(tidyr)
library(stringr)

# ============================================================================
# 1. PATHS AND OPTIONS
# ============================================================================

# Optional manual path override. Leave as NULL for auto-detection.
# Example:
# hrs_root_manual <- "/Users/yourname/path/to/econ-data-starters/hrs"
if (!exists("hrs_root_manual", inherits = TRUE)) {
  hrs_root_manual <- NULL
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

resolve_hrs_root <- function(script_name) {
  env_root <- Sys.getenv("HRS_ROOT", unset = "")

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
  candidates <- c(hrs_root_manual, env_root, search_paths, file.path(search_paths, "hrs"))
  candidates <- unique(candidates[!is.na(candidates) & nzchar(candidates)])

  for (path in candidates) {
    path_norm <- normalizePath(path, winslash = "/", mustWork = FALSE)
    if (file.exists(file.path(path_norm, "README.md")) &&
        file.exists(file.path(path_norm, "code", script_name))) {
      return(path_norm)
    }
  }

  stop(
    "Could not locate the hrs/ directory.\n",
    "Run this script from hrs/, hrs/code/, from the repo root, ",
    "or set hrs_root_manual / HRS_ROOT to the hrs path.\n",
    paste0("Current working directory: ", getwd(), "\n"),
    'Manual override in this script: hrs_root_manual <- "/path/to/hrs"\n',
    'Manual override before sourcing: Sys.setenv(HRS_ROOT = "/path/to/hrs")',
    call. = FALSE
  )
}

normalize_var_names <- function(x) {
  x <- unname(x)
  x <- x[!is.na(x) & nzchar(x)]
  unique(tolower(x))
}

# Low-memory mode is always on in this standalone optional loader.
keep_starter_vars_only <- TRUE
if (!exists("extra_time_invariant_vars", inherits = TRUE)) {
  extra_time_invariant_vars <- character(0)
}
if (!exists("extra_wave_stubs", inherits = TRUE)) {
  extra_wave_stubs <- character(0)
}
if (!exists("write_dta_export", inherits = TRUE)) {
  write_dta_export <- FALSE
}
if (!exists("write_csv_export", inherits = TRUE)) {
  write_csv_export <- FALSE
}
if (!exists("hrs_output_dir", inherits = TRUE)) {
  hrs_output_dir <- NULL
}
if (!exists("hrs_output_basename", inherits = TRUE)) {
  hrs_output_basename <- "hrs_long"
}
# ---------------------------------------------------------------------------
# USER SETTINGS
# ---------------------------------------------------------------------------
# Leave hrs_waves and hrs_years as NULL to keep all 16 waves. Use ONE or both
# if you want a smaller build. If both are set, the selected waves are combined.
# Examples:
# hrs_waves <- c(14, 15, 16)
# hrs_years <- c(2018, 2020, 2022)
if (!exists("hrs_waves", inherits = TRUE)) {
  hrs_waves <- NULL
}
if (!exists("hrs_years", inherits = TRUE)) {
  hrs_years <- NULL
}

# Add variables beyond the starter set here.
# Examples:
# extra_time_invariant_vars <- c("raedyrs")
# extra_wave_stubs <- c("rcovrt", "scovrt")

hrs_root <- resolve_hrs_root("01_reshape_and_save_optional_low_memory.R")
cat(paste0("Using HRS root: ", hrs_root, "\n"))

raw_data <- file.path(hrs_root, "data", "raw", "randhrs1992_2022v1.dta")
if (!file.exists(raw_data)) {
  stop(
    "Could not find raw RAND HRS data file:\n", raw_data, "\n",
    "Download randhrs1992_2022v1.dta and place it in hrs/data/raw/.",
    call. = FALSE
  )
}

if (is.null(hrs_output_dir)) {
  hrs_output_dir <- file.path(hrs_root, "output")
}
dir.create(hrs_output_dir, showWarnings = FALSE, recursive = TRUE)

out_rds <- file.path(hrs_output_dir, paste0(hrs_output_basename, ".rds"))
out_dta <- file.path(hrs_output_dir, paste0(hrs_output_basename, "_from_r.dta"))
out_csv <- file.path(hrs_output_dir, paste0(hrs_output_basename, "_from_r.csv"))

# Starter variables are enough for 02_clean_demographics plus common examples.
starter_time_invariant_vars <- c(
  "hhidpn", "hhid", "pn", "hacohort",
  "ragender", "rabyear", "raeduc", "raracem", "rahispan"
)
starter_wave_stubs <- c(
  "inw", "ragey_b", "rmstat", "rshlt", "rcesd", "rbmi", "rconde",
  "rhosp", "radl5a", "riadl5a", "rmobila", "hitot", "hatotb", "rwtresp"
)

# These RAND variables use suffix wave numbering, e.g. radtype1, radtype2.
suffix_wave_stubs <- c(
  "radtype", "radappm", "radappy", "radream", "radreay",
  "radrecm", "radrecy", "radendm", "radendy", "radstat",
  "radappd", "radread", "radrecd", "radendd"
)

wave_year_map <- tibble(
  wave = 1:16,
  year = c(1992, 1994, 1996, 1998, 2000, 2002, 2004, 2006,
           2008, 2010, 2012, 2014, 2016, 2018, 2020, 2022)
)

resolve_requested_waves <- function(waves, years, wave_year_map) {
  requested <- integer(0)

  if (!is.null(waves) && length(waves) > 0) {
    requested <- c(requested, as.integer(waves))
  }

  if (!is.null(years) && length(years) > 0) {
    years <- as.integer(years)
    matched_waves <- wave_year_map$wave[wave_year_map$year %in% years]
    missing_years <- setdiff(years, wave_year_map$year)
    if (length(missing_years) > 0) {
      warning(
        "These years do not map to RAND HRS waves in this starter: ",
        paste(missing_years, collapse = ", "),
        call. = FALSE
      )
    }
    requested <- c(requested, matched_waves)
  }

  if (length(requested) == 0) {
    requested <- wave_year_map$wave
  }

  requested <- sort(unique(requested))
  invalid_waves <- setdiff(requested, wave_year_map$wave)
  if (length(invalid_waves) > 0) {
    stop(
      "Invalid HRS wave(s): ", paste(invalid_waves, collapse = ", "),
      ". Valid waves are 1-16.",
      call. = FALSE
    )
  }

  requested
}

requested_waves <- resolve_requested_waves(hrs_waves, hrs_years, wave_year_map)
cat(sprintf("Using HRS waves: %s\n", paste(requested_waves, collapse = ", ")))

wide_names_from_stubs <- function(stubs, waves = 1:16) {
  stubs <- normalize_var_names(stubs)
  unique(unlist(lapply(stubs, function(stub) {
    if (identical(stub, "inw")) {
      return(paste0("inw", waves))
    }
    if (stub %in% suffix_wave_stubs) {
      return(paste0(stub, waves))
    }

    prefix <- substr(stub, 1, 1)
    concept <- substr(stub, 2, nchar(stub))
    if (prefix %in% c("r", "s", "h") && nzchar(concept)) {
      return(paste0(prefix, waves, concept))
    }

    paste0(stub, waves)
  }), use.names = FALSE))
}

# ============================================================================
# 2. LOAD THE RAW DATA
# ============================================================================

if (keep_starter_vars_only) {
  requested_time_invariant <- normalize_var_names(c(
    starter_time_invariant_vars,
    extra_time_invariant_vars
  ))
  requested_wave_stubs <- normalize_var_names(c(starter_wave_stubs, extra_wave_stubs))
  requested_raw_vars <- unique(c(
    requested_time_invariant,
    wide_names_from_stubs(requested_wave_stubs, waves = requested_waves)
  ))

  cat("Reading RAND HRS metadata to select low-memory columns...\n")
  raw_metadata <- read_dta(raw_data, n_max = 0)
  raw_names <- names(raw_metadata)
  raw_lookup <- setNames(raw_names, tolower(raw_names))
  present_raw_vars <- unname(raw_lookup[intersect(requested_raw_vars, names(raw_lookup))])
  missing_raw_vars <- setdiff(requested_raw_vars, names(raw_lookup))

  if (!"hhidpn" %in% tolower(present_raw_vars)) {
    stop("The required identifier hhidpn was not found in the raw file.", call. = FALSE)
  }

  cat(sprintf("Loading %d selected raw variables from RAND HRS...\n",
              length(present_raw_vars)))
  if (length(missing_raw_vars) > 0) {
    preview <- paste(head(missing_raw_vars, 12), collapse = ", ")
    if (length(missing_raw_vars) > 12) preview <- paste0(preview, ", ...")
    cat(sprintf("[INFO] Requested raw variables not found: %s\n", preview))
  }

  hrs_wide <- read_dta(raw_data, col_select = all_of(present_raw_vars))
} else {
  cat("Loading full RAND HRS data. This may take a few minutes...\n")
  hrs_wide <- read_dta(raw_data)
}

names(hrs_wide) <- tolower(names(hrs_wide))
cat(sprintf("Loaded %d respondents with %d variables.\n",
            nrow(hrs_wide), ncol(hrs_wide)))

# ============================================================================
# 3. IDENTIFY VARIABLE GROUPS
# ============================================================================

all_names <- names(hrs_wide)

r_wave_vars <- all_names[str_detect(all_names, "^r\\d+")]
h_wave_vars <- all_names[str_detect(all_names, "^h\\d+")]
s_wave_vars <- all_names[str_detect(all_names, "^s\\d+")]
inw_vars <- all_names[str_detect(all_names, "^inw\\d+$")]

suffix_pattern <- paste0("^(", paste(suffix_wave_stubs, collapse = "|"), ")(\\d+)$")
suffix_wave_vars <- all_names[str_detect(all_names, suffix_pattern)]

cat(sprintf("Found %d R-prefix wave-varying variables.\n", length(r_wave_vars)))
cat(sprintf("Found %d H-prefix wave-varying variables.\n", length(h_wave_vars)))
cat(sprintf("Found %d S-prefix wave-varying variables.\n", length(s_wave_vars)))
cat(sprintf("Found %d INW variables.\n", length(inw_vars)))
cat(sprintf("Found %d suffix-numbered death/admin variables.\n", length(suffix_wave_vars)))

all_wave_vars <- c(r_wave_vars, h_wave_vars, s_wave_vars, inw_vars, suffix_wave_vars)
time_invariant_vars <- setdiff(all_names, all_wave_vars)
cat(sprintf("Found %d time-invariant variables.\n", length(time_invariant_vars)))

if (!"hhidpn" %in% all_names) {
  stop("hhidpn is required but was not found after loading the raw file.", call. = FALSE)
}
if (length(all_wave_vars) == 0) {
  stop("No wave-varying variables were found to reshape.", call. = FALSE)
}

# ============================================================================
# 4. RESHAPE FROM WIDE TO LONG
# ============================================================================

cat("Reshaping from wide to long format...\n")

fix_dup_labels <- function(df) {
  for (v in names(df)) {
    labs <- attr(df[[v]], "labels")
    if (!is.null(labs) && any(duplicated(labs))) {
      attr(df[[v]], "labels") <- NULL
    }
  }
  df
}
hrs_wide <- fix_dup_labels(hrs_wide)
cat("  Fixed any duplicate value labels.\n")

ti <- hrs_wide %>% select(all_of(c("hhidpn", time_invariant_vars)))
ti <- ti[, !duplicated(names(ti))]

long_components <- list()

if (length(inw_vars) > 0) {
  long_components$inw <- hrs_wide %>%
    select(hhidpn, all_of(inw_vars)) %>%
    pivot_longer(
      cols = all_of(inw_vars),
      names_to = "wave",
      names_prefix = "inw",
      values_to = "inw"
    ) %>%
    mutate(wave = as.integer(wave))
  cat(sprintf("  INW reshaped: %d rows.\n", nrow(long_components$inw)))
}

if (length(r_wave_vars) > 0) {
  long_components$r <- hrs_wide %>%
    select(hhidpn, all_of(r_wave_vars)) %>%
    pivot_longer(
      cols = all_of(r_wave_vars),
      names_to = c("wave", ".value"),
      names_pattern = "^r(\\d+)(.+)$"
    ) %>%
    mutate(wave = as.integer(wave)) %>%
    rename_with(~ paste0("r", .), .cols = -c(hhidpn, wave))
  cat(sprintf("  R-prefix reshaped: %d rows, %d columns.\n",
              nrow(long_components$r), ncol(long_components$r)))
}

if (length(h_wave_vars) > 0) {
  long_components$h <- hrs_wide %>%
    select(hhidpn, all_of(h_wave_vars)) %>%
    pivot_longer(
      cols = all_of(h_wave_vars),
      names_to = c("wave", ".value"),
      names_pattern = "^h(\\d+)(.+)$"
    ) %>%
    mutate(wave = as.integer(wave)) %>%
    rename_with(~ paste0("h", .), .cols = -c(hhidpn, wave))
  cat(sprintf("  H-prefix reshaped: %d rows, %d columns.\n",
              nrow(long_components$h), ncol(long_components$h)))
}

if (length(s_wave_vars) > 0) {
  long_components$s <- hrs_wide %>%
    select(hhidpn, all_of(s_wave_vars)) %>%
    rename(.resp_id = hhidpn) %>%
    pivot_longer(
      cols = all_of(s_wave_vars),
      names_to = c("wave", ".value"),
      names_pattern = "^s(\\d+)(.+)$"
    ) %>%
    mutate(wave = as.integer(wave)) %>%
    rename_with(~ paste0("s", .), .cols = -c(.resp_id, wave)) %>%
    rename(hhidpn = .resp_id)
  cat(sprintf("  S-prefix reshaped: %d rows, %d columns.\n",
              nrow(long_components$s), ncol(long_components$s)))
}

if (length(suffix_wave_vars) > 0) {
  long_components$suffix <- hrs_wide %>%
    select(hhidpn, all_of(suffix_wave_vars)) %>%
    pivot_longer(
      cols = all_of(suffix_wave_vars),
      names_to = c(".value", "wave"),
      names_pattern = suffix_pattern
    ) %>%
    mutate(wave = as.integer(wave))
  cat(sprintf("  Suffix-numbered variables reshaped: %d rows, %d columns.\n",
              nrow(long_components$suffix), ncol(long_components$suffix)))
}

if (length(long_components) == 0) {
  stop("No long-format components were created.", call. = FALSE)
}

cat("Joining reshaped components...\n")
hrs_long <- ti %>% left_join(long_components[[1]], by = "hhidpn")
if (length(long_components) > 1) {
  for (component in long_components[-1]) {
    hrs_long <- hrs_long %>% left_join(component, by = c("hhidpn", "wave"))
  }
}

cat(sprintf("Reshaped to long format: %d person-wave observations, %d variables.\n",
            nrow(hrs_long), ncol(hrs_long)))

# ============================================================================
# 5. ADD SURVEY YEAR, SORT, AND SAVE
# ============================================================================

hrs_long <- hrs_long %>%
  filter(wave %in% requested_waves) %>%
  left_join(wave_year_map, by = "wave") %>%
  arrange(hhidpn, wave)

cat("Saving outputs...\n")
saveRDS(hrs_long, out_rds)
cat(sprintf("Saved: %s\n", out_rds))

if (write_dta_export) {
  tryCatch({
    write_dta(hrs_long, out_dta)
    cat(sprintf("Saved optional Stata export: %s\n", out_dta))
  }, error = function(e) {
    cat(sprintf("Warning: Could not save .dta file: %s\n", e$message))
    cat("The .rds file was saved successfully.\n")
  })
} else {
  cat("Skipped optional Stata export. Set write_dta_export <- TRUE to create a .dta export.\n")
}

if (write_csv_export) {
  tryCatch({
    write.csv(hrs_long, out_csv, row.names = FALSE, na = "")
    cat(sprintf("Saved optional CSV export: %s\n", out_csv))
  }, error = function(e) {
    cat(sprintf("Warning: Could not save .csv file: %s\n", e$message))
  })
} else {
  cat("Skipped optional CSV export. Set write_csv_export <- TRUE to create a .csv export.\n")
}

# ============================================================================
# 6. VALIDATION CHECKS
# ============================================================================

cat("\nValidation checks:\n")
expected_n <- 45234 * length(requested_waves)
if (nrow(hrs_long) == expected_n) {
  cat(sprintf(
    "[PASS] Observation count is %d (= 45,234 x %d selected wave(s)).\n",
    nrow(hrs_long), length(requested_waves)
  ))
} else {
  cat(sprintf("[WARN] Expected %d observations but found %d.\n", expected_n, nrow(hrs_long)))
}

observed_waves <- sort(unique(hrs_long$wave))
if (identical(observed_waves, requested_waves)) {
  cat(sprintf("[PASS] Wave selection matches requested waves: %s.\n",
              paste(requested_waves, collapse = ", ")))
} else {
  cat(sprintf(
    "[WARN] Requested waves %s but observed waves %s.\n",
    paste(requested_waves, collapse = ", "),
    paste(observed_waves, collapse = ", ")
  ))
}

if (all(c("hhidpn", "wave", "year", "inw") %in% names(hrs_long))) {
  cat("[PASS] Key identifiers hhidpn, wave, year, and inw are present.\n")
} else {
  missing_keys <- setdiff(c("hhidpn", "wave", "year", "inw"), names(hrs_long))
  cat(sprintf("[WARN] Missing key identifiers: %s\n", paste(missing_keys, collapse = ", ")))
}

cat(sprintf("\nDone. Long-format panel has %d observations and %d variables.\n",
            nrow(hrs_long), ncol(hrs_long)))
cat("Next step: run 02_clean_demographics.R\n")

################################################################################
# NOTES FOR USERS:
#
# 1. This standalone optional script reads only the selected starter columns,
#    requested extras, and selected waves before reshaping.
#
# 2. Use long-format stubs for wave-varying extras, for example:
#      extra_wave_stubs <- c("rcovrt", "scovrt")
#
# 3. haven::read_dta() preserves Stata extended missing values as tagged NAs.
#    For most starter analyses, treating all tagged NAs as missing is fine.
################################################################################
