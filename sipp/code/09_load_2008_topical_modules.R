################################################################################
# 09_load_2008_topical_modules.R
#
# Purpose: Load selected 2008 SIPP topical module fixed-width files, writing one
#          output per selected wave because topical module content differs by wave.
#
# Inputs: data/2008/wave{wave}/p08putm{wave}.dat.gz and matching .sas layout
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
if (!exists("sipp_2008_tm_waves", inherits = TRUE)) {
  sipp_2008_tm_waves <- c(13)
}
if (!exists("sipp_2008_tm_keep_all", inherits = TRUE)) {
  sipp_2008_tm_keep_all <- FALSE
}
if (!exists("sipp_2008_tm_allocs", inherits = TRUE)) {
  sipp_2008_tm_allocs <- FALSE
}
if (!exists("sipp_2008_tm_extra_vars", inherits = TRUE)) {
  sipp_2008_tm_extra_vars <- character()
}
if (!exists("sipp_2008_tm_n_max", inherits = TRUE)) {
  sipp_2008_tm_n_max <- Inf
}
if (!exists("sipp_2008_tm_skip_missing", inherits = TRUE)) {
  sipp_2008_tm_skip_missing <- FALSE
}
if (!exists("sipp_2008_tm_write_dta_export", inherits = TRUE)) {
  sipp_2008_tm_write_dta_export <- FALSE
}
if (!exists("sipp_2008_tm_family_tag", inherits = TRUE)) {
  sipp_2008_tm_family_tag <- NULL
}
if (!exists("sipp_2008_tm_family_label", inherits = TRUE)) {
  sipp_2008_tm_family_label <- NULL
}
if (!exists("sipp_2008_tm_family_note", inherits = TRUE)) {
  sipp_2008_tm_family_note <- NULL
}

################################################################################
# HELPERS
################################################################################

get_current_script_dir <- function() {
  command_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", command_args, value = TRUE)
  if (length(file_arg) > 0) return(dirname(normalizePath(sub("^--file=", "", file_arg[[1]]), winslash = "/", mustWork = FALSE)))
  frame_paths <- vapply(sys.frames(), function(frame) if (!is.null(frame$ofile)) frame$ofile else "", character(1))
  frame_paths <- frame_paths[nzchar(frame_paths)]
  if (length(frame_paths) > 0) return(dirname(normalizePath(tail(frame_paths, 1), winslash = "/", mustWork = FALSE)))
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
        file.exists(file.path(path_norm, "code", script_name))) return(path_norm)
  }
  stop("Could not locate the sipp/ directory.", call. = FALSE)
}

topical_labels <- c(
  "1" = "Recipiency History; Employment History; Tax Rebates",
  "2" = "Work Disability History; Education and Training History; Marital History; Migration History; Fertility History; Household Relationships; Tax Rebates",
  "3" = "Welfare Reform; Retirement and Pension Plan Coverage",
  "4" = "Assets and Liabilities; Real Estate, Dependent Care, and Vehicles; Mortgages, Stocks, Interest Accounts, Rental Property, Business Value, Other Assets; Work-Related Expenses/Child Support Paid; Medical Expenses/Health Care Utilization; Child Well-being",
  "5" = "Child Care; Work Schedule; Annual Income and Retirement Accounts; Taxes",
  "6" = "Adult Well-being; Child Support Agreements; Support for Non-household Members; Functional Limitations and Disability; Employer Provided Health Benefits",
  "7" = "Assets and Liabilities; Real Estate, Dependent Care, and Vehicles; Mortgages, Stocks, Interest Accounts, Rental Property, Business Value, Other Assets; Work-Related Expenses/Child Support Paid; Medical Expenses/Health Care Utilization",
  "8" = "Child Care; Work Schedule; Annual Income and Retirement Accounts; Taxes",
  "9" = "Informal Care-giving; Adult Well-being",
  "10" = "Assets and Liabilities; Real Estate, Dependent Care, and Vehicles; Mortgages, Stocks, Interest Accounts, Rental Property, Business Value, Other Assets; Work-Related Expenses/Child Support Paid; Medical Expenses/Health Care Utilization; Child Well-being",
  "11" = "Retirement and Pension Plan Coverage",
  "13" = "Professional Certificates and Certifications"
)

available_topical_waves <- as.integer(names(topical_labels))

normalize_waves <- function(waves) {
  if (is.null(waves) || identical(tolower(waves), "all")) return(available_topical_waves)
  waves <- unique(as.integer(waves))
  invalid <- setdiff(waves, available_topical_waves)
  if (length(invalid) > 0) {
    stop(
      "Invalid 2008 topical wave(s): ", paste(invalid, collapse = ", "),
      ". Local public topical files are present for waves ",
      paste(available_topical_waves, collapse = ", "), ".",
      call. = FALSE
    )
  }
  waves
}

parse_sas_layout <- function(path) {
  lines <- readLines(path, warn = FALSE)
  input_start <- which(trimws(lines) == "INPUT")
  if (length(input_start) == 0) stop("Could not find INPUT block in ", path, call. = FALSE)
  lines <- lines[(input_start[[1]] + 1):length(lines)]
  lines <- lines[!grepl("^\\s*;", lines)]
  lines <- lines[grepl("^\\s*[A-Za-z]", lines)]
  pattern <- "^\\s*([A-Za-z][A-Za-z0-9_]*)\\s+(\\$\\s+)?([0-9]+)\\s*-\\s*([0-9]+)"
  pieces <- lapply(lines, function(line) {
    hit <- regexec(pattern, line, perl = TRUE)
    parts <- regmatches(line, hit)[[1]]
    if (length(parts) == 0) return(NULL)
    tibble(
      name = tolower(parts[[2]]),
      is_string = nzchar(trimws(parts[[3]])),
      start = as.integer(parts[[4]]),
      end = as.integer(parts[[5]])
    )
  })
  out <- bind_rows(pieces)
  if (nrow(out) == 0) stop("Could not parse fixed-width positions from ", path, call. = FALSE)
  out
}

select_layout <- function(layout) {
  extras <- tolower(sipp_2008_tm_extra_vars)
  keep <- layout$name != "filler"
  if (!isTRUE(sipp_2008_tm_keep_all)) {
    keep <- keep & (substr(layout$name, 1, 1) != "a" | layout$name %in% extras | isTRUE(sipp_2008_tm_allocs))
  }
  layout[keep, , drop = FALSE]
}

clean_family_text <- function(x) {
  if (is.null(x) || length(x) == 0 || !nzchar(as.character(x[[1]]))) return(NA_character_)
  as.character(x[[1]])
}

clean_family_tag <- function(x) {
  tag <- clean_family_text(x)
  if (is.na(tag)) return(NA_character_)
  tag <- tolower(gsub("[^A-Za-z0-9]+", "_", tag))
  tag <- gsub("^_+|_+$", "", tag)
  if (!nzchar(tag)) return(NA_character_)
  tag
}

family_tag <- clean_family_tag(sipp_2008_tm_family_tag)
family_label <- clean_family_text(sipp_2008_tm_family_label)
family_note <- clean_family_text(sipp_2008_tm_family_note)

topical_output_suffix <- function(wave) {
  if (!is.na(family_tag)) {
    return(paste0("_2008_topical_", family_tag, "_wave", wave))
  }
  paste0("_2008_topical_wave", wave)
}

to_number <- function(x) suppressWarnings(as.numeric(trimws(x)))

sipp_root <- resolve_sipp_root("09_load_2008_topical_modules.R")
if (is.null(sipp_output_dir)) {
  sipp_output_dir <- file.path(sipp_root, "output")
}
dir.create(sipp_output_dir, recursive = TRUE, showWarnings = FALSE)

topical_path <- function(wave, ext) {
  file.path(sipp_root, "data", "2008", paste0("wave", wave), paste0("p08putm", wave, ext))
}

load_topical_wave <- function(wave) {
  dat_path <- topical_path(wave, ".dat.gz")
  sas_path <- topical_path(wave, ".sas")
  if (!file.exists(dat_path) || !file.exists(sas_path)) {
    msg <- paste0("No local 2008 SIPP topical wave ", wave, " data/layout pair found.")
    if (isTRUE(sipp_2008_tm_skip_missing)) {
      warning(msg, call. = FALSE)
      return(NULL)
    }
    stop(msg, call. = FALSE)
  }

  layout <- select_layout(parse_sas_layout(sas_path))
  cat(paste0("Reading 2008 SIPP topical wave ", wave, "\n"))
  data <- read_fwf(
    dat_path,
    fwf_positions(layout$start, layout$end, layout$name),
    n_max = if (is.finite(sipp_2008_tm_n_max)) as.integer(sipp_2008_tm_n_max) else Inf,
    col_types = cols(.default = col_character()),
    progress = FALSE
  )
  character_vars <- intersect(c("ssuid", "shhadid"), names(data))
  for (nm in setdiff(names(data), character_vars)) {
    data[[nm]] <- to_number(data[[nm]])
  }
  if ("epppnum" %in% names(data)) data$pnum <- data$epppnum
  if ("eeducate" %in% names(data)) data$eeduc <- data$eeducate

  bind_cols(
    tibble(
      source_file = paste0("p08putm", wave, ".dat"),
      sipp_file_year = 2008L,
      panel_wave = as.integer(wave),
      topical_family = family_tag,
      topical_family_label = family_label,
      topical_family_note = family_note,
      topical_modules = unname(topical_labels[as.character(wave)])
    ),
    data
  )
}

selected_waves <- normalize_waves(sipp_2008_tm_waves)
cat(paste0("Selected 2008 SIPP topical waves: ", paste(selected_waves, collapse = ", "), "\n"))
cat("Topical wave outputs are written separately; do not append unlike modules without harmonizing concepts first.\n")
if (!is.na(family_tag)) {
  cat(paste0("Topical family: ", family_tag, "\n"))
  if (!is.na(family_note)) cat(paste0("Family note: ", family_note, "\n"))
}

sipp_2008_topical_modules <- list()
for (wave in selected_waves) {
  wave_data <- load_topical_wave(wave)
  if (is.null(wave_data)) next
  sipp_2008_topical_modules[[paste0("wave", wave)]] <- wave_data
  out_rds <- file.path(sipp_output_dir, paste0(sipp_output_basename, topical_output_suffix(wave), ".rds"))
  saveRDS(wave_data, out_rds)
  cat(paste0("Saved 2008 SIPP topical wave ", wave, ": ", out_rds, " (", nrow(wave_data), " rows, ", ncol(wave_data), " columns)\n"))
  if (isTRUE(sipp_2008_tm_write_dta_export)) {
    if (!requireNamespace("haven", quietly = TRUE)) {
      warning("Package haven is required for optional Stata export.", call. = FALSE)
    } else {
      out_dta <- file.path(sipp_output_dir, paste0(sipp_output_basename, topical_output_suffix(wave), "_from_r.dta"))
      haven::write_dta(wave_data, out_dta)
      cat(paste0("Saved optional Stata export: ", out_dta, "\n"))
    }
  }
}

if (length(sipp_2008_topical_modules) == 0) {
  stop("No 2008 SIPP topical module files were loaded.", call. = FALSE)
}

sipp_2008_topical <- sipp_2008_topical_modules[[length(sipp_2008_topical_modules)]]
