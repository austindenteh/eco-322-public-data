********************************************************************************
* 09_load_tas_index.do
*
* Purpose: Load selected Transition into Adulthood Supplement (TAS) waves into a
*          compact index file with merge keys and interview metadata.
*
* Output: output/psid_tas_wave_index.dta
********************************************************************************

clear all
set more off
set maxvar 32767

* ============================================================================
* 1. USER SETTINGS
* ============================================================================
*
* Optional manual path override:
* global psid_root "/Users/yourname/path/to/econ-data-starters/psid"
* do "$psid_root/code/09_load_tas_index.do"
*
* Output and TAS options:
* global psid_output_dir "/private/tmp/psid_tas_smoke"
* global psid_output_basename "psid_tas"
* global psid_write_csv_export 1
* global psid_tas_years "2019 2021 2023"
* global psid_tas_years "all"
* global psid_tas_extra_vars "TA190001"

local cwd "`c(pwd)'"
if "$psid_root" != "" & fileexists("$psid_root/code/09_load_tas_index.do") {
    global psid_root "$psid_root"
}
else if fileexists("code/09_load_tas_index.do") & fileexists("README.md") {
    global psid_root "`cwd'"
}
else if fileexists("09_load_tas_index.do") & fileexists("../README.md") {
    global psid_root "`cwd'/.."
}
else if fileexists("psid/code/09_load_tas_index.do") & fileexists("psid/README.md") {
    global psid_root "`cwd'/psid"
}
else {
    display as error "Could not locate the psid/ directory."
    display as error "Run from psid/, psid/code/, repo root, or set global psid_root."
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

local tas_years "2019 2021 2023"
if "$psid_tas_years" != "" {
    local requested = lower("$psid_tas_years")
    if "`requested'" == "all" {
        local tas_years "2005 2007 2009 2011 2013 2015 2017 2019 2021 2023"
    }
    else {
        local tas_years "`requested'"
    }
}

foreach y of local tas_years {
    local valid_year = 0
    foreach allowed in 2005 2007 2009 2011 2013 2015 2017 2019 2021 2023 {
        if "`y'" == "`allowed'" {
            local valid_year = 1
        }
    }
    if !`valid_year' {
        display as error "Invalid TAS year: `y'"
        display as error "Choose from 2005 2007 2009 2011 2013 2015 2017 2019 2021 2023."
        error 198
    }
}

local write_csv_export = 0
if "$psid_write_csv_export" == "1" {
    local write_csv_export = 1
}

display as text "Using PSID root: $psid_root"
display as text "Selected TAS years: `tas_years'"

capture program drop psid_run_setup
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

capture program drop psid_copy_if_exists
program define psid_copy_if_exists
    args old new
    gen double `new' = .
    capture confirm variable `old'
    if !_rc {
        replace `new' = `old'
    }
end

capture program drop psid_tas_year_info
program define psid_tas_year_info, rclass
    args year
    if "`year'" == "2005" {
        return local folder "ta2005"
        return local base "TA2005"
        return local prefix "ta05"
        return local nums "1 2 3 4 5 11 10 6 7 8 9 12 13 14"
    }
    else if "`year'" == "2007" {
        return local folder "ta2007"
        return local base "TA2007"
        return local prefix "ta07"
        return local nums "1 2 3 4 5 11 10 6 7 8 9 12 13 14"
    }
    else if "`year'" == "2009" {
        return local folder "ta2009"
        return local base "TA2009"
        return local prefix "ta09"
        return local nums "1 2 3 4 5 11 10 6 7 8 9 12 13 14"
    }
    else if "`year'" == "2011" {
        return local folder "ta2011"
        return local base "TA2011"
        return local prefix "ta11"
        return local nums "1 2 3 4 5 11 10 6 7 8 9 12 13 14"
    }
    else if "`year'" == "2013" {
        return local folder "ta2013"
        return local base "TA2013"
        return local prefix "ta13"
        return local nums "1 2 3 4 5 11 10 6 7 8 9 12 13 14"
    }
    else if "`year'" == "2015" {
        return local folder "ta2015"
        return local base "TA2015"
        return local prefix "ta15"
        return local nums "1 2 3 4 5 11 10 6 7 8 9 12 13 14"
    }
    else if "`year'" == "2017" {
        return local folder "TA2017"
        return local base "TA2017"
        return local prefix "ta17"
        return local nums "1 2 3 4 5 6 7 8 9 10 11 12 13 14"
    }
    else if "`year'" == "2019" {
        return local folder "TA2019"
        return local base "TA2019"
        return local prefix "ta19"
        return local nums "1 2 3 4 . 5 7 9 10 11 12 13 14 15"
    }
    else if "`year'" == "2021" {
        return local folder "TA2021"
        return local base "TA2021"
        return local prefix "ta21"
        return local nums "1 2 3 4 . 5 6 8 9 10 11 12 13 14"
    }
    else if "`year'" == "2023" {
        return local folder "TA2023"
        return local base "TA2023"
        return local prefix "ta23"
        return local nums "1 2 3 4 . 5 6 8 9 10 11 12 13 14"
    }
end

capture program drop psid_tas_raw_name
program define psid_tas_raw_name, rclass
    args prefix num
    if "`num'" == "." {
        return local varname ""
    }
    else {
        local varname "`prefix'`=string(real("`num'"), "%04.0f")'"
        return local varname "`varname'"
    }
end

capture program drop psid_load_tas_year
program define psid_load_tas_year
    args year output_file
    psid_tas_year_info `year'
    local folder "`r(folder)'"
    local base "`r(base)'"
    local prefix "`r(prefix)'"
    local nums "`r(nums)'"
    local raw_dir "data/supplemental_studies/transition_into_adulthood/`folder'"
    local setup_path "`raw_dir'/`base'.do"
    local txt_path "`raw_dir'/`base'.txt"
    if !fileexists("`setup_path'") | !fileexists("`txt_path'") {
        display as error "Missing TAS files for `year'."
        error 601
    }

    display as text "Reading PSID TAS `year'"
    psid_run_setup "`setup_path'" "`raw_dir'"
    rename _all, lower

    local targets "release_number tas_interview_id family_interview_id sequence_number current_state reference_status interview_mode interview_length_minutes tas_interview_month tas_interview_day tas_interview_year psid_interview_month psid_interview_day psid_interview_year"
    local i = 1
    foreach target of local targets {
        local num : word `i' of `nums'
        psid_tas_raw_name "`prefix'" "`num'"
        local raw "`r(varname)'"
        if "`raw'" == "" {
            gen double `target' = .
        }
        else {
            psid_copy_if_exists `raw' `target'
        }
        local ++i
    }

    gen double tas_weight = .
    gen double tas_long_weight = .
    foreach v of varlist _all {
        local lab : variable label `v'
        local lab_lower = lower(strtrim(`"`lab'"'))
        if "`lab_lower'" == "cross sectional weight" {
            replace tas_weight = `v'
        }
        else if "`lab_lower'" == "weight" {
            replace tas_weight = `v' if missing(tas_weight)
        }
        else if strpos("`lab_lower'", "long weight") == 1 {
            replace tas_long_weight = `v'
        }
    }

    gen str32 source_module = "transition_into_adulthood"
    gen str12 source_file = "`base'"
    gen int survey_year = `year'

    local keep_vars "source_module source_file survey_year release_number tas_interview_id family_interview_id sequence_number current_state reference_status interview_mode interview_length_minutes tas_interview_month tas_interview_day tas_interview_year psid_interview_month psid_interview_day psid_interview_year tas_weight tas_long_weight"
    local extras = lower("$psid_tas_extra_vars")
    foreach extra of local extras {
        capture confirm variable `extra'
        if !_rc {
            local keep_vars "`keep_vars' `extra'"
        }
        else {
            display as text "Requested TAS extra variable not found in `year'; skipping: `extra'"
        }
    }
    keep `keep_vars'
    save "`output_file'", replace
end

local first_year = 1
tempfile tas_index
foreach y of local tas_years {
    tempfile one_year
    psid_load_tas_year `y' "`one_year'"
    if `first_year' {
        use "`one_year'", clear
        save "`tas_index'", replace
        local first_year = 0
    }
    else {
        use "`tas_index'", clear
        append using "`one_year'"
        save "`tas_index'", replace
    }
}

use "`tas_index'", clear
sort survey_year family_interview_id sequence_number
compress
save "`output_dir'/`output_basename'_tas_wave_index.dta", replace
if `write_csv_export' {
    export delimited using "`output_dir'/`output_basename'_tas_wave_index.csv", replace
}
display as text "Saved tas_wave_index: `output_dir'/`output_basename'_tas_wave_index.dta"
