################################################################################
# 04_load_additional_modules.R
#
# Purpose: Load additional optional PSID modules that are useful but should not
#          be merged into the main starter by default.
#
# Inputs:  data/family_relation_matrix/MX23REL/MX23REL.txt + MX23REL.do
#          data/pregnancy_intentions/pregint23/PREGINT23.txt + PREGINT23.do
#          data/active_savings/ActSavings89_94/ACT89.txt + ACT89.do
#          data/active_savings/ActSavings89_94/ACT94.txt + ACT94.do
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
#   psid_output_dir <- "/private/tmp/psid_additional_smoke"
#   psid_additional_modules <- c("pregnancy_intentions", "active_savings")
#   psid_family_relation_years <- c(2019, 2021, 2023)
#   psid_pregnancy_extra_vars <- c("PGINT9")
#   psid_active_savings_extra_vars <- c("ACT89V3")

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

# Choose any subset of: family_relation_matrix, pregnancy_intentions,
# active_savings. Use "all" or NULL to load all three.
if (!exists("psid_additional_modules", inherits = TRUE)) {
  psid_additional_modules <- c("pregnancy_intentions", "active_savings", "family_relation_matrix")
}

# The relationship matrix has 3.5M rows before filtering. Default to the latest
# year to keep the starter run quick. Use NULL for all years.
if (!exists("psid_family_relation_years", inherits = TRUE)) {
  psid_family_relation_years <- 2023
}

if (!exists("psid_pregnancy_extra_vars", inherits = TRUE)) {
  psid_pregnancy_extra_vars <- character(0)
}
if (!exists("psid_active_savings_extra_vars", inherits = TRUE)) {
  psid_active_savings_extra_vars <- character(0)
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

psid_root <- resolve_psid_root("04_load_additional_modules.R")
if (is.null(psid_output_dir)) {
  psid_output_dir <- file.path(psid_root, "output")
}
dir.create(psid_output_dir, recursive = TRUE, showWarnings = FALSE)

normalize_var_names <- function(x) {
  x <- unname(x)
  x <- x[!is.na(x) & nzchar(x)]
  unique(tolower(x))
}

parse_stata_infix_spec <- function(do_path) {
  txt <- paste(readLines(do_path, warn = FALSE), collapse = "\n")
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

read_psid_fwf <- function(txt_path, spec, vars = NULL) {
  if (is.null(vars)) {
    selected <- spec
  } else {
    requested <- normalize_var_names(vars)
    selected <- spec[match(requested, spec$name_lower), ]
    selected <- selected[!is.na(selected$name_lower), ]
    missing_vars <- setdiff(requested, selected$name_lower)
    if (length(missing_vars) > 0) {
      warning(
        "These requested variables were not found and will be skipped: ",
        paste(missing_vars, collapse = ", "),
        call. = FALSE
      )
    }
  }
  if (nrow(selected) == 0) {
    stop("No variables selected from ", txt_path, call. = FALSE)
  }
  read_fwf(
    txt_path,
    fwf_positions(selected$start, selected$end, selected$name_lower),
    col_types = cols(.default = col_double()),
    progress = FALSE,
    show_col_types = FALSE
  )
}

rename_known_vars <- function(data, rename_map) {
  from <- intersect(names(rename_map), names(data))
  if (length(from) == 0) return(data)
  names(data)[match(from, names(data))] <- unname(rename_map[from])
  data
}

write_module <- function(data, suffix) {
  out_rds <- file.path(psid_output_dir, paste0(psid_output_basename, "_", suffix, ".rds"))
  saveRDS(data, out_rds)
  cat(paste0("Saved ", suffix, ": ", out_rds, " (", nrow(data), " rows)\n"))
  if (isTRUE(psid_write_dta_export)) {
    out_dta <- file.path(psid_output_dir, paste0(psid_output_basename, "_", suffix, "_from_r.dta"))
    write_dta(data, out_dta)
    cat(paste0("Saved optional Stata export: ", out_dta, "\n"))
  }
}

resolve_modules <- function(modules) {
  available <- c("family_relation_matrix", "pregnancy_intentions", "active_savings")
  if (is.null(modules) || identical(tolower(modules), "all")) {
    return(available)
  }
  modules <- tolower(modules)
  invalid <- setdiff(modules, available)
  if (length(invalid) > 0) {
    stop(
      "Invalid PSID additional modules: ", paste(invalid, collapse = ", "), "\n",
      "Choose from: ", paste(available, collapse = ", "), " or use 'all'.",
      call. = FALSE
    )
  }
  unique(modules)
}

load_family_relation_matrix <- function() {
  raw_dir <- file.path(psid_root, "data", "family_relation_matrix", "MX23REL")
  do_path <- file.path(raw_dir, "MX23REL.do")
  txt_path <- file.path(raw_dir, "MX23REL.txt")
  if (!file.exists(do_path) || !file.exists(txt_path)) {
    stop("Missing family relationship matrix files.", call. = FALSE)
  }

  rename_map <- c(
    mx1 = "release_number",
    mx2 = "interview_year",
    mx3 = "family_interview_id",
    mx4 = "ego_sequence_number",
    mx5 = "ego_1968_family_id",
    mx6 = "ego_person_number",
    mx7 = "ego_relation_to_reference",
    mx8 = "ego_relation_to_alter",
    mx9 = "alter_sequence_number",
    mx10 = "alter_1968_family_id",
    mx11 = "alter_person_number",
    mx12 = "alter_relation_to_reference"
  )

  cat("Reading PSID additional module: family_relation_matrix\n")
  data <- read_psid_fwf(txt_path, parse_stata_infix_spec(do_path))
  data <- rename_known_vars(data, rename_map)
  if (!is.null(psid_family_relation_years)) {
    data <- filter(data, interview_year %in% as.integer(psid_family_relation_years))
  }
  data <- mutate(
    data,
    source_module = "family_relation_matrix",
    source_file = "MX23REL",
    .before = 1
  )
  write_module(data, "family_relation_matrix")
  invisible(data)
}

load_pregnancy_intentions <- function() {
  raw_dir <- file.path(psid_root, "data", "pregnancy_intentions", "pregint23")
  do_path <- file.path(raw_dir, "PREGINT23.do")
  txt_path <- file.path(raw_dir, "PREGINT23.txt")
  if (!file.exists(do_path) || !file.exists(txt_path)) {
    stop("Missing pregnancy intentions files.", call. = FALSE)
  }

  rename_map <- c(
    pgint1 = "release_number",
    pgint2 = "individual_1968_family_id",
    pgint3 = "individual_person_number",
    pgint4 = "report_year",
    pgint5 = "reporter_sex",
    pgint6 = "newborn_parent_checkpoint",
    pgint7 = "wants_another_child",
    pgint8 = "wants_or_not_another_child",
    pgint9 = "current_partner_checkpoint",
    pgint10 = "partner_wants_another_child",
    pgint11 = "more_children_intended",
    pgint12 = "contraception_last_3_months"
  )

  keep_vars <- c(names(rename_map), psid_pregnancy_extra_vars)
  cat("Reading PSID additional module: pregnancy_intentions\n")
  data <- read_psid_fwf(txt_path, parse_stata_infix_spec(do_path), vars = keep_vars)
  data <- rename_known_vars(data, rename_map)
  data <- mutate(
    data,
    source_module = "pregnancy_intentions",
    source_file = "PREGINT23",
    .before = 1
  )
  write_module(data, "pregnancy_intentions")
  invisible(data)
}

load_active_savings_one <- function(year) {
  raw_dir <- file.path(psid_root, "data", "active_savings", "ActSavings89_94")
  base <- paste0("ACT", substr(as.character(year), 3, 4))
  do_path <- file.path(raw_dir, paste0(base, ".do"))
  txt_path <- file.path(raw_dir, paste0(base, ".txt"))
  if (!file.exists(do_path) || !file.exists(txt_path)) {
    stop("Missing active savings files for ", year, ".", call. = FALSE)
  }

  prefix <- paste0("act", substr(as.character(year), 3, 4), "v")
  common_names <- c(
    "release_number", "family_interview_id", "put_into_annuity", "cash_in_annuity",
    "buy_real_estate", "sell_real_estate", "home_improvement", "buy_business",
    "sell_business", "assets_move_out", "debts_move_out", "assets_brought_in",
    "debts_brought_in", "gift_inheritance_1", "gift_inheritance_2"
  )
  if (year == 1989) {
    common_names <- c(common_names, "net_into_stock")
  } else {
    common_names <- c(common_names, "gift_inheritance_3", "net_into_stock", "sell_main_home")
  }

  raw_names <- paste0(prefix, seq_along(common_names))
  rename_map <- setNames(common_names, raw_names)
  keep_vars <- c(raw_names, psid_active_savings_extra_vars)
  data <- read_psid_fwf(txt_path, parse_stata_infix_spec(do_path), vars = keep_vars)
  data <- rename_known_vars(data, rename_map)
  data$survey_year <- year
  data$source_file <- base
  data
}

load_active_savings <- function() {
  cat("Reading PSID additional module: active_savings\n")
  data <- bind_rows(load_active_savings_one(1989), load_active_savings_one(1994)) %>%
    mutate(source_module = "active_savings", .before = 1) %>%
    relocate(survey_year, .after = source_file)
  write_module(data, "active_savings")
  invisible(data)
}

selected_modules <- resolve_modules(psid_additional_modules)
cat(paste0("Selected PSID additional modules: ", paste(selected_modules, collapse = ", "), "\n"))

loaded_modules <- list()
for (module in selected_modules) {
  loaded_modules[[module]] <- switch(
    module,
    family_relation_matrix = load_family_relation_matrix(),
    pregnancy_intentions = load_pregnancy_intentions(),
    active_savings = load_active_savings()
  )
}
