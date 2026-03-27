# =============================================================================
# 01_load_1988.R — Load Ghana DHS 1988 Women's Individual Recode
# =============================================================================
# This script loads the Ghana 1988 DHS (DHS Phase II) women's individual
# recode (IR), harmonizes variable names, and saves a working dataset.
#
# DHS Phase II — Ghana 1988
# Women: GHIR02FL.DTA (N = 4,488; ages 15-49)
# Men:   NO men's recode exists for 1988
#
# KEY DIFFERENCES from later waves:
# - v024 does NOT exist -> use v101 for region
# - v025 does NOT exist -> use v102 for type of residence
# - v149 (educational attainment) does NOT exist
# - v155 (literacy) does NOT exist
# - v190 (wealth index) does NOT exist
# - v481/v481c (health insurance) does NOT exist
#
# Input:  data/raw/ghana_1988/GHIR02DT/GHIR02FL.DTA
# Output: output/ghana_dhs_1988_working.rds
#         output/ghana_dhs_1988_working_from_R.dta
# =============================================================================

library(haven)
library(dplyr)

# --- Paths ----------------------------------------------------------------
dhs_root  <- file.path(dirname(getwd()))
if (!dir.exists(file.path(dhs_root, "data"))) dhs_root <- getwd()  # fallback
raw_dir   <- file.path(dhs_root, "data", "raw", "ghana_1988")
out_dir   <- file.path(dhs_root, "output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

women_file <- file.path(raw_dir, "GHIR02DT", "GHIR02FL.DTA")

stopifnot(
  "Women's recode not found" = file.exists(women_file)
)

sink(file.path(out_dir, "01_load_1988_R_log.txt"), split = TRUE)
cat("============================================================\n")
cat("Ghana DHS 1988 -- Load and Harmonize (R)\n")
cat("============================================================\n\n")

# ==========================================================================
# SECTION 1: Load and harmonize women's individual recode (IR)
# ==========================================================================
# NOTE: No men's recode exists for the 1988 wave. Output is women only.

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
    interview_year  = ifelse(as.integer(v007) < 100L, as.integer(v007) + 1900L, as.integer(v007)),  # v007 stores 2-digit year in early DHS
    interview_cmc   = as.integer(v008),
    age_years       = as.integer(v012),
    region          = as.integer(v101),     # 1988: v024 does not exist; use v101
    residence       = as.integer(v102),     # 1988: v025 does not exist; use v102
    educ_level      = as.integer(v106),
    educ_attain     = NA_integer_,          # v149 does not exist in 1988
    literacy        = NA_integer_,          # v155 does not exist in 1988
    wealth_index    = NA_integer_,          # v190 does not exist in 1988
    religion        = as.integer(v130),
    ethnicity       = as.integer(v131),
    marital_status  = as.integer(v501),
    ever_married    = as.integer(v502),
    working_now     = as.integer(v714),
    any_insurance   = NA_integer_,          # v481 does not exist in 1988
    nhis_enrolled   = NA_integer_           # v481c does not exist in 1988
  )

cat(sprintf("  Women harmonized: %d observations\n", nrow(women)))
rm(women_raw)

# ==========================================================================
# SECTION 2: Save (no men to append — women only)
# ==========================================================================

cat("\n--- No men's recode in 1988 — saving women only ---\n")
dhs1988 <- women %>%
  arrange(female, cluster_id, household_id, respondent_id)

rm(women)

# --- Validation -----------------------------------------------------------
cat("\n=== Validation Checks ===\n")
cat(sprintf("Total observations: %d\n", nrow(dhs1988)))

n_women <- sum(dhs1988$female == 1)
cat(sprintf("Women: %d  (no men's recode in 1988)\n", n_women))

stopifnot(all(dhs1988$interview_year == 1988))   # all fieldwork in 1988

cat("\n-- Sex distribution --\n")
print(table(dhs1988$female, useNA = "ifany"))

cat("\n-- Region distribution --\n")
print(table(dhs1988$region, useNA = "ifany"))

cat("\n-- Education level --\n")
print(table(dhs1988$educ_level, useNA = "ifany"))

cat("\n-- Sample weight summary --\n")
print(summary(dhs1988$sample_weight))
stopifnot(all(dhs1988$sample_weight > 0))

cat(sprintf("\nAge range: %d - %d\n", min(dhs1988$age_years), max(dhs1988$age_years)))

# --- Save -----------------------------------------------------------------
saveRDS(dhs1988, file.path(out_dir, "ghana_dhs_1988_working.rds"))
write_dta(dhs1988, file.path(out_dir, "ghana_dhs_1988_working_from_R.dta"))

cat("\n============================================================\n")
cat(sprintf("Saved: %s\n", file.path(out_dir, "ghana_dhs_1988_working.rds")))
cat(sprintf("  Total N = %d (Women only -- no men's recode in 1988)\n", nrow(dhs1988)))
cat("============================================================\n")

sink()
