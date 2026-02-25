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
#          PRE-2019 (2004-2014, optional): 5-file hierarchical design
#            Load .dta files (created by CDC do-files from raw ASCII)
#            Merge personsx + familyxx + househld + samadult/samchild
#            Harmonize variable names
#
#          NOTE: Pre-2019 .dta files must be created by running the
#          CDC-provided Stata do-files first. If the .dta files don't exist,
#          run 01_load_and_append.do in Stata first. For 2019-2024 (the
#          default), this R script works standalone — no Stata needed.
#
#          DEFAULT: Loads 2019-2024 only (post-redesign, CSV files).
#          To include pre-2019 years, uncomment the pre2019_years line
#          below. The script auto-detects which year folders are present
#          and skips any missing years.
#
# Input:   data/NHIS 2019/ ... data/NHIS 2024/  (CSV in .zip)
#          data/NHIS 2004/ ... data/NHIS 2014/  (optional: .dta files)
# Output:  output/nhis_adult.rds   (sample adults, all loaded years)
#          output/nhis_adult.dta
#          output/nhis_child.rds   (sample children, all loaded years)
#          output/nhis_child.dta
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

nhis_root <- "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/nhis"

# --- Post-2019 years (redesigned, CSV format — DEFAULT) ---
# These years use simple CSV files. No special setup needed.
# The script auto-detects which year folders exist and skips missing ones.
post2019_years <- 2019:2024

# --- Pre-2019 years (OPTIONAL — uncomment to include) ---
# Pre-2019 years require .dta files (created by running CDC do-files in Stata).
# If you haven't run the Stata script first, the .dta files won't exist.
# Leave as empty integer(0) to skip pre-2019 entirely (the default).
#
# To include pre-2019 years, uncomment ONE of the lines below:
# pre2019_years <- 2004:2014
# pre2019_years <- 2010:2014
pre2019_years <- integer(0)

# NOTE: Years 2015-2018 follow pre-2019 design but only have .zip files.
#       To include them, create .dta files first using the Stata script,
#       then add to pre2019_years.

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

  # --- Merge familyxx ---
  fam_file <- file.path(ydir, "familyxx.dta")
  if (file.exists(fam_file)) {
    family <- read_dta(fam_file)
    names(family) <- tolower(names(family))
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
    person <- person %>%
      left_join(house, by = c("hhx", "srvy_yr"),
                suffix = c("", ".hh"))
    dup_cols <- grep("\\.hh$", names(person), value = TRUE)
    if (length(dup_cols) > 0) person <- person %>% select(-all_of(dup_cols))
  }

  # --- Merge sample file (inner join: keep only sample persons) ---
  sample_data <- read_dta(sample_file)
  names(sample_data) <- tolower(names(sample_data))

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

  return(merged)
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
adult <- bind_rows(c(pre2019_adult_list, post2019_adult_list))
cat(paste0("  Combined: ", nrow(adult), " observations, ", ncol(adult), " variables\n"))

# --- Child ---
cat("--- Child file ---\n")
child <- bind_rows(c(pre2019_child_list, post2019_child_list))
cat(paste0("  Combined: ", nrow(child), " observations, ", ncol(child), " variables\n"))

# ============================================================================
# 5. SAVE COMBINED DATASETS
# ============================================================================

cat("\nSaving combined datasets...\n")

# --- Adult ---
adult <- adult %>% arrange(srvy_yr, hhx)
saveRDS(adult, file.path(nhis_root, "output", "nhis_adult.rds"))
cat("Saved: output/nhis_adult.rds\n")
tryCatch({
  write_dta(adult, file.path(nhis_root, "output", "nhis_adult.dta"))
  cat("Saved: output/nhis_adult.dta\n")
}, error = function(e) cat(paste0("Could not save adult .dta: ", e$message, "\n")))

# --- Child ---
child <- child %>% arrange(srvy_yr, hhx)
saveRDS(child, file.path(nhis_root, "output", "nhis_child.rds"))
cat("Saved: output/nhis_child.rds\n")
tryCatch({
  write_dta(child, file.path(nhis_root, "output", "nhis_child.dta"))
  cat("Saved: output/nhis_child.dta\n")
}, error = function(e) cat(paste0("Could not save child .dta: ", e$message, "\n")))

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
#    The .dta files for 2004-2014 were created by running CDC-provided Stata
#    do-files on the raw fixed-width ASCII (.DAT) data. Each do-file uses
#    `infix` to read the .DAT file and saves a .dta file. If the .dta files
#    don't exist, run 01_load_and_append.do in Stata first (it auto-creates
#    them from the CDC do-files).
#
# 2. EXTENDING TO 2015-2018:
#    These years have only .zip files. To include them:
#    a. Extract the zips in Stata and run CDC do-files to create .dta
#    b. Then add years to pre2019_years above
#    OR use the CSV zip alternatives (2016-2018 have xxxcsv.zip):
#      unzip(file.path(ydir, "personsxcsv.zip"), exdir = ydir)
#      read_csv(file.path(ydir, "personsx.csv"))
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
