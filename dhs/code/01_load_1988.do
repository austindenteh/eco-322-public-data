* =============================================================================
* 01_load_1988.do — Load Ghana DHS 1988 Women's Individual Recode
* =============================================================================
* This script loads the Ghana 1988 DHS (DHS Phase II) women's individual
* recode (IR), harmonizes variable names, and saves a working dataset.
*
* DHS Phase II — Ghana 1988
* Women: GHIR02FL.DTA (N = 4,488; ages 15–49)
* Men:   NO men's recode exists for 1988
*
* KEY DIFFERENCES from later waves:
* - v024 does NOT exist → use v101 for region
* - v025 does NOT exist → use v102 for type of residence
* - v149 (educational attainment) does NOT exist
* - v155 (literacy) does NOT exist
* - v190 (wealth index) does NOT exist
* - v481/v481c (health insurance) does NOT exist
*
* Input:  data/raw/ghana_1988/GHIR02DT/GHIR02FL.DTA
* Output: output/ghana_dhs_1988_working.dta
* =============================================================================

clear all
set more off
version 16.1

* --- Paths ----------------------------------------------------------------
* Set the root to the dhs/ folder. Adjust if running from a different location.
local dhs_root ".."
local raw_dir  "`dhs_root'/data/raw/ghana_1988"
local out_dir  "`dhs_root'/output"

* Auto-detect file paths (DHS downloads may use different subfolder names)
local women_file "`raw_dir'/GHIR02DT/GHIR02FL.DTA"

capture confirm file "`women_file'"
if _rc {
    di as err "Women's recode not found at: `women_file'"
    di as err "Please verify the path and adjust if needed."
    exit 601
}

capture mkdir "`out_dir'"

* --- Log ------------------------------------------------------------------
capture log close
log using "`out_dir'/01_load_1988_log.txt", text replace

di as txt "============================================================"
di as txt "Ghana DHS 1988 — Load and Harmonize"
di as txt "============================================================"

* ==========================================================================
* SECTION 1: Load and harmonize women's individual recode (IR)
* ==========================================================================
* NOTE: No men's recode exists for the 1988 wave. Output is women only.

di _n as txt "--- Loading women's individual recode ---"
use "`women_file'", clear
di as txt "  Observations: " _N
di as txt "  Variables:    " c(k)

* Create harmonized variable names
gen byte female = 1
gen str5 source_sample = "women"

gen cluster_id      = v001
gen household_id    = v002
gen respondent_id   = v003
gen sample_weight   = v005 / 1000000   // DHS weights have 6 implied decimals
gen interview_month = v006
gen interview_year  = v007
replace interview_year = interview_year + 1900 if interview_year < 100  // v007 stores 2-digit year in early DHS phases
gen interview_cmc   = v008
gen age_years       = v012
gen region          = v101          // 1988: v024 does not exist; use v101
gen residence       = v102          // 1988: v025 does not exist; use v102 (1=urban, 2=rural)
gen educ_level      = v106          // 0=none, 1=primary, 2=secondary, 3=higher
gen educ_attain     = .             // v149 does not exist in 1988
gen literacy        = .             // v155 does not exist in 1988
gen wealth_index    = .             // v190 does not exist in 1988
gen religion        = v130
gen ethnicity       = v131
gen marital_status  = v501          // 0=never, 1=married, 2=living together, ...
gen ever_married    = v502          // 0=never, 1=currently, 2=formerly
gen working_now     = v714          // 0=no, 1=yes
gen any_insurance   = .             // v481 does not exist in 1988
gen nhis_enrolled   = .             // v481c does not exist in 1988 (NHIS not yet created)

* Keep only harmonized variables
keep female source_sample cluster_id household_id respondent_id ///
     sample_weight interview_month interview_year interview_cmc ///
     age_years region residence educ_level educ_attain literacy ///
     wealth_index religion ethnicity marital_status ever_married ///
     working_now any_insurance nhis_enrolled

* --- Labels ---------------------------------------------------------------
label var female          "Female respondent (1=yes, 0=no)"
label var source_sample   "Source sample (women / men)"
label var cluster_id      "DHS cluster number"
label var household_id    "DHS household number"
label var respondent_id   "Respondent line number"
label var sample_weight   "Individual sample weight (de-normalized)"
label var interview_month "Month of interview"
label var interview_year  "Year of interview"
label var interview_cmc   "Date of interview (century month code)"
label var age_years       "Respondent current age in years"
label var region          "Region (DHS code, from v101)"
label var residence       "Type of residence (1=urban, 2=rural, from v102)"
label var educ_level      "Highest education level (0=none 1=pri 2=sec 3=higher)"
label var educ_attain     "Educational attainment (detailed) — NOT AVAILABLE in 1988"
label var literacy        "Literacy — NOT AVAILABLE in 1988"
label var wealth_index    "Wealth index quintile — NOT AVAILABLE in 1988"
label var religion        "Religion (DHS code)"
label var ethnicity       "Ethnicity (DHS code)"
label var marital_status  "Current marital status (DHS code)"
label var ever_married    "Ever-married grouping (0=never 1=current 2=former)"
label var working_now     "Currently working (0=no 1=yes)"
label var any_insurance   "Covered by any health insurance — NOT AVAILABLE in 1988"
label var nhis_enrolled   "Enrolled in NHIS — NOT AVAILABLE in 1988"

* --- Validation -----------------------------------------------------------
di _n as txt "=== Validation Checks ==="

count
local total_n = r(N)
di as txt "Total observations: `total_n'"

count if female == 1
local n_women = r(N)
di as txt "Women: `n_women'  (no men's recode in 1988)"

assert interview_year == 1988   // all fieldwork in 1988

tab female, m
tab region, m
tab educ_level, m

summarize sample_weight, detail
assert r(min) > 0

summarize age_years
di as txt "Age range: " r(min) " - " r(max)

* --- Save -----------------------------------------------------------------
sort female cluster_id household_id respondent_id

compress
save "`out_dir'/ghana_dhs_1988_working.dta", replace

di _n as txt "============================================================"
di as txt "Saved: `out_dir'/ghana_dhs_1988_working.dta"
di as txt "  Total N = `total_n' (Women only — no men's recode in 1988)"
di as txt "============================================================"

log close
