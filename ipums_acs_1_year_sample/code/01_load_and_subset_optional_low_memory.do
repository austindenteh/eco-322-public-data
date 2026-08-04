********************************************************************************
* 01_load_and_subset_optional_low_memory.do
*
* Purpose: Optional low-memory alternative to 01_load_and_subset.do.
*          Imports one yearly ACS file at a time, keeps only the raw columns
*          needed by 02_clean_demographics.do plus any user-requested extras,
*          saves temporary yearly files, and then appends them into the usual
*          output/acs_working.dta file.
*
* Important: This script is designed for the standard starter workflow.
*            It does NOT keep the full ACS raw files in memory. If you need
*            many extra raw variables beyond the starter workflow, use
*            01_load_and_subset.do instead.
*
* Input:   data/raw/acs_YYYY.dta
* Output:  output/acs_working.dta
*          temporary yearly .dta files under output/_tmp_low_memory_stata/
*
* Usage:   Run from ipums_acs_1_year_sample/, ipums_acs_1_year_sample/code/,
*          from the repo root, or set global acs_root first.
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
* global acs_root "/path/to/ipums_acs_1_year_sample"

local cwd `"`c(pwd)'"'
if "$acs_root" != "" & fileexists("$acs_root/code/01_load_and_subset_optional_low_memory.do") {
    global acs_root "$acs_root"
}
else if fileexists("code/01_load_and_subset_optional_low_memory.do") & fileexists("README.md") {
    global acs_root "`cwd'"
}
else if fileexists("01_load_and_subset_optional_low_memory.do") & fileexists("../README.md") {
    global acs_root "`cwd'/.."
}
else if fileexists("ipums_acs_1_year_sample/code/01_load_and_subset_optional_low_memory.do") ///
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

local raw_dir  "data/raw"
local out_dta  "output/acs_working.dta"
local temp_dir "output/_tmp_low_memory_stata"

* ============================================================================
* USER SETTINGS
* ============================================================================
* Recommended for most student projects. Use 01_load_and_subset.do only when
* the project needs a broad raw-variable surface beyond the starter and extras.
*
* What this script does:
*   1. Imports one yearly ACS file at a time
*   2. Keeps only the raw columns needed by 02_clean_demographics.do
*   3. Saves a temporary yearly .dta file
*   4. Appends those yearly files into output/acs_working.dta
*
* What this script does NOT do:
*   - It does not keep the full ACS raw files in memory
*   - It does not clean or harmonize variables itself
*   - It does not automatically harmonize extra user-added variables
*   - It only merges user-added alias families; it does not recode changing
*     meanings or value definitions across years
*
* Important:
*   - This script expects yearly files named data/raw/acs_YYYY.dta
*   - It reduces memory pressure during import, but the final combined ACS
*     working file must still fit once appended

* Choose either a consecutive year range or an explicit year list.
* If years_to_load is not empty, it overrides first_year/last_year.
* Example:
* local years_to_load "2015 2016 2018 2024"
local years_to_load ""

* Consecutive-year option.
local first_year 2023
local last_year  2024

* If 1, delete and rebuild the temporary low-memory folder each time.
local overwrite_temp_files 1

* If 1, remove output/_tmp_low_memory_stata/ after a successful run.
local cleanup_temp_files 1

* Add stable raw variable names here if you want extra columns carried forward.
* Example:
* local extra_keep_vars "ageimmig english"
local extra_keep_vars ""

* Add cross-year raw variable families here when names differ by year.
* Each quoted entry is: merged_name:raw_alias1 raw_alias2 ...
* IMPORTANT: This only merges raw aliases into one column. If the coding or
* meaning of your added variable changes across years, you must harmonize that
* variable later in 02_clean_demographics.do or in your analysis code.
*
* Example:
* local extra_var_families ///
*     `" "language_primary:language languaged" "'
local extra_var_families

* ============================================================================
* 2. PREP TEMP DIRECTORY
* ============================================================================

capture mkdir "output"
capture mkdir "`temp_dir'"
if _rc != 0 {
    if `overwrite_temp_files' {
        capture local old_temp_files : dir "`temp_dir'" files "*.dta"
        if _rc == 0 {
            foreach f of local old_temp_files {
                capture erase "`temp_dir'/`f'"
            }
        }
        capture rmdir "`temp_dir'"
        capture mkdir "`temp_dir'"
        if _rc != 0 {
            display as error "Could not rebuild the temporary folder: `temp_dir'"
            exit 198
        }
    }
    else {
        display as error "Temporary folder already exists: `temp_dir'"
        display as error "Set overwrite_temp_files = 1 or remove the folder first."
        exit 198
    }
}

* ============================================================================
* 3. DEFINE CORE KEEP LIST
* ============================================================================

local required_loader_vars "year sample serial pernum"

local core_keep_vars ///
    "year sample serial pernum perwt hhwt " ///
    "cluster strata statefip countyfip puma gq " ///
    "age sex race hispan marst " ///
    "educ educd " ///
    "empstat incwage poverty " ///
    "hcovany hcovpriv hcovpub hinscaid hinscare " ///
    "citizen bpl"

local target_keep_vars "`core_keep_vars' `extra_keep_vars'"
local extra_family_names ""
local n_extra_families 0

if trim(`"`extra_var_families'"') != "" {
    display as text "[INFO] extra_var_families only merge raw aliases into one column."
    display as text "       If coding or meanings change across years, harmonize that"
    display as text "       added variable later in 02_clean_demographics.do or in"
    display as text "       your analysis code."
}

foreach family_def of local extra_var_families {
    gettoken family_name alias_vars : family_def, parse(":")
    local alias_vars : subinstr local alias_vars ":" "", all
    local alias_vars : list retok alias_vars

    if trim(`"`family_name'"') == "" {
        display as error "Each extra_var_families entry needs a merged variable name."
        exit 198
    }
    if trim(`"`alias_vars'"') == "" {
        display as error "extra_var_families entry `family_name' is missing its alias list."
        exit 198
    }

    capture confirm name `family_name'
    if _rc != 0 {
        display as error "Merged family name is not a valid Stata variable name: `family_name'"
        exit 198
    }

    local ++n_extra_families
    local extra_family_names "`extra_family_names' `family_name'"
    local extra_family_name`n_extra_families' "`family_name'"
    local extra_family_aliases`n_extra_families' "`alias_vars'"
    local family_years`n_extra_families' ""
    local target_keep_vars "`target_keep_vars' `alias_vars'"
}

local target_keep_vars : list uniq target_keep_vars

* ============================================================================
* 4. DEFINE YEAR LIST
* ============================================================================

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
* 5. LOAD EACH YEAR, KEEP SELECTED COLUMNS, SAVE TEMP FILES
* ============================================================================

display as text _newline "============================================"
display as text "   LOW-MEMORY ACS LOAD (`year_label')"
display as text "============================================"

local temp_files ""
local loaded_columns_any_year ""

foreach y of local years {

    local dta_file "`raw_dir'/acs_`y'.dta"
    if !fileexists("`dta_file'") {
        display as error "Required yearly ACS file not found: `dta_file'"
        exit 601
    }

    display as text _newline "--- Year `y' ---"

    * Load one observation to inspect which variables are present.
    use in 1/1 using "`dta_file'", clear
    rename *, lower

    foreach req of local required_loader_vars {
        capture confirm variable `req'
        if _rc != 0 {
            display as error "Yearly file is missing required variable `req': `dta_file'"
            exit 198
        }
    }

    local keep_vars ""
    foreach v of local target_keep_vars {
        capture confirm variable `v'
        if _rc == 0 {
            local keep_vars "`keep_vars' `v'"
        }
    }
    local keep_vars : list uniq keep_vars

    if trim(`"`keep_vars'"') == "" {
        display as error "No requested columns were found in `dta_file'"
        exit 198
    }

    * Re-load the full year using only the selected columns.
    use `keep_vars' using "`dta_file'", clear
    rename *, lower

    capture assert year == `y' if year != .
    if _rc != 0 {
        display as error "Year check failed for `dta_file' -- expected all rows to have year = `y'"
        exit 459
    }

    local expected_sample = `y' * 100 + 1
    capture assert sample == `expected_sample' if sample != .
    if _rc != 0 {
        display as error "Sample check failed for `dta_file' -- expected all rows to have sample = `expected_sample'"
        exit 459
    }

    gen double individ = sample * 10000000000 + serial * 100 + pernum
    format individ %18.0f
    isid individ

    ds
    local current_vars `r(varlist)'
    local loaded_columns_any_year : list loaded_columns_any_year | current_vars

    forvalues i = 1/`n_extra_families' {
        local family_name `"`extra_family_name`i''"'
        local alias_vars `"`extra_family_aliases`i''"'
        local matched_this_year 0
        foreach alias of local alias_vars {
            capture confirm variable `alias'
            if _rc == 0 {
                local matched_this_year 1
            }
        }
        if `matched_this_year' {
            local family_years`i' "`family_years`i'' `y'"
        }
    }

    compress
    local temp_file "acs_`y'_selected.dta"
    save "`temp_dir'/`temp_file'", replace
    local temp_files "`temp_files' `temp_file'"

    display as text "  Imported `y': " _N " observations, " c(k) " selected variables"
}

local temp_files : list retok temp_files
if trim(`"`temp_files'"') == "" {
    display as error "No ACS years were loaded. Check your raw files and year settings."
    exit 198
}

* ============================================================================
* 6. APPEND TEMP FILES
* ============================================================================

display as text _newline "Appending selected yearly files..."

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

forvalues i = 1/`n_extra_families' {
    local family_name `"`extra_family_name`i''"'
    local alias_vars `"`extra_family_aliases`i''"'
    local present_aliases ""

    foreach alias of local alias_vars {
        capture confirm variable `alias'
        if _rc == 0 {
            local present_aliases "`present_aliases' `alias'"
        }
    }
    local present_aliases : list retok present_aliases

    if trim(`"`present_aliases'"') != "" {
        local output_exists 0
        capture confirm variable `family_name'
        if _rc == 0 {
            local output_exists 1
        }

        local name_in_aliases : list family_name in present_aliases
        if `output_exists' & !`name_in_aliases' {
            display as error "Merged family name already exists in the data: `family_name'"
            display as error "Choose a different name in extra_var_families."
            exit 198
        }

        local first_alias : word 1 of `present_aliases'
        capture confirm string variable `first_alias'
        local first_is_string = (_rc == 0)

        if !`output_exists' {
            if `first_is_string' {
                gen strL `family_name' = ""
            }
            else {
                gen `family_name' = .
            }
        }

        if `first_is_string' {
            foreach alias of local present_aliases {
                if !(`output_exists' & "`alias'" == "`family_name'") {
                    replace `family_name' = `alias' if `family_name' == "" & !missing(`alias')
                }
            }
        }
        else {
            foreach alias of local present_aliases {
                if !(`output_exists' & "`alias'" == "`family_name'") {
                    replace `family_name' = `alias' if missing(`family_name') & !missing(`alias')
                }
            }
        }
    }
}

sort year serial pernum
compress

display as text "Total observations: " _N
display as text "Total selected variables: " c(k)

* ============================================================================
* 7. SAVE OUTPUT
* ============================================================================

display as text _newline "============================================"
display as text "   SAVING LOW-MEMORY WORKING DATASET"
display as text "============================================"

save "`out_dta'", replace
display as text "Saved: `out_dta'"

* ============================================================================
* 8. VALIDATION AND USER FEEDBACK
* ============================================================================

display as text _newline "============================================"
display as text "   VALIDATION CHECKS"
display as text "============================================"

display as text _newline "[INFO] Observations per year:"
tab year

levelsof year, local(loaded_years)
local loaded_years : list retok loaded_years
if trim(`"`loaded_years'"') == trim(`"`years'"') {
    display as text "[PASS] Loaded years match request: `loaded_years'"
}
else {
    display as error "[FAIL] Expected years `years' but found `loaded_years'"
}

local core_family_names "identifiers survey_design geography demographics education economics insurance immigration"
local core_family_identifiers "year sample serial pernum individ"
local core_family_survey_design "perwt hhwt cluster strata"
local core_family_geography "statefip countyfip puma"
local core_family_demographics "age sex race hispan marst"
local core_family_education "educ educd"
local core_family_economics "empstat incwage poverty"
local core_family_insurance "hcovany hcovpriv hcovpub hinscaid hinscare"
local core_family_immigration "citizen bpl"

foreach family_name of local core_family_names {
    local family_vars `"`core_family_`family_name''"'
    local found_family 0
    foreach v of local family_vars {
        local present : list v in loaded_columns_any_year
        if `present' {
            local found_family 1
        }
    }

    if `found_family' {
        display as text "[PASS] Found a supported `family_name' variable family"
    }
    else {
        display as error "[FAIL] Missing the `family_name' variable family"
    }
}

if trim(`"`extra_keep_vars'"') != "" {
    local missing_extra ""
    foreach v of local extra_keep_vars {
        local present : list v in loaded_columns_any_year
        if !`present' {
            local missing_extra "`missing_extra' `v'"
        }
    }
    local missing_extra : list retok missing_extra

    if trim(`"`missing_extra'"') == "" {
        display as text "[PASS] All extra_keep_vars were found in at least one loaded year"
    }
    else {
        display as text "[WARN] Some extra_keep_vars were never found: `missing_extra'"
    }
}

if trim(`"`extra_var_families'"') != "" {
    local missing_families ""
    forvalues i = 1/`n_extra_families' {
        local family_name `"`extra_family_name`i''"'
        local matched_years `"`family_years`i''"'
        local matched_years : list uniq matched_years
        local matched_years : list retok matched_years

        if trim(`"`matched_years'"') != "" {
            display as text "[INFO] extra_var_family '`family_name'' matched in year(s): `matched_years'"
        }
        else {
            local missing_families "`missing_families' `family_name'"
        }
    }
    local missing_families : list retok missing_families

    if trim(`"`missing_families'"') == "" {
        display as text "[PASS] All extra_var_families matched at least one loaded year"
    }
    else {
        display as text "[WARN] Some extra_var_families never matched: `missing_families'"
    }
}

* ============================================================================
* 9. CLEAN UP TEMP FILES (OPTIONAL)
* ============================================================================

if `cleanup_temp_files' {
    local temp_cleanup_files : dir "`temp_dir'" files "*.dta"
    foreach f of local temp_cleanup_files {
        capture erase "`temp_dir'/`f'"
    }
    capture rmdir "`temp_dir'"
    display as text _newline "Removed temporary folder: `temp_dir'"
}
else {
    display as text _newline "Temporary files kept in: `temp_dir'"
}

display as text _newline "============================================"
display as text "   LOW-MEMORY LOAD COMPLETE"
display as text "============================================"
display as text "  Observations: " _N
display as text "  Variables:    " c(k)
display as text _newline "Next step: run 02_clean_demographics.do"
