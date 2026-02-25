********************************************************************************
* 01_load_and_append.do
*
* Purpose: Import BRFSS SAS Transport (.XPT) files for each survey year,
*          add a survey year identifier, and append all years into a single
*          stacked dataset.
*
* Input:   data/raw/LLCP20XX.XPT   (default: 2023-2024; expandable to 2011-2024)
* Output:  output/brfss_appended.dta
*
* Usage:   Run this script from the brfss/ directory:
*            cd "/path/to/brfss"
*            do code/01_load_and_append.do
*
* Data:    Behavioral Risk Factor Surveillance System (BRFSS)
*          CDC annual telephone health survey, 400,000+ adults per year.
*          We focus on 2011 forward because the BRFSS switched from
*          landline-only to a dual-frame (landline + cell phone) design
*          in 2011, making pre-2011 data not directly comparable.
*
* Note:    The raw files are SAS Transport (.XPT) format distributed by CDC.
*          Variable names in XPT files are ALL CAPS. Some variable names
*          changed across years (handled in 02_clean_and_harmonize.do).
*
* Author:  Austin Denteh (legacy code and Claude Code)
* Date:    February 2026
********************************************************************************

clear all
set more off

* ============================================================================
* 1. DEFINE PATHS
* ============================================================================
* Set the working directory to the brfss/ folder.
* Users should update this path to match their system.

global brfss_root "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/brfss"
cd "$brfss_root"

local raw_dir  "data/raw"
local out_dta  "output/brfss_appended.dta"

* ============================================================================
* 2. DEFINE YEAR RANGE
* ============================================================================
* 2011 is the first year of the dual-frame (landline + cell) methodology.
* The scripts default to 2023-2024 to keep download/processing sizes manageable.
*
* To expand to more years, download the corresponding LLCP20XX.XPT files
* from the shared Dropbox folder (see README) and change first_year below.
* Examples:
*   local first_year 2011    // Full 14-year range (2011-2024, ~12 GB)
*   local first_year 2019    // Recent 6 years (2019-2024)
*   local first_year 2023    // Default 2 years (2023-2024)

local first_year 2023
local last_year  2024

* ============================================================================
* 3. LOOP: IMPORT EACH YEAR AND SAVE AS TEMPFILE
* ============================================================================
* For each year:
*   (a) Import the SAS Transport file using -import sasxport5-
*   (b) Add a surveyyear variable
*   (c) Save as a temporary Stata file
*
* NOTE: Each XPT file is 600 MB - 1.2 GB, so this loop takes a while.
* On a typical machine, expect 5-10 minutes per year.

display as text _newline "============================================"
display as text "   LOADING BRFSS DATA (`first_year'-`last_year')"
display as text "============================================"

tempfile master
local is_first = 1

forvalues y = `first_year'(1)`last_year' {

    display as text _newline "--- Year `y' ---"

    * Import SAS transport file
    import sasxport5 "`raw_dir'/LLCP`y'.XPT", clear

    * Add survey year identifier
    gen surveyyear = `y'
    label var surveyyear "BRFSS survey year"

    display as text "  Imported `y': " _N " observations, " c(k) " variables"

    * Append to master
    if `is_first' == 1 {
        save `master', replace
        local is_first = 0
    }
    else {
        append using `master', force
        save `master', replace
    }
}

* ============================================================================
* 4. SORT AND SAVE
* ============================================================================

display as text _newline "============================================"
display as text "   SAVING APPENDED DATASET"
display as text "============================================"

sort surveyyear _psu
compress

save "`out_dta'", replace
display as text "Saved: `out_dta'"
display as text "Total observations: " _N
display as text "Total variables: " c(k)

* ============================================================================
* 5. VALIDATION CHECKS
* ============================================================================

display as text _newline "============================================"
display as text "   VALIDATION CHECKS"
display as text "============================================"

* --- 5a. Check year range ---
quietly summarize surveyyear
if r(min) == `first_year' & r(max) == `last_year' {
    display as text "[PASS] Survey year range: " r(min) " to " r(max)
}
else {
    display as error "[FAIL] Expected year range `first_year'-`last_year' but found " r(min) " to " r(max)
}

* --- 5b. Check observations per year ---
display as text _newline "[INFO] Observations per survey year:"
tab surveyyear

* --- 5c. Check total is plausible ---
* Each year typically has 400,000-500,000 respondents.
quietly tab surveyyear
local n_years = r(r)
local lower_bound = `n_years' * 350000
local upper_bound = `n_years' * 600000
if _N > `lower_bound' & _N < `upper_bound' {
    display as text "[PASS] Total observations (" _N ") is plausible for `n_years' year(s)"
}
else {
    display as error "[FAIL] Total observations (" _N ") seems implausible for `n_years' year(s)"
}

* --- 5d. Check key survey design variables exist ---
local design_vars "_psu _ststr _llcpwt"
local all_exist = 1
local missing_vars ""
foreach v of local design_vars {
    capture confirm variable `v'
    if _rc != 0 {
        local all_exist = 0
        local missing_vars "`missing_vars' `v'"
    }
}
if `all_exist' == 1 {
    display as text "[PASS] Survey design variables present: `design_vars'"
}
else {
    display as error "[FAIL] Missing survey design variable(s):`missing_vars'"
}

* --- 5e. Check key content variables exist ---
local content_vars "genhlth menthlth physhlth _state _ageg5yr _age80 sex educa marital employ1 income2"
local all_exist = 1
local missing_vars ""
foreach v of local content_vars {
    capture confirm variable `v'
    if _rc != 0 {
        local all_exist = 0
        local missing_vars "`missing_vars' `v'"
    }
}
if `all_exist' == 1 {
    display as text "[PASS] Key content variables present"
}
else {
    display as text "[INFO] Some content variables not present in all years:`missing_vars'"
    display as text "       This is expected — variable names change across years."
    display as text "       See 02_clean_and_harmonize.do for cross-year harmonization."
}

* --- 5f. Check no year has zero observations ---
local any_empty = 0
forvalues y = `first_year'(1)`last_year' {
    quietly count if surveyyear == `y'
    if r(N) == 0 {
        local any_empty = 1
        display as error "[FAIL] Year `y' has 0 observations"
    }
}
if `any_empty' == 0 {
    display as text "[PASS] All years have observations"
}

display as text _newline "============================================"
display as text "   VALIDATION COMPLETE"
display as text "============================================"
display as text _newline "Next step: run 02_clean_and_harmonize.do"

********************************************************************************
* NOTES FOR USERS:
*
* 1. METHODOLOGY BREAK IN 2011: The BRFSS switched from landline-only to a
*    dual-frame (landline + cell phone) design in 2011. This fundamentally
*    changed the sampling, weighting, and resulting estimates. Pre-2011 data
*    are NOT directly comparable. This repository focuses on 2011 forward.
*
* 2. SAS TRANSPORT FORMAT: The raw data come as .XPT files (SAS Transport v5).
*    Stata imports these with -import sasxport5-. Variable names are typically
*    uppercase. Some years may have slightly different variable lists.
*
* 3. VARIABLE CHANGES ACROSS YEARS:
*    - Race/ethnicity: _RACEGR3 (2011-2021) vs. _RACEGR4 (2022+)
*    - Income: INCOME2 (2011-2020) vs. INCOME3 (2021+)
*    - Sex: SEX (2011-2021) vs. SEXVAR/BIRTHSEX (2022+)
*    These are harmonized in 02_clean_and_harmonize.do.
*
* 4. APPEND WITH FORCE: We use -append, force- because variable lists differ
*    across years. Variables that exist in some years but not others will have
*    missing values for the years where they are absent.
*
* 5. FILE SIZE: The appended dataset will be very large (5+ million obs,
*    300+ variables). Ensure you have sufficient disk space and RAM.
*    Consider using -compress- before saving (included in this script).
*
* 6. EXPANDING YEAR RANGE: To include more years:
*    - Download the LLCP20XX.XPT files from Dropbox or CDC
*    - Place them in data/raw/
*    - Change `first_year' in Section 2 (e.g., 2011 for the full range)
*    - Re-run this script
*
* 7. ADDING NEW YEARS: When new BRFSS data become available:
*    - Download the LLCP20XX.XPT file from CDC
*    - Place it in data/raw/
*    - Update `last_year' in Section 2
*    - Re-run this script
********************************************************************************
