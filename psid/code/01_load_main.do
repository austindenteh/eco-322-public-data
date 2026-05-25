********************************************************************************
* 01_load_main.do
*
* Purpose: Load selected main PSID family files and the cross-year individual
*          file, then create compact family-year and person-year starter files.
*
* Inputs:  data/family_files/fam*/FAM*.txt + FAM*.do
*          data/cross_year_individual/ind2023er/IND2023ER.txt + IND2023ER.do
* Outputs: output/psid_family_year.dta
*          output/psid_person_year.dta
*
* Usage:   Run from psid/, psid/code/, repo root, or set global psid_root.
********************************************************************************

clear all
set more off
set maxvar 32767

* ============================================================================
* 1. USER SETTINGS
* ============================================================================
*
* Uncomment and edit these globals to customize the build. You can also define
* them before running this do-file.
*
* Optional manual path override:
* global psid_root "/Users/yourname/path/to/econ-data-starters/psid"
* do "$psid_root/code/01_load_main.do"
*
* Year selection:
* global psid_years "2019 2021 2023"
* global psid_years "all"
*
* Output overrides:
* global psid_output_dir "/private/tmp/psid_smoke"
* global psid_output_basename "psid_smoke"
* global psid_write_csv_export 1
*
* Starter-surface options:
* global psid_keep_nonresp_person_years 1
* global psid_include_default_concepts 0
*
* Stable raw-name extras. Use uppercase or lowercase raw PSID variable names.
* global psid_family_extra_vars "ER85812"
* global psid_individual_extra_vars "ER32000"
*
* Alias families. The loader uses the first listed raw variable that exists and
* renames it to the family name.
* global psid_family_extra_var_families ///
*     `" "total_family_income_custom:ER16462 ER46935 ER85629" "'
* global psid_indiv_extra_var_families ///
*     `" "births_custom:ER32022" "'
*
* The README lists the default starter concepts. They cover common demographics,
* family composition, income, work, housing, weights, and generalized public-use
* geography when those labels exist in a selected wave.

local cwd "`c(pwd)'"
if "$psid_root" != "" & fileexists("$psid_root/code/01_load_main.do") {
    global psid_root "$psid_root"
}
else if fileexists("code/01_load_main.do") & fileexists("README.md") {
    global psid_root "`cwd'"
}
else if fileexists("01_load_main.do") & fileexists("../README.md") {
    global psid_root "`cwd'/.."
}
else if fileexists("psid/code/01_load_main.do") & fileexists("psid/README.md") {
    global psid_root "`cwd'/psid"
}
else {
    display as error "Could not locate the psid/ directory."
    display as error "Run from psid/, psid/code/, repo root, or set global psid_root."
    display as error `"Manual override: global psid_root "/path/to/psid""'
    error 601
}

cd "$psid_root"
capture mkdir "output"

local output_dir "output"
if "$psid_output_dir" != "" {
    local output_dir "$psid_output_dir"
    capture mkdir "`output_dir'"
}

local output_basename "psid"
if "$psid_output_basename" != "" {
    local output_basename "$psid_output_basename"
}

local family_out "`output_dir'/`output_basename'_family_year.dta"
local person_out "`output_dir'/`output_basename'_person_year.dta"

local available_years "1968 1969 1970 1971 1972 1973 1974 1975 1976 1977 1978 1979 1980 1981 1982 1983 1984 1985 1986 1987 1988 1989 1990 1991 1992 1993 1994 1995 1996 1997 1999 2001 2003 2005 2007 2009 2011 2013 2015 2017 2019 2021 2023"

* Default to a quick modern build. Set global psid_years "all" for all waves.
local selected_years "2019 2021 2023"
if "$psid_years" != "" {
    local psid_years_l = lower("$psid_years")
    if "`psid_years_l'" == "all" {
        local selected_years "`available_years'"
    }
    else {
        local selected_years "$psid_years"
    }
}

foreach y of local selected_years {
    local ok: list y in available_years
    if !`ok' {
        display as error "Invalid PSID year requested: `y'"
        display as error "Valid main PSID years are 1968-1997 annually and 1999-2023 biennially."
        error 198
    }
}

local keep_nonresponse = 0
if "$psid_keep_nonresp_person_years" == "1" {
    local keep_nonresponse = 1
}

local include_default_family_concepts = 1
if "$psid_include_default_concepts" == "0" {
    local include_default_family_concepts = 0
}

if "$psid_individual_extra_vars" != "" & "$psid_indiv_extra_vars" == "" {
    global psid_indiv_extra_vars "$psid_individual_extra_vars"
}

local write_csv_export = 0
if "$psid_write_csv_export" == "1" {
    local write_csv_export = 1
}

display as text "Using PSID root: $psid_root"
display as text "Selected PSID years: `selected_years'"

program define psid_run_setup
    args setup_path raw_dir
    tempfile setup_tmp
    file open rin using "`setup_path'", read
    file open rout using "`setup_tmp'", write replace
    file read rin line
    while r(eof) == 0 {
        local line = subinstr(`"`line'"', `"using [path]\"', `"using "`raw_dir'/"', .)
        local line = subinstr(`"`line'"', `"using [path]/"', `"using "`raw_dir'/"', .)
        local line = subinstr(`"`line'"', `".txt, clear"', `".txt", clear"', .)
        file write rout `"`line'"' _n
        file read rin line
    }
    file close rin
    file close rout
    do "`setup_tmp'"
end

program define psid_find_label, rclass
    args pattern
    local found
    foreach v of varlist _all {
        local lab : variable label `v'
        local labu = upper(strtrim(`"`lab'"'))
        if "`found'" == "" & regexm(`"`labu'"', `"`pattern'"') {
            local found "`v'"
        }
    }
    return local var "`found'"
end

program define psid_find_label_last, rclass
    args pattern
    local found
    foreach v of varlist _all {
        local lab : variable label `v'
        local labu = upper(strtrim(`"`lab'"'))
        if regexm(`"`labu'"', `"`pattern'"') {
            local found "`v'"
        }
    }
    return local var "`found'"
end

program define psid_find_annual_label, rclass
    args pattern yy
    local found
    foreach v of varlist _all {
        local lab : variable label `v'
        local labu = upper(strtrim(`"`lab'"'))
        if "`found'" == "" & regexm(`"`labu'"', `"`pattern'.*`yy'$"') {
            local found "`v'"
        }
    }
    return local var "`found'"
end

program define psid_family_file_parts, rclass
    args year
    if real("`year'") >= 1994 {
        return local dir "fam`year'er"
        return local base "FAM`year'ER"
    }
    else {
        return local dir "fam`year'"
        return local base "FAM`year'"
    }
end

* ============================================================================
* 1. LOAD FAMILY-YEAR FILES
* ============================================================================

tempfile family_all
local first_family = 1

foreach y of local selected_years {
    psid_family_file_parts `y'
    local fam_dir "`r(dir)'"
    local fam_base "`r(base)'"
    local raw_dir "data/family_files/`fam_dir'"
    local setup_path "`raw_dir'/`fam_base'.do"
    local txt_path "`raw_dir'/`fam_base'.txt"

    if !fileexists("`setup_path'") | !fileexists("`txt_path'") {
        display as error "Missing family setup or text file for `y':"
        display as error "`setup_path'"
        display as error "`txt_path'"
        error 601
    }

    display as text "Reading family file for `y'"
    psid_run_setup "`setup_path'" "`raw_dir'"
    rename _all, lower

    local yy = substr("`y'", 3, 2)

    if "`y'" == "1968" {
        * FAM1968 V3, not V2, matches ER30001 in the cross-year individual file.
        local family_id_var "v3"
    }
    else {
        psid_find_label "^`y' FAMILY INTERVIEW \(ID\) NUMBER$"
        local family_id_var "`r(var)'"
    }
    if "`family_id_var'" == "" {
        psid_find_label "^`y' INTERVIEW NUMBER$"
        local family_id_var "`r(var)'"
    }
    if "`family_id_var'" == "" {
        psid_find_label "^`y' INTERVEW NUMBER$"
        local family_id_var "`r(var)'"
    }
    if "`family_id_var'" == "" {
        psid_find_label "^`y' INTERVIEW #$"
        local family_id_var "`r(var)'"
    }
    if "`family_id_var'" == "" {
        psid_find_label "^`y' INT NUMBER$"
        local family_id_var "`r(var)'"
    }
    if "`family_id_var'" == "" {
        psid_find_label "^`y' INT #$"
        local family_id_var "`r(var)'"
    }
    if "`family_id_var'" == "" {
        psid_find_label "^INTERVIEW NUMBER `yy'$"
        local family_id_var "`r(var)'"
    }
    if "`family_id_var'" == "" {
        psid_find_label "^`yy' ID NO\.$"
        local family_id_var "`r(var)'"
    }
    if "`family_id_var'" == "" {
        display as error "Could not identify `y' family interview number in `setup_path'."
        error 111
    }

    local keep_vars "`family_id_var'"
    local rename_pairs

    if `include_default_family_concepts' {
        psid_find_label_last "^# IN FU$"
        local v "`r(var)'"
        if "`v'" == "" {
            psid_find_label "^TOTAL # IN FU$"
            local v "`r(var)'"
        }
        if "`v'" == "" {
            psid_find_label "^FAMILY SIZE$"
            local v "`r(var)'"
        }
        if "`v'" == "" {
            psid_find_label "^[0-9][0-9][0-9][0-9] FAMILY SIZE$"
            local v "`r(var)'"
        }
        if "`v'" != "" {
            local keep_vars "`keep_vars' `v'"
            local rename_pairs `"`rename_pairs' "`v' family_size""'
        }

        psid_find_label "^AGE OF( [0-9][0-9][0-9][0-9])? HEAD$"
        local v "`r(var)'"
        if "`v'" == "" {
            psid_find_label "^AGE OF HEAD$"
            local v "`r(var)'"
        }
        if "`v'" == "" {
            psid_find_label "^AGE OF REFERENCE PERSON$"
            local v "`r(var)'"
        }
        if "`v'" != "" {
            local keep_vars "`keep_vars' `v'"
            local rename_pairs `"`rename_pairs' "`v' head_age""'
        }

        psid_find_label "^SEX OF( [0-9][0-9][0-9][0-9])? HEAD$"
        local v "`r(var)'"
        if "`v'" == "" {
            psid_find_label "^SEX OF HEAD$"
            local v "`r(var)'"
        }
        if "`v'" == "" {
            psid_find_label "^SEX OF REFERENCE PERSON$"
            local v "`r(var)'"
        }
        if "`v'" != "" {
            local keep_vars "`keep_vars' `v'"
            local rename_pairs `"`rename_pairs' "`v' head_sex""'
        }

        psid_find_label "^MARITAL STATUS-GENERATED$"
        local v "`r(var)'"
        if "`v'" == "" {
            psid_find_label "^[0-9][0-9][0-9][0-9] MARITAL STATUS$"
            local v "`r(var)'"
        }
        if "`v'" == "" {
            psid_find_label "^REFERENCE PERSON MARITAL STATUS$"
            local v "`r(var)'"
        }
        if "`v'" == "" {
            psid_find_label "^A3 MARITAL STATUS$"
            local v "`r(var)'"
        }
        if "`v'" == "" {
            psid_find_label "^MARITAL STATUS$"
            local v "`r(var)'"
        }
        if "`v'" != "" {
            local keep_vars "`keep_vars' `v'"
            local rename_pairs `"`rename_pairs' "`v' marital_status""'
        }

        psid_find_label "^# CHILDREN IN FU$"
        local v "`r(var)'"
        if "`v'" == "" {
            psid_find_label "^# CHILDREN IN FAMILY UNIT$"
            local v "`r(var)'"
        }
        if "`v'" != "" {
            local keep_vars "`keep_vars' `v'"
            local rename_pairs `"`rename_pairs' "`v' children_in_fu""'
        }

        psid_find_label "^AGE YOUNGEST CHILD$"
        local v "`r(var)'"
        if "`v'" != "" {
            local keep_vars "`keep_vars' `v'"
            local rename_pairs `"`rename_pairs' "`v' age_youngest_child""'
        }

        psid_find_label "OWN/RENT OR WHAT$"
        local v "`r(var)'"
        if "`v'" != "" {
            local keep_vars "`keep_vars' `v'"
            local rename_pairs `"`rename_pairs' "`v' housing_tenure""'
        }

        psid_find_label "^CURRENT STATE$"
        local v "`r(var)'"
        if "`v'" == "" {
            psid_find_label "^STATE NOW$"
            local v "`r(var)'"
        }
        if "`v'" == "" {
            psid_find_label "^STATE \([0-9][0-9]\)$"
            local v "`r(var)'"
        }
        if "`v'" == "" {
            psid_find_label "^PSID STATE OF RESIDENCE CODE$"
            local v "`r(var)'"
        }
        if "`v'" == "" {
            psid_find_label "^FIPS STATE CODE$"
            local v "`r(var)'"
        }
        if "`v'" != "" {
            local keep_vars "`keep_vars' `v'"
            local rename_pairs `"`rename_pairs' "`v' current_state""'
        }

        psid_find_label "^CURRENT REGION$"
        local v "`r(var)'"
        if "`v'" == "" {
            psid_find_label "^REGION OF [0-9][0-9][0-9][0-9] INTERVIEW$"
            local v "`r(var)'"
        }
        if "`v'" == "" {
            psid_find_label "^REGION NOW$"
            local v "`r(var)'"
        }
        if "`v'" != "" {
            local keep_vars "`keep_vars' `v'"
            local rename_pairs `"`rename_pairs' "`v' current_region""'
        }

        psid_find_label "^METRO/NONMETRO INDICATOR$"
        local v "`r(var)'"
        if "`v'" != "" {
            local keep_vars "`keep_vars' `v'"
            local rename_pairs `"`rename_pairs' "`v' metro_nonmetro""'
        }

        psid_find_label "^BEALE RURAL-URBAN CODE$"
        local v "`r(var)'"
        if "`v'" == "" {
            psid_find_label "^RURAL-URBAN CODE \(BEALE-COLLAPSED\)$"
            local v "`r(var)'"
        }
        if "`v'" != "" {
            local keep_vars "`keep_vars' `v'"
            local rename_pairs `"`rename_pairs' "`v' beale_rural_urban""'
        }

        psid_find_label "^REF PERSON TOTAL HOURS OF WORK-[0-9][0-9][0-9][0-9]$"
        local v "`r(var)'"
        if "`v'" == "" {
            psid_find_label "^HD [0-9][0-9][0-9][0-9] TOTAL WORK HOURS$"
            local v "`r(var)'"
        }
        if "`v'" != "" {
            local keep_vars "`keep_vars' `v'"
            local rename_pairs `"`rename_pairs' "`v' head_total_work_hours""'
        }

        psid_find_label "^LABOR INCOME OF REF PERSON-[0-9][0-9][0-9][0-9]$"
        local v "`r(var)'"
        if "`v'" == "" {
            psid_find_label "^HD [0-9][0-9][0-9][0-9] TOTAL LABOR INCOME$"
            local v "`r(var)'"
        }
        if "`v'" != "" {
            local keep_vars "`keep_vars' `v'"
            local rename_pairs `"`rename_pairs' "`v' head_labor_income""'
        }

        psid_find_label "^FOOD EXPENDITURE [0-9][0-9][0-9][0-9]$"
        local v "`r(var)'"
        if "`v'" != "" {
            local keep_vars "`keep_vars' `v'"
            local rename_pairs `"`rename_pairs' "`v' food_expenditure""'
        }

        psid_find_label "^TOTAL FAMILY INCOME"
        local v "`r(var)'"
        if "`v'" == "" {
            psid_find_label "^TOTAL [0-9][0-9][0-9][0-9] FAMILY MONEY INCOME"
            local v "`r(var)'"
        }
        if "`v'" == "" {
            psid_find_label "^TOT FAM MONEY"
            local v "`r(var)'"
        }
        if "`v'" == "" {
            psid_find_label "^FAM MONEY INC"
            local v "`r(var)'"
        }
        if "`v'" != "" {
            local keep_vars "`keep_vars' `v'"
            local rename_pairs `"`rename_pairs' "`v' total_family_income""'
        }

        psid_find_label "CORE/IMMIGRANT FAM WEIGHT NUMBER 1$"
        local v "`r(var)'"
        if "`v'" == "" {
            psid_find_label "CORE/IMMIGRANT FAMILY WEIGHT$"
            local v "`r(var)'"
        }
        if "`v'" == "" {
            psid_find_label "LONGITUDINAL CORE FAMILY WEIGHT$"
            local v "`r(var)'"
        }
        if "`v'" == "" {
            psid_find_label "FAMILY WEIGHT$"
            local v "`r(var)'"
        }
        if "`v'" != "" {
            local keep_vars "`keep_vars' `v'"
            local rename_pairs `"`rename_pairs' "`v' family_weight""'
        }
    }

    foreach raw of global psid_family_extra_vars {
        local raw_l = lower("`raw'")
        capture confirm variable `raw_l'
        if !_rc {
            local keep_vars "`keep_vars' `raw_l'"
        }
    }

    foreach spec in $psid_family_extra_var_families {
        gettoken concept aliases : spec, parse(":")
        local concept = lower(strtrim("`concept'"))
        local aliases = subinstr("`aliases'", ":", "", 1)
        local chosen
        foreach raw of local aliases {
            local raw_l = lower("`raw'")
            capture confirm variable `raw_l'
            if !_rc & "`chosen'" == "" {
                local chosen "`raw_l'"
            }
        }
        if "`chosen'" != "" {
            local keep_vars "`keep_vars' `chosen'"
            local rename_pairs `"`rename_pairs' "`chosen' `concept'""'
        }
    }

    local keep_vars: list uniq keep_vars
    keep `keep_vars'
    rename `family_id_var' family_interview_id
    gen survey_year = `y'
    gen str20 source_family_file = "`fam_base'"
    gen str20 source_family_id_var = upper("`family_id_var'")
    order survey_year family_interview_id source_family_file source_family_id_var

    foreach pair in `rename_pairs' {
        gettoken from to : pair
        if "`from'" != "`family_id_var'" & "`from'" != "`to'" {
            capture confirm variable `from'
            if !_rc {
                capture confirm variable `to'
                if _rc {
                    rename `from' `to'
                }
            }
        }
    }

    compress
    if `first_family' {
        save "`family_all'", replace
        local first_family = 0
    }
    else {
        append using "`family_all'"
        save "`family_all'", replace
    }
}

use "`family_all'", clear
sort survey_year family_interview_id
save "`family_out'", replace
display as text "Saved family-year file: `family_out'"

* ============================================================================
* 2. LOAD CROSS-YEAR INDIVIDUAL FILE AND CREATE PERSON-YEARS
* ============================================================================

local ind_dir "data/cross_year_individual/ind2023er"
local ind_setup "`ind_dir'/IND2023ER.do"
local ind_txt "`ind_dir'/IND2023ER.txt"
if !fileexists("`ind_setup'") | !fileexists("`ind_txt'") {
    display as error "Missing cross-year individual setup or text file:"
    display as error "`ind_setup'"
    display as error "`ind_txt'"
    error 601
}

display as text "Reading cross-year individual file"
psid_run_setup "`ind_setup'" "`ind_dir'"
rename _all, lower

capture confirm variable er30001
if _rc {
    display as error "Required identifier ER30001 was not found."
    error 111
}
capture confirm variable er30002
if _rc {
    display as error "Required identifier ER30002 was not found."
    error 111
}

local static_keep "er30001 er30002"
local static_renames
psid_find_label "^SEX OF INDIVIDUAL$"
local sexvar "`r(var)'"
if "`sexvar'" != "" {
    local static_keep "`static_keep' `sexvar'"
    local static_renames `"`static_renames' "`sexvar' sex""'
}

psid_find_label "^WHETHER SAMPLE OR NONSAMPLE$"
local samplevar "`r(var)'"
if "`samplevar'" == "" {
    psid_find_label "^WTR ORIGINAL SAMPLE/BORN IN/MOVED IN$"
    local samplevar "`r(var)'"
}
if "`samplevar'" != "" {
    local static_keep "`static_keep' `samplevar'"
    local static_renames `"`static_renames' "`samplevar' sample_status""'
}

foreach raw of global psid_indiv_extra_vars {
    local raw_l = lower("`raw'")
    capture confirm variable `raw_l'
    if !_rc {
        local static_keep "`static_keep' `raw_l'"
    }
}

foreach spec in $psid_indiv_extra_var_families {
    gettoken concept aliases : spec, parse(":")
    local concept = lower(strtrim("`concept'"))
    local aliases = subinstr("`aliases'", ":", "", 1)
    local chosen
    foreach raw of local aliases {
        local raw_l = lower("`raw'")
        capture confirm variable `raw_l'
        if !_rc & "`chosen'" == "" {
            local chosen "`raw_l'"
        }
    }
    if "`chosen'" != "" {
        local static_keep "`static_keep' `chosen'"
        local static_renames `"`static_renames' "`chosen' `concept'""'
    }
}

tempfile person_all
local first_person = 1

foreach y of local selected_years {
    local yy = substr("`y'", 3, 2)

    psid_find_label "^`y' INTERVIEW NUMBER$"
    local family_var "`r(var)'"
    if "`family_var'" == "" {
        display as error "Could not find `y' interview number in the cross-year individual file."
        error 111
    }

    psid_find_annual_label "^SEQUENCE NUMBER" "`yy'"
    local seqvar "`r(var)'"
    psid_find_annual_label "^RELATIONSHIP TO HEAD" "`yy'"
    local relvar "`r(var)'"
    if "`relvar'" == "" {
        psid_find_annual_label "^RELATION TO HEAD" "`yy'"
        local relvar "`r(var)'"
    }
    if "`relvar'" == "" {
        psid_find_annual_label "^RELATION TO REFERENCE PERSON" "`yy'"
        local relvar "`r(var)'"
    }
    psid_find_annual_label "^AGE OF INDIVIDUAL" "`yy'"
    local agevar "`r(var)'"
    if "`agevar'" == "" {
        psid_find_annual_label "^AGE FROM BIRTH DATE" "`yy'"
        local agevar "`r(var)'"
    }
    psid_find_annual_label "^MONTH IND BORN" "`yy'"
    local mbirthvar "`r(var)'"
    if "`mbirthvar'" == "" {
        psid_find_annual_label "^MONTH INDIVIDUAL BORN" "`yy'"
        local mbirthvar "`r(var)'"
    }
    psid_find_annual_label "^YEAR IND BORN" "`yy'"
    local ybirthvar "`r(var)'"
    if "`ybirthvar'" == "" {
        psid_find_annual_label "^YEAR INDIVIDUAL BORN" "`yy'"
        local ybirthvar "`r(var)'"
    }
    psid_find_annual_label "^MARR PAIRS INDICATOR" "`yy'"
    local mpairvar "`r(var)'"
    if "`mpairvar'" == "" {
        psid_find_annual_label "^MARITAL PAIRS INDICATOR" "`yy'"
        local mpairvar "`r(var)'"
    }
    psid_find_annual_label "^WHETHER MOVED IN/OUT" "`yy'"
    local movedvar "`r(var)'"
    if "`movedvar'" == "" {
        psid_find_annual_label "^WHETHER MOVED IN" "`yy'"
        local movedvar "`r(var)'"
    }
    psid_find_annual_label "^MONTH MOVED IN/OUT" "`yy'"
    local mmovedvar "`r(var)'"
    if "`mmovedvar'" == "" {
        psid_find_annual_label "^MONTH MOVED IN" "`yy'"
        local mmovedvar "`r(var)'"
    }
    psid_find_annual_label "^YEAR MOVED IN/OUT" "`yy'"
    local ymovedvar "`r(var)'"
    if "`ymovedvar'" == "" {
        psid_find_annual_label "^YEAR MOVED IN" "`yy'"
        local ymovedvar "`r(var)'"
    }
    psid_find_annual_label "^RESPONDENT[?]" "`yy'"
    local respvar "`r(var)'"
    psid_find_annual_label "^EMPLOYMENT STAT" "`yy'"
    local empvar "`r(var)'"
    if "`empvar'" == "" {
        psid_find_annual_label "^EMPLOYMENT STATUS" "`yy'"
        local empvar "`r(var)'"
    }
    psid_find_annual_label "^YEARS? COMPLETED EDUC" "`yy'"
    local educvar "`r(var)'"
    if "`educvar'" == "" {
        psid_find_annual_label "^YRS COMPLETED EDUC" "`yy'"
        local educvar "`r(var)'"
    }
    if "`educvar'" == "" {
        psid_find_annual_label "^COMPLETED EDUC" "`yy'"
        local educvar "`r(var)'"
    }

    psid_find_annual_label "^CORE/IMM INDIVIDUAL LONGITUDINAL WT" "`yy'"
    local wtvar "`r(var)'"
    if "`wtvar'" == "" {
        psid_find_annual_label "^CORE INDIVIDUAL LONGITUDINAL WEIGHT" "`yy'"
        local wtvar "`r(var)'"
    }
    if "`wtvar'" == "" {
        psid_find_annual_label "^CORE IND WEIGHT" "`yy'"
        local wtvar "`r(var)'"
    }
    if "`wtvar'" == "" {
        psid_find_annual_label "^COMBINED IND WEIGHT" "`yy'"
        local wtvar "`r(var)'"
    }
    if "`wtvar'" == "" {
        psid_find_annual_label "^COMBO IND WEIGHT" "`yy'"
        local wtvar "`r(var)'"
    }
    if "`wtvar'" == "" {
        psid_find_annual_label "^INDIVIDUAL WEIGHT" "`yy'"
        local wtvar "`r(var)'"
    }

    preserve
        local keep_vars "`static_keep' `family_var'"
        if "`seqvar'" != "" local keep_vars "`keep_vars' `seqvar'"
        if "`relvar'" != "" local keep_vars "`keep_vars' `relvar'"
        if "`agevar'" != "" local keep_vars "`keep_vars' `agevar'"
        if "`mbirthvar'" != "" local keep_vars "`keep_vars' `mbirthvar'"
        if "`ybirthvar'" != "" local keep_vars "`keep_vars' `ybirthvar'"
        if "`mpairvar'" != "" local keep_vars "`keep_vars' `mpairvar'"
        if "`movedvar'" != "" local keep_vars "`keep_vars' `movedvar'"
        if "`mmovedvar'" != "" local keep_vars "`keep_vars' `mmovedvar'"
        if "`ymovedvar'" != "" local keep_vars "`keep_vars' `ymovedvar'"
        if "`respvar'" != "" local keep_vars "`keep_vars' `respvar'"
        if "`empvar'" != "" local keep_vars "`keep_vars' `empvar'"
        if "`educvar'" != "" local keep_vars "`keep_vars' `educvar'"
        if "`wtvar'" != "" local keep_vars "`keep_vars' `wtvar'"
        local keep_vars: list uniq keep_vars
        keep `keep_vars'

        if "`family_var'" == "er30001" {
            gen family_interview_id = er30001
            rename er30001 psid_1968_family_id
        }
        else {
            rename er30001 psid_1968_family_id
            rename `family_var' family_interview_id
        }
        rename er30002 person_number
        if "`seqvar'" != "" rename `seqvar' sequence_number
        else gen sequence_number = .
        if "`relvar'" != "" rename `relvar' relation_to_head
        else gen relation_to_head = .
        if "`agevar'" != "" rename `agevar' age_individual
        else gen age_individual = .
        if "`mbirthvar'" != "" rename `mbirthvar' month_individual_born
        else gen month_individual_born = .
        if "`ybirthvar'" != "" rename `ybirthvar' year_individual_born
        else gen year_individual_born = .
        if "`mpairvar'" != "" rename `mpairvar' marital_pairs_indicator
        else gen marital_pairs_indicator = .
        if "`movedvar'" != "" rename `movedvar' moved_in_out
        else gen moved_in_out = .
        if "`mmovedvar'" != "" rename `mmovedvar' month_moved_in_out
        else gen month_moved_in_out = .
        if "`ymovedvar'" != "" rename `ymovedvar' year_moved_in_out
        else gen year_moved_in_out = .
        if "`respvar'" != "" rename `respvar' respondent_status
        else gen respondent_status = .
        if "`empvar'" != "" rename `empvar' employment_status
        else gen employment_status = .
        if "`educvar'" != "" rename `educvar' years_completed_education
        else gen years_completed_education = .
        if "`wtvar'" != "" rename `wtvar' individual_weight
        else gen individual_weight = .

        foreach pair in `static_renames' {
            gettoken from to : pair
            capture confirm variable `from'
            if !_rc {
                capture confirm variable `to'
                if _rc {
                    rename `from' `to'
                }
            }
        }

        gen survey_year = `y'
        order psid_1968_family_id person_number survey_year family_interview_id

        if !`keep_nonresponse' {
            drop if missing(family_interview_id) | family_interview_id == 0
        }

        merge m:1 survey_year family_interview_id using "`family_all'", keep(master match) gen(_merge_family)
        gen byte has_family_record = (_merge_family == 3)
        drop _merge_family
        compress

        if `first_person' {
            save "`person_all'", replace
            local first_person = 0
        }
        else {
            append using "`person_all'"
            save "`person_all'", replace
        }
    restore
}

use "`person_all'", clear
sort psid_1968_family_id person_number survey_year
save "`person_out'", replace
display as text "Saved person-year file: `person_out'"
display as text "Person-year rows: " _N

if `write_csv_export' {
    export delimited using "`output_dir'/`output_basename'_person_year.csv", replace
}
