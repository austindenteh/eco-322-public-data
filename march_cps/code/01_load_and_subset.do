********************************************************************************
* 01_load_and_subset.do
*
* Purpose: Load an IPUMS CPS ASEC extract and save a working dataset.
*          Auto-detects which data file is in data/raw/ (see README).
*          Two pre-built extracts are available:
*            - Quick start (2021-2025, ~2.6 GB)
*            - Full analysis (2005-2025, ~14 GB)
*
* Input:   data/raw/cps_*.dta        (auto-detects IPUMS CPS extract)
* Output:  output/cps_asec.dta
*
* Usage:   Run from the march_cps/ directory:
*            cd "/path/to/march_cps"
*            do code/01_load_and_subset.do
*
* Data:    Current Population Survey, Annual Social and Economic Supplement
*          (CPS ASEC, also called the "March CPS"). Person-level records with
*          detailed income, employment, health insurance, demographics, and
*          program participation. ~150,000-200,000 persons per year.
*
*          Extracted from IPUMS CPS (https://cps.ipums.org).
*          Two extracts available (script auto-detects):
*            cps_00012_2021_2025.dta  (2021-2025, ~2.6 GB — quick start)
*            cps_00011_2005_2025.dta  (2005-2025, ~14 GB — full analysis)
*
* Author:  Austin Denteh (legacy code and Claude Code)
* Date:    February 2026
********************************************************************************

clear all
set more off
set maxvar 10000

* ============================================================================
* 1. DEFINE PATHS
* ============================================================================
* Set the working directory to the march_cps/ folder.
* Users should update this path to match their system.

global cps_root "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/march_cps"
cd "$cps_root"

local out_dta  "output/cps_asec.dta"

* --- Auto-detect which data file is present ---
* The script checks for available CPS extract files in data/raw/.
* If multiple files exist, it prefers the smaller (2021-2025) extract
* so the script runs quickly by default. Users with the full extract
* can override by setting local raw_dta before this block.

local raw_dta "data/raw/cps_00012_2021_2025.dta"
foreach f in "cps_00012_2021_2025.dta" "cps_00012_2001_2025.dta" "cps_00011_2005_2025.dta" "cps_00010.dta" {
    capture confirm file "data/raw/`f'"
    if _rc == 0 & "`raw_dta'" == "" {
        local raw_dta "data/raw/`f'"
    }
}
if "`raw_dta'" == "" {
    display as error "ERROR: No CPS data file found in data/raw/"
    display as error "Download from the shared Dropbox folder — see README.md"
    error 601
}
display as text "Using data file: `raw_dta'"

* ============================================================================
* 2. DEFINE YEAR RANGE
* ============================================================================
* The CPS ASEC YEAR variable refers to the survey year. Income and insurance
* questions typically refer to the PRIOR calendar year.
* Example: YEAR=2025 contains income data for calendar year 2024.
*
* The year range is set AFTER loading the data, based on what's in the file.
* If you want to restrict further, change first_year/last_year below.
* For the full 2005-2025 extract, the default covers:
*   - Pre-ACA baseline (2005-2013)
*   - ACA Medicaid expansion (2014+)
*   - Great Recession and recovery (2007-2012)
*   - COVID-19 pandemic (2020-2021)
*   - Recent trends (2022-2025)

* ============================================================================
* 3. LOAD RAW DATA
* ============================================================================

display as text _newline "============================================"
display as text "   LOADING CPS ASEC DATA"
display as text "============================================"

use "`raw_dta'", clear
display as text "Loaded: " _N " observations, " c(k) " variables."

* Detect the year range in the data
quietly summarize year
local data_min_year = r(min)
local data_max_year = r(max)
display as text "Year range in raw data: `data_min_year' to `data_max_year'"

* Set year range — defaults to whatever is in the data.
* Override these locals if you want a narrower window.
local first_year `data_min_year'
local last_year  `data_max_year'

* ============================================================================
* 4. RESTRICT TO YEAR RANGE (if needed)
* ============================================================================

if `first_year' > `data_min_year' | `last_year' < `data_max_year' {
    display as text _newline "Restricting to years `first_year'-`last_year'..."
    keep if year >= `first_year' & year <= `last_year'
    display as text "After year restriction: " _N " observations."
}
else {
    display as text "Using full year range: `first_year'-`last_year' (no restriction needed)."
}

* ============================================================================
* 5. CREATE KEY IDENTIFIERS
* ============================================================================
* IPUMS provides several ID variables:
*   SERIAL    = household serial number (unique within year)
*   PERNUM    = person number within household
*   CPSID     = household-level linking ID (for linking across months)
*   CPSIDP    = person-level linking ID (for linking across months)
*   CPSIDV    = validation version of person ID
*
* For cross-sectional analysis within a single year, use SERIAL + PERNUM.
* For linking persons across the 2 years they are in the CPS rotation,
* use CPSIDP (available 1989+).

* Create a unique person-year identifier
gen double individ = serial * 100 + pernum
label var individ "Person-year identifier (serial*100 + pernum)"

* ============================================================================
* 6. SORT AND SAVE
* ============================================================================

sort year serial pernum
compress

save "`out_dta'", replace
display as text _newline "Saved: `out_dta'"
display as text "Observations: " _N
display as text "Variables: " c(k)

* ============================================================================
* 7. VALIDATION CHECKS
* ============================================================================

display as text _newline "============================================"
display as text "   VALIDATION CHECKS"
display as text "============================================"

* --- 7a. Check year range ---
quietly summarize year
display as text "[PASS] Year range: " r(min) " to " r(max) " (" r(N) " observations)"

* --- 7b. Observations per year ---
display as text _newline "[INFO] Observations per year:"
tab year

* --- 7c. Check total is plausible ---
* Each year typically has 150,000-210,000 person records.
quietly levelsof year, local(yr_levels)
local n_years : word count `yr_levels'
local low_bound = `n_years' * 130000
local high_bound = `n_years' * 250000
if _N > `low_bound' & _N < `high_bound' {
    display as text "[PASS] Total observations (" _N ") is plausible for `n_years' years"
}
else {
    display as error "[FAIL] Total observations (" _N ") seems implausible for `n_years' years"
}

* --- 7d. Check key variables exist ---
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

* --- 7e. Check weight variable ---
quietly summarize asecwt
if r(N) > 0 & r(mean) > 0 {
    display as text "[PASS] ASEC weight (asecwt) has non-missing, positive values"
}
else {
    display as error "[FAIL] ASEC weight has issues: N=" r(N) ", mean=" r(mean)
}

* --- 7f. Check health insurance variables (available in most years) ---
local ins_vars "phinsur himcaidly himcarely"
local ins_exist = 1
foreach v of local ins_vars {
    capture confirm variable `v'
    if _rc != 0 {
        local ins_exist = 0
    }
}
if `ins_exist' == 1 {
    display as text "[PASS] Health insurance variables present"
}
else {
    display as text "[INFO] Some health insurance variables not found — check codebook for year coverage"
}

* --- 7g. Quick summary ---
display as text _newline "--- Quick summary of key variables ---"
summarize year age inctot incwage asecwt

display as text _newline "============================================"
display as text "   VALIDATION COMPLETE"
display as text "============================================"
display as text _newline "Next step: run 02_clean_demographics.do"

********************************************************************************
* NOTES ON DATA FILES AND YEAR COVERAGE:
*
* Two pre-built extracts are available (see README):
*   cps_00012_2021_2025.dta  (~2.6 GB, 2021-2025 — quick start)
*   cps_00011_2005_2025.dta  (~14 GB, 2005-2025 — full analysis)
*
* You can also create your own IPUMS CPS extract at https://cps.ipums.org.
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
*
*   - Income top-coding: Has changed over time. IPUMS provides
*     EARNWEEK2_CPIU_2010 and similar inflation-adjusted versions.
*
* For 1988-2004 data, you may also want to account for:
*   - Sample redesign in 1994
*   - ASEC supplement changes in 2000
*   - Post-9/11 changes to immigration questions
********************************************************************************
