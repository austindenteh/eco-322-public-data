* =============================================================================
* 01_load_2003.do — Load Ghana DHS 2003 Individual and Men's Recodes
* =============================================================================
* This script loads the Ghana 2003 Standard DHS (DHS-IV+) women's individual
* recode (IR) and men's recode (MR), harmonizes variable names into a common
* surface, appends the two samples, and saves a working dataset.
*
* DHS Phase IV+ — Ghana 2003
* Women: GHIR4BFL.DTA (N = 5,691; ages 15–49)
* Men:   GHMR4BFL.DTA (N = 5,015; ages 15–59)
*
* NOTE: Health insurance variables (v481/v481c) do NOT exist in the 2003 wave.
*       NHIS was not launched until 2003 and enrollment data not collected.
*       any_insurance and nhis_enrolled are set to missing (.).
*
* Input:  data/raw/ghana_2003/GHIR4BDT/GHIR4BFL.DTA
*         data/raw/ghana_2003/GHMR4BDT/GHMR4BFL.DTA
* Output: output/ghana_dhs_2003_working.dta
* =============================================================================

clear all
set more off
version 16.1

* --- Paths ----------------------------------------------------------------
* Set the root to the dhs/ folder. Adjust if running from a different location.
local dhs_root ".."
local raw_dir  "`dhs_root'/data/raw/ghana_2003"
local out_dir  "`dhs_root'/output"

* Auto-detect file paths (DHS downloads may use different subfolder names)
local women_file "`raw_dir'/GHIR4BDT/GHIR4BFL.DTA"
local men_file   "`raw_dir'/GHMR4BDT/GHMR4BFL.DTA"

capture confirm file "`women_file'"
if _rc {
    di as err "Women's recode not found at: `women_file'"
    di as err "Please verify the path and adjust if needed."
    exit 601
}

capture confirm file "`men_file'"
if _rc {
    di as err "Men's recode not found at: `men_file'"
    di as err "Please verify the path and adjust if needed."
    exit 601
}

capture mkdir "`out_dir'"

* --- Log ------------------------------------------------------------------
capture log close
log using "`out_dir'/01_load_2003_log.txt", text replace

di as txt "============================================================"
di as txt "Ghana DHS 2003 — Load and Harmonize"
di as txt "============================================================"

* --- Tempfiles ------------------------------------------------------------
tempfile women_common men_common

* ==========================================================================
* SECTION 1: Load and harmonize women's individual recode (IR)
* ==========================================================================

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
gen interview_cmc   = v008
gen age_years       = v012
gen region          = v024
gen residence       = v025          // 1 = urban, 2 = rural
gen educ_level      = v106          // 0=none, 1=primary, 2=secondary, 3=higher
gen educ_attain     = v149          // 0=none, 1-5 detailed
gen literacy        = v155          // 0=cannot read, 1=parts, 2=whole sentence
gen wealth_index    = v190          // 1=poorest ... 5=richest
gen religion        = v130
gen ethnicity       = v131
gen marital_status  = v501          // 0=never, 1=married, 2=living together, ...
gen ever_married    = v502          // 0=never, 1=currently, 2=formerly
gen working_now     = v714          // 0=no, 1=yes
gen any_insurance   = .             // v481 does NOT exist in 2003
gen nhis_enrolled   = .             // v481c does NOT exist in 2003

* Keep only harmonized variables
keep female source_sample cluster_id household_id respondent_id ///
     sample_weight interview_month interview_year interview_cmc ///
     age_years region residence educ_level educ_attain literacy ///
     wealth_index religion ethnicity marital_status ever_married ///
     working_now any_insurance nhis_enrolled

save `women_common', replace
di as txt "  Women harmonized: " _N " observations"

* ==========================================================================
* SECTION 2: Load and harmonize men's recode (MR)
* ==========================================================================

di _n as txt "--- Loading men's recode ---"
use "`men_file'", clear
di as txt "  Observations: " _N
di as txt "  Variables:    " c(k)

gen byte female = 0
gen str3 source_sample = "men"

gen cluster_id      = mv001
gen household_id    = mv002
gen respondent_id   = mv003
gen sample_weight   = mv005 / 1000000
gen interview_month = mv006
gen interview_year  = mv007
gen interview_cmc   = mv008
gen age_years       = mv012
gen region          = mv024
gen residence       = mv025
gen educ_level      = mv106
gen educ_attain     = mv149
gen literacy        = mv155
gen wealth_index    = mv190
gen religion        = mv130
gen ethnicity       = mv131
gen marital_status  = mv501
gen ever_married    = mv502
gen working_now     = mv714
gen any_insurance   = .             // mv481 does NOT exist in 2003
gen nhis_enrolled   = .             // mv481c does NOT exist in 2003

keep female source_sample cluster_id household_id respondent_id ///
     sample_weight interview_month interview_year interview_cmc ///
     age_years region residence educ_level educ_attain literacy ///
     wealth_index religion ethnicity marital_status ever_married ///
     working_now any_insurance nhis_enrolled

save `men_common', replace
di as txt "  Men harmonized: " _N " observations"

* ==========================================================================
* SECTION 3: Append and save
* ==========================================================================

di _n as txt "--- Appending women + men ---"
use `women_common', clear
append using `men_common'

sort female cluster_id household_id respondent_id

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
label var region          "Region (DHS code)"
label var residence       "Type of residence (1=urban, 2=rural)"
label var educ_level      "Highest education level (0=none 1=pri 2=sec 3=higher)"
label var educ_attain     "Educational attainment (detailed)"
label var literacy        "Literacy (0=cannot read 1=parts 2=whole)"
label var wealth_index    "Wealth index quintile (1=poorest 5=richest)"
label var religion        "Religion (DHS code)"
label var ethnicity       "Ethnicity (DHS code)"
label var marital_status  "Current marital status (DHS code)"
label var ever_married    "Ever-married grouping (0=never 1=current 2=former)"
label var working_now     "Currently working (0=no 1=yes)"
label var any_insurance   "Covered by any health insurance (not available in 2003)"
label var nhis_enrolled   "Enrolled in NHIS (not available in 2003)"

* --- Validation -----------------------------------------------------------
di _n as txt "=== Validation Checks ==="

count
local total_n = r(N)
di as txt "Total observations: `total_n'"

count if female == 1
local n_women = r(N)
count if female == 0
local n_men = r(N)
di as txt "Women: `n_women'  |  Men: `n_men'"

assert interview_year == 2003

tab female, m
tab region, m
tab educ_level, m

summarize sample_weight, detail
assert r(min) > 0

summarize age_years
di as txt "Age range: " r(min) " - " r(max)

* Note: nhis_enrolled is all missing in 2003 (NHIS not yet launched)
di as txt "NOTE: any_insurance and nhis_enrolled are all missing (.) in 2003"
count if !missing(any_insurance)
assert r(N) == 0
count if !missing(nhis_enrolled)
assert r(N) == 0

* --- Save -----------------------------------------------------------------
compress
save "`out_dir'/ghana_dhs_2003_working.dta", replace

di _n as txt "============================================================"
di as txt "Saved: `out_dir'/ghana_dhs_2003_working.dta"
di as txt "  Total N = `total_n' (Women = `n_women', Men = `n_men')"
di as txt "============================================================"

log close
