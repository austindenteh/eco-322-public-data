# =============================================================================
# 01_load_1998.R — Load Ghana DHS 1998 Individual and Men's Recodes
# =============================================================================
# This script loads the Ghana 1998 Standard DHS (DHS-IV) women's individual
# recode (IR) and men's recode (MR), harmonizes variable names into a common
# surface, appends the two samples, and saves a working dataset.
#
# DHS Phase IV — Ghana 1998
# Women: GHIR41FL.DTA (N = 4,843; ages 15-49)
# Men:   GHMR41FL.DTA (N = 1,546; ages 15-59)
#
# NOTE: v155 (literacy), v190 (wealth index), v481/v481c (insurance) do NOT
#       exist in the 1998 wave. These are set to missing.
#       v149 (educational attainment) DOES exist.
#
# Input:  data/raw/ghana_1998/GHIR41DT/GHIR41FL.DTA
#         data/raw/ghana_1998/GHMR41DT/GHMR41FL.DTA
# Output: output/ghana_dhs_1998_working.rds
#         output/ghana_dhs_1998_working.dta
# =============================================================================

library(haven)
library(dplyr)

# --- Paths ----------------------------------------------------------------
dhs_root  <- file.path(dirname(getwd()))
if (!dir.exists(file.path(dhs_root, "data"))) dhs_root <- getwd()  # fallback
raw_dir   <- file.path(dhs_root, "data", "raw", "ghana_1998")
out_dir   <- file.path(dhs_root, "output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

women_file <- file.path(raw_dir, "GHIR41DT", "GHIR41FL.DTA")
men_file   <- file.path(raw_dir, "GHMR41DT", "GHMR41FL.DTA")

stopifnot(
  "Women's recode not found" = file.exists(women_file),
  "Men's recode not found"   = file.exists(men_file)
)

sink(file.path(out_dir, "01_load_1998_R_log.txt"), split = TRUE)
cat("============================================================\n")
cat("Ghana DHS 1998 -- Load and Harmonize (R)\n")
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
    interview_year  = ifelse(as.integer(v007) < 100L, as.integer(v007) + 1900L, as.integer(v007)),  # v007 stores 2-digit year in early DHS
    interview_cmc   = as.integer(v008),
    age_years       = as.integer(v012),
    region          = as.integer(v024),
    residence       = as.integer(v025),
    educ_level      = as.integer(v106),
    educ_attain     = as.integer(v149),
    literacy        = NA_integer_,         # v155 does NOT exist in 1998
    wealth_index    = NA_integer_,         # v190 does NOT exist in 1998
    religion        = as.integer(v130),
    ethnicity       = as.integer(v131),
    marital_status  = as.integer(v501),
    ever_married    = as.integer(v502),
    working_now     = as.integer(v714),
    any_insurance   = NA_integer_,         # v481 does NOT exist in 1998
    nhis_enrolled   = NA_integer_          # v481c does NOT exist in 1998
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
    interview_year  = ifelse(as.integer(mv007) < 100L, as.integer(mv007) + 1900L, as.integer(mv007)),  # mv007 stores 2-digit year in early DHS
    interview_cmc   = as.integer(mv008),
    age_years       = as.integer(mv012),
    region          = as.integer(mv024),
    residence       = as.integer(mv025),
    educ_level      = as.integer(mv106),
    educ_attain     = as.integer(mv149),
    literacy        = NA_integer_,         # mv155 does NOT exist in 1998
    wealth_index    = NA_integer_,         # mv190 does NOT exist in 1998
    religion        = as.integer(mv130),
    ethnicity       = as.integer(mv131),
    marital_status  = as.integer(mv501),
    ever_married    = as.integer(mv502),
    working_now     = as.integer(mv714),
    any_insurance   = NA_integer_,         # mv481 does NOT exist in 1998
    nhis_enrolled   = NA_integer_          # mv481c does NOT exist in 1998
  )

cat(sprintf("  Men harmonized: %d observations\n", nrow(men)))
rm(men_raw)

# ==========================================================================
# SECTION 3: Append and save
# ==========================================================================

cat("\n--- Appending women + men ---\n")
dhs1998 <- bind_rows(women, men) %>%
  arrange(female, cluster_id, household_id, respondent_id)

rm(women, men)

# --- Validation -----------------------------------------------------------
cat("\n=== Validation Checks ===\n")
cat(sprintf("Total observations: %d\n", nrow(dhs1998)))

n_women <- sum(dhs1998$female == 1)
n_men   <- sum(dhs1998$female == 0)
cat(sprintf("Women: %d  |  Men: %d\n", n_women, n_men))

stopifnot(all(dhs1998$interview_year %in% c(1998L, 1999L)))   # fieldwork spanned late 1998 into early 1999

cat("\n-- Sex distribution --\n")
print(table(dhs1998$female, useNA = "ifany"))

cat("\n-- Region distribution --\n")
print(table(dhs1998$region, useNA = "ifany"))

cat("\n-- Education level --\n")
print(table(dhs1998$educ_level, useNA = "ifany"))

cat("\n-- Sample weight summary --\n")
print(summary(dhs1998$sample_weight))
stopifnot(all(dhs1998$sample_weight > 0))

cat(sprintf("\nAge range: %d - %d\n", min(dhs1998$age_years), max(dhs1998$age_years)))

# --- Save -----------------------------------------------------------------
saveRDS(dhs1998, file.path(out_dir, "ghana_dhs_1998_working.rds"))
write_dta(dhs1998, file.path(out_dir, "ghana_dhs_1998_working_from_R.dta"))

cat("\n============================================================\n")
cat(sprintf("Saved: %s\n", file.path(out_dir, "ghana_dhs_1998_working.rds")))
cat(sprintf("  Total N = %d (Women = %d, Men = %d)\n", nrow(dhs1998), n_women, n_men))
cat("============================================================\n")

sink()
