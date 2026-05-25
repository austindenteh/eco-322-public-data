################################################################################
# 03_load_linkable_modules.R
#
# Purpose: Load selected PSID linkable modules that use 1968 family/person IDs.
#          These files are separate from the main family/person-year starter.
#
# Inputs:  data/parent_identification/pid23/PID23.txt + PID23.do
#          data/marriage_history/mh85_23/MH85_23.txt + MH85_23.do
#          data/childbirth_adaoption_history/cah85_23/CAH85_23.txt + CAH85_23.do
# Outputs: output/psid_parent_id.rds
#          output/psid_marriage_history.rds
#          output/psid_childbirth_adoption_history.rds
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
#   psid_output_dir <- "/private/tmp/psid_modules_smoke"
#   psid_linkable_modules <- c("parent_id", "marriage_history")
#   psid_linkable_keep_all_vars <- FALSE
#   psid_childbirth_extra_vars <- c("CAH103", "CAH110", "CAH112")

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

# Choose any subset of: parent_id, marriage_history, childbirth_adoption.
# Use "all" or NULL to load all three.
if (!exists("psid_linkable_modules", inherits = TRUE)) {
  psid_linkable_modules <- c("parent_id", "marriage_history", "childbirth_adoption")
}

# The linkable modules are modestly sized, so the default keeps all raw columns
# and renames the most important linkage fields. Set FALSE to keep only starter
# keys plus module-specific extras below.
if (!exists("psid_linkable_keep_all_vars", inherits = TRUE)) {
  psid_linkable_keep_all_vars <- TRUE
}

if (!exists("psid_parent_extra_vars", inherits = TRUE)) {
  psid_parent_extra_vars <- character(0)
}
if (!exists("psid_marriage_extra_vars", inherits = TRUE)) {
  psid_marriage_extra_vars <- character(0)
}
if (!exists("psid_childbirth_extra_vars", inherits = TRUE)) {
  psid_childbirth_extra_vars <- character(0)
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

psid_root <- resolve_psid_root("03_load_linkable_modules.R")
if (is.null(psid_output_dir)) {
  psid_output_dir <- file.path(psid_root, "output")
}
dir.create(psid_output_dir, recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# 2. FIXED-WIDTH HELPERS
# ============================================================================

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
  out <- tibble(
    name = parsed[, 1],
    name_lower = tolower(parsed[, 1]),
    start = as.integer(parsed[, 2]),
    end = as.integer(parsed[, 3])
  )
  distinct(out, name_lower, .keep_all = TRUE)
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
    file = txt_path,
    col_positions = fwf_positions(
      start = selected$start,
      end = selected$end,
      col_names = selected$name_lower
    ),
    col_types = cols(.default = col_double()),
    progress = FALSE,
    show_col_types = FALSE
  )
}

rename_known_vars <- function(data, rename_map) {
  from <- intersect(names(rename_map), names(data))
  if (length(from) == 0) return(data)
  to <- unname(rename_map[from])
  names(data)[match(from, names(data))] <- to
  data
}

# ============================================================================
# 3. MODULE SPECS
# ============================================================================

parent_rename <- c(
  pid1 = "release_number",
  pid2 = "individual_1968_family_id",
  pid3 = "individual_person_number",
  pid4 = "birth_mother_1968_family_id",
  pid5 = "birth_mother_person_number",
  pid6 = "adoptive_mother1_1968_family_id",
  pid7 = "adoptive_mother1_person_number",
  pid8 = "adoptive_mother2_1968_family_id",
  pid9 = "adoptive_mother2_person_number",
  pid23 = "birth_father_1968_family_id",
  pid24 = "birth_father_person_number",
  pid25 = "adoptive_father1_1968_family_id",
  pid26 = "adoptive_father1_person_number",
  pid27 = "adoptive_father2_1968_family_id",
  pid28 = "adoptive_father2_person_number"
)

marriage_rename <- c(
  mh1 = "release_number",
  mh2 = "individual_1968_family_id",
  mh3 = "individual_person_number",
  mh4 = "sex",
  mh5 = "birth_month",
  mh6 = "birth_year",
  mh7 = "spouse_1968_family_id",
  mh8 = "spouse_person_number",
  mh9 = "marriage_order",
  mh10 = "month_married",
  mh11 = "year_married",
  mh12 = "marriage_status",
  mh13 = "month_widowed_or_divorced",
  mh14 = "year_widowed_or_divorced",
  mh15 = "month_separated",
  mh16 = "year_separated",
  mh17 = "year_most_recently_reported",
  mh18 = "number_of_marriages",
  mh19 = "last_known_marital_status",
  mh20 = "number_of_marriage_records"
)

childbirth_rename <- c(
  cah1 = "release_number",
  cah2 = "record_type",
  cah3 = "parent_1968_family_id",
  cah4 = "parent_person_number",
  cah5 = "parent_sex",
  cah6 = "parent_birth_month",
  cah7 = "parent_birth_year",
  cah8 = "mother_marital_status_at_birth",
  cah9 = "birth_order",
  cah10 = "child_1968_family_id",
  cah11 = "child_person_number",
  cah12 = "child_sex",
  cah13 = "child_birth_month",
  cah15 = "child_birth_year",
  cah16 = "child_birth_weight_ounces",
  cah22 = "child_birth_state",
  cah23 = "child_birth_county",
  cah24 = "child_last_reported_location",
  cah25 = "child_moved_out_or_died_month",
  cah26 = "child_moved_out_or_died_year",
  cah27 = "child_hispanicity",
  cah28 = "child_race_1",
  cah29 = "child_race_2",
  cah30 = "child_race_3",
  cah35 = "multiple_birth_checkpoint",
  cah36 = "part_of_multiple_birth",
  cah37 = "multiple_birth_type",
  cah54 = "gestation_weeks",
  cah75 = "prenatal_visits",
  cah103 = "wanted_to_become_pregnant",
  cah110 = "pregnancy_wanted_by_mother",
  cah112 = "pregnancy_wanted_by_father",
  cah114 = "year_reported_number_of_kids",
  cah115 = "year_reported_this_child",
  cah116 = "num_natural_or_adopted_children",
  cah117 = "relationship_to_adoptive_parent",
  cah118 = "number_birth_or_adoption_records"
)

module_specs <- list(
  parent_id = list(
    folder = file.path("data", "parent_identification", "pid23"),
    base = "PID23",
    output_suffix = "parent_id",
    source_module = "parent_identification",
    rename = parent_rename,
    key_vars = names(parent_rename),
    extra_vars = psid_parent_extra_vars
  ),
  marriage_history = list(
    folder = file.path("data", "marriage_history", "mh85_23"),
    base = "MH85_23",
    output_suffix = "marriage_history",
    source_module = "marriage_history",
    rename = marriage_rename,
    key_vars = names(marriage_rename),
    extra_vars = psid_marriage_extra_vars
  ),
  childbirth_adoption = list(
    folder = file.path("data", "childbirth_adaoption_history", "cah85_23"),
    base = "CAH85_23",
    output_suffix = "childbirth_adoption_history",
    source_module = "childbirth_adoption_history",
    rename = childbirth_rename,
    key_vars = names(childbirth_rename),
    extra_vars = psid_childbirth_extra_vars
  )
)

resolve_modules <- function(modules) {
  available <- names(module_specs)
  if (is.null(modules) || identical(tolower(modules), "all")) {
    return(available)
  }
  modules <- tolower(modules)
  invalid <- setdiff(modules, available)
  if (length(invalid) > 0) {
    stop(
      "Invalid PSID linkable modules: ", paste(invalid, collapse = ", "), "\n",
      "Choose from: ", paste(available, collapse = ", "), " or use 'all'.",
      call. = FALSE
    )
  }
  unique(modules)
}

load_module <- function(module_name) {
  spec <- module_specs[[module_name]]
  raw_dir <- file.path(psid_root, spec$folder)
  do_path <- file.path(raw_dir, paste0(spec$base, ".do"))
  txt_path <- file.path(raw_dir, paste0(spec$base, ".txt"))

  if (!file.exists(do_path) || !file.exists(txt_path)) {
    stop(
      "Missing setup or text file for module ", module_name, ":\n",
      do_path, "\n", txt_path,
      call. = FALSE
    )
  }

  infix_spec <- parse_stata_infix_spec(do_path)
  vars <- NULL
  if (!isTRUE(psid_linkable_keep_all_vars)) {
    vars <- c(spec$key_vars, spec$extra_vars)
  }

  cat(paste0("Reading PSID linkable module: ", module_name, "\n"))
  data <- read_psid_fwf(txt_path, infix_spec, vars = vars)
  data <- rename_known_vars(data, spec$rename)
  data <- mutate(
    data,
    source_module = spec$source_module,
    source_file = spec$base,
    .before = 1
  )

  out_rds <- file.path(psid_output_dir, paste0(psid_output_basename, "_", spec$output_suffix, ".rds"))
  saveRDS(data, out_rds)
  cat(paste0("Saved ", module_name, ": ", out_rds, " (", nrow(data), " rows)\n"))

  if (isTRUE(psid_write_dta_export)) {
    out_dta <- file.path(psid_output_dir, paste0(psid_output_basename, "_", spec$output_suffix, "_from_r.dta"))
    write_dta(data, out_dta)
    cat(paste0("Saved optional Stata export: ", out_dta, "\n"))
  }

  invisible(data)
}

selected_modules <- resolve_modules(psid_linkable_modules)
cat(paste0("Selected PSID linkable modules: ", paste(selected_modules, collapse = ", "), "\n"))

loaded_modules <- lapply(selected_modules, load_module)
names(loaded_modules) <- selected_modules
