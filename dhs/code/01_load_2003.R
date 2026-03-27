# =============================================================================
# 01_load_2003.R — Load Ghana DHS 2003 Individual and Men's Recodes
# =============================================================================
# This script loads the Ghana 2003 Standard DHS (DHS-IV+) women's individual
# recode (IR) and men's recode (MR), harmonizes variable names into a common
# surface, appends the two samples, and saves a working dataset.
#
# DHS Phase IV+ — Ghana 2003
# Women: GHIR4BFL.DTA (N = 5,691; ages 15-49)
# Men:   GHMR4BFL.DTA (N = 5,015; ages 15-59)
#
# NOTE: Health insurance variables (v481/v481c) do NOT exist in the 2003 wave.
#       NHIS was not launched until 2003 and enrollment data not collected.
#       any_insurance and nhis_enrolled are set to NA.
#
# Input:  data/raw/ghana_2003/GHIR4BDT/GHIR4BFL.DTA
#         data/raw/ghana_2003/GHMR4BDT/GHMR4BFL.DTA
# Output: output/ghana_dhs_2003_working.rds
#         output/ghana_dhs_2003_working_from_R.dta
# =============================================================================

library(haven)
library(dplyr)

# --- Paths ----------------------------------------------------------------
dhs_root  <- file.path(dirname(getwd()))
if (!dir.exists(file.path(dhs_root, "data"))) dhs_root <- getwd()  # fallback
raw_dir   <- file.path(dhs_root, "data", "raw", "ghana_2003")
out_dir   <- file.path(dhs_root, "output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

women_file <- file.path(raw_dir, "GHIR4BDT", "GHIR4BFL.DTA")
men_file   <- file.path(raw_dir, "GHMR4BDT", "GHMR4BFL.DTA")

stopifnot(
  "Women's recode not found" = file.exists(women_file),
  "Men's recode not found"   = file.exists(men_file)
)

sink(file.path(out_dir, "01_load_2003_R_log.txt"), split = TRUE)
cat("============================================================\n")
cat("Ghana DHS 2003 -- Load and Harmonize (R)\n")
cat("============================================================\n\n")

# ==========================================================================
# SECTION 1: Load and harmonize women's individual recode (IR)
# ==========================================================================

cat("--- Loading women's individual recode ---\n")
women_raw <- read_dta(women_file)
cat(sprintf("  Observations: %d\n  Variables:    %d\n", nrow(women_raw), ncol(women_raw)))

women <- women_raw %>%
  transmute(
    female          = 1L,
    source_sample   = "women",
    cluster_id      = as.integer(v001),
    household_id    = as.integer(v002),
    respondent_id   = as.integer(v003),
    sample_weight   = as.numeric(v005) / 1e6,
    interview_month = as.integer(v006),
    interview_year  = as.integer(v007),
    interview_cmc   = as.integer(v008),
    age_years       = as.integer(v012),
    region          = as.integer(v024),
    residence       = as.integer(v025),
    educ_level      = as.integer(v106),
    educ_attain     = as.integer(v149),
    literacy        = as.integer(v155),
    wealth_index    = as.integer(v190),
    religion        = as.integer(v130),
    ethnicity       = as.integer(v131),
    marital_status  = as.integer(v501),
    ever_married    = as.integer(v502),
    working_now     = as.integer(v714),
    any_insurance   = NA_integer_,   # v481 does NOT exist in 2003
    nhis_enrolled   = NA_integer_    # v481c does NOT exist in 2003
  )

cat(sprintf("  Women harmonized: %d observations\n", nrow(women)))
rm(women_raw)

# ==========================================================================
# SECTION 2: Load and harmonize men's recode (MR)
# ==========================================================================

cat("\n--- Loading men's recode ---\n")
men_raw <- read_dta(men_file)
cat(sprintf("  Observations: %d\n  Variables:    %d\n", nrow(men_raw), ncol(men_raw)))

men <- men_raw %>%
  transmute(
    female          = 0L,
    source_sample   = "men",
    cluster_id      = as.integer(mv001),
    household_id    = as.integer(mv002),
    respondent_id   = as.integer(mv003),
    sample_weight   = as.numeric(mv005) / 1e6,
    interview_month = as.integer(mv006),
    interview_year  = as.integer(mv007),
    interview_cmc   = as.integer(mv008),
    age_years       = as.integer(mv012),
    region          = as.integer(mv024),
    residence       = as.integer(mv025),
    educ_level      = as.integer(mv106),
    educ_attain     = as.integer(mv149),
    literacy        = as.integer(mv155),
    wealth_index    = as.integer(mv190),
    religion        = as.integer(mv130),
    ethnicity       = as.integer(mv131),
    marital_status  = as.integer(mv501),
    ever_married    = as.integer(mv502),
    working_now     = as.integer(mv714),
    any_insurance   = NA_integer_,   # mv481 does NOT exist in 2003
    nhis_enrolled   = NA_integer_    # mv481c does NOT exist in 2003
  )

cat(sprintf("  Men harmonized: %d observations\n", nrow(men)))
rm(men_raw)

# ==========================================================================
# SECTION 3: Append and save
# ==========================================================================

cat("\n--- Appending women + men ---\n")
dhs2003 <- bind_rows(women, men) %>%
  arrange(female, cluster_id, household_id, respondent_id)

rm(women, men)

# --- Validation -----------------------------------------------------------
cat("\n=== Validation Checks ===\n")
cat(sprintf("Total observations: %d\n", nrow(dhs2003)))

n_women <- sum(dhs2003$female == 1)
n_men   <- sum(dhs2003$female == 0)
cat(sprintf("Women: %d  |  Men: %d\n", n_women, n_men))

stopifnot(all(dhs2003$interview_year == 2003))

cat("\n-- Sex distribution --\n")
print(table(dhs2003$female, useNA = "ifany"))

cat("\n-- Region distribution --\n")
print(table(dhs2003$region, useNA = "ifany"))

cat("\n-- Education level --\n")
print(table(dhs2003$educ_level, useNA = "ifany"))

cat("\n-- Sample weight summary --\n")
print(summary(dhs2003$sample_weight))
stopifnot(all(dhs2003$sample_weight > 0))

cat(sprintf("\nAge range: %d - %d\n", min(dhs2003$age_years), max(dhs2003$age_years)))

# Note: any_insurance and nhis_enrolled are all NA in 2003 (NHIS not yet launched)
cat("\nNOTE: any_insurance and nhis_enrolled are all NA in 2003\n")
stopifnot(all(is.na(dhs2003$any_insurance)))
stopifnot(all(is.na(dhs2003$nhis_enrolled)))

# --- Save -----------------------------------------------------------------
saveRDS(dhs2003, file.path(out_dir, "ghana_dhs_2003_working.rds"))
write_dta(dhs2003, file.path(out_dir, "ghana_dhs_2003_working_from_R.dta"))

cat("\n============================================================\n")
cat(sprintf("Saved: %s\n", file.path(out_dir, "ghana_dhs_2003_working.rds")))
cat(sprintf("  Total N = %d (Women = %d, Men = %d)\n", nrow(dhs2003), n_women, n_men))
cat("============================================================\n")

sink()
