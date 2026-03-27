* =============================================================================
* 02_clean_2003.do — Clean and Analyze Ghana DHS 2003
* =============================================================================
* This script loads the harmonized 2003 working dataset, creates analysis
* variables for demographics, education, literacy, wealth, and other domains,
* and produces descriptive statistics.
*
* Ghana DHS 2003 (DHS Phase IV+)
* - 10 administrative regions
* - NHIS not yet launched; health insurance variables NOT available
*
* Input:  output/ghana_dhs_2003_working.dta
* Output: output/ghana_dhs_2003_analysis.dta
* =============================================================================

clear all
set more off
version 16.1

* --- Paths ----------------------------------------------------------------
local dhs_root ".."
local out_dir  "`dhs_root'/output"

capture log close
log using "`out_dir'/02_clean_2003_log.txt", text replace

di as txt "============================================================"
di as txt "Ghana DHS 2003 — Clean and Analyze"
di as txt "============================================================"

use "`out_dir'/ghana_dhs_2003_working.dta", clear
di as txt "Loaded " _N " observations"

* ==========================================================================
* SECTION 1: Demographics
* ==========================================================================

di _n as txt "--- Section 1: Demographics ---"

* Urban/rural
gen byte urban = (residence == 1)
label var urban "Urban residence (1=urban, 0=rural)"

* Age groups
gen byte age_group = .
replace age_group = 1 if inrange(age_years, 15, 19)
replace age_group = 2 if inrange(age_years, 20, 24)
replace age_group = 3 if inrange(age_years, 25, 29)
replace age_group = 4 if inrange(age_years, 30, 34)
replace age_group = 5 if inrange(age_years, 35, 39)
replace age_group = 6 if inrange(age_years, 40, 44)
replace age_group = 7 if inrange(age_years, 45, 49)
replace age_group = 8 if inrange(age_years, 50, 59)  // men go to 59
label var age_group "5-year age group"
label define age_group_lbl 1 "15-19" 2 "20-24" 3 "25-29" 4 "30-34" ///
    5 "35-39" 6 "40-44" 7 "45-49" 8 "50-59"
label values age_group age_group_lbl

* Marital status categories
gen byte married       = (marital_status == 1)     if !missing(marital_status)
gen byte cohabiting    = (marital_status == 2)     if !missing(marital_status)
gen byte in_union      = inlist(marital_status, 1, 2) if !missing(marital_status)
gen byte never_married = (marital_status == 0)     if !missing(marital_status)
gen byte widowed       = (marital_status == 3)     if !missing(marital_status)
gen byte divorced_sep  = inlist(marital_status, 4, 5) if !missing(marital_status)

label var married       "Currently married"
label var cohabiting    "Living together/cohabiting"
label var in_union      "Currently in union (married or cohabiting)"
label var never_married "Never married/in union"
label var widowed       "Widowed"
label var divorced_sep  "Divorced or separated"

* Currently working
gen byte employed = .
replace employed = 1 if working_now == 1
replace employed = 0 if working_now == 0
label var employed "Currently working"

* ==========================================================================
* SECTION 2: Education
* ==========================================================================

di _n as txt "--- Section 2: Education ---"

gen byte educ_none    = (educ_level == 0) if !missing(educ_level)
gen byte educ_primary = (educ_level == 1) if !missing(educ_level)
gen byte educ_second  = (educ_level == 2) if !missing(educ_level)
gen byte educ_higher  = (educ_level == 3) if !missing(educ_level)

label var educ_none    "No education"
label var educ_primary "Primary education"
label var educ_second  "Secondary education"
label var educ_higher  "Higher education"

* Literate (can read whole sentence or parts of sentence)
* DHS standard: literate if higher education OR can read part/whole sentence
* (following DHS-Indicators-Stata-master/Chap03_RC/RC_CHAR.do)
gen byte literate = .
replace literate = 0 if literacy == 0                   // cannot read
replace literate = 1 if inlist(literacy, 1, 2)          // can read part/whole
replace literate = 1 if educ_level == 3                 // higher education always trumps
label var literate "Literate (higher educ or can read part/whole sentence)"

* ==========================================================================
* SECTION 3: Religion
* ==========================================================================

di _n as txt "--- Section 3: Religion ---"

* Religion categories (consistent across Ghana DHS waves)
gen byte christian     = inlist(religion, 1, 2, 3, 4, 5, 6) if !missing(religion) & religion != 99
gen byte muslim        = (religion == 7) if !missing(religion) & religion != 99
gen byte traditional   = (religion == 8) if !missing(religion) & religion != 99
gen byte no_religion   = (religion == 9) if !missing(religion) & religion != 99
gen byte other_religion = (religion == 96) if !missing(religion) & religion != 99

label var christian      "Christian (all denominations)"
label var muslim         "Muslim"
label var traditional    "Traditional/spiritualist"
label var no_religion    "No religion"
label var other_religion "Other religion"

* Detailed Christian denominations
gen byte catholic       = (religion == 1) if !missing(religion) & religion != 99
gen byte protestant     = inlist(religion, 2, 3, 4) if !missing(religion) & religion != 99
gen byte pentecostal    = (religion == 5) if !missing(religion) & religion != 99
gen byte other_christian = (religion == 6) if !missing(religion) & religion != 99

label var catholic        "Catholic"
label var protestant      "Protestant (Anglican, Methodist, Presbyterian)"
label var pentecostal     "Pentecostal/Charismatic"
label var other_christian "Other Christian"

* ==========================================================================
* SECTION 4: Ethnicity
* ==========================================================================

di _n as txt "--- Section 4: Ethnicity ---"

gen byte akan        = (ethnicity == 1) if !missing(ethnicity) & ethnicity != 99
gen byte ga_dangme   = (ethnicity == 2) if !missing(ethnicity) & ethnicity != 99
gen byte ewe         = (ethnicity == 3) if !missing(ethnicity) & ethnicity != 99
gen byte guan        = (ethnicity == 4) if !missing(ethnicity) & ethnicity != 99
gen byte mole_dagbani = (ethnicity == 5) if !missing(ethnicity) & ethnicity != 99
gen byte grusi       = (ethnicity == 6) if !missing(ethnicity) & ethnicity != 99
gen byte gurma       = (ethnicity == 7) if !missing(ethnicity) & ethnicity != 99
gen byte mande       = (ethnicity == 8) if !missing(ethnicity) & ethnicity != 99
gen byte other_eth   = (ethnicity == 9) if !missing(ethnicity) & ethnicity != 99

label var akan         "Akan"
label var ga_dangme    "Ga/Dangme"
label var ewe          "Ewe"
label var guan         "Guan"
label var mole_dagbani "Mole-Dagbani"
label var grusi        "Grusi"
label var gurma        "Gurma"
label var mande        "Mande"
label var other_eth    "Other ethnicity"

* ==========================================================================
* SECTION 5: Region Labels (10 regions in 2003)
* ==========================================================================

di _n as txt "--- Section 5: Region Labels ---"

label define region_lbl 1 "Western" 2 "Central" 3 "Greater Accra" 4 "Volta" ///
    5 "Eastern" 6 "Ashanti" 7 "Brong Ahafo" 8 "Northern" 9 "Upper East" ///
    10 "Upper West"
label values region region_lbl

* Northern vs Southern Ghana (for regional analysis)
gen byte northern = inlist(region, 8, 9, 10)
label var northern "Northern Ghana (Northern, Upper East, Upper West)"

* ==========================================================================
* SECTION 6: Wealth
* ==========================================================================

di _n as txt "--- Section 6: Wealth ---"

label define wealth_lbl 1 "Poorest" 2 "Poorer" 3 "Middle" 4 "Richer" 5 "Richest"
label values wealth_index wealth_lbl

gen byte poor = inlist(wealth_index, 1, 2) if !missing(wealth_index)
label var poor "Bottom two wealth quintiles"

* ==========================================================================
* SECTION 7: Descriptive Statistics
* ==========================================================================

di _n as txt "============================================================"
di as txt "DESCRIPTIVE STATISTICS — Ghana DHS 2003"
di as txt "============================================================"

* 7a. Sample composition
di _n as txt "--- 7a. Sample Composition ---"
tab female, m
tab urban female, m
tab age_group female, m

* 7b. Education
di _n as txt "--- 7b. Education ---"
tab educ_level female, m
tab literate female, m

* 7c. Marital status
di _n as txt "--- 7c. Marital Status ---"
tab marital_status female, m
tab in_union female, m

* 7d. Employment
di _n as txt "--- 7d. Employment ---"
tab employed female, m

* 7e. Religion
di _n as txt "--- 7e. Religion ---"
tab religion female, m

* 7f. Ethnicity
di _n as txt "--- 7f. Ethnicity ---"
tab ethnicity female, m

* 7g. Wealth
di _n as txt "--- 7g. Wealth ---"
tab wealth_index female, m
tab poor female, m

* 7h. Region
di _n as txt "--- 7h. Region ---"
tab region female, m
tab northern female, m

* 7i. Summary means (no insurance variables — not available in 2003)
di _n as txt "--- 7i. Summary Means ---"
summarize female urban age_years educ_none educ_primary educ_second educ_higher ///
    literate in_union employed poor

di _n as txt "--- 7j. Summary Means by Sex ---"
di as txt "=== Women ==="
summarize urban age_years educ_none educ_primary educ_second educ_higher ///
    literate in_union employed poor if female == 1

di as txt "=== Men ==="
summarize urban age_years educ_none educ_primary educ_second educ_higher ///
    literate in_union employed poor if female == 0

* ==========================================================================
* SECTION 8: Save Analysis Dataset
* ==========================================================================

compress
save "`out_dir'/ghana_dhs_2003_analysis.dta", replace

di _n as txt "============================================================"
di as txt "Saved: `out_dir'/ghana_dhs_2003_analysis.dta"
di as txt "  N = " _N
di as txt "============================================================"

log close
