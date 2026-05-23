********************************************************************************
* 01_load_and_subset_optional_low_memory.do
*
* Purpose: Optional low-memory alternative to 01_load_and_subset.do.
*          Imports only the raw columns needed by 02_clean_and_analyze.do plus
*          user-requested extras, optionally filters years and states, creates
*          identifiers, and saves the usual output/dec_cps_working.dta file.
*
* Important: This script is designed for the standard starter workflow.
*            It does NOT import every raw variable. If you need most of the
*            IPUMS CPS extract, use 01_load_and_subset.do instead.
*
* Input:   data/raw/ plus a pre-converted .dta file (if available)
*      OR  data/raw/cps_00014.dat      (raw IPUMS ASCII + .do layout)
* Output:  output/dec_cps_working.dta
*
* Usage:   Run from dec_cps_food_insecurity_supplement/, from code/,
*          from the repo root, or set global dec_cps_root first.
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
* Optional manual path override. Uncomment and edit if auto-detection fails:
* global dec_cps_root "/Users/yourname/path/to/econ-data-starters/dec_cps_food_insecurity_supplement"
* Then run: do "$dec_cps_root/code/01_load_and_subset_optional_low_memory.do"

local cwd `"`c(pwd)'"'
if "$dec_cps_root" != "" & fileexists("$dec_cps_root/code/01_load_and_subset_optional_low_memory.do") {
    global dec_cps_root "$dec_cps_root"
}
else if fileexists("code/01_load_and_subset_optional_low_memory.do") & fileexists("README.md") {
    global dec_cps_root "`cwd'"
}
else if fileexists("01_load_and_subset_optional_low_memory.do") & fileexists("../README.md") {
    global dec_cps_root "`cwd'/.."
}
else if fileexists("dec_cps_food_insecurity_supplement/code/01_load_and_subset_optional_low_memory.do") ///
    & fileexists("dec_cps_food_insecurity_supplement/README.md") {
    global dec_cps_root "`cwd'/dec_cps_food_insecurity_supplement"
}
else {
    display as error "Could not locate the dec_cps_food_insecurity_supplement/ directory."
    display as error "Run from the dataset folder, from code/, from the repo root,"
    display as error "or set global dec_cps_root first."
    display as error `"Manual override: global dec_cps_root "/path/to/dec_cps_food_insecurity_supplement""'
    exit 198
}

cd "$dec_cps_root"
display as text "Using December CPS root: $dec_cps_root"

local raw_dir "data/raw"
local out_dta "output/dec_cps_working.dta"

* ============================================================================
* USER SETTINGS
* ============================================================================
* This script is optional. Most users should keep using 01_load_and_subset.do.
* Use this version if the full December CPS extract strains your machine.
*
* What this script does:
*   1. Reads only selected raw columns from the IPUMS CPS extract
*   2. Optionally keeps selected survey years and/or state FIPS codes
*   3. Carries user-requested extra raw variables forward
*   4. Saves output/dec_cps_working.dta for 02_clean_and_analyze.do
*
* What this script does NOT do:
*   - It does not keep every raw IPUMS CPS variable
*   - It does not clean or harmonize variables itself
*   - It does not automatically harmonize extra user-added variables
*   - It only merges user-added alias families; it does not recode changing
*     meanings or value definitions across years

* Keep all available years by default. To keep selected years, use:
* local years_to_keep "2018 2020 2024"
local years_to_keep ""

* Keep all states by default. To keep selected states, use numeric FIPS codes:
* local states_to_keep "37 45 51"   // NC, SC, VA
local states_to_keep ""

* Add stable raw variable names here if you want extra columns carried forward.
* Example variables available in this Dec CPS extract:
* local extra_keep_vars "fsstmpvalc fstotxpnc"
local extra_keep_vars ""

* Add cross-year raw variable families here when names differ by year.
* Each quoted entry is: merged_name:raw_alias1 raw_alias2 ...
* IMPORTANT: This only merges raw aliases into one column. If the coding or
* meaning of your added variable changes across years, you must harmonize that
* variable later in 02_clean_and_analyze.do or in your analysis code.
*
* Example template after you verify the raw aliases have comparable coding:
* local extra_var_families ///
*     `" "merged_name:old_raw_name new_raw_name" "'
local extra_var_families

* ============================================================================
* 2. DEFINE CORE KEEP LIST
* ============================================================================

local required_loader_vars "year serial month pernum"

local core_keep_vars ///
    "year serial month cpsid region statefip faminc " ///
    "fshwtscale fsstatus fsrawscr fsstatusd fsstatusa fsstatusc " ///
    "fsrawscra fsrawscrc " ///
    "fsfdstmp fsstmpjan fsstmpfeb fsstmpmar fsstmpapr fsstmpmay " ///
    "fsstmpjun fsstmpjul fsstmpaug fsstmpsep fsstmpoct fsstmpnov fsstmpdec " ///
    "fslnchfrc fswic fsfdbnk fssoupk " ///
    "fssuppwth hhrespln pernum wtfinl relate age sex race marst " ///
    "nchild nativity hispan empstat educ99 lineno"

local extra_keep_vars = lower("`extra_keep_vars'")
local target_keep_vars "`core_keep_vars' `extra_keep_vars'"

local n_extra_families 0
if trim(`"`extra_var_families'"') != "" {
    display as text "[INFO] extra_var_families only merge raw aliases into one column."
    display as text "       If coding or meanings change across years, harmonize that"
    display as text "       added variable later in 02_clean_and_analyze.do or in"
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
    local extra_family_name`n_extra_families' "`family_name'"
    local extra_family_aliases`n_extra_families' "`alias_vars'"
    local target_keep_vars "`target_keep_vars' `alias_vars'"
}

local target_keep_vars : list uniq target_keep_vars

* ============================================================================
* 3. AUTO-DETECT AND LOAD SELECTED COLUMNS
* ============================================================================

display as text _newline "============================================"
display as text "   LOW-MEMORY DECEMBER CPS FSS LOAD"
display as text "============================================"

local load_method ""
local raw_dta ""

local dta_files : dir "`raw_dir'" files "*.dta"
if `"`dta_files'"' != "" {
    local first_dta : word 1 of `dta_files'
    local raw_dta "`raw_dir'/`first_dta'"
    local load_method "dta"
}
else if fileexists("`raw_dir'/cps_00014.dat") & fileexists("`raw_dir'/cps_00014.do") {
    local load_method "dat"
}

if "`load_method'" == "" {
    display as error "ERROR: No data file found in data/raw/"
    display as error "Option 1: Place a pre-converted .dta in data/raw/"
    display as error "Option 2: Place cps_00014.dat + cps_00014.do in data/raw/"
    display as error "See README.md for instructions."
    exit 601
}

if "`load_method'" == "dta" {
    display as text _newline "Loading selected columns from pre-converted .dta: `raw_dta'"

    use in 1/1 using "`raw_dta'", clear
    rename *, lower

    local keep_vars ""
    foreach v of local target_keep_vars {
        capture confirm variable `v'
        if _rc == 0 {
            local keep_vars "`keep_vars' `v'"
        }
    }
    local keep_vars : list uniq keep_vars

    if trim(`"`keep_vars'"') == "" {
        display as error "None of the requested variables were found in `raw_dta'."
        exit 198
    }

    use `keep_vars' using "`raw_dta'", clear
    rename *, lower
}
else if "`load_method'" == "dat" {
    display as text _newline "No .dta found. Loading selected columns from raw IPUMS ASCII..."
    display as text "Reading variable positions from data/raw/cps_00014.do..."

    local infix_spec ""
    local parsed_vars ""

    tempname layout
    file open `layout' using "`raw_dir'/cps_00014.do", read text
    file read `layout' line
    while r(eof) == 0 {
        if regexm(`"`line'"', "^[ ]*([A-Za-z0-9]+)[ ]+([A-Za-z_][A-Za-z0-9_]*)[ ]+([0-9]+)[-]([0-9]+)") {
            local storage_type = regexs(1)
            local current_var  = lower(regexs(2))
            local start_col    = regexs(3)
            local end_col      = regexs(4)

            local wanted 0
            foreach requested of local target_keep_vars {
                if "`current_var'" == "`requested'" {
                    local wanted 1
                }
            }

            if `wanted' {
                local infix_spec "`infix_spec' `storage_type' `current_var' `start_col'-`end_col'"
                local parsed_vars "`parsed_vars' `current_var'"
            }
        }
        file read `layout' line
    }
    file close `layout'

    local parsed_vars : list uniq parsed_vars
    if trim(`"`infix_spec'"') == "" {
        display as error "Could not find any requested variables in cps_00014.do."
        exit 198
    }

    foreach req of local required_loader_vars {
        local found_req 0
        foreach parsed of local parsed_vars {
            if "`parsed'" == "`req'" {
                local found_req 1
            }
        }
        if `found_req' == 0 {
            display as error "Required variable `req' was not found in cps_00014.do."
            exit 198
        }
    }

    quietly infix `infix_spec' using "`raw_dir'/cps_00014.dat", clear

    * Apply the same implied-decimal scaling used in the IPUMS .do file.
    foreach v in hwtfinl fshwtscale fssuppwth wtfinl earnwt wtvet compwt ///
        lnkfw1mwt lnkfw1ywt lnkfw8wt lnkfwmis45wt lnkfwmis14wt ///
        lnkfwmis58wt panlwt fssuppwt {
        capture confirm variable `v'
        if _rc == 0 {
            quietly replace `v' = `v' / 10000
        }
    }

    capture confirm variable fsrasch
    if _rc == 0 quietly replace fsrasch = fsrasch / 1000

    foreach v in fsrascha fsraschc fsraschm fsraschma fsraschmc {
        capture confirm variable `v'
        if _rc == 0 {
            quietly replace `v' = `v' / 100
        }
    }
}

* ============================================================================
* 4. FILTER YEARS AND STATES
* ============================================================================

if trim(`"`years_to_keep'"') != "" {
    gen byte __keep_year = 0
    foreach y of local years_to_keep {
        quietly replace __keep_year = 1 if year == `y'
    }
    keep if __keep_year
    drop __keep_year
}

if trim(`"`states_to_keep'"') != "" {
    capture confirm variable statefip
    if _rc != 0 {
        display as error "states_to_keep requires statefip, but statefip is not in the extract."
        exit 198
    }

    gen byte __keep_state = 0
    foreach s of local states_to_keep {
        quietly replace __keep_state = 1 if statefip == `s'
    }
    keep if __keep_state
    drop __keep_state
}

if _N == 0 {
    display as error "No observations remain after applying year/state filters."
    exit 2000
}

* Merge optional alias families after filtering.
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
        capture confirm variable `family_name'
        if _rc == 0 {
            local family_exists 1
        }
        else {
            local family_exists 0
        }

        local first_alias : word 1 of `present_aliases'
        if `family_exists' == 0 {
            clonevar `family_name' = `first_alias'
        }

        foreach alias of local present_aliases {
            if "`alias'" != "`family_name'" {
                quietly replace `family_name' = `alias' if missing(`family_name') & !missing(`alias')
            }
        }
    }
}

* ============================================================================
* 5. VALIDATE AND CREATE IDENTIFIERS
* ============================================================================

display as text _newline "Data loaded."
display as text "  Observations: " _N
display as text "  Variables:    " c(k)

display as text _newline "--- Verifying all records are December ---"
tab month
assert month == 12
display as text "[PASS] All records are December (month == 12)."

gen double hhid = year * 10000000 + serial
format hhid %15.0f
label var hhid "Unique household ID (year*10M + serial)"

gen double individ = hhid * 100 + pernum
format individ %20.0f
label var individ "Unique person ID (hhid*100 + pernum)"

isid year individ
display as text "[PASS] Unique person ID (individ) verified."

display as text _newline "--- Low-memory selection summary ---"
tab year
capture confirm variable statefip
if _rc == 0 {
    quietly levelsof statefip, local(states_retained)
    local n_states : word count `states_retained'
    display as text "States retained: `n_states'"
}
display as text "Variables retained: " c(k)

* ============================================================================
* 6. SAVE
* ============================================================================

capture mkdir "output"
compress
save "`out_dta'", replace

display as text _newline "============================================"
display as text "   LOW-MEMORY LOAD COMPLETE"
display as text "============================================"
display as text "Saved: `out_dta'"
display as text "Next step: run 02_clean_and_analyze.do"
