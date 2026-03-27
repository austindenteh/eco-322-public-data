# =============================================================================
# 01_load_2014.R — Load Ghana DHS 2014 Individual and Men's Recodes
# =============================================================================
# This script loads the Ghana 2014 Standard DHS (DHS-VII) women's individual
# recode (IR) and men's recode (MR), harmonizes variable names into a common
# surface, appends the two samples, and saves a working dataset.
#
# DHS Phase VII — Ghana 2014
# Women: GHIR72FL.DTA (N = 9,396; ages 15-49)
# Men:   GHMR71FL.DTA (N = 4,388; ages 15-59)
#
# IMPORTANT: In 2014, NHIS enrollment moved from v481c to v481e.
#   v481c = "social security" (all missing in Ghana 2014)
#   v481e = "national/district health insurance (NHIS)"
#
# Input:  data/raw/ghana_2014/GHIR72DT/GHIR72FL.DTA
#         data/raw/ghana_2014/GHMR71DT/GHMR71FL.DTA
# Output: output/ghana_dhs_2014_working.rds
#         output/ghana_dhs_2014_working.dta
# =============================================================================

library(haven)
library(dplyr)

# --- Paths ----------------------------------------------------------------
dhs_root  <- file.path(dirname(getwd()))
if (!dir.exists(file.path(dhs_root, "data"))) dhs_root <- getwd()
raw_dir   <- file.path(dhs_root, "data", "raw", "ghana_2014")
out_dir   <- file.path(dhs_root, "output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

women_file <- file.path(raw_dir, "GHIR72DT", "GHIR72FL.DTA")
men_file   <- file.path(raw_dir, "GHMR71DT", "GHMR71FL.DTA")

stopifnot(
  "Women's recode not found" = file.exists(women_file),
  "Men's recode not found"   = file.exists(men_file)
)

sink(file.path(out_dir, "01_load_2014_R_log.txt"), split = TRUE)
cat("============================================================\n")
cat("Ghana DHS 2014 -- Load and Harmonize (R)\n")
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
    any_insurance   = as.integer(v481),
    nhis_enrolled   = as.integer(v481e)   # 2014: v481e = NHIS (NOT v481c)
  )

women <- women %>%
  mutate(
    any_insurance = ifelse(any_insurance == 9, NA_integer_, any_insurance),
    nhis_enrolled = ifelse(nhis_enrolled == 9, NA_integer_, nhis_enrolled)
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
    any_insurance   = as.integer(mv481),
    nhis_enrolled   = as.integer(mv481e)   # 2014: mv481e = NHIS (NOT mv481c)
  )

men <- men %>%
  mutate(
    any_insurance = ifelse(any_insurance == 9, NA_integer_, any_insurance),
    nhis_enrolled = ifelse(nhis_enrolled == 9, NA_integer_, nhis_enrolled)
  )

cat(sprintf("  Men harmonized: %d observations\n", nrow(men)))
rm(men_raw)

# ==========================================================================
# SECTION 3: Append and save
# ==========================================================================

cat("\n--- Appending women + men ---\n")
dhs2014 <- bind_rows(women, men) %>%
  arrange(female, cluster_id, household_id, respondent_id)

rm(women, men)

# --- Validation -----------------------------------------------------------
cat("\n=== Validation Checks ===\n")
cat(sprintf("Total observations: %d\n", nrow(dhs2014)))

n_women <- sum(dhs2014$female == 1)
n_men   <- sum(dhs2014$female == 0)
cat(sprintf("Women: %d  |  Men: %d\n", n_women, n_men))

stopifnot(all(dhs2014$interview_year %in% c(2014, 2015)))

cat("\n-- Sex distribution --\n")
print(table(dhs2014$female, useNA = "ifany"))

cat("\n-- Region distribution --\n")
print(table(dhs2014$region, useNA = "ifany"))

cat("\n-- Education level --\n")
print(table(dhs2014$educ_level, useNA = "ifany"))

cat("\n-- Sample weight summary --\n")
print(summary(dhs2014$sample_weight))
stopifnot(all(dhs2014$sample_weight > 0))

cat(sprintf("\nAge range: %d - %d\n", min(dhs2014$age_years), max(dhs2014$age_years)))

cat("\n-- NHIS enrollment by sex --\n")
print(table(dhs2014$nhis_enrolled, dhs2014$female, useNA = "ifany"))

# --- Save -----------------------------------------------------------------
saveRDS(dhs2014, file.path(out_dir, "ghana_dhs_2014_working.rds"))
write_dta(dhs2014, file.path(out_dir, "ghana_dhs_2014_working_from_R.dta"))

cat("\n============================================================\n")
cat(sprintf("Saved: %s\n", file.path(out_dir, "ghana_dhs_2014_working.rds")))
cat(sprintf("  Total N = %d (Women = %d, Men = %d)\n", nrow(dhs2014), n_women, n_men))
cat("============================================================\n")

sink()
