********************************************************************************
* 03_build_cross_era_bridge.do
*
* Purpose: Explicitly append already-cleaned BRFSS files from the 2000-2010
*          pre-2011 era and the 2011-plus era without hiding the 2011 sampling
*          and weighting break.
*
* Inputs:  output/brfss_pre2011_clean.dta
*          output/brfss_2011plus_clean.dta
* Output:  output/brfss_cross_era_bridge.dta
*
* Important: This script performs mechanical alignment only. It does not
* normalize pooled weights, declare a pooled survey design, or establish that
* any outcome is trend-comparable across 2010 and 2011.
********************************************************************************

clear all
set more off

* ============================================================================
* USER SETTINGS
* ============================================================================

* Optional explicit inputs and output directory:
* global brfss_pre2011_clean_file "/path/to/brfss_pre2011_clean.dta"
* global brfss_2011plus_clean_file "/path/to/brfss_2011plus_clean.dta"
* global brfss_bridge_output_dir "/path/to/scratch/output"

* Extra variables must exist under the same name in both cleaned era files.
* This setting does not harmonize different coding or meaning across eras.
* global brfss_bridge_extra_vars "my_harmonized_outcome"

* ============================================================================
* PATHS
* ============================================================================

local cwd `"`c(pwd)'"'
if "$brfss_root" != "" & fileexists("$brfss_root/code/03_build_cross_era_bridge.do") {
    global brfss_root "$brfss_root"
}
else if fileexists("code/03_build_cross_era_bridge.do") & fileexists("README.md") {
    global brfss_root "`cwd'"
}
else if fileexists("03_build_cross_era_bridge.do") & fileexists("../README.md") {
    global brfss_root "`cwd'/.."
}
else if fileexists("brfss/code/03_build_cross_era_bridge.do") & fileexists("brfss/README.md") {
    global brfss_root "`cwd'/brfss"
}
else {
    display as error "Could not locate the brfss/ directory."
    display as error "Run from brfss/, brfss/code/, the repo root, or set global brfss_root."
    exit 198
}

cd "$brfss_root"
display as text "Using BRFSS root: $brfss_root"

if "$brfss_pre2011_clean_file" != "" {
    local pre_file "$brfss_pre2011_clean_file"
}
else {
    local pre_file "output/brfss_pre2011_clean.dta"
}

if "$brfss_2011plus_clean_file" != "" {
    local plus_file "$brfss_2011plus_clean_file"
}
else {
    local plus_file "output/brfss_2011plus_clean.dta"
}

if "$brfss_bridge_output_dir" != "" {
    local out_dir "$brfss_bridge_output_dir"
}
else if "$brfss_output_dir" != "" {
    local out_dir "$brfss_output_dir"
}
else {
    local out_dir "output"
}
capture mkdir "`out_dir'"
local out_dta "`out_dir'/brfss_cross_era_bridge.dta"

if !fileexists("`pre_file'") {
    display as error "Missing pre-2011 cleaned file: `pre_file'"
    exit 601
}
if !fileexists("`plus_file'") {
    display as error "Missing 2011-plus cleaned file: `plus_file'"
    exit 601
}

* ============================================================================
* BRIDGE CONTRACT
* ============================================================================

local common_bridge_vars ///
    surveyyear statefips county_code_raw county_code_source countyfips ///
    seqno month year age age_cat female race_eth white black hispanic ///
    raceother educ_cat hsdropout hsgraduate somecollege college ///
    marital_cat married divorced widowed nevermarried income_cat ///
    working student genhealth fair_or_poor mental_days physical_days ///
    bmi bmi_cat smoker current_smoker diabetes asthma_ever ///
    asthma_current heartattack heartdisease

local extra_bridge_vars "$brfss_bridge_extra_vars"
local reserved_vars ///
    analysis_weight psu strata _llcpwt _psu _ststr analysis_weight_raw ///
    psu_raw strata_raw survey_era post2011 sampling_frame ///
    weighting_method weight_source bmi_cat_era_specific bmi_cat_cross_era

foreach v of local extra_bridge_vars {
    local reserved_pos : list posof "`v'" in reserved_vars
    if `reserved_pos' > 0 {
        display as error "Reserved bridge name cannot be an extra variable: `v'"
        exit 198
    }
}

local bridge_vars "`common_bridge_vars' `extra_bridge_vars'"
local bridge_vars : list uniq bridge_vars

* ============================================================================
* PRE-2011 INPUT
* ============================================================================

display as text "Loading pre-2011 cleaned file: `pre_file'"
use `bridge_vars' analysis_weight psu strata using "`pre_file'", clear

quietly count
local pre_rows = r(N)
if `pre_rows' == 0 {
    display as error "Pre-2011 bridge input contains no observations."
    exit 2000
}
capture assert inrange(surveyyear, 2000, 2010)
if _rc != 0 {
    display as error "Pre-2011 bridge input must contain only years 2000-2010."
    exit 459
}

rename bmi_cat bmi_cat_era_specific
capture label values bmi_cat_era_specific
recast double analysis_weight psu strata
rename analysis_weight analysis_weight_raw
rename psu psu_raw
rename strata strata_raw
gen str10 survey_era = "pre2011"
gen byte post2011 = 0
gen str28 sampling_frame = "primarily_landline"
gen str24 weighting_method = "post_stratification"
gen str12 weight_source = "_FINALWT"

tempfile pre_bridge plus_bridge
save `pre_bridge', replace

* ============================================================================
* 2011-PLUS INPUT
* ============================================================================

display as text "Loading 2011-plus cleaned file: `plus_file'"
use `bridge_vars' _llcpwt _psu _ststr using "`plus_file'", clear

quietly count
local plus_rows = r(N)
if `plus_rows' == 0 {
    display as error "2011-plus bridge input contains no observations."
    exit 2000
}
capture assert surveyyear >= 2011 & !missing(surveyyear)
if _rc != 0 {
    display as error "The 2011-plus bridge input must contain only years 2011 or later."
    exit 459
}

rename bmi_cat bmi_cat_era_specific
capture label values bmi_cat_era_specific
recast double _llcpwt _psu _ststr
rename _llcpwt analysis_weight_raw
rename _psu psu_raw
rename _ststr strata_raw
gen str10 survey_era = "2011plus"
gen byte post2011 = 1
gen str28 sampling_frame = "landline_cell_dual_frame"
gen str24 weighting_method = "raking"
gen str12 weight_source = "_LLCPWT"
save `plus_bridge', replace

* Load the earlier era first so the appended file is chronological by default.
use `pre_bridge', clear
append using `plus_bridge'

gen byte bmi_cat_cross_era = .
replace bmi_cat_cross_era = 1 if bmi > 0 & bmi < 18.5
replace bmi_cat_cross_era = 2 if bmi >= 18.5 & bmi < 25
replace bmi_cat_cross_era = 3 if bmi >= 25 & bmi < 30
replace bmi_cat_cross_era = 4 if bmi >= 30 & !missing(bmi)

label var survey_era "BRFSS sampling/weighting era"
label var post2011 "Observation is from 2011-plus BRFSS era"
label var sampling_frame "BRFSS sampling-frame era"
label var weighting_method "Annual BRFSS weighting method"
label var weight_source "Original annual weight variable"
label var analysis_weight_raw "Original era-specific annual analysis weight"
label var psu_raw "Original era-specific PSU"
label var strata_raw "Original era-specific stratum"
label var bmi_cat_era_specific "CDC BMI category within source era; definitions differ"
label var bmi_cat_cross_era "BMI category reconstructed from continuous BMI"
label define bmi_bridge_lbl 1 "Underweight" 2 "Normal weight" 3 "Overweight" 4 "Obese", replace
label values bmi_cat_cross_era bmi_bridge_lbl

* ============================================================================
* VALIDATION AND SAVE
* ============================================================================

local expected_rows = `pre_rows' + `plus_rows'
assert _N == `expected_rows'
assert surveyyear <= 2010 if survey_era == "pre2011"
assert surveyyear >= 2011 if survey_era == "2011plus"
assert post2011 == (surveyyear >= 2011)
assert inrange(bmi_cat_cross_era, 1, 4) if !missing(bmi_cat_cross_era)
assert weight_source == "_FINALWT" if survey_era == "pre2011"
assert weight_source == "_LLCPWT" if survey_era == "2011plus"

duplicates tag surveyyear statefips seqno, generate(_bridge_duplicate_key)
quietly count if _bridge_duplicate_key > 0
local duplicate_key_rows = r(N)
drop _bridge_duplicate_key

sort surveyyear statefips seqno
compress
recast double analysis_weight_raw psu_raw strata_raw
save "`out_dta'", replace

display as text "[PASS] Pre-2011 rows: `pre_rows'"
display as text "[PASS] 2011-plus rows: `plus_rows'"
display as text "[PASS] Bridge rows: " _N
display as text "[INFO] Rows in duplicated surveyyear + statefips + seqno groups: `duplicate_key_rows'"
display as text "[PASS] Era, weight-source, and cross-era BMI metadata validated."
display as result "Saved: `out_dta'"
display as text "[CAUTION] analysis_weight_raw contains original annual weights only."
display as text "          No pooled normalization or survey design has been imposed."

********************************************************************************
* MEMORY NOTE
*
* The bridge reads selected variables directly from each Stata file. For the R
* workflow, use the optional low-memory era loaders when RAM is constrained;
* an RDS file must be opened before its columns can be selected.
********************************************************************************
