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
* Usage:   Run this script from the brfss/ directory, brfss/code/, or the repo root:
*            cd "/path/to/brfss"
*            do code/01_load_and_append.do
*          or
*            cd "/path/to/brfss/code"
*            do 01_load_and_append.do
*          or
*            cd "/path/to/eco-322-public-data"
*            do brfss/code/01_load_and_append.do
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
* Auto-detect the dataset root from the current working directory.
* You can also set global brfss_root before running the script.
*
* Optional manual override if auto-detection fails:
* global brfss_root "/path/to/brfss"

local cwd `"`c(pwd)'"'
if "$brfss_root" != "" & fileexists("$brfss_root/code/01_load_and_append.do") {
    global brfss_root "$brfss_root"
}
else if fileexists("code/01_load_and_append.do") & fileexists("README.md") {
    global brfss_root "`cwd'"
}
else if fileexists("01_load_and_append.do") & fileexists("../README.md") {
    global brfss_root "`cwd'/.."
}
else if fileexists("brfss/code/01_load_and_append.do") & fileexists("brfss/README.md") {
    global brfss_root "`cwd'/brfss"
}
else {
    display as error "Could not locate the brfss/ directory."
    display as error "Run from brfss/, brfss/code/, the repo root, or set global brfss_root first."
    exit 198
}

cd "$brfss_root"
display as text "Using BRFSS root: $brfss_root"

local raw_dir  "data/raw"
local out_dta  "output/brfss_appended.dta"

* ============================================================================
* 2. DEFINE YEARS TO LOAD
* ============================================================================
* 2011 is the first year of the dual-frame (landline + cell) methodology.
* The scripts default to 2023-2024 to keep download/processing sizes manageable.
*
* Choose either a consecutive year range or an explicit year list.
* If years_to_load is not empty, it overrides first_year/last_year.
* Examples:
*   local years_to_load "2011 2014 2024"   // Non-consecutive year list
*   local first_year 2011    // Full 14-year range (2011-2024, ~12 GB)
*   local first_year 2019    // Recent 6 years (2019-2024)
*   local first_year 2023    // Default 2 years (2023-2024)

local years_to_load ""
local first_year 2023
local last_year  2024

local years ""
if trim(`"`years_to_load'"') != "" {
    local years `years_to_load'
    local years : list uniq years
    local years : list sort years
    local years : list retok years
    local year_label `"`years'"'
}
else {
    forvalues y = `first_year'(1)`last_year' {
        local years "`years' `y'"
    }
    local years : list retok years
    local year_label "`first_year'-`last_year'"
}

if trim(`"`years'"') == "" {
    display as error "No years selected. Set years_to_load or first_year/last_year."
    exit 198
}

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
display as text "   LOADING BRFSS DATA (`year_label')"
display as text "============================================"

tempfile master
local is_first = 1

foreach y of local years {

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

* --- 5a. Check loaded years ---
levelsof surveyyear, local(loaded_years)
local loaded_years : list retok loaded_years
if trim(`"`loaded_years'"') == trim(`"`years'"') {
    display as text "[PASS] Loaded years match request: `loaded_years'"
}
else {
    display as error "[FAIL] Expected years `years' but found `loaded_years'"
}

* --- 5b. Check observations per year ---
display as text _newline "[INFO] Observations per survey year:"
tab surveyyear

* --- 5c. Check key survey design variables exist ---
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

* --- 5d. Check supported harmonization families exist ---
local family_names "sex race income age employment diabetes copd"
local family_label_sex "SEX / SEXVAR / BIRTHSEX"
local family_vars_sex "sex sexvar birthsex"
local family_label_race "_RACEGR2 / _RACEGR3 / _RACEGR4"
local family_vars_race "_racegr2 _racegr3 _racegr4"
local family_label_income "INCOME2 / INCOME3"
local family_vars_income "income2 income3"
local family_label_age "_IMPAGE / _AGE80"
local family_vars_age "_impage _age80"
local family_label_employment "EMPLOY / EMPLOY1"
local family_vars_employment "employ employ1"
local family_label_diabetes "DIABETE3 / DIABETE4"
local family_vars_diabetes "diabete3 diabete4"
local family_label_copd "CHCCOPD / CHCCOPD1 / CHCCOPD3"
local family_vars_copd "chccopd chccopd1 chccopd3"

foreach family_name of local family_names {
    local found_family = 0
    local family_vars `"`family_vars_`family_name''"'
    foreach v of local family_vars {
        capture confirm variable `v'
        if _rc == 0 local found_family = 1
    }

    local family_label `"`family_label_`family_name''"'
    if `found_family' == 1 {
        display as text "[PASS] Found a supported `family_name' variable family (`family_label')"
    }
    else {
        display as error "[FAIL] No supported `family_name' variable family found (`family_label')"
    }
}

* --- 5e. Check no year has zero observations ---
local any_empty = 0
foreach y of local years {
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
*    - Race/ethnicity: _RACEGR2 (2011-2014) vs. _RACEGR3 (2015-2021, 2023-2024)
*      vs. _RACEGR4 (2022)
*    - Income: INCOME2 (2011-2020) vs. INCOME3 (2021-2024)
*    - Sex: SEX (2011-2020) vs. SEXVAR/BIRTHSEX (2021-2024)
*    - COPD: CHCCOPD / CHCCOPD1 (older layouts) vs. CHCCOPD3 (modern layouts)
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
*    - Set `first_year' / `last_year' for a consecutive range, or
*      set `years_to_load' for an explicit year list
*    - Re-run this script
*
* 7. ADDING NEW YEARS: When new BRFSS data become available:
*    - Download the LLCP20XX.XPT file from CDC
*    - Place it in data/raw/
*    - Update `last_year' or `years_to_load' in Section 2
*    - Re-run this script
********************************************************************************
