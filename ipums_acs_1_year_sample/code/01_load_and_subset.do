********************************************************************************
* 01_load_and_subset.do
*
* Purpose: Load yearly IPUMS ACS files, append them, create a unique record
*          identifier, validate, and save.
*
* Input:   data/raw/acs_YYYY.dta
*
* Output:  output/acs_working.dta
*
* Data:    American Community Survey (ACS) 1-year samples via IPUMS USA.
*          Annual cross-sectional survey of approx. 3.5 million individuals
*          per year. Covers demographics, education, employment, income,
*          health insurance, immigration, disability, and housing.
*
*          Source: IPUMS USA, University of Minnesota.
*          https://usa.ipums.org
*
* Usage:   Run from ipums_acs_1_year_sample/, ipums_acs_1_year_sample/code/,
*          or the repo root:
*            do code/01_load_and_subset.do
*          You can also set global acs_root first.
*
* Author:  Austin Denteh (adapted from Kuka et al. 2020 replication code)
* Date:    February 2026
********************************************************************************

clear all
set more off
set maxvar 10000

* ============================================================================
* 1. DEFINE PATHS
* ============================================================================
* Auto-detect the dataset root from the current working directory.
* You can also set global acs_root before running the script.
*
* Optional manual override if auto-detection fails:
* global acs_root "/path/to/ipums_acs_1_year_sample"

local cwd `"`c(pwd)'"'

if "$acs_root" != "" & fileexists("$acs_root/code/01_load_and_subset.do") {
    global acs_root "$acs_root"
}
else if fileexists("code/01_load_and_subset.do") & fileexists("README.md") {
    global acs_root "`cwd'"
}
else if fileexists("01_load_and_subset.do") & fileexists("../README.md") {
    global acs_root "`cwd'/.."
}
else if fileexists("ipums_acs_1_year_sample/code/01_load_and_subset.do") ///
    & fileexists("ipums_acs_1_year_sample/README.md") {
    global acs_root "`cwd'/ipums_acs_1_year_sample"
}
else {
    display as error "Could not locate the ipums_acs_1_year_sample/ directory."
    display as error "Run from the dataset folder, its code/ folder, the repo root,"
    display as error "or set global acs_root first."
    exit 198
}

cd "$acs_root"
display as text "Using ACS root: $acs_root"

local out_dta  "output/acs_working.dta"

* ============================================================================
* 2. USER SETTINGS
* ============================================================================
* This main script keeps all available columns from the selected yearly ACS
* files. If that is still too heavy for your machine, use
* 01_load_and_subset_optional_low_memory.do instead.

* Choose either a consecutive year range or an explicit year list.
* If years_to_load is not empty, it overrides first_year/last_year.
* Example:
* local years_to_load "2015 2016 2018 2024"
local years_to_load ""

* Consecutive-year option.
local first_year 2023
local last_year  2024

* If 1, remove the temporary yearly folder after a successful run.
local cleanup_temp_files 1

local raw_dir  "data/raw"
local temp_dir "output/_tmp_full_yearly_stata"

* ============================================================================
* 3. BUILD THE WORKING FILE FROM YEARLY ACS FILES
* ============================================================================
* The main script now expects yearly ACS files named data/raw/acs_YYYY.dta.

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

capture mkdir "output"
capture mkdir "`temp_dir'"
if _rc != 0 {
    local old_temp_files : dir "`temp_dir'" files "*.dta"
    foreach f of local old_temp_files {
        capture erase "`temp_dir'/`f'"
    }
    capture rmdir "`temp_dir'"
    capture mkdir "`temp_dir'"
    if _rc != 0 {
        display as error "Could not rebuild the temporary folder: `temp_dir'"
        exit 198
    }
}

display as text _newline "============================================"
display as text "   BUILDING ACS WORKING FILE FROM YEARLY FILES (`year_label')"
display as text "============================================"

local temp_files ""
foreach y of local years {
    local year_file "`raw_dir'/acs_`y'.dta"
    if !fileexists("`year_file'") {
        display as error "Required yearly ACS file not found: `year_file'"
        exit 601
    }

    display as text _newline "--- Year `y' ---"
    use "`year_file'", clear
    rename *, lower

    capture confirm variable year
    if _rc != 0 {
        display as error "Yearly file is missing year: `year_file'"
        exit 198
    }
    capture confirm variable sample
    if _rc != 0 {
        display as error "Yearly file is missing sample: `year_file'"
        exit 198
    }

    capture assert year == `y' if year != .
    if _rc != 0 {
        display as error "Year check failed for `year_file' -- expected all rows to have year = `y'"
        exit 459
    }

    compress
    local temp_file "acs_`y'_full.dta"
    save "`temp_dir'/`temp_file'", replace
    local temp_files "`temp_files' `temp_file'"

    display as text "  Imported `y': " _N " observations, " c(k) " variables"
}

local temp_files : list retok temp_files
if trim(`"`temp_files'"') == "" {
    display as error "No ACS years were loaded. Check your yearly files and year settings."
    exit 198
}

local is_first 1
foreach f of local temp_files {
    if `is_first' {
        use "`temp_dir'/`f'", clear
        local is_first 0
    }
    else {
        append using "`temp_dir'/`f'"
    }
}

display as text _newline "No non-ACS-1-year observations found -- yearly files are already restricted."
display as text "Remaining observations: " _N

* ============================================================================
* 4. CREATE UNIQUE PERSON IDENTIFIER
* ============================================================================
* Create a unique record ID for each person record in the saved extract.

gen double individ = sample * 10000000000 + serial * 100 + pernum
format individ %18.0f

* Verify uniqueness in the saved extract
isid individ
display as text _newline "Unique record ID verified."

* ============================================================================
* 5. BASIC VALIDATION
* ============================================================================

display as text _newline "============================================"
display as text "   VALIDATION CHECKS"
display as text "============================================"

* --- 5a. Year range ---
summarize year
display as text "Year range: " r(min) " to " r(max)
if r(min) >= 2006 {
    display as text "  [OK] All years are ACS (2006+)."
}
else {
    display as error "  [WARN] Found years before 2006 — check data."
}

* --- 5b. Key variables exist ---
* These are common IPUMS variables used by the starter cleaning script.
display as text _newline "Checking key variables:"
local n_found = 0
local n_missing = 0
foreach v in year sample serial pernum perwt statefip age sex race hispan ///
              educ educd empstat hcovany poverty citizen bpl incwage {
    capture confirm variable `v'
    if _rc != 0 {
        display as text "  `v': not in extract"
        local n_missing = `n_missing' + 1
    }
    else {
        display as text "  `v': found [OK]"
        local n_found = `n_found' + 1
    }
}
display as text _newline "  Found `n_found' of 18 key variables."
if `n_missing' > 0 {
    display as text "  `n_missing' variable(s) not in this extract."
    display as text "  The 02_clean_demographics.do script will skip sections whose source variables are missing."
}

* --- 5c. Sample sizes by year ---
display as text _newline "--- Observations per year ---"
tab year

* --- 5d. Weight summary ---
capture confirm variable perwt
if _rc == 0 {
    display as text _newline "--- Person weight (perwt) summary ---"
    summarize perwt, detail
}
else {
    display as text _newline "[INFO] perwt not found — weight summary skipped."
}

* ============================================================================
* 6. SAVE WORKING COPY
* ============================================================================

compress
save "`out_dta'", replace

if `cleanup_temp_files' {
    local temp_cleanup_files : dir "`temp_dir'" files "*.dta"
    foreach f of local temp_cleanup_files {
        capture erase "`temp_dir'/`f'"
    }
    capture rmdir "`temp_dir'"
}

display as text _newline "============================================"
display as text "   LOAD AND SUBSET COMPLETE"
display as text "============================================"
display as text "Saved: `out_dta'"
display as text "  Observations: " _N
display as text "  Variables:    " c(k)
display as text _newline "Next step: run 02_clean_demographics.do"

********************************************************************************
* NOTES:
*
* 1. YEARLY ACS FILES:
*    The main script now expects yearly files named acs_YYYY.dta.
*    It keeps all available columns from the selected years.
*    If you only need the starter columns, use the optional low-memory
*    script instead.
*
* 2. YEAR SELECTION:
*    Use first_year / last_year for consecutive years or years_to_load
*    for an explicit year list.
*
* 3. CUSTOM IPUMS EXTRACTS:
*    Go to https://usa.ipums.org/usa/ to create yearly ACS extracts.
*    Select ACS 1-year samples for the desired years and download one
*    yearly file per sample as Stata (.dta) format.
*    The 02_clean_demographics.do script skips sections whose source
*    variables are not in your extract.
*
* 4. SURVEY DESIGN:
*    The ACS is a complex survey with stratification and clustering.
*    - Person weight: perwt (for person-level estimates)
*    - Household weight: hhwt (for household-level estimates)
*    - Replicate weights: repwtp1-repwtp80 (for standard errors)
*    - Strata: strata (for svyset)
*    - Cluster: cluster (for svyset)
*    To set up survey design in Stata:
*      svyset cluster [pw=perwt], strata(strata)
*
* 5. IDENTIFIERS:
*    individ is a unique record ID within the saved extract.
*    It is not a longitudinal person ID across time.
*
* 6. COVID-19 NOTE (2020):
*    The 2020 ACS had disrupted data collection due to COVID-19.
*    The Census Bureau released experimental weights for 2020 data.
*    See docs/ for guidance on using 2020 data.
********************************************************************************
