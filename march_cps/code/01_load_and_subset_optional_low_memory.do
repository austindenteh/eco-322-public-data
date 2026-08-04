********************************************************************************
* 01_load_and_subset_optional_low_memory.do
*
* Purpose: Optional low-memory loader for the CPS ASEC starter. Reads yearly
*          files one at a time and keeps only the variables needed by
*          02_clean_demographics.do, plus optional extras.
*
* Input:   data/raw/cps_*_YYYY.dta  (one file per ASEC survey year)
* Output:  output/cps_asec.dta
*
* Usage:   Run from march_cps/, march_cps/code/, from the repo root,
*          or set global cps_root to the march_cps/ directory.
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
* Then run: do "$cps_root/code/01_load_and_subset_optional_low_memory.do"

local cwd "`c(pwd)'"
if "$cps_root" != "" & fileexists("$cps_root/code/01_load_and_subset_optional_low_memory.do") {
    global cps_root "$cps_root"
}
else if fileexists("code/01_load_and_subset_optional_low_memory.do") & fileexists("README.md") {
    global cps_root "`cwd'"
}
else if fileexists("01_load_and_subset_optional_low_memory.do") & fileexists("../README.md") {
    global cps_root "`cwd'/.."
}
else if fileexists("march_cps/code/01_load_and_subset_optional_low_memory.do") & fileexists("march_cps/README.md") {
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
capture mkdir "output/_tmp_low_memory_stata"

local out_dta "output/cps_asec.dta"

* ============================================================================
* 2. USER SETTINGS
* ============================================================================

* Recommended for most student projects. Start with the compact default range,
* confirm the variables and cleaner, and then expand the years.
* Examples:
*   global cps_years_to_load "2025"
*   global cps_years_to_load "2019 2021 2023 2025"
*   local extra_keep_vars "diffhear diffeye"

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

* Replicate weights are useful for variance estimation but add many columns.
local keep_replicate_weights 0

* Add extra stable IPUMS variable names here, separated by spaces.
local extra_keep_vars ""

* Add cross-year raw variable families here when names differ by year.
* Each quoted entry is: merged_name:raw_alias1 raw_alias2 ...
* IMPORTANT: This only merges raw aliases into one column. If the coding or
* meaning of your added variable changes across years, harmonize that variable
* later in 02_clean_demographics.do / .R or in your analysis code.
*
* Example:
* local extra_var_families ///
*     "employer_plan:covergh grpdeply"
local extra_var_families

local overwrite_temp_files 1
local cleanup_temp_files 1

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
* 3. SELECT COLUMNS
* ============================================================================

local base_keep_vars ///
    "year serial pernum cpsidp cpsid cpsidv " ///
    "asecwt statefip " ///
    "age sex race hispan educ educ99 schlcoll " ///
    "marst empstat labforce fullpart wkswork1 " ///
    "inctot incwage incss incssi incwelfr incunemp incbus hhincome " ///
    "foodstmp " ///
    "phinsur himcaidly himcarely covergh anycovly anycovnw " ///
    "nativity citizen bpl yrimmig " ///
    "offpov offpovuniv offtotval offcutoff poverty cutoff"

local repwt_vars ""
if `keep_replicate_weights' {
    forvalues i = 1/160 {
        local repwt_vars "`repwt_vars' repwtp`i'"
    }
}

local requested_vars "`base_keep_vars' `repwt_vars' `extra_keep_vars'"
local extra_family_names ""
local n_extra_families 0

if trim(`"`extra_var_families'"') != "" {
    display as text "[INFO] extra_var_families only merge raw aliases into one column."
    display as text "[INFO] If coding or meanings change across years, harmonize the added variable later."
}

local family_name ""
local alias_vars ""

foreach token of local extra_var_families {
    if strpos("`token'", ":") {
        if trim(`"`family_name'"') != "" {
            local alias_vars : list retok alias_vars

            if trim(`"`alias_vars'"') == "" {
                display as error "extra_var_families entry `family_name' is missing its alias list."
                error 198
            }

            capture confirm name `family_name'
            if _rc != 0 {
                display as error "Merged family name is not a valid Stata variable name: `family_name'"
                error 198
            }

            local ++n_extra_families
            local extra_family_names "`extra_family_names' `family_name'"
            local extra_family_name`n_extra_families' "`family_name'"
            local extra_family_aliases`n_extra_families' "`alias_vars'"
            local family_years`n_extra_families' ""
            local requested_vars "`requested_vars' `alias_vars'"
        }

        gettoken family_name alias_vars : token, parse(":")
        local alias_vars : subinstr local alias_vars ":" "", all
    }
    else {
        local alias_vars "`alias_vars' `token'"
    }
}

if trim(`"`family_name'"') != "" {
    local alias_vars : list retok alias_vars

    if trim(`"`family_name'"') == "" {
        display as error "Each extra_var_families entry needs a merged variable name."
        error 198
    }
    if trim(`"`alias_vars'"') == "" {
        display as error "extra_var_families entry `family_name' is missing its alias list."
        error 198
    }

    capture confirm name `family_name'
    if _rc != 0 {
        display as error "Merged family name is not a valid Stata variable name: `family_name'"
        error 198
    }

    local ++n_extra_families
    local extra_family_names "`extra_family_names' `family_name'"
    local extra_family_name`n_extra_families' "`family_name'"
    local extra_family_aliases`n_extra_families' "`alias_vars'"
    local family_years`n_extra_families' ""
    local requested_vars "`requested_vars' `alias_vars'"
}

* ============================================================================
* 4. LOAD SELECTED COLUMNS YEAR BY YEAR
* ============================================================================

display as text _newline "============================================"
display as text "   LOW-MEMORY CPS ASEC LOAD"
display as text "============================================"

tempfile master
local first_file 1
local temp_files ""

foreach y of local years_to_load {
    quietly _find_cps_year_file, year(`y')
    local raw_dta "`r(file)'"
    local temp_file "output/_tmp_low_memory_stata/cps_`y'_selected.dta"
    local temp_files "`temp_files' `temp_file'"

    if `overwrite_temp_files' == 0 {
        capture confirm file "`temp_file'"
        if _rc == 0 {
            display as text "Reusing temp file for `y': `temp_file'"
            use "`temp_file'", clear
            if `first_file' {
                save `master', replace
                local first_file 0
            }
            else {
                append using `master'
                save `master', replace
            }
            continue
        }
    }

    display as text "Reading selected columns for `y': `raw_dta'"

    quietly describe using "`raw_dta'", varlist
    local available_vars "`r(varlist)'"
    local keep_vars ""
    local missing_selected ""

    foreach v of local requested_vars {
        if strpos(" `available_vars' ", " `v' ") {
            local keep_vars "`keep_vars' `v'"
        }
        else {
            local missing_selected "`missing_selected' `v'"
        }
    }

    if "`missing_selected'" != "" {
        display as text "Variables not found in `y' extract:"
        foreach v of local missing_selected {
            display as text "  - `v'"
        }
    }

    foreach v in year serial pernum {
        if !strpos(" `keep_vars' ", " `v' ") {
            display as error "Required variable missing from `raw_dta': `v'"
            error 111
        }
    }

    use `keep_vars' using "`raw_dta'", clear
    capture rename *, lower

    quietly count if year != `y' & !missing(year)
    if r(N) > 0 {
        display as error "`raw_dta' contains YEAR values other than `y'."
        tab year
        error 459
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
            local family_years`i' "`family_years`i'' `y'"

            capture confirm variable `family_name'
            local output_exists = (_rc == 0)
            local name_in_aliases : list family_name in present_aliases
            if `output_exists' & !`name_in_aliases' {
                display as error "Merged family name already exists in the data: `family_name'"
                display as error "Choose a different name in extra_var_families."
                error 110
            }

            local first_alias : word 1 of `present_aliases'
            capture confirm string variable `first_alias'
            local family_is_string = (_rc == 0)

            if !`output_exists' {
                if `family_is_string' {
                    gen strL `family_name' = ""
                }
                else {
                    gen `family_name' = .
                }
            }

            if `family_is_string' {
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

    gen double individ = year * 10000000 + serial * 100 + pernum
    format individ %18.0f
    label var individ "Unique record ID within saved extract (year, serial, pernum)"
    isid individ

    sort year serial pernum
    compress
    save "`temp_file'", replace

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

quietly summarize year
display as text "Year range: " r(min) " to " r(max)

if `cleanup_temp_files' {
    foreach f of local temp_files {
        capture erase "`f'"
    }
    capture rmdir "output/_tmp_low_memory_stata"
}

if trim(`"`extra_keep_vars'"') != "" {
    local missing_extra ""
    foreach v of local extra_keep_vars {
        capture confirm variable `v'
        if _rc != 0 {
            local missing_extra "`missing_extra' `v'"
        }
    }
    local missing_extra : list retok missing_extra

    if trim(`"`missing_extra'"') == "" {
        display as text "[PASS] All extra_keep_vars were found in the appended data"
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

display as text _newline "Next step: run 02_clean_demographics.do"
