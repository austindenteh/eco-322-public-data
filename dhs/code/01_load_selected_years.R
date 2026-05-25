################################################################################
# 01_load_selected_years.R
#
# Purpose: Standalone selected-years Ghana DHS loader. Reads selected raw
#          columns from selected Ghana IR/MR Stata recode files, harmonizes the
#          same starter surface used by the wave-specific 01_load_YYYY scripts,
#          and saves a combined selected-years working dataset.
#
# Input:   data/raw/ghana_YYYY/... DHS Stata recode folders
# Output:  output/ghana_dhs_selected_working.rds
#          optional output/ghana_dhs_YYYY_working.rds
#          optional output/ghana_dhs_YYYY_working_from_R.dta
#          optional output/ghana_dhs_selected_working_from_R.dta
#
# Usage:   Run from dhs/, dhs/code/, from the repo root, or set
#          dhs_root_manual / DHS_ROOT.
################################################################################

library(haven)
library(dplyr)

# ============================================================================
# 1. PATHS AND USER SETTINGS
# ============================================================================

# Optional manual path override. Leave as NULL for auto-detection.
# Example:
# dhs_root_manual <- "/Users/yourname/path/to/econ-data-starters/dhs"
if (!exists("dhs_root_manual", inherits = TRUE)) {
  dhs_root_manual <- NULL
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

resolve_dhs_root <- function(script_name) {
  env_root <- Sys.getenv("DHS_ROOT", unset = "")

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
  candidates <- c(dhs_root_manual, env_root, search_paths, file.path(search_paths, "dhs"))
  candidates <- unique(candidates[!is.na(candidates) & nzchar(candidates)])

  for (path in candidates) {
    path_norm <- normalizePath(path, winslash = "/", mustWork = FALSE)
    if (file.exists(file.path(path_norm, "README.md")) &&
        file.exists(file.path(path_norm, "code", script_name))) {
      return(path_norm)
    }
  }

  stop(
    "Could not locate the dhs/ directory.\n",
    "Run this script from dhs/, dhs/code/, from the repo root, ",
    "or set dhs_root_manual / DHS_ROOT to the dhs path.\n",
    paste0("Current working directory: ", getwd(), "\n"),
    'Manual override in this script: dhs_root_manual <- "/path/to/dhs"\n',
    'Manual override before sourcing: Sys.setenv(DHS_ROOT = "/path/to/dhs")',
    call. = FALSE
  )
}

if (!exists("dhs_years", inherits = TRUE)) {
  dhs_years <- c(1988, 1993, 1998, 2003, 2008, 2014, 2022)
}
if (!exists("dhs_samples", inherits = TRUE)) {
  dhs_samples <- c("women", "men")
}
if (!exists("dhs_output_dir", inherits = TRUE)) {
  dhs_output_dir <- NULL
}
if (!exists("write_dta_export", inherits = TRUE)) {
  write_dta_export <- FALSE
}
if (!exists("write_wave_outputs", inherits = TRUE)) {
  write_wave_outputs <- TRUE
}
if (!exists("dhs_combined_basename", inherits = TRUE)) {
  dhs_combined_basename <- "ghana_dhs_selected_working"
}
if (!exists("extra_vars", inherits = TRUE)) {
  extra_vars <- character(0)
}
if (!exists("extra_var_families", inherits = TRUE)) {
  extra_var_families <- list()
}

# Add raw variables beyond the starter set here. Use raw DHS names. For pooled
# women/men builds, use extra_var_families when names differ by sample prefix.
# Examples:
# dhs_years <- c(2008, 2022)
# dhs_samples <- c("women")
# write_wave_outputs <- TRUE
# extra_vars <- c("v133")
# extra_var_families <- list(insurance_type = c("v481c", "v481e", "mv481c", "mv481e"))

dhs_root <- resolve_dhs_root("01_load_selected_years.R")
if (is.null(dhs_output_dir)) {
  dhs_output_dir <- file.path(dhs_root, "output")
}
dir.create(dhs_output_dir, showWarnings = FALSE, recursive = TRUE)

sink(file.path(dhs_output_dir, "01_load_selected_years_R_log.txt"), split = TRUE)
on.exit(sink(), add = TRUE)

cat("============================================================\n")
cat("Ghana DHS selected-years loader (R)\n")
cat("============================================================\n")
cat(sprintf("Using DHS root: %s\n", dhs_root))
cat(sprintf("Using output directory: %s\n\n", dhs_output_dir))

# ============================================================================
# 2. WAVE METADATA AND HELPERS
# ============================================================================

wave_specs <- list(
  `1988` = list(
    women = c("GHIR02DT", "GHIR02FL.DTA"),
    men = NULL,
    valid_interview_years = 1988L,
    region_suffix = "101",
    residence_suffix = "102",
    educ_attain_suffix = NA_character_,
    literacy_suffix = NA_character_,
    wealth_suffix = NA_character_,
    any_insurance_suffix = NA_character_,
    nhis_suffix = NA_character_
  ),
  `1993` = list(
    women = c("GHIR31DT", "GHIR31FL.DTA"),
    men = c("GHMR31DT", "GHMR31FL.DTA"),
    valid_interview_years = c(1993L, 1994L),
    region_suffix = "024",
    residence_suffix = "025",
    educ_attain_suffix = "149",
    literacy_suffix = NA_character_,
    wealth_suffix = NA_character_,
    any_insurance_suffix = NA_character_,
    nhis_suffix = NA_character_
  ),
  `1998` = list(
    women = c("GHIR41DT", "GHIR41FL.DTA"),
    men = c("GHMR41DT", "GHMR41FL.DTA"),
    valid_interview_years = c(1998L, 1999L),
    region_suffix = "024",
    residence_suffix = "025",
    educ_attain_suffix = "149",
    literacy_suffix = NA_character_,
    wealth_suffix = NA_character_,
    any_insurance_suffix = NA_character_,
    nhis_suffix = NA_character_
  ),
  `2003` = list(
    women = c("GHIR4BDT", "GHIR4BFL.DTA"),
    men = c("GHMR4BDT", "GHMR4BFL.DTA"),
    valid_interview_years = 2003L,
    region_suffix = "024",
    residence_suffix = "025",
    educ_attain_suffix = "149",
    literacy_suffix = "155",
    wealth_suffix = "190",
    any_insurance_suffix = NA_character_,
    nhis_suffix = NA_character_
  ),
  `2008` = list(
    women = c("GHIR5ADT", "GHIR5AFL.DTA"),
    men = c("GHMR5ADT", "GHMR5AFL.DTA"),
    valid_interview_years = 2008L,
    region_suffix = "024",
    residence_suffix = "025",
    educ_attain_suffix = "149",
    literacy_suffix = "155",
    wealth_suffix = "190",
    any_insurance_suffix = "481",
    nhis_suffix = "481c"
  ),
  `2014` = list(
    women = c("GHIR72DT", "GHIR72FL.DTA"),
    men = c("GHMR71DT", "GHMR71FL.DTA"),
    valid_interview_years = c(2014L, 2015L),
    region_suffix = "024",
    residence_suffix = "025",
    educ_attain_suffix = "149",
    literacy_suffix = "155",
    wealth_suffix = "190",
    any_insurance_suffix = "481",
    nhis_suffix = "481e"
  ),
  `2022` = list(
    women = c("GHIR8CDT", "GHIR8CFL.DTA"),
    men = c("GHMR8CDT", "GHMR8CFL.DTA"),
    valid_interview_years = c(2022L, 2023L),
    region_suffix = "024",
    residence_suffix = "025",
    educ_attain_suffix = "149",
    literacy_suffix = "155",
    wealth_suffix = "190",
    any_insurance_suffix = "481",
    nhis_suffix = "481e"
  )
)

normalize_var_names <- function(x) {
  x <- unname(x)
  x <- x[!is.na(x) & nzchar(x)]
  unique(tolower(x))
}

extra_vars <- normalize_var_names(extra_vars)
if (is.null(extra_var_families)) {
  extra_var_families <- list()
}
if (!is.list(extra_var_families)) {
  stop("extra_var_families must be a named list of variable aliases.", call. = FALSE)
}
if (length(extra_var_families) > 0) {
  family_names <- names(extra_var_families)
  if (is.null(family_names) || any(is.na(family_names) | !nzchar(family_names))) {
    stop("Each entry in extra_var_families must have a descriptive name.", call. = FALSE)
  }
  names(extra_var_families) <- tolower(family_names)
  extra_var_families <- lapply(extra_var_families, normalize_var_names)
  cat(
    paste(
      "[INFO] extra_var_families only merge raw aliases into one column.",
      "If coding or meanings change across waves, harmonize that added variable",
      "later in 02_clean_YYYY.R or in your analysis code.\n"
    )
  )
}
family_alias_vars <- normalize_var_names(unlist(extra_var_families, use.names = FALSE))

reserved_output_names <- c(
  "female", "source_sample", "cluster_id", "household_id", "respondent_id",
  "sample_weight", "interview_month", "interview_year", "interview_cmc",
  "age_years", "region", "residence", "educ_level", "educ_attain",
  "literacy", "wealth_index", "religion", "ethnicity", "marital_status",
  "ever_married", "working_now", "any_insurance", "nhis_enrolled"
)
name_collisions <- intersect(c(extra_vars, names(extra_var_families)), reserved_output_names)
if (length(name_collisions) > 0) {
  stop(
    "Extra variables or family names collide with starter output names: ",
    paste(name_collisions, collapse = ", "),
    call. = FALSE
  )
}

selected_years <- sort(unique(as.integer(dhs_years)))
valid_years <- as.integer(names(wave_specs))
invalid_years <- setdiff(selected_years, valid_years)
if (length(invalid_years) > 0) {
  stop(
    "Unsupported DHS year(s): ", paste(invalid_years, collapse = ", "),
    ". Supported years are: ", paste(valid_years, collapse = ", "),
    call. = FALSE
  )
}

selected_samples <- unique(tolower(dhs_samples))
invalid_samples <- setdiff(selected_samples, c("women", "men"))
if (length(invalid_samples) > 0) {
  stop("dhs_samples must contain only 'women' and/or 'men'.", call. = FALSE)
}

raw_var <- function(prefix, suffix) {
  if (is.na(suffix) || !nzchar(suffix)) return(NA_character_)
  paste0(prefix, suffix)
}

find_recode_file <- function(year, sample_type, spec) {
  recode_spec <- spec[[sample_type]]
  if (is.null(recode_spec)) return(NA_character_)

  expected <- file.path(
    dhs_root, "data", "raw", paste0("ghana_", year),
    recode_spec[[1]], recode_spec[[2]]
  )
  if (file.exists(expected)) {
    return(expected)
  }

  parent_dir <- dirname(expected)
  if (dir.exists(parent_dir)) {
    hits <- list.files(
      parent_dir,
      pattern = paste0("^", gsub("([.])", "\\\\\\1", basename(expected)), "$"),
      ignore.case = TRUE,
      full.names = TRUE
    )
    if (length(hits) > 0) {
      return(hits[[1]])
    }
  }

  stop(
    "Could not find ", sample_type, " recode for Ghana DHS ", year, " at:\n",
    expected, "\n",
    "Download the DHS Stata recode file and preserve the DHS folder name.",
    call. = FALSE
  )
}

coalesce_raw_values <- function(raw, aliases, n) {
  present <- aliases[aliases %in% names(raw)]
  if (length(present) == 0) {
    return(rep(NA, n))
  }

  values <- raw[present]
  tryCatch(
    dplyr::coalesce(!!!values),
    error = function(e) {
      values_chr <- lapply(values, as.character)
      dplyr::coalesce(!!!values_chr)
    }
  )
}

sample_var_map <- function(sample_type, spec) {
  prefix <- if (sample_type == "women") "v" else "mv"

  c(
    cluster_id = raw_var(prefix, "001"),
    household_id = raw_var(prefix, "002"),
    respondent_id = raw_var(prefix, "003"),
    sample_weight = raw_var(prefix, "005"),
    interview_month = raw_var(prefix, "006"),
    interview_year = raw_var(prefix, "007"),
    interview_cmc = raw_var(prefix, "008"),
    age_years = raw_var(prefix, "012"),
    region = raw_var(prefix, spec$region_suffix),
    residence = raw_var(prefix, spec$residence_suffix),
    educ_level = raw_var(prefix, "106"),
    educ_attain = raw_var(prefix, spec$educ_attain_suffix),
    literacy = raw_var(prefix, spec$literacy_suffix),
    wealth_index = raw_var(prefix, spec$wealth_suffix),
    religion = raw_var(prefix, "130"),
    ethnicity = raw_var(prefix, "131"),
    marital_status = raw_var(prefix, "501"),
    ever_married = raw_var(prefix, "502"),
    working_now = raw_var(prefix, "714"),
    any_insurance = raw_var(prefix, spec$any_insurance_suffix),
    nhis_enrolled = raw_var(prefix, spec$nhis_suffix)
  )
}

required_output_names <- c(
  "cluster_id", "household_id", "respondent_id", "sample_weight",
  "interview_month", "interview_year", "interview_cmc", "age_years",
  "region", "residence", "educ_level", "religion", "ethnicity",
  "marital_status", "ever_married", "working_now"
)

read_sample_low_memory <- function(year, sample_type, spec) {
  sample_file <- find_recode_file(year, sample_type, spec)
  var_map <- sample_var_map(sample_type, spec)

  required_raw_vars <- unname(var_map[required_output_names])
  selected_raw_vars <- unique(c(unname(var_map), extra_vars, family_alias_vars))
  selected_raw_vars <- selected_raw_vars[!is.na(selected_raw_vars) & nzchar(selected_raw_vars)]

  cat(sprintf(
    "\n--- Loading %s %s recode with %d requested raw columns ---\n",
    year, sample_type, length(selected_raw_vars)
  ))

  raw <- read_dta(sample_file, col_select = any_of(selected_raw_vars))
  names(raw) <- tolower(names(raw))
  cat(sprintf("  Source file: %s\n", sample_file))
  cat(sprintf("  Observations: %d\n  Loaded variables: %d\n", nrow(raw), ncol(raw)))

  missing_required <- setdiff(required_raw_vars, names(raw))
  if (length(missing_required) > 0) {
    stop(
      "Missing required raw variable(s) in ", basename(sample_file), ": ",
      paste(missing_required, collapse = ", "),
      call. = FALSE
    )
  }

  n <- nrow(raw)
  pick <- function(output_name, required = FALSE) {
    raw_name <- var_map[[output_name]]
    if (is.na(raw_name) || !nzchar(raw_name)) {
      return(rep(NA_integer_, n))
    }
    if (!(raw_name %in% names(raw))) {
      if (required) {
        stop(
          "Missing required raw variable ", raw_name, " for output ",
          output_name, call. = FALSE
        )
      }
      return(rep(NA_integer_, n))
    }
    raw[[raw_name]]
  }

  fix_year <- function(x) {
    year_value <- as.integer(x)
    ifelse(!is.na(year_value) & year_value < 100L, year_value + 1900L, year_value)
  }

  out <- tibble(
    female = if (sample_type == "women") 1L else 0L,
    source_sample = sample_type,
    cluster_id = as.integer(pick("cluster_id", required = TRUE)),
    household_id = as.integer(pick("household_id", required = TRUE)),
    respondent_id = as.integer(pick("respondent_id", required = TRUE)),
    sample_weight = as.numeric(pick("sample_weight", required = TRUE)) / 1e6,
    interview_month = as.integer(pick("interview_month", required = TRUE)),
    interview_year = fix_year(pick("interview_year", required = TRUE)),
    interview_cmc = as.integer(pick("interview_cmc", required = TRUE)),
    age_years = as.integer(pick("age_years", required = TRUE)),
    region = as.integer(pick("region", required = TRUE)),
    residence = as.integer(pick("residence", required = TRUE)),
    educ_level = as.integer(pick("educ_level", required = TRUE)),
    educ_attain = as.integer(pick("educ_attain")),
    literacy = as.integer(pick("literacy")),
    wealth_index = as.integer(pick("wealth_index")),
    religion = as.integer(pick("religion", required = TRUE)),
    ethnicity = as.integer(pick("ethnicity", required = TRUE)),
    marital_status = as.integer(pick("marital_status", required = TRUE)),
    ever_married = as.integer(pick("ever_married", required = TRUE)),
    working_now = as.integer(pick("working_now", required = TRUE)),
    any_insurance = as.integer(pick("any_insurance")),
    nhis_enrolled = as.integer(pick("nhis_enrolled"))
  )

  out <- out %>%
    mutate(
      any_insurance = ifelse(any_insurance %in% c(9L, 99L), NA_integer_, any_insurance),
      nhis_enrolled = ifelse(nhis_enrolled %in% c(9L, 99L), NA_integer_, nhis_enrolled)
    )

  for (extra in extra_vars) {
    out[[extra]] <- if (extra %in% names(raw)) raw[[extra]] else NA
  }

  for (family_name in names(extra_var_families)) {
    out[[family_name]] <- coalesce_raw_values(raw, extra_var_families[[family_name]], n)
  }

  out
}

load_wave <- function(year) {
  spec <- wave_specs[[as.character(year)]]
  available_samples <- selected_samples
  if (is.null(spec$men) && "men" %in% available_samples) {
    cat(sprintf("[INFO] Ghana DHS %s has no men's recode; skipping men.\n", year))
    available_samples <- setdiff(available_samples, "men")
  }

  if (length(available_samples) == 0) {
    stop("No available samples requested for Ghana DHS ", year, ".", call. = FALSE)
  }

  wave_parts <- lapply(available_samples, function(sample_type) {
    read_sample_low_memory(year, sample_type, spec)
  })

  wave_data <- bind_rows(wave_parts) %>%
    mutate(
      survey_year = year,
      region_scheme = if_else(year == 2022L, "16_region", "10_region"),
      has_men_recode = year != 1988L,
      has_wealth_index = year >= 2003L,
      has_literacy = year >= 2003L,
      has_health_insurance = year %in% c(2008L, 2014L, 2022L),
      .before = interview_month
    ) %>%
    arrange(female, cluster_id, household_id, respondent_id)

  invalid_interview_years <- setdiff(
    sort(unique(wave_data$interview_year)),
    spec$valid_interview_years
  )
  if (length(invalid_interview_years) > 0) {
    stop(
      "Unexpected interview year(s) in Ghana DHS ", year, ": ",
      paste(invalid_interview_years, collapse = ", "),
      call. = FALSE
    )
  }
  if (any(is.na(wave_data$sample_weight)) || any(wave_data$sample_weight <= 0, na.rm = TRUE)) {
    stop("Sample weights must be nonmissing and positive for Ghana DHS ", year, ".", call. = FALSE)
  }

  n_women <- sum(wave_data$female == 1L)
  n_men <- sum(wave_data$female == 0L)
  cat("\n=== Validation Checks ===\n")
  cat(sprintf("Year: %s\n", year))
  cat(sprintf("Total observations: %d\n", nrow(wave_data)))
  cat(sprintf("Women: %d  |  Men: %d\n", n_women, n_men))
  cat(sprintf("Interview years present: %s\n", paste(sort(unique(wave_data$interview_year)), collapse = ", ")))
  cat(sprintf("Raw/extra columns in output: %d\n", ncol(wave_data)))

  if (isTRUE(write_wave_outputs)) {
    output_base <- paste0("ghana_dhs_", year, "_working")
    out_rds <- file.path(dhs_output_dir, paste0(output_base, ".rds"))
    out_dta <- file.path(dhs_output_dir, paste0(output_base, "_from_R.dta"))

    saveRDS(wave_data, out_rds)
    cat(sprintf("Saved wave file: %s\n", out_rds))
    if (isTRUE(write_dta_export)) {
      write_dta(wave_data, out_dta)
      cat(sprintf("Saved optional Stata wave export: %s\n", out_dta))
    }
  }

  invisible(wave_data)
}

print_pooling_guidance <- function(years, samples) {
  years <- sort(unique(as.integer(years)))
  samples <- unique(tolower(samples))

  cat("\n=== Pooling Guidance ===\n")
  cat("This loader harmonizes a starter surface; it does not make every DHS concept fully comparable across waves.\n")
  cat("Best-supported pooled windows:\n")
  cat("  - 2008, 2014: strongest NHIS window with the same 10-region geography.\n")
  cat("  - 2008, 2014, 2022: useful for national NHIS/descriptive work; map 2022 regions before raw region comparisons.\n")
  cat("  - 2003, 2008, 2014, 2022: wealth/literacy plus common demographics, but health insurance starts in 2008.\n")
  cat("  - 1993 onward: basic demographics only; no wealth/literacy before 2003 and no insurance before 2008.\n")
  cat("  - 1988: women only; use for women-only long-run comparisons.\n")

  if (1988L %in% years) {
    cat("[NOTE] 1988 has no men's recode. Requests for men are skipped for that wave.\n")
  }
  if (any(years < 2003L) && any(years >= 2003L)) {
    cat("[NOTE] Wealth and literacy variables are not available before 2003; pooled columns are missing for 1988/1993/1998.\n")
  }
  if (any(years < 2008L) && any(years >= 2008L)) {
    cat("[NOTE] Health insurance/NHIS variables are only available in 2008, 2014, and 2022.\n")
  }
  if (2022L %in% years && any(years < 2022L)) {
    cat("[NOTE] 2022 uses Ghana's 16-region post-2019 geography; earlier waves use 10 regions.\n")
  }
  if (length(extra_var_families) > 0) {
    cat("[NOTE] extra_var_families coalesce aliases by name only; check coding and meaning before analysis.\n")
  }
  if ("men" %in% samples && 1988L %in% years) {
    cat("[NOTE] Sex-pooled analyses including 1988 have an unbalanced sample frame because 1988 is women-only.\n")
  }
  cat("Wave-level flags in the combined output: region_scheme, has_men_recode, has_wealth_index, has_literacy, has_health_insurance.\n\n")
}

# ============================================================================
# 3. RUN SELECTED WAVES
# ============================================================================

cat(sprintf("Selected years: %s\n", paste(selected_years, collapse = ", ")))
cat(sprintf("Selected samples: %s\n", paste(selected_samples, collapse = ", ")))
cat(sprintf("Extra vars: %s\n", ifelse(length(extra_vars) == 0, "(none)", paste(extra_vars, collapse = ", "))))
cat(sprintf(
  "Extra families: %s\n",
  ifelse(length(extra_var_families) == 0, "(none)", paste(names(extra_var_families), collapse = ", "))
))
cat(sprintf("Write per-wave outputs: %s\n", write_wave_outputs))
cat(sprintf("Optional Stata export from R: %s\n", write_dta_export))
print_pooling_guidance(selected_years, selected_samples)

loaded_waves <- lapply(selected_years, load_wave)
combined_data <- bind_rows(loaded_waves) %>%
  arrange(survey_year, female, cluster_id, household_id, respondent_id)

combined_rds <- file.path(dhs_output_dir, paste0(dhs_combined_basename, ".rds"))
combined_dta <- file.path(dhs_output_dir, paste0(dhs_combined_basename, "_from_R.dta"))

saveRDS(combined_data, combined_rds)
cat(sprintf("\nSaved combined selected-years file: %s\n", combined_rds))
cat(sprintf("Combined N = %d\n", nrow(combined_data)))
cat(sprintf("Survey years present: %s\n", paste(sort(unique(combined_data$survey_year)), collapse = ", ")))
if (isTRUE(write_dta_export)) {
  write_dta(combined_data, combined_dta)
  cat(sprintf("Saved optional combined Stata export: %s\n", combined_dta))
}

cat("\n============================================================\n")
cat("Ghana DHS selected-years loader complete.\n")
cat("============================================================\n")
