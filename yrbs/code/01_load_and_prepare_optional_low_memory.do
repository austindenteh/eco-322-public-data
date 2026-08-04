********************************************************************************
* 01_load_and_prepare_optional_low_memory.do
*
* Purpose: Optional low-memory alternative to 01_load_and_prepare.do.
*          Reads the 9 raw CDC SAS files one at a time, keeps only the columns
*          needed by 02_clean_and_analyze.do plus user-requested extras, filters
*          years/site types/state codes, and appends the reduced files into the
*          usual output/yrbs_combined.dta file.
*
* Important: This script targets the raw SAS files directly. It does not require
*            data/raw/sadc_2023_combined_all.dta to exist.
*
* Input:   data/raw/sadc_2023_*.sas7bdat
* Output:  output/yrbs_combined.dta
*
* Usage:   Run from yrbs/, yrbs/code/, from the repo root,
*          or set global yrbs_root first.
*
* Author:  Austin Denteh (legacy code), Claude Code, and Codex
* Date:    April 2026
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
* global yrbs_root "/path/to/yrbs"

local cwd `"`c(pwd)'"'
if "$yrbs_root" != "" & fileexists("$yrbs_root/code/01_load_and_prepare_optional_low_memory.do") {
    global yrbs_root "$yrbs_root"
}
else if fileexists("code/01_load_and_prepare_optional_low_memory.do") & fileexists("README.md") {
    global yrbs_root "`cwd'"
}
else if fileexists("01_load_and_prepare_optional_low_memory.do") & fileexists("../README.md") {
    global yrbs_root "`cwd'/.."
}
else if fileexists("yrbs/code/01_load_and_prepare_optional_low_memory.do") & fileexists("yrbs/README.md") {
    global yrbs_root "`cwd'/yrbs"
}
else {
    display as error "Could not locate the yrbs/ directory."
    display as error "Run from yrbs/, yrbs/code/, the repo root, or set global yrbs_root first."
    exit 198
}

cd "$yrbs_root"
display as text "Using YRBS root: $yrbs_root"

local raw_sas_dir "data/raw"
local out_dta     "output/yrbs_combined.dta"

* ============================================================================
* USER SETTINGS
* ============================================================================
* Recommended for most student projects. It keeps selected YRBS variables,
* years, site types, or state samples and avoids building/loading the full
* combined .dta file.

* Keep all available years by default. Example: local years_to_keep "2019 2021 2023"
local years_to_keep ""

* Keep State rows by default because the public-use National file does not
* include state identifiers. You may broaden this deliberately if your project
* needs another sample:
*   local site_types_to_keep "National"
*   local site_types_to_keep "State District"
*   local site_types_to_keep ""
local site_types_to_keep "State"

* Keep all site codes by default. Use this for state-level subsets, for example:
*   local states_to_keep "NC SC VA"
* State codes are applied after AZB -> AZ and NYA -> NY recoding.
local states_to_keep ""

* Add extra raw variables here if they exist in the SAS chunks.
* This script keeps extra variables but does not harmonize or recode them.
local extra_keep_vars ""

* ============================================================================
* 2. DEFINE SOURCE FILES AND KEEP LIST
* ============================================================================

local sas_files ///
    sadc_2023_national.sas7bdat ///
    sadc_2023_district.sas7bdat ///
    sadc_2023_state_a_d.sas7bdat ///
    sadc_2023_state_e_h.sas7bdat ///
    sadc_2023_state_i_l.sas7bdat ///
    sadc_2023_state_m.sas7bdat ///
    sadc_2023_state_n_p.sas7bdat ///
    sadc_2023_state_q_t.sas7bdat ///
    sadc_2023_state_u_z.sas7bdat

local core_keep_vars "year sitetype sitecode sitename weight sex age grade race4"
local core_keep_vars "`core_keep_vars' q14 q26 q27 q28 q29 q30 q33 q42 q48"
local core_keep_vars "`core_keep_vars' qn14 qn26 qn27 qn28"
local keep_vars "`core_keep_vars' `extra_keep_vars'"

foreach f of local sas_files {
    capture confirm file "`raw_sas_dir'/`f'"
    if _rc != 0 {
        display as error "Missing raw SAS file: `raw_sas_dir'/`f'"
        exit 601
    }
}

display as text _newline "============================================"
display as text "   LOW-MEMORY YRBS LOAD FROM RAW SAS FILES"
display as text "============================================"
display as text "Years: " cond(trim(`"`years_to_keep'"') == "", "all", `"`years_to_keep'"')
display as text "Site types: " cond(trim(`"`site_types_to_keep'"') == "", "all", `"`site_types_to_keep'"')
display as text "State/site codes: " cond(trim(`"`states_to_keep'"') == "", "all", `"`states_to_keep'"')

* ============================================================================
* 3. READ EACH RAW SAS CHUNK, FILTER, AND APPEND
* ============================================================================

tempfile combined
local have_data 0

foreach f of local sas_files {
    display as text _newline "Reading selected columns from `f'..."
    import sas `keep_vars' using "`raw_sas_dir'/`f'", clear
    rename *, lower

    replace sitecode = "AZ" if sitecode == "AZB"
    replace sitecode = "NY" if sitecode == "NYA"

    if trim(`"`years_to_keep'"') != "" {
        gen byte _keep_year = 0
        foreach y of local years_to_keep {
            replace _keep_year = 1 if year == `y'
        }
        keep if _keep_year == 1
        drop _keep_year
    }

    if trim(`"`site_types_to_keep'"') != "" {
        gen byte _keep_site_type = 0
        foreach s of local site_types_to_keep {
            replace _keep_site_type = 1 if lower(sitetype) == lower("`s'")
        }
        keep if _keep_site_type == 1
        drop _keep_site_type
    }

    if trim(`"`states_to_keep'"') != "" {
        gen byte _keep_state = 0
        foreach s of local states_to_keep {
            replace _keep_state = 1 if upper(sitecode) == upper("`s'")
        }
        keep if _keep_state == 1
        drop _keep_state
    }

    if _N == 0 {
        display as text "  Kept 0 rows after filters; skipping."
        continue
    }

    compress
    display as text "  Kept " _N " rows and " c(k) " columns."

    if `have_data' == 0 {
        save `combined', replace
        local have_data 1
    }
    else {
        append using `combined'
        save `combined', replace
    }
}

if `have_data' == 0 {
    display as error "No observations matched the requested filters."
    exit 2000
}

use `combined', clear
sort year sitetype sitecode
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

display as text _newline "--- Observations by year ---"
tab year

display as text _newline "--- Observations by site type ---"
tab sitetype

local all_exist = 1
local missing_vars ""
foreach v of local core_keep_vars {
    capture confirm variable `v'
    if _rc != 0 {
        local all_exist = 0
        local missing_vars "`missing_vars' `v'"
    }
}
if `all_exist' == 1 {
    display as text "[PASS] Core variables needed by 02_clean_and_analyze.do are present"
}
else {
    display as error "[FAIL] Missing variable(s):`missing_vars'"
}

quietly summarize weight
if r(N) > 0 & r(mean) > 0 {
    display as text "[PASS] Survey weight has non-missing, positive values"
}
else {
    display as error "[FAIL] Survey weight has issues: N=" r(N) ", mean=" r(mean)
}

display as text _newline "============================================"
display as text "   LOW-MEMORY LOAD COMPLETE"
display as text "============================================"
display as text _newline "Next step: run 02_clean_and_analyze.do"
