********************************************************************************
* 01_load_and_subset.do
*
* Purpose: Load yearly IPUMS CPS ASEC extracts and save a working dataset.
*          The expected raw files are one file per survey year:
*          data/raw/cps_<extract id>_<year>.dta, e.g. cps_00015_2005.dta.
*
* Input:   data/raw/cps_*_YYYY.dta  (one file per ASEC survey year)
* Output:  output/cps_asec.dta
*
* Usage:   Run from march_cps/, march_cps/code/, from the repo root,
*          or set global cps_root to the march_cps/ directory.
*
* Data:    Current Population Survey, Annual Social and Economic Supplement
*          (CPS ASEC, also called the "March CPS"). Person-level records with
*          detailed income, employment, health insurance, demographics, and
*          program participation. ~150,000-200,000 persons per year.
*
*          Extracted from IPUMS CPS (https://cps.ipums.org).
*
* Author:  Austin Denteh (legacy code and Claude Code)
* Date:    February 2026; revised for yearly extracts May 2026
********************************************************************************

clear all
set more off
set maxvar 10000

* ============================================================================
* 1. DEFINE PATHS
* ============================================================================
* Auto-detect the dataset root from global cps_root, the dataset folder,
* code/, or the repo root.
*
* Optional manual path override. Uncomment and edit if auto-detection fails:
* global cps_root "/Users/yourname/path/to/econ-data-starters/march_cps"
* Then run: do "$cps_root/code/01_load_and_subset.do"

local cwd "`c(pwd)'"
if "$cps_root" != "" & fileexists("$cps_root/code/01_load_and_subset.do") {
    global cps_root "$cps_root"
}
else if fileexists("code/01_load_and_subset.do") & fileexists("README.md") {
    global cps_root "`cwd'"
}
else if fileexists("01_load_and_subset.do") & fileexists("../README.md") {
    global cps_root "`cwd'/.."
}
else if fileexists("march_cps/code/01_load_and_subset.do") & fileexists("march_cps/README.md") {
    global cps_root "`cwd'/march_cps"
}
else {
    display as error "Could not locate the march_cps/ directory."
    display as error "Run from march_cps/, march_cps/code/, from the repo root, or set global cps_root."
    display as error `"Manual override: global cps_root "/path/to/march_cps""'
    error 601
}

cd "$cps_root"
capture mkdir "output"

local out_dta "output/cps_asec.dta"

* ============================================================================
* 2. DEFINE YEAR SETTINGS
* ============================================================================
* The CPS ASEC YEAR variable refers to the survey year. Income and insurance
* questions typically refer to the PRIOR calendar year.
* Example: YEAR=2025 contains income data for calendar year 2024.
*
* Defaults cover 2005-2010 but the last year can be manually extended to 2025
* To run a smaller smoke test before calling this
* script, set one of:
*   global cps_years_to_load "2021 2022"
*   global cps_first_year 2021
*   global cps_last_year 2025
*
* From a shell, CPS_YEARS="2021,2022" is also honored.

local first_year 2005
local last_year 2010
if "$cps_first_year" != "" local first_year "$cps_first_year"
if "$cps_last_year"  != "" local last_year  "$cps_last_year"

local years_to_load "$cps_years_to_load"
local env_years : env CPS_YEARS
if "`years_to_load'" == "" & "`env_years'" != "" {
    local years_to_load "`env_years'"
}
local years_to_load : subinstr local years_to_load "," " ", all

if "`years_to_load'" == "" {
    forvalues y = `first_year'/`last_year' {
        local years_to_load "`years_to_load' `y'"
    }
}

display as text "Requested CPS ASEC years: `years_to_load'"

* Helper: find exactly one yearly file for a survey year.
capture program drop _find_cps_year_file
program define _find_cps_year_file, rclass
    syntax, YEAR(integer)

    local candidate_files : dir "data/raw" files "cps_*_`year'.dta"
    local matches ""
    foreach f of local candidate_files {
        if regexm("`f'", "^cps_[0-9]+_`year'[.]dta$") {
            local matches "`matches' `f'"
        }
    }

    local n_matches : word count `matches'
    if `n_matches' == 0 {
        display as error "No yearly CPS file found for `year'."
        display as error "Expected data/raw/cps_<extract id>_`year'.dta"
        error 601
    }
    if `n_matches' > 1 {
        display as error "Multiple yearly CPS files found for `year':"
        foreach f of local matches {
            display as error "  - `f'"
        }
        display as error "Keep one cps_<extract id>_<year>.dta file per year in data/raw/."
        error 459
    }

    local one_file : word 1 of `matches'
    return local file "data/raw/`one_file'"
end

* ============================================================================
* 3. LOAD AND APPEND YEARLY FILES
* ============================================================================

display as text _newline "============================================"
display as text "   LOADING CPS ASEC DATA"
display as text "============================================"

tempfile master
local first_file 1

foreach y of local years_to_load {
    quietly _find_cps_year_file, year(`y')
    local raw_dta "`r(file)'"
    display as text "Loading `y': `raw_dta'"

    use "`raw_dta'", clear
    capture rename *, lower

    foreach v in year serial pernum {
        capture confirm variable `v'
        if _rc != 0 {
            display as error "Required variable missing from `raw_dta': `v'"
            error 111
        }
    }

    quietly count if year != `y' & !missing(year)
    if r(N) > 0 {
        display as error "`raw_dta' contains YEAR values other than `y'."
        tab year
        error 459
    }

    gen double individ = year * 10000000 + serial * 100 + pernum
    format individ %18.0f
    label var individ "Unique record ID within saved extract (year, serial, pernum)"
    isid individ

    if `first_file' {
        save `master', replace
        local first_file 0
    }
    else {
        append using `master'
        save `master', replace
    }

    display as text "  appended observations so far: " _N
}

use `master', clear
sort year serial pernum
isid individ
compress

save "`out_dta'", replace
display as text _newline "Saved: `out_dta'"
display as text "Observations: " _N
display as text "Variables: " c(k)

* ============================================================================
* 4. VALIDATION CHECKS
* ============================================================================

display as text _newline "============================================"
display as text "   VALIDATION CHECKS"
display as text "============================================"

quietly summarize year
display as text "[PASS] Year range: " r(min) " to " r(max) " (" r(N) " observations)"

display as text _newline "[INFO] Observations per year:"
tab year

quietly levelsof year, local(yr_levels)
local n_years : word count `yr_levels'
local low_bound = `n_years' * 130000
local high_bound = `n_years' * 250000
if _N > `low_bound' & _N < `high_bound' {
    display as text "[PASS] Total observations (" _N ") is plausible for `n_years' years"
}
else {
    display as text "[NOTE] Total observations (" _N ") for `n_years' years"
}

local key_vars "year serial pernum cpsidp asecwt statefip age sex race hispan educ empstat labforce inctot incwage incss incwelfr incssi"
local all_exist = 1
local missing_vars ""
foreach v of local key_vars {
    capture confirm variable `v'
    if _rc != 0 {
        local all_exist = 0
        local missing_vars "`missing_vars' `v'"
    }
}
if `all_exist' == 1 {
    display as text "[PASS] All key variables present"
}
else {
    display as error "[FAIL] Missing variable(s):`missing_vars'"
}

quietly summarize asecwt
if r(N) > 0 & r(mean) > 0 {
    display as text "[PASS] ASEC weight (asecwt) has non-missing, positive values"
}
else {
    display as error "[FAIL] ASEC weight has issues: N=" r(N) ", mean=" r(mean)
}

display as text _newline "--- Quick summary of key variables ---"
summarize year age inctot incwage asecwt

display as text _newline "============================================"
display as text "   VALIDATION COMPLETE"
display as text "============================================"
display as text _newline "Next step: run 02_clean_demographics.do"

********************************************************************************
* NOTES ON DATA FILES AND YEAR COVERAGE:
*
* This repository now expects one IPUMS CPS ASEC .dta file per year:
*   data/raw/cps_00015_2005.dta
*   data/raw/cps_00016_2006.dta
*   ...
*   data/raw/cps_00035_2025.dta
*
*
* Key considerations for different year ranges:
*
*   - Health insurance variables: Changed significantly in 2014 (ACA),
*     and again in 2019 (redesigned insurance questions).
*     HINSCARE/HINSCAID available 1988-2013.
*     HIMCAIDLY/HIMCARELY available 1988-2025.
*     ANYCOVLY/ANYCOVNW available starting 2019.
*
*   - Education (EDUC): Coding changed in 1992 (EDUC vs. HIGRADE).
*     Use EDUC99 for consistent post-1992 coding.
*
*   - Immigration variables (BPL, CITIZEN, YRIMMIG): Available 1994+.
*
*   - Replicate weights (REPWTP1-REPWTP160): Available 2005+.
********************************************************************************
