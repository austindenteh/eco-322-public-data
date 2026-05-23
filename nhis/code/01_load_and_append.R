################################################################################
# 01_load_and_append.R
#
# Purpose: Load NHIS data files, harmonize variable names across the 2019
#          redesign break, and save combined working datasets for BOTH
#          adults and children.
#
#          This script performs the full data build pipeline:
#
#          POST-2019 (2019-2024): Flat 2-file design
#            Unzip and import CSV files (adult, child) — simple and fast
#
#          PRE-2019 (2004-2018, optional): 5-file hierarchical design
#            Load .dta files (created or reused by the Stata loader)
#            Merge personsx + familyxx + househld + samadult/samchild
#            Harmonize variable names
#
#          NOTE: Pre-2019 .dta files must be created by running the Stata
#          loader first. For 2019-2024 (the default), this R script works
#          standalone — no Stata needed.
#
#          DEFAULT: Loads 2019-2024 only (post-redesign, CSV files).
#          To include pre-2019 years, uncomment the pre2019_years line
#          below. The script auto-detects which year folders are present
#          and skips any missing years.
#
# Input:   data/NHIS 2019/ ... data/NHIS 2024/  (CSV in .zip)
#          data/NHIS 2004/ ... data/NHIS 2018/  (optional: .dta files)
# Output:  output/nhis_adult.rds   (sample adults, all loaded years)
#          output/nhis_child.rds   (sample children, all loaded years)
#          output/nhis_adult_from_r.dta / nhis_child_from_r.dta (optional)
#
# Author:  Austin Denteh (legacy code and Claude Code)
# Date:    February 2026
################################################################################

library(haven)
library(dplyr)
library(readr)

# ============================================================================
# 1. DEFINE PATHS AND YEAR RANGE
# ============================================================================

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

nhis_root <- resolve_nhis_root("01_load_and_append.R")
cat(paste0("Using NHIS root: ", nhis_root, "\n"))

out_dir <- file.path(nhis_root, "output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# --- Post-2019 years (redesigned, CSV format — DEFAULT) ---
# These years use simple CSV files. No special setup needed.
# The script auto-detects which year folders exist and skips missing ones.
if (!exists("post2019_years", inherits = TRUE)) {
  post2019_years <- 2019:2024
}

# --- Pre-2019 years (OPTIONAL — uncomment to include) ---
# Pre-2019 years require .dta files (created by running the Stata loader).
# If you haven't run the Stata script first, the .dta files won't exist.
# Leave as empty integer(0) to skip pre-2019 entirely (the default).
#
# To include pre-2019 years, uncomment ONE of the lines below:
# pre2019_years <- 2004:2018
# pre2019_years <- 2010:2018
if (!exists("pre2019_years", inherits = TRUE)) {
  pre2019_years <- integer(0)
}

# NOTE: Years 2015-2018 follow the pre-2019 design but some components
#       arrive as zipped ASCII/CSV files. Run the Stata loader once to create
#       component .dta files before loading those years in R.
#
# The R workflow writes compact .rds files by default. Set this to TRUE only
# if you also want Stata-format copies created by R. These can be large.
if (!exists("write_dta_export", inherits = TRUE)) {
  write_dta_export <- FALSE
}

normalize_var_names <- function(x) {
  x <- unname(x)
  x <- x[!is.na(x) & nzchar(x)]
  unique(tolower(x))
}

# Full all-column NHIS builds can exceed memory in R when pre-2019 years are
# included. Set this to TRUE to keep only variables needed by the starter
# cleaner, plus any names in extra_vars or extra_var_families.
if (!exists("keep_starter_vars_only", inherits = TRUE)) {
  keep_starter_vars_only <- FALSE
}
if (!exists("extra_vars", inherits = TRUE)) {
  extra_vars <- character(0)
}
if (!exists("extra_var_families", inherits = TRUE)) {
  extra_var_families <- list()
}
if (is.null(extra_var_families)) {
  extra_var_families <- list()
}
if (!is.list(extra_var_families)) {
  stop("extra_var_families must be a named list of variable aliases.", call. = FALSE)
}

extra_vars <- normalize_var_names(extra_vars)
if (length(extra_var_families) > 0) {
  family_names <- names(extra_var_families)
  if (is.null(family_names) ||
      any(is.na(family_names) | !nzchar(family_names))) {
    stop("Each entry in extra_var_families must have a descriptive name.", call. = FALSE)
  }
  names(extra_var_families) <- tolower(family_names)
  extra_var_families <- lapply(extra_var_families, normalize_var_names)

  cat(
    paste(
      "[INFO] extra_var_families only merge raw aliases into one column.",
      "If coding or meanings change across years, harmonize that added variable",
      "later in 02_clean_and_analyze.R or in your analysis code.\n"
    )
  )
}
family_alias_vars <- normalize_var_names(unlist(extra_var_families, use.names = FALSE))

adult_starter_vars <- c(
  "srvy_yr", "hhx", "era_post2019",
  "agep_a", "sex_a", "hisp_a", "raceallp_a", "educ_a",
  "citizenp_a", "notcov_a", "medicare_a", "medicaid_a", "private_a",
  "phstat_a", "pdmed12m_a", "pnmed12m_a",
  "hypev_a", "chlev_a", "chdev_a", "angev_a", "miev_a", "strev_a",
  "asev_a", "canev_a", "dibev_a", "copdev_a", "arthev_a", "depev_a",
  "anxev_a", "phqcat_a", "gadcat_a", "bmicat_a",
  "ratcat_a", "incgrp_a", "ernyr_a", "wtfa_a", "pstrat", "ppsu"
)

child_starter_vars <- c(
  "srvy_yr", "hhx", "era_post2019",
  "agep_c", "sex_c", "hisp_c", "raceallp_c",
  "notcov_c", "medicare_c", "medicaid_c", "private_c", "phstat_c",
  "wtfa_c", "pstrat", "ppsu"
)

keep_starter_columns <- function(df, sample_type) {
  if (!keep_starter_vars_only) return(df)

  starter_vars <- if (sample_type == "adult") adult_starter_vars else child_starter_vars
  keep_vars <- unique(c(starter_vars, extra_vars, family_alias_vars, names(extra_var_families)))
  df %>% select(any_of(keep_vars))
}

coalesce_family_columns <- function(df, output_name, candidate_vars) {
  present <- candidate_vars[candidate_vars %in% names(df)]
  if (length(present) == 0) {
    return(df)
  }

  if (output_name %in% names(df) && !(output_name %in% present)) {
    stop(
      "extra_var_families output name '", output_name,
      "' already exists in the data. Include it in that family's alias list ",
      "or choose a different family name.",
      call. = FALSE
    )
  }

  values <- df[present]
  if (any(vapply(values, is.character, logical(1)))) {
    values <- lapply(values, as.character)
  }

  merged <- values[[1]]
  if (length(values) > 1) {
    for (i in 2:length(values)) {
      merged <- dplyr::coalesce(merged, values[[i]])
    }
  }

  df[[output_name]] <- merged
  df
}

coalesce_extra_var_families <- function(df, sample_label) {
  if (length(extra_var_families) == 0 || nrow(df) == 0) {
    return(df)
  }

  for (family_name in names(extra_var_families)) {
    df <- coalesce_family_columns(df, family_name, extra_var_families[[family_name]])
  }
  df
}

report_extra_var_families <- function(df, sample_label) {
  if (length(extra_var_families) == 0 || nrow(df) == 0) {
    return(invisible(NULL))
  }

  missing_families <- character(0)
  for (family_name in names(extra_var_families)) {
    present <- extra_var_families[[family_name]][extra_var_families[[family_name]] %in% names(df)]
    if (length(present) == 0) {
      missing_families <- c(missing_families, family_name)
      next
    }

    nonmissing <- Reduce(`|`, lapply(present, function(var_name) !is.na(df[[var_name]])))
    if ("srvy_yr" %in% names(df) && any(nonmissing, na.rm = TRUE)) {
      matched_years <- sort(unique(df$srvy_yr[nonmissing]))
      cat(paste0(
        "[INFO] ", sample_label, " extra_var_family '", family_name,
        "' matched in year(s): ", paste(matched_years, collapse = ", "), "\n"
      ))
    } else {
      cat(paste0(
        "[INFO] ", sample_label, " extra_var_family '", family_name,
        "' matched column(s): ", paste(present, collapse = ", "), "\n"
      ))
    }
  }

  if (length(missing_families) == 0) {
    cat(paste0("[PASS] ", sample_label, ": all extra_var_families matched at least one column\n"))
  } else {
    cat(paste0(
      "[WARN] ", sample_label, ": some extra_var_families never matched: ",
      paste(missing_families, collapse = ", "), "\n"
    ))
  }
  invisible(NULL)
}

format_nhis_key <- function(x, width) {
  x <- haven::zap_labels(x)
  x_chr <- trimws(as.character(x))
  x_num <- suppressWarnings(as.numeric(x_chr))
  out <- ifelse(
    is.na(x_num),
    x_chr,
    sprintf(paste0("%0", width, ".0f"), x_num)
  )
  out[is.na(x) | !nzchar(x_chr)] <- NA_character_
  out
}

normalize_pre2019_keys <- function(df) {
  if ("hhx" %in% names(df)) df$hhx <- format_nhis_key(df$hhx, 6)
  if ("fmx" %in% names(df)) df$fmx <- format_nhis_key(df$fmx, 2)
  if ("fpx" %in% names(df)) df$fpx <- format_nhis_key(df$fpx, 2)
  if ("srvy_yr" %in% names(df)) {
    df$srvy_yr <- as.integer(haven::zap_labels(df$srvy_yr))
  }
  df
}

# ============================================================================
# HELPER FUNCTION: Load and merge a pre-2019 year
# ============================================================================
# This function:
#   1. Loads personsx.dta (all household members)
#   2. Merges familyxx.dta (family-level)
#   3. Merges househld.dta (household-level)
#   4. Merges samadult.dta or samchild.dta
#   5. Keeps only sample adults/children (inner join)
#   6. Harmonizes variable names to 2019+ convention

load_pre2019_year <- function(year, sample_type = "adult") {

  ydir <- file.path(nhis_root, "data", paste0("NHIS ", year))

  # Determine sample file
  if (sample_type == "adult") {
    sample_file <- file.path(ydir, "samadult.dta")
    suffix <- "_a"
  } else {
    sample_file <- file.path(ydir, "samchild.dta")
    suffix <- "_c"
  }

  # Check files exist
  person_file <- file.path(ydir, "personsx.dta")
  if (!file.exists(person_file)) {
    cat(paste0("  personsx.dta not found for ", year, ". Skipping.\n"))
    return(NULL)
  }
  if (!file.exists(sample_file)) {
    cat(paste0("  ", basename(sample_file), " not found for ", year, ". Skipping.\n"))
    return(NULL)
  }

  # --- Load person-level file ---
  person <- read_dta(person_file)
  names(person) <- tolower(names(person))

  if (!"srvy_yr" %in% names(person)) person$srvy_yr <- year
  person <- normalize_pre2019_keys(person)

  # --- Merge familyxx ---
  fam_file <- file.path(ydir, "familyxx.dta")
  if (file.exists(fam_file)) {
    family <- read_dta(fam_file)
    names(family) <- tolower(names(family))
    family <- normalize_pre2019_keys(family)
    person <- person %>%
      left_join(family, by = c("hhx", "fmx", "srvy_yr"),
                suffix = c("", ".fam"))
    dup_cols <- grep("\\.fam$", names(person), value = TRUE)
    if (length(dup_cols) > 0) person <- person %>% select(-all_of(dup_cols))
  }

  # --- Merge househld ---
  hh_file <- file.path(ydir, "househld.dta")
  if (file.exists(hh_file)) {
    house <- read_dta(hh_file)
    names(house) <- tolower(names(house))
    house <- normalize_pre2019_keys(house)
    person <- person %>%
      left_join(house, by = c("hhx", "srvy_yr"),
                suffix = c("", ".hh"))
    dup_cols <- grep("\\.hh$", names(person), value = TRUE)
    if (length(dup_cols) > 0) person <- person %>% select(-all_of(dup_cols))
  }

  # --- Merge sample file (inner join: keep only sample persons) ---
  sample_data <- read_dta(sample_file)
  names(sample_data) <- tolower(names(sample_data))
  sample_data <- normalize_pre2019_keys(sample_data)

  merged <- person %>%
    inner_join(sample_data, by = c("hhx", "fmx", "fpx", "srvy_yr"),
               suffix = c("", ".sam"))
  dup_cols <- grep("\\.sam$", names(merged), value = TRUE)
  if (length(dup_cols) > 0) merged <- merged %>% select(-all_of(dup_cols))

  cat(paste0("  Sample ", sample_type, "s: ", nrow(merged), "\n"))

  # ---------------------------------------------------------------
  # HARMONIZE VARIABLE NAMES TO POST-2019 CONVENTION
  # ---------------------------------------------------------------

  # Demographics
  rename_map <- c(
    "age_p"    = paste0("agep", suffix),
    "sex"      = paste0("sex", suffix),
    "origin_i" = paste0("hisp", suffix),
    "racerpi2" = paste0("raceallp", suffix),
    "citizenp" = paste0("citizenp", suffix),
    "plborn"   = paste0("plborn", suffix),
    "regionbr" = paste0("regionbr", suffix),
    "geobrth"  = paste0("geobrth", suffix),
    "frrp"     = paste0("frrp", suffix)
  )

  # Adult-only renames
  if (sample_type == "adult") {
    rename_map <- c(rename_map,
      "educ1"    = "educ_a",
      "notcov"   = "notcov_a",
      "medicare" = "medicare_a",
      "medicaid" = "medicaid_a",
      "private"  = "private_a",
      "schip"    = "schip_a",
      "single"   = "single_a",
      "ihs"      = "ihs_a",
      "hinotyr"  = "hinotyr_a",
      "phstat"   = "phstat_a",
      "pdmed12m" = "pdmed12m_a",
      "pnmed12m" = "pnmed12m_a"
    )
  } else {
    rename_map <- c(rename_map,
      "notcov"   = "notcov_c",
      "medicare" = "medicare_c",
      "medicaid" = "medicaid_c",
      "private"  = "private_c",
      "schip"    = "schip_c",
      "phstat"   = "phstat_c"
    )
  }

  for (old_name in names(rename_map)) {
    new_name <- rename_map[old_name]
    if (old_name %in% names(merged) && !(new_name %in% names(merged))) {
      names(merged)[names(merged) == old_name] <- new_name
    }
  }

  # Harmonize within-pre-2019 insurance variable name changes
  # othergov (2004-07) -> othgov (2008+)
  if ("othergov" %in% names(merged) && !("othgov" %in% names(merged)))
    names(merged)[names(merged) == "othergov"] <- "othgov"
  # otherpub (2004-07) -> othpub (2008+)
  if ("otherpub" %in% names(merged) && !("othpub" %in% names(merged)))
    names(merged)[names(merged) == "otherpub"] <- "othpub"
  # military (2004-07) -> milcare (2008+)
  if ("military" %in% names(merged) && !("milcare" %in% names(merged)))
    names(merged)[names(merged) == "military"] <- "milcare"
  # phospyr (2004-05) -> phospyr2 (2006+)
  if ("phospyr" %in% names(merged) && !("phospyr2" %in% names(merged)))
    names(merged)[names(merged) == "phospyr"] <- "phospyr2"
  # ffdstyn (2004-10) -> fsnap (2011+)
  if ("ffdstyn" %in% names(merged) && !("fsnap" %in% names(merged)))
    names(merged)[names(merged) == "ffdstyn"] <- "fsnap"

  # Chronic conditions: add suffix (adult only)
  if (sample_type == "adult") {
    chronic_vars <- c("hypev", "chlev", "chdev", "angev", "miev", "strev",
                       "asev", "canev", "dibev", "copdev", "arthev", "depev", "anxev")
    for (cv in chronic_vars) {
      new_cv <- paste0(cv, "_a")
      if (cv %in% names(merged) && !(new_cv %in% names(merged)))
        names(merged)[names(merged) == cv] <- new_cv
    }
  }

  # Income / poverty ratio
  # The poverty ratio category variable changes name across years:
  #   2004-2006: rat_cat  (no suffix)
  #   2007-2013: rat_cat2, rat_cat3  (two imputations)
  #   2014:      rat_cat4, rat_cat5  (two imputations)
  # Pick the first available variant and rename to ratcat_a.
  ratcat_renamed <- FALSE
  for (rc in c("rat_cat", "rat_cat2", "rat_cat4")) {
    if (!ratcat_renamed && rc %in% names(merged)) {
      names(merged)[names(merged) == rc] <- "ratcat_a"
      ratcat_renamed <- TRUE
    }
  }

  incgrp_renamed <- FALSE
  for (ig in c("incgrp", "incgrp2", "incgrp4")) {
    if (!incgrp_renamed && ig %in% names(merged)) {
      names(merged)[names(merged) == ig] <- "incgrp_a"
      incgrp_renamed <- TRUE
    }
  }

  # Drop alternate imputation versions
  drop_inc <- c("rat_cat3", "rat_cat5", "incgrp3", "incgrp5")
  merged <- merged %>% select(-any_of(drop_inc))

  # Personal earnings (from personsx): ernyr_p -> ernyr_a (adult only)
  if (sample_type == "adult" && "ernyr_p" %in% names(merged))
    names(merged)[names(merged) == "ernyr_p"] <- "ernyr_a"

  # Survey design: harmonize stratum/PSU
  if (year <= 2005) {
    if ("stratum" %in% names(merged)) {
      merged$pstrat <- 1000 + merged$stratum
      merged$stratum <- NULL
    }
    if ("psu" %in% names(merged))
      names(merged)[names(merged) == "psu"] <- "ppsu"
  } else {
    if ("strat_p" %in% names(merged)) {
      merged$pstrat <- 2000 + merged$strat_p
      merged$strat_p <- NULL
    }
    if ("psu_p" %in% names(merged))
      names(merged)[names(merged) == "psu_p"] <- "ppsu"
  }

  # Weights
  if (sample_type == "adult") {
    if ("wtfa_sa" %in% names(merged))
      names(merged)[names(merged) == "wtfa_sa"] <- "wtfa_a"
  } else {
    if ("wtfa_sc" %in% names(merged))
      names(merged)[names(merged) == "wtfa_sc"] <- "wtfa_c"
  }
  if ("wtfa" %in% names(merged))
    names(merged)[names(merged) == "wtfa"] <- "wtfa_person"

  # Mark era
  merged$era_post2019 <- 0L

  keep_starter_columns(merged, sample_type)
}

bind_rows_compatible <- function(data_list, label) {
  data_list <- Filter(Negate(is.null), data_list)
  if (length(data_list) == 0) return(tibble())

  # Stata value labels can make otherwise-compatible numeric columns disagree.
  data_list <- lapply(data_list, haven::zap_labels)

  all_names <- unique(unlist(lapply(data_list, names), use.names = FALSE))
  char_vars <- all_names[vapply(all_names, function(nm) {
    any(vapply(data_list, function(df) {
      nm %in% names(df) && is.character(df[[nm]])
    }, logical(1)))
  }, logical(1))]

  if (length(char_vars) > 0) {
    data_list <- lapply(data_list, function(df) {
      for (nm in intersect(char_vars, names(df))) {
        df[[nm]] <- as.character(df[[nm]])
      }
      df
    })
    preview <- paste(head(char_vars, 8), collapse = ", ")
    if (length(char_vars) > 8) preview <- paste0(preview, ", ...")
    cat(paste0(
      "[INFO] ", label, ": coerced ", length(char_vars),
      " mixed character columns before append (", preview, ")\n"
    ))
  }

  bind_rows(data_list)
}

# ============================================================================
# 2. LOAD PRE-2019 FILES (optional)
# ============================================================================

pre2019_adult_list <- list()
pre2019_child_list <- list()

if (length(pre2019_years) > 0) {

cat("============================================\n")
cat("   LOADING PRE-2019 NHIS FILES\n")
cat("============================================\n\n")

# --- Adults ---
cat("--- ADULT FILES ---\n")
for (y in pre2019_years) {
  cat(paste0("--- Year ", y, " ---\n"))
  result <- load_pre2019_year(y, "adult")
  if (!is.null(result)) pre2019_adult_list[[as.character(y)]] <- result
}

# --- Children ---
cat("\n--- CHILD FILES ---\n")
for (y in pre2019_years) {
  cat(paste0("--- Year ", y, " ---\n"))
  result <- load_pre2019_year(y, "child")
  if (!is.null(result)) pre2019_child_list[[as.character(y)]] <- result
}

} else {
  cat("[INFO] Pre-2019 years: skipped (not enabled). To include, uncomment pre2019_years above.\n\n")
}

# ============================================================================
# 3. LOAD POST-2019 FILES (2019-2024)
# ============================================================================

cat("\n============================================\n")
cat("   LOADING POST-2019 NHIS FILES\n")
cat("============================================\n\n")

post2019_adult_list <- list()
post2019_child_list <- list()

for (y in post2019_years) {
  cat(paste0("--- Year ", y, " ---\n"))

  ydir <- file.path(nhis_root, "data", paste0("NHIS ", y))
  yy   <- substr(as.character(y), 3, 4)

  # --- Adult ---
  csv_file <- file.path(ydir, paste0("adult", yy, ".csv"))
  zip_file <- file.path(ydir, paste0("adult", yy, "csv.zip"))

  if (!file.exists(csv_file) && file.exists(zip_file)) {
    cat("  Unzipping adult...\n")
    unzip(zip_file, exdir = ydir, overwrite = TRUE)
  }
  if (file.exists(csv_file)) {
    df <- read_csv(csv_file, col_types = cols(.default = "c"), show_col_types = FALSE)
    names(df) <- tolower(names(df))
    df <- type_convert(df, col_types = cols(.default = col_guess()))
    if (!"srvy_yr" %in% names(df)) df$srvy_yr <- y
    df$era_post2019 <- 1L
    df <- keep_starter_columns(df, "adult")
    cat(paste0("  Adult: ", nrow(df), " obs\n"))
    post2019_adult_list[[as.character(y)]] <- df
  }

  # --- Child ---
  csv_file <- file.path(ydir, paste0("child", yy, ".csv"))
  zip_file <- file.path(ydir, paste0("child", yy, "csv.zip"))

  if (!file.exists(csv_file) && file.exists(zip_file)) {
    cat("  Unzipping child...\n")
    unzip(zip_file, exdir = ydir, overwrite = TRUE)
  }
  if (file.exists(csv_file)) {
    df <- read_csv(csv_file, col_types = cols(.default = "c"), show_col_types = FALSE)
    names(df) <- tolower(names(df))
    df <- type_convert(df, col_types = cols(.default = col_guess()))
    if (!"srvy_yr" %in% names(df)) df$srvy_yr <- y
    df$era_post2019 <- 1L
    df <- keep_starter_columns(df, "child")
    cat(paste0("  Child: ", nrow(df), " obs\n"))
    post2019_child_list[[as.character(y)]] <- df
  }
}

# ============================================================================
# 4. APPEND ALL YEARS
# ============================================================================

cat("\n============================================\n")
cat("   APPENDING ALL YEARS\n")
cat("============================================\n\n")

# --- Adult ---
cat("--- Adult file ---\n")
adult <- bind_rows_compatible(c(pre2019_adult_list, post2019_adult_list), "adult")
adult <- coalesce_extra_var_families(adult, "adult")
cat(paste0("  Combined: ", nrow(adult), " observations, ", ncol(adult), " variables\n"))

# --- Child ---
cat("--- Child file ---\n")
child <- bind_rows_compatible(c(pre2019_child_list, post2019_child_list), "child")
child <- coalesce_extra_var_families(child, "child")
cat(paste0("  Combined: ", nrow(child), " observations, ", ncol(child), " variables\n"))

# ============================================================================
# 5. SAVE COMBINED DATASETS
# ============================================================================

cat("\nSaving combined datasets...\n")

# --- Adult ---
adult <- adult %>% arrange(srvy_yr, hhx)
saveRDS(adult, file.path(nhis_root, "output", "nhis_adult.rds"))
cat("Saved: output/nhis_adult.rds\n")
if (write_dta_export) {
  tryCatch({
    write_dta(adult, file.path(out_dir, "nhis_adult_from_r.dta"))
    cat("Saved: output/nhis_adult_from_r.dta\n")
  }, error = function(e) cat(paste0("Could not save adult .dta: ", e$message, "\n")))
} else {
  cat("Skipped optional Stata export. Set write_dta_export <- TRUE to create output/nhis_adult_from_r.dta.\n")
}

# --- Child ---
child <- child %>% arrange(srvy_yr, hhx)
saveRDS(child, file.path(nhis_root, "output", "nhis_child.rds"))
cat("Saved: output/nhis_child.rds\n")
if (write_dta_export) {
  tryCatch({
    write_dta(child, file.path(out_dir, "nhis_child_from_r.dta"))
    cat("Saved: output/nhis_child_from_r.dta\n")
  }, error = function(e) cat(paste0("Could not save child .dta: ", e$message, "\n")))
} else {
  cat("Skipped optional Stata export. Set write_dta_export <- TRUE to create output/nhis_child_from_r.dta.\n")
}

# ============================================================================
# 6. VALIDATION CHECKS
# ============================================================================

cat("\n============================================\n")
cat("   VALIDATION CHECKS\n")
cat("============================================\n\n")

# --- Adult ---
cat("--- Adult file ---\n")
print(as.data.frame(adult %>% count(srvy_yr)), row.names = FALSE)
cat(paste0("\n  Era distribution:\n"))
print(as.data.frame(adult %>% count(era_post2019) %>%
  mutate(era = ifelse(era_post2019 == 0, "Pre-2019", "2019+"))), row.names = FALSE)

adult_key <- c("srvy_yr", "hhx", "agep_a", "sex_a", "wtfa_a", "pstrat", "ppsu")
present <- adult_key %in% names(adult)
if (all(present)) {
  cat("[PASS] All key adult variables present\n")
} else {
  cat(paste0("[FAIL] Missing: ", paste(adult_key[!present], collapse = ", "), "\n"))
}

# --- Child ---
cat("\n--- Child file ---\n")
print(as.data.frame(child %>% count(srvy_yr)), row.names = FALSE)

child_key <- c("srvy_yr", "hhx", "pstrat", "ppsu")
present <- child_key %in% names(child)
if (all(present)) {
  cat("[PASS] All key child variables present\n")
} else {
  cat(paste0("[FAIL] Missing: ", paste(child_key[!present], collapse = ", "), "\n"))
}

report_extra_var_families(adult, "adult")
report_extra_var_families(child, "child")

n_adult_years <- length(unique(adult$srvy_yr))
n_child_years <- length(unique(child$srvy_yr))
cat(paste0("\n[INFO] Adult total: ", nrow(adult), " obs across ",
           n_adult_years, " years (",
           min(adult$srvy_yr), "-", max(adult$srvy_yr), ")\n"))
cat(paste0("[INFO] Child total: ", nrow(child), " obs across ",
           n_child_years, " years (",
           min(child$srvy_yr), "-", max(child$srvy_yr), ")\n"))

cat("\n============================================\n")
cat("   DONE\n")
cat("============================================\n")
cat("Next step: run 02_clean_and_analyze.R\n")

################################################################################
# NOTES:
#
# 1. PRE-2019 .DTA FILES:
#    The .dta files for 2004-2018 are created or reused by the Stata loader.
#    Some 2015-2018 components are distributed as zipped ASCII/CSV files, and
#    the Stata loader handles extraction plus CSV fallback when needed.
#
# 2. FULL 2004-2024 R BUILDS:
#    Full all-column R builds can exceed memory because pre-2019 files carry
#    thousands of raw variables. For a full-year R build that feeds the starter
#    cleaner, set these before sourcing this script:
#      pre2019_years <- 2004:2018
#      keep_starter_vars_only <- TRUE
#    Use extra_vars for stable additional variable names. Use
#    extra_var_families for aliases that changed names across years, for
#    example:
#      extra_var_families <- list(
#        health_status_raw = c("phstat_a", "phstat")
#      )
#    Alias families merge columns by name only. They do not recode changing
#    meanings or value systems.
#
# 3. VARIABLE HARMONIZATION:
#    Variable names are renamed to match 2019+ convention (_a/_c suffix).
#    But CODING differs between eras (e.g., insurance 1/2/3 vs 1/2).
#    The cleaning script (02_clean_and_analyze.R) handles coding differences.
#
# 4. SURVEY DESIGN:
#    Stratum offsets (1000 for 2004-05, 2000 for 2006+) ensure strata
#    are distinct when pooling across design periods.
#
# 5. CITATION:
#    National Center for Health Statistics. National Health Interview
#    Survey, [year]. Hyattsville, Maryland.
#    https://www.cdc.gov/nchs/nhis/index.htm
################################################################################
