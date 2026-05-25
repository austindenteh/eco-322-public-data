********************************************************************************
* 05_load_cds_index.do
*
* Purpose: Load the PSID Child Development Supplement (CDS) cumulative ID map
*          and build a compact long-format CDS wave index.
*
* Outputs: output/psid_cds_cumulative_id_map.dta
*          output/psid_cds_wave_index.dta
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
* do "$psid_root/code/05_load_cds_index.do"
*
* Output and CDS index options:
* global psid_output_dir "/private/tmp/psid_cds_index_smoke"
* global psid_output_basename "psid_cds"
* global psid_write_csv_export 1
* global psid_cds_waves "2014 2019 2021"
* global psid_cds_waves "all"
* global psid_cds_keep_all_cumulative 0
* global psid_cds_extra_vars "PCGHH_19"

local cwd "`c(pwd)'"
if "$psid_root" != "" & fileexists("$psid_root/code/05_load_cds_index.do") {
    global psid_root "$psid_root"
}
else if fileexists("code/05_load_cds_index.do") & fileexists("README.md") {
    global psid_root "`cwd'"
}
else if fileexists("05_load_cds_index.do") & fileexists("../README.md") {
    global psid_root "`cwd'/.."
}
else if fileexists("psid/code/05_load_cds_index.do") & fileexists("psid/README.md") {
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

local cds_waves "1997 2002 2007 2014 2019 2021"
if "$psid_cds_waves" != "" {
    local requested = lower("$psid_cds_waves")
    if "`requested'" == "all" {
        local cds_waves "1997 2002 2007 2014 2019 2021"
    }
    else {
        local cds_waves "`requested'"
    }
}

foreach y of local cds_waves {
    if !inlist("`y'", "1997", "2002", "2007", "2014", "2019", "2021") {
        display as error "Invalid CDS index wave: `y'"
        display as error "CDSIND2021 has standalone index blocks for 1997 2002 2007 2014 2019 2021."
        display as error "The 2020 COVID-era CDS files have component flags but no full index block here."
        error 198
    }
}

local keep_all_cumulative = 1
if "$psid_cds_keep_all_cumulative" == "0" {
    local keep_all_cumulative = 0
}

local write_csv_export = 0
if "$psid_write_csv_export" == "1" {
    local write_csv_export = 1
}

display as text "Using PSID root: $psid_root"
display as text "Selected CDS index waves: `cds_waves'"

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

capture program drop psid_rename_if_exists
program define psid_rename_if_exists
    args old new
    capture confirm variable `old'
    if !_rc {
        capture confirm variable `new'
        if _rc {
            rename `old' `new'
        }
    }
end

capture program drop psid_copy_if_exists
program define psid_copy_if_exists
    args old new
    capture drop `new'
    gen double `new' = .
    capture confirm variable `old'
    if !_rc {
        replace `new' = `old'
    }
end

capture program drop psid_cds_keep_optional_var
program define psid_cds_keep_optional_var
    args varname
    capture confirm variable `varname'
    if _rc {
        display as text "Requested CDS extra variable not found; skipping: `varname'"
    }
end

local raw_dir "data/supplemental_studies/child_development_supplement/cdsind2021"
local setup_path "`raw_dir'/CDSIND2021.do"
local txt_path "`raw_dir'/CDSIND2021.txt"
if !fileexists("`setup_path'") | !fileexists("`txt_path'") {
    display as error "Missing CDS cumulative ID map files."
    error 601
}

display as text "Reading PSID supplement: CDS cumulative ID map"
psid_run_setup "`setup_path'" "`raw_dir'"
rename _all, lower
psid_rename_if_exists cdscumrel release_number
psid_rename_if_exists cdscumid68 psid_1968_family_id
psid_rename_if_exists cdscumpn person_number

gen str32 source_module = "child_development_supplement"
gen str12 source_file = "CDSIND2021"
order source_module source_file release_number psid_1968_family_id person_number

tempfile cumulative_all wave_index
save "`cumulative_all'", replace

preserve
if `keep_all_cumulative' == 0 {
    local keep_vars "source_module source_file release_number psid_1968_family_id person_number pcghh_20 pcgch_20"
    foreach y of local cds_waves {
        local suffix = substr("`y'", 3, 2)
        foreach stem in cdstype crfid crsn cds_hid cds_sn id68pcg pnpcg crpcgfid crpcgsn id68ocg pnocg crocgfid crocgsn cdspcgsn pcghhno {
            capture confirm variable `stem'`suffix'
            if !_rc {
                local keep_vars "`keep_vars' `stem'`suffix'"
            }
        }
        foreach stem in demog_ pcghh_ pcgch_ child_ {
            capture confirm variable `stem'`suffix'
            if !_rc {
                local keep_vars "`keep_vars' `stem'`suffix'"
            }
        }
    }
    local extras = lower("$psid_cds_extra_vars")
    foreach extra of local extras {
        capture confirm variable `extra'
        if !_rc {
            local keep_vars "`keep_vars' `extra'"
        }
        else {
            display as text "Requested CDS extra variable not found; skipping: `extra'"
        }
    }
    keep `keep_vars'
}
compress
save "`output_dir'/`output_basename'_cds_cumulative_id_map.dta", replace
if `write_csv_export' {
    export delimited using "`output_dir'/`output_basename'_cds_cumulative_id_map.csv", replace
}
display as text "Saved cds_cumulative_id_map: `output_dir'/`output_basename'_cds_cumulative_id_map.dta"
restore

local first_wave = 1
foreach y of local cds_waves {
    local suffix = substr("`y'", 3, 2)
    tempfile one_wave
    use "`cumulative_all'", clear
    gen int survey_year = `y'
    psid_copy_if_exists cdstype`suffix' cds_person_type
    psid_copy_if_exists crfid`suffix' core_family_interview_id
    psid_copy_if_exists crsn`suffix' core_sequence_number
    psid_copy_if_exists cds_hid`suffix' cds_household_interview_id
    psid_copy_if_exists cds_sn`suffix' cds_sequence_number
    psid_copy_if_exists id68pcg`suffix' pcg_1968_family_id
    psid_copy_if_exists pnpcg`suffix' pcg_person_number
    psid_copy_if_exists crpcgfid`suffix' pcg_core_family_interview_id
    psid_copy_if_exists crpcgsn`suffix' pcg_core_sequence_number
    psid_copy_if_exists id68ocg`suffix' ocg_1968_family_id
    psid_copy_if_exists pnocg`suffix' ocg_person_number
    psid_copy_if_exists crocgfid`suffix' ocg_core_family_interview_id
    psid_copy_if_exists crocgsn`suffix' ocg_core_sequence_number
    psid_copy_if_exists cdspcgsn`suffix' pcg_cds_sequence_number
    psid_copy_if_exists pcghhno`suffix' household_pcg_indicator
    psid_copy_if_exists demog_`suffix' demog_file
    psid_copy_if_exists pcghh_`suffix' pcg_household_file
    psid_copy_if_exists pcgch_`suffix' pcg_child_file
    psid_copy_if_exists child_`suffix' child_file
    keep if !missing(cds_person_type) & cds_person_type != 0
    keep source_module source_file survey_year psid_1968_family_id person_number ///
        cds_person_type core_family_interview_id core_sequence_number ///
        cds_household_interview_id cds_sequence_number pcg_1968_family_id ///
        pcg_person_number pcg_core_family_interview_id pcg_core_sequence_number ///
        ocg_1968_family_id ocg_person_number ocg_core_family_interview_id ///
        ocg_core_sequence_number pcg_cds_sequence_number household_pcg_indicator ///
        demog_file pcg_household_file pcg_child_file child_file
    save "`one_wave'", replace

    if `first_wave' {
        use "`one_wave'", clear
        save "`wave_index'", replace
        local first_wave = 0
    }
    else {
        use "`wave_index'", clear
        append using "`one_wave'"
        save "`wave_index'", replace
    }
}

use "`wave_index'", clear
sort psid_1968_family_id person_number survey_year
compress
save "`output_dir'/`output_basename'_cds_wave_index.dta", replace
if `write_csv_export' {
    export delimited using "`output_dir'/`output_basename'_cds_wave_index.csv", replace
}
display as text "Saved cds_wave_index: `output_dir'/`output_basename'_cds_wave_index.dta"
