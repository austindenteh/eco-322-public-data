********************************************************************************
* 01_load_pre2011_optional_low_memory.do
*
* Purpose: Optional low-memory BRFSS pre-2011 loader for 2000-2010.
*          Imports one year at a time, keeps only starter variables plus
*          user-requested extras, and appends selected years into the canonical
*          pre-2011 Stata output.
*
* Input:   data/raw/CDBRFSYYXPT.zip or data/raw/CDBRFSYY.XPT
*          Default years: 2009-2010
* Output:  output/brfss_pre2011_appended.dta
*
* Note:    Stata imports each full XPT year before dropping unused variables.
*          This still reduces the appended output size and downstream cleaner
*          memory use, but the import step itself needs enough RAM for one year.
********************************************************************************

clear all
set more off
set varabbrev off

* ============================================================================
* USER SETTINGS
* ============================================================================
* Recommended for most student projects. Use the full pre-2011 loader only
* when the project needs a broad raw-variable surface beyond the starter and
* extras.
*
* Optional manual root override:
* global brfss_root "/path/to/econ-data-starters/brfss"

* Optional output directory override for smoke tests or scratch builds:
* global brfss_pre2011_output_dir "/private/tmp/brfss_pre2011_output"

* Choose either a consecutive year range or an explicit year list.
* If years_to_load is not empty, it overrides first_year/last_year.
* Example:
* local years_to_load "2000 2004 2010"
local years_to_load ""
local first_year 2009
local last_year  2010

* Optional non-editing override:
* global brfss_pre2011_years "2000 2004 2010"
if "$brfss_pre2011_years" != "" {
    local years_to_load "$brfss_pre2011_years"
}

* Add stable raw variable names here if you want extra columns carried forward.
* Example:
* local extra_keep_vars "flushot3 cholchk"
local extra_keep_vars ""
if "$brfss_pre2011_extra_keep_vars" != "" {
    local extra_keep_vars "$brfss_pre2011_extra_keep_vars"
}

* Add cross-year raw variable families here when names differ by year.
* The name before ":" becomes the merged output variable.
* Example:
* local extra_var_families `" "flu_shot:flushot2 flushot3 flushot4" "checkup_raw_user:checkup checkup1" "'
local extra_var_families ""
if "$brfss_pre2011_extra_var_families" != "" {
    local extra_var_families `"$brfss_pre2011_extra_var_families"'
}

* Delete temporary extracted XPT files after a successful run.
local cleanup_temp_files 1

* ============================================================================
* 1. DEFINE PATHS AND YEARS
* ============================================================================

local cwd `"`c(pwd)'"'
if "$brfss_root" != "" & fileexists("$brfss_root/code/01_load_pre2011_optional_low_memory.do") {
    global brfss_root "$brfss_root"
}
else if fileexists("code/01_load_pre2011_optional_low_memory.do") & fileexists("README.md") {
    global brfss_root "`cwd'"
}
else if fileexists("01_load_pre2011_optional_low_memory.do") & fileexists("../README.md") {
    global brfss_root "`cwd'/.."
}
else if fileexists("brfss/code/01_load_pre2011_optional_low_memory.do") & fileexists("brfss/README.md") {
    global brfss_root "`cwd'/brfss"
}
else {
    display as error "Could not locate the brfss/ directory."
    display as error "Run from brfss/, brfss/code/, the repo root, or set global brfss_root first."
    exit 198
}

cd "$brfss_root"
display as text "Using BRFSS root: $brfss_root"

local raw_dir "data/raw"
if "$brfss_pre2011_output_dir" != "" {
    local out_dir "$brfss_pre2011_output_dir"
}
else {
    local out_dir "output"
}
capture mkdir "`out_dir'"

local out_dta "`out_dir'/brfss_pre2011_appended.dta"
local tmp_dir "`out_dir'/_tmp_pre2011_stata"
capture mkdir "`tmp_dir'"

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

foreach y of local years {
    if !inrange(`y', 2000, 2010) {
        display as error "This pre-2011 loader supports 2000-2010 only. Invalid year: `y'"
        exit 198
    }
}

* ============================================================================
* 2. DEFINE CORE KEEP LIST
* ============================================================================

local core_keep ///
    "_psu _ststr _finalwt _poststr _state ctycode _impcty cpcounty " ///
    "seqno dispcode imonth iyear " ///
    "age _impage _ageg5yr sex " ///
    "_racegr _racegr2 _raceg2 _raceg3_ _prace _mrace race2 hispanc2 " ///
    "educa marital income2 employ " ///
    "genhlth menthlth physhlth " ///
    "hlthplan persdoc persdoc2 medcost checkup checkup1 " ///
    "diabetes diabete2 asthma asthma2 asthnow " ///
    "cvdinfar cvdcorhd cvdstrok " ///
    "cvdinfr2 cvdinfr3 cvdinfr4 cvdcrhd2 cvdcrhd3 cvdcrhd4 " ///
    "cvdstrk2 cvdstrk3 _bmi2 _bmi2cat _rfbmi2 " ///
    "_bmi3 _bmi3cat _rfbmi3 _bmi4 _bmi4cat _rfbmi4 " ///
    "_smoker2 _smoker3 smoke100 smokeday"

local family_output_vars ""
foreach spec of local extra_var_families {
    local colon_pos = strpos(`"`spec'"', ":")
    if `colon_pos' <= 1 {
        display as error "Invalid extra_var_families entry: `spec'"
        display as error "Use the form output_name:source_var1 source_var2"
        exit 198
    }
    local output_name = strtrim(substr(`"`spec'"', 1, `colon_pos' - 1))
    local family_output_vars "`family_output_vars' `output_name'"
}

* ============================================================================
* 3. IMPORT EACH YEAR
* ============================================================================

display as text _newline "============================================"
display as text "   LOADING BRFSS PRE-2011 LOW-MEMORY DATA (`year_label')"
display as text "============================================"

tempfile master
local is_first = 1

foreach y of local years {
    local yy = substr("`y'", 3, 2)
    local xpt_name "CDBRFS`yy'.XPT"
    local xpt_file "`raw_dir'/`xpt_name'"
    local zip_file "`raw_dir'/CDBRFS`yy'XPT.zip"
    local zip_file_upper "`raw_dir'/CDBRFS`yy'XPT.ZIP"
    local import_file ""

    display as text _newline "--- Year `y' ---"

    if fileexists("`xpt_file'") {
        local import_file "`xpt_file'"
        display as text "  Source: `xpt_file'"
    }
    else {
        if fileexists("`zip_file'") {
            local zip_source "`zip_file'"
        }
        else if fileexists("`zip_file_upper'") {
            local zip_source "`zip_file_upper'"
        }
        else {
            display as error "No BRFSS pre-2011 file found for `y'. Expected `xpt_file' or CDBRFS`yy'XPT.zip in `raw_dir'."
            exit 601
        }

        local year_tmp "`tmp_dir'/`y'"
        capture mkdir "`year_tmp'"
        capture erase "`year_tmp'/`xpt_name'"
        quietly cd "`year_tmp'"
        unzipfile "$brfss_root/`zip_source'", replace
        quietly cd "$brfss_root"
        local extracted_name "`xpt_name'"
        if !fileexists("`year_tmp'/`extracted_name'") {
            local lower_xpt_name = lower("`xpt_name'")
            if fileexists("`year_tmp'/`lower_xpt_name'") {
                local extracted_name "`lower_xpt_name'"
            }
            else {
                display as error "Could not find `xpt_name' (case-insensitive) after extracting `zip_source'."
                exit 601
            }
        }
        local import_file "`year_tmp'/`extracted_name'"
        display as text "  Source: `zip_source'"
    }

    import sasxport5 "`import_file'", clear
    quietly rename *, lower

    gen surveyyear = `y'
    label var surveyyear "BRFSS survey year"

    * Build user-requested alias-family outputs.
    foreach spec of local extra_var_families {
        local colon_pos = strpos(`"`spec'"', ":")
        local output_name = strtrim(substr(`"`spec'"', 1, `colon_pos' - 1))
        local candidates = strtrim(substr(`"`spec'"', `colon_pos' + 1, .))
        local matched ""

        capture confirm variable `output_name'
        if _rc == 0 {
            display as error "extra_var_families output name `output_name' already exists. Choose a different family name."
            exit 110
        }

        gen double `output_name' = .
        foreach candidate of local candidates {
            local candidate_lc = lower("`candidate'")
            capture confirm variable `candidate_lc'
            if _rc == 0 {
                capture confirm numeric variable `candidate_lc'
                if _rc == 0 {
                    replace `output_name' = `candidate_lc' if missing(`output_name')
                }
                else {
                    replace `output_name' = real(`candidate_lc') if missing(`output_name')
                }
                local matched "`matched' `candidate_lc'"
            }
        }

        if trim("`matched'") == "" {
            drop `output_name'
            display as result "  [WARN] Alias family `output_name' matched no variables in `y'."
        }
        else {
            label var `output_name' "User alias family: `matched'"
        }
    }

    local present_keep ""
    local wanted_keep "`core_keep' `extra_keep_vars' `family_output_vars' surveyyear"
    foreach v of local wanted_keep {
        local v_lc = lower("`v'")
        capture confirm variable `v_lc'
        if _rc == 0 {
            local present_keep "`present_keep' `v_lc'"
        }
    }
    local present_keep : list uniq present_keep
    keep `present_keep'

    display as text "  Imported `y': " _N " observations, " c(k) " kept variables"

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
* 4. SAVE AND VALIDATE
* ============================================================================

sort surveyyear _state _psu
compress

save "`out_dta'", replace
display as text _newline "Saved: `out_dta'"
display as text "Total observations: " _N
display as text "Total variables: " c(k)

display as text _newline "============================================"
display as text "   VALIDATION CHECKS"
display as text "============================================"

levelsof surveyyear, local(loaded_years)
local loaded_years : list retok loaded_years
if trim(`"`loaded_years'"') == trim(`"`years'"') {
    display as text "[PASS] Loaded years match request: `loaded_years'"
}
else {
    display as error "[FAIL] Expected years `years' but found `loaded_years'"
    exit 459
}

display as text _newline "[INFO] Observations per survey year:"
tab surveyyear

local required_vars "_state _psu _ststr _finalwt surveyyear"
local missing_required ""
foreach v of local required_vars {
    capture confirm variable `v'
    if _rc != 0 {
        local missing_required "`missing_required' `v'"
    }
}
if trim("`missing_required'") == "" {
    display as text "[PASS] Required design variables present: `required_vars'"
}
else {
    display as error "[FAIL] Missing required variable(s):`missing_required'"
    exit 459
}

local county_vars ""
foreach v in ctycode _impcty cpcounty {
    capture confirm variable `v'
    if _rc == 0 {
        local county_vars "`county_vars' `v'"
    }
}
if trim("`county_vars'") != "" {
    display as text "[PASS] County source variable(s) present:`county_vars'"
}
else {
    display as result "[WARN] No county source variables found in selected years."
}

if `cleanup_temp_files' == 1 {
    foreach y of local years {
        local yy = substr("`y'", 3, 2)
        capture erase "`tmp_dir'/`y'/CDBRFS`yy'.XPT"
        capture erase "`tmp_dir'/`y'/cdbrfs`yy'.xpt"
        capture rmdir "`tmp_dir'/`y'"
    }
    capture rmdir "`tmp_dir'"
}

display as text _newline "============================================"
display as text "   COMPLETE"
display as text "============================================"
display as text "pre-2011 appended file: `out_dta'"
