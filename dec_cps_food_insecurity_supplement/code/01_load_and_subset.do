********************************************************************************
* 01_load_and_subset.do
*
* Purpose: Load the IPUMS CPS December Food Security Supplement extract,
*          validate, create identifiers, and save a working dataset.
*          Auto-detects whether a pre-converted .dta file or raw .dat
*          file is available in data/raw/.
*
* Input:   data/raw/ plus a pre-converted .dta file (if available)
*      OR  data/raw/cps_00014.dat      (raw IPUMS ASCII + .do loader)
* Output:  output/dec_cps_working.dta
*
* Data:    Current Population Survey, Food Security Supplement (CPS-FSS).
*          Conducted each December. Person-level records with household
*          food security status, SNAP participation, food spending, and
*          food assistance programs. ~100,000-200,000 persons per year.
*
*          Extracted from IPUMS CPS (https://cps.ipums.org).
*
* Usage:   Run from dec_cps_food_insecurity_supplement/, from code/,
*          from the repo root, or set global dec_cps_root first.
*
* Author:  Austin Denteh (legacy code and Claude Code)
* Date:    March 2026
********************************************************************************

clear all
set more off
set maxvar 10000

* ============================================================================
* 1. DEFINE PATHS
* ============================================================================
* Auto-detect the dataset root from the current working directory.
*
* Optional manual override if auto-detection fails:
* global dec_cps_root "/path/to/dec_cps_food_insecurity_supplement"

local cwd `"`c(pwd)'"'
if "$dec_cps_root" != "" & fileexists("$dec_cps_root/code/01_load_and_subset.do") {
    global dec_cps_root "$dec_cps_root"
}
else if fileexists("code/01_load_and_subset.do") & fileexists("README.md") {
    global dec_cps_root "`cwd'"
}
else if fileexists("01_load_and_subset.do") & fileexists("../README.md") {
    global dec_cps_root "`cwd'/.."
}
else if fileexists("dec_cps_food_insecurity_supplement/code/01_load_and_subset.do") & fileexists("dec_cps_food_insecurity_supplement/README.md") {
    global dec_cps_root "`cwd'/dec_cps_food_insecurity_supplement"
}
else {
    display as error "Could not locate the dec_cps_food_insecurity_supplement/ directory."
    display as error "Run from the dataset folder, from code/, from the repo root, or set global dec_cps_root first."
    exit 198
}

cd "$dec_cps_root"
display as text "Using December CPS root: $dec_cps_root"

local out_dta "output/dec_cps_working.dta"

* ============================================================================
* 2. AUTO-DETECT AND LOAD DATA
* ============================================================================
* The script checks for data files in data/raw/ in this order:
*   1. Pre-converted .dta file (fastest — downloaded from Dropbox)
*   2. Raw IPUMS .dat file + .do loader (requires running IPUMS infix script)
*
* If you have multiple .dta files, it uses the first one found alphabetically.
* Override by setting local raw_dta before this block:
*   local raw_dta "data/raw/my_file.dta"

display as text _newline "============================================"
display as text "   LOADING DECEMBER CPS FSS DATA"
display as text "============================================"

local raw_dta ""
local load_method ""

* --- Check for .dta files first ---
local dta_files : dir "data/raw" files "*.dta"
if `"`dta_files'"' != "" {
    local first_dta : word 1 of `dta_files'
    local raw_dta "data/raw/`first_dta'"
    local load_method "dta"
}

* --- Fall back to .dat + .do ---
if "`raw_dta'" == "" {
    capture confirm file "data/raw/cps_00014.dat"
    local has_dat = (_rc == 0)
    capture confirm file "data/raw/cps_00014.do"
    local has_do = (_rc == 0)

    if `has_dat' & `has_do' {
        local load_method "dat"
    }
}

* --- Error if nothing found ---
if "`load_method'" == "" {
    display as error "ERROR: No data file found in data/raw/"
    display as error ""
    display as error "Option 1: Download a pre-converted .dta from Dropbox"
    display as error "Option 2: Place cps_00014.dat + cps_00014.do in data/raw/"
    display as error "See README.md for instructions."
    error 601
}

* --- Load the data ---
if "`load_method'" == "dta" {
    display as text _newline "Loading pre-converted .dta: `raw_dta'"
    display as text "This may take a few minutes for large files..."
    use "`raw_dta'", clear
}
else if "`load_method'" == "dat" {
    display as text _newline "No .dta found. Loading from raw IPUMS ASCII..."
    display as text "Running data/raw/cps_00014.do to read cps_00014.dat..."
    display as text "This may take several minutes..."
    cd "data/raw"
    do cps_00014.do
    cd "$dec_cps_root"
}

display as text _newline "Data loaded."
display as text "  Observations: " _N
display as text "  Variables:    " c(k)

* ============================================================================
* 3. LOWERCASE VARIABLE NAMES
* ============================================================================
* IPUMS variables may be uppercase. Lowercase for consistency.

rename *, lower
display as text _newline "Variable names lowercased."

* ============================================================================
* 4. VERIFY DECEMBER ONLY
* ============================================================================
* All records should be from December (month == 12).

display as text _newline "--- Verifying all records are December ---"
tab month
assert month == 12
display as text "[PASS] All records are December (month == 12)."

* ============================================================================
* 5. CREATE UNIQUE IDENTIFIERS
* ============================================================================
* IPUMS CPS identifies individuals by year + serial (household) + pernum
* (person within household). Create unique IDs.

gen double hhid = year * 10000000 + serial
format hhid %15.0f
label var hhid "Unique household ID (year*10M + serial)"

gen double individ = hhid * 100 + pernum
format individ %20.0f
label var individ "Unique person ID (hhid*100 + pernum)"

* Verify uniqueness
isid year individ
display as text _newline "[PASS] Unique person ID (individ) verified."

* ============================================================================
* 6. VALIDATION CHECKS
* ============================================================================

display as text _newline "============================================"
display as text "   VALIDATION CHECKS"
display as text "============================================"

* --- 6a. Year range ---
summarize year
local yr_min = r(min)
local yr_max = r(max)
display as text _newline "Year range: `yr_min' to `yr_max'"
if `yr_min' >= 2001 & `yr_max' <= 2025 {
    display as text "  [PASS] Year range is within expected bounds (2001-2025)."
}
else {
    display as text "  [INFO] Year range differs from expected 2001-2025."
}

* --- 6b. Observations per year ---
display as text _newline "--- Observations per year ---"
tab year

* --- 6c. Key variables exist ---
display as text _newline "Checking key variables:"
local n_found = 0
local n_missing = 0
foreach v in year serial pernum fssuppwth fshwtscale wtfinl ///
             fsstatus fsstatusd fsrawscr fsfdstmp ///
             age sex race hispan empstat educ99 {
    capture confirm variable `v'
    if _rc == 0 {
        display as text "  `v': found [OK]"
        local n_found = `n_found' + 1
    }
    else {
        display as text "  `v': not in extract"
        local n_missing = `n_missing' + 1
    }
}
display as text _newline "  Found `n_found' of 16 key variables."
if `n_missing' > 0 {
    display as text "  `n_missing' variable(s) not in this extract."
    display as text "  Some sections in 02_clean_and_analyze.do may be skipped."
}

* --- 6d. Food security scale weight ---
capture confirm variable fshwtscale
if _rc == 0 {
    display as text _newline "--- Food security scale weight (fshwtscale) ---"
    summarize fshwtscale, detail
    count if fshwtscale > 0 & fshwtscale != .
    display as text "  Non-missing, positive: " r(N)
}

* --- 6e. Food security status ---
capture confirm variable fsstatusd
if _rc == 0 {
    display as text _newline "--- Food security status (detailed) ---"
    tab fsstatusd
}

* ============================================================================
* 7. COMPRESS AND SAVE
* ============================================================================

compress
save "`out_dta'", replace

display as text _newline "============================================"
display as text "   LOAD AND SUBSET COMPLETE"
display as text "============================================"
display as text "Saved: `out_dta'"
display as text "  Observations: " _N
display as text "  Variables:    " c(k)
display as text _newline "Next step: run 02_clean_and_analyze.do"

********************************************************************************
* NOTES:
*
* 1. DATA LOADING:
*    The IPUMS extract (cps_00014) is a fixed-format ASCII file (.dat).
*    The accompanying .do file reads the .dat using Stata's -infix- command
*    and applies value labels. If a pre-converted .dta file is available
*    (from Dropbox), the script loads that instead for faster startup.
*
* 2. WEIGHTS:
*    - fshwtscale: Use for food security status/score analyses
*    - fssuppwth:  Use for other FSS variables (SNAP, food spending)
*    - wtfinl:     Use for basic CPS demographic variables
*    - earnwt:     Use for earnings-related variables
*
* 3. DECEMBER ONLY:
*    All records are from the December CPS. The Food Security Supplement
*    is administered only in December.
*
* 4. HOUSEHOLD VS. PERSON:
*    Food security is measured at the household level. All persons in a
*    household share the same food security status. Consider restricting
*    to one person per household (e.g., relate == 101 for reference person)
*    when analyzing food security outcomes.
*
* 5. CREATING YOUR OWN EXTRACT:
*    Go to https://cps.ipums.org to create a custom December CPS extract.
*    Select "December" samples for desired years.
*    Download the .dat + .do files and place in data/raw/.
********************************************************************************
