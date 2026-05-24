********************************************************************************
* 02_clean_demographics.do
*
* Purpose: Load the reshaped RAND HRS long-format dataset, create starter
*          demographic variables, save an analysis-ready file, and optionally
*          run descriptive tables/regression examples.
*
* Input:   output/hrs_long.dta  (from 01_reshape_and_save.do)
* Output:  output/hrs_demographics_clean.dta
*
* Usage:   Run from hrs/, hrs/code/, from the repo root, or set global hrs_root.
********************************************************************************

clear all
set more off
set maxvar 32767

* ============================================================================
* 1. DEFINE PATHS AND OPTIONS
* ============================================================================
* Optional manual path override. Uncomment and edit if auto-detection fails:
* global hrs_root "/Users/yourname/path/to/econ-data-starters/hrs"
* Then run: do "$hrs_root/code/02_clean_demographics.do"

local cwd "`c(pwd)'"
if "$hrs_root" != "" & fileexists("$hrs_root/code/02_clean_demographics.do") {
    global hrs_root "$hrs_root"
}
else if fileexists("code/02_clean_demographics.do") & fileexists("README.md") {
    global hrs_root "`cwd'"
}
else if fileexists("02_clean_demographics.do") & fileexists("../README.md") {
    global hrs_root "`cwd'/.."
}
else if fileexists("hrs/code/02_clean_demographics.do") & fileexists("hrs/README.md") {
    global hrs_root "`cwd'/hrs"
}
else {
    display as error "Could not locate the hrs/ directory."
    display as error "Run from hrs/, hrs/code/, from the repo root, or set global hrs_root."
    display as error `"Manual override: global hrs_root "/path/to/hrs""'
    error 601
}

cd "$hrs_root"
capture mkdir "output"

local input_basename "hrs_long"
if "$hrs_input_basename" != "" {
    local input_basename "$hrs_input_basename"
}

local input_dir "output"
if "$hrs_input_dir" != "" {
    local input_dir "$hrs_input_dir"
}

local output_dir "output"
if "$hrs_output_dir" != "" {
    local output_dir "$hrs_output_dir"
    capture mkdir "`output_dir'"
}

local in_dta "`input_dir'/`input_basename'.dta"
if !fileexists("`in_dta'") & fileexists("`input_dir'/`input_basename'_from_r.dta") {
    local in_dta "`input_dir'/`input_basename'_from_r.dta"
}
local out_dta "`output_dir'/hrs_demographics_clean.dta"

* Public starter scripts keep examples visible but off by default.
local run_examples 0
if "$hrs_run_examples" == "1" {
    local run_examples 1
}

* ============================================================================
* 2. LOAD DATA
* ============================================================================

if !fileexists("`in_dta'") {
    display as error "Could not find `in_dta'. Run 01_reshape_and_save.do first."
    error 601
}

use "`in_dta'", clear
display as text "Loaded " _N " person-wave observations."

local required_vars "hhidpn wave year inw ragender raeduc raracem rahispan rmstat hacohort"
local missing_required
foreach v of local required_vars {
    capture confirm variable `v'
    if _rc != 0 {
        local missing_required `missing_required' `v'
    }
}
if wordcount("`missing_required'") > 0 {
    display as error "The reshaped HRS file is missing required variables:`missing_required'"
    error 111
}

xtset hhidpn wave
display as text "Panel variable: hhidpn | Time variable: wave (1-16)"

* ============================================================================
* 3. CLEAN DEMOGRAPHIC VARIABLES
* ============================================================================

display as text _newline "============================================"
display as text "   CLEANING HRS DEMOGRAPHICS"
display as text "============================================"

* Gender: ragender 1 = Male, 2 = Female
gen female = .
replace female = 0 if ragender == 1
replace female = 1 if ragender == 2
label var female "Female (0/1)"
label define female_lbl 0 "Male" 1 "Female", replace
label values female female_lbl

* Education: raeduc 1=Lt HS, 2=GED, 3=HS grad, 4=Some college, 5=College+
gen educ_cat = .
replace educ_cat = 1 if raeduc == 1
replace educ_cat = 2 if raeduc == 2 | raeduc == 3
replace educ_cat = 3 if raeduc == 4
replace educ_cat = 4 if raeduc == 5
label var educ_cat "Education (4 categories)"
label define educ_lbl 1 "Less than HS" 2 "HS/GED" 3 "Some college" 4 "College+", replace
label values educ_cat educ_lbl

* Race/ethnicity: raracem 1=White, 2=Black, 3=Other; rahispan 1=Hispanic
gen race_eth = .
replace race_eth = 1 if rahispan == 0 & raracem == 1
replace race_eth = 2 if rahispan == 0 & raracem == 2
replace race_eth = 3 if rahispan == 1
replace race_eth = 4 if rahispan == 0 & raracem == 3
label var race_eth "Race/ethnicity"
label define race_lbl 1 "White NH" 2 "Black NH" 3 "Hispanic" 4 "Other NH", replace
label values race_eth race_lbl

* Marital status: rmstat is wave-varying
gen marital = .
replace marital = 1 if inrange(rmstat, 1, 3)
replace marital = 2 if inrange(rmstat, 4, 6)
replace marital = 3 if rmstat == 7
replace marital = 4 if rmstat == 8
label var marital "Marital status (4 categories)"
label define mar_lbl 1 "Married/Partnered" 2 "Sep/Divorced" 3 "Widowed" 4 "Never married", replace
label values marital mar_lbl

* Entry cohort labels
label define cohort_lbl 0 "AHEAD (spouse)" 1 "AHEAD" 2 "CODA" 3 "HRS" ///
    4 "War Baby" 5 "Early Boomer" 6 "Mid Boomer" 7 "Late Boomer" 8 "Early Gen X", replace
label values hacohort cohort_lbl

* Respondent interview count across waves
tempvar interviewed_flag
gen byte `interviewed_flag' = (inw == 1) if !missing(inw)
bysort hhidpn: egen total_waves = total(`interviewed_flag')
label var total_waves "Number of waves with respondent interview"

display as text "Created: female, educ_cat, race_eth, marital, total_waves"

* ============================================================================
* 4. SAVE CLEANED DATA
* ============================================================================

save "`out_dta'", replace
display as text "Saved: `out_dta'"

* ============================================================================
* 5. OPTIONAL DESCRIPTIVE TABLES AND REGRESSIONS
* ============================================================================

if `run_examples' {
    display as text _newline "--- Response rates by wave ---"
    tabulate wave inw, row

    display as text _newline "--- Distribution of waves responded ---"
    tabulate total_waves

    display as text _newline "--- Gender distribution ---"
    tab female if wave == 1 | (wave > 1 & inw == 1), missing

    display as text _newline "--- Education distribution ---"
    tab educ_cat if inw == 1 & wave == 4, missing

    display as text _newline "--- Race/ethnicity distribution ---"
    tab race_eth if inw == 1 & wave == 4, missing

    display as text _newline "--- Marital status by wave (interviewed respondents) ---"
    tab wave marital if inw == 1, row

    capture confirm variable rshlt
    if !_rc {
        display as text _newline "--- Self-rated health: missing value patterns ---"
        gen str24 shlt_status = "Valid" if rshlt >= 1 & rshlt <= 5
        replace shlt_status = "Not interviewed (.)" if rshlt == .
        replace shlt_status = "Don't know (.D)" if rshlt == .d
        replace shlt_status = "Refused (.R)" if rshlt == .r
        replace shlt_status = "Other missing" if rshlt > 5 & rshlt < . & shlt_status == ""
        replace shlt_status = "Other ext. missing" if rshlt > . & shlt_status == ""
        tab shlt_status wave if wave >= 4, missing
        drop shlt_status
    }

    display as text _newline "=========================================="
    display as text "   DESCRIPTIVE STATISTICS (interviewed only)"
    display as text "=========================================="

    summarize ragey_b female rshlt rcesd rbmi rconde ///
        rhosp radl5a riadl5a rmobila hitot hatotb ///
        if inw == 1, detail

    tabstat rshlt if inw == 1, by(wave) statistics(mean sd n) format(%9.2f)
    tabstat rcesd if inw == 1, by(wave) statistics(mean sd n) format(%9.2f)
    tabstat rbmi if inw == 1, by(wave) statistics(mean sd n) format(%9.1f)

    display as text _newline "=========================================="
    display as text "   SIMPLE REGRESSION EXAMPLE"
    display as text "=========================================="

    reg rshlt ragey_b female i.educ_cat i.race_eth if inw == 1
    reg rshlt ragey_b female i.educ_cat i.race_eth if inw == 1 [pw=rwtresp]
    xtreg rshlt ragey_b i.marital if inw == 1, fe
}
else {
    display as text _newline "Example tables and regressions are off by default."
    display as text "Set global hrs_run_examples 1 before running this script to print them."
}

display as text _newline "Starter HRS cleaning complete."
