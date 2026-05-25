********************************************************************************
* 07_load_cds_time_diary.do
*
* Purpose: Load selected PSID Child Development Supplement (CDS) time-diary
*          component files as separate outputs.
*
* Outputs: output/psid_cds_time_diary_YYYY_filekey.dta
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
* do "$psid_root/code/07_load_cds_time_diary.do"
*
* Output and file-selection options:
* global psid_output_dir "/private/tmp/psid_cds_time_smoke"
* global psid_output_basename "psid_cds_time"
* global psid_write_csv_export 1
* global psid_cds_time_diary_waves "2019 2020"
* global psid_cds_time_diary_waves "all"
* global psid_cds_time_diary_files "activity media"
* global psid_cds_time_diary_files "all"

local cwd "`c(pwd)'"
if "$psid_root" != "" & fileexists("$psid_root/code/07_load_cds_time_diary.do") {
    global psid_root "$psid_root"
}
else if fileexists("code/07_load_cds_time_diary.do") & fileexists("README.md") {
    global psid_root "`cwd'"
}
else if fileexists("07_load_cds_time_diary.do") & fileexists("../README.md") {
    global psid_root "`cwd'/.."
}
else if fileexists("psid/code/07_load_cds_time_diary.do") & fileexists("psid/README.md") {
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

global psid_cdstime_outdir "`output_dir'"
global psid_cdstime_base "`output_basename'"

local cds_waves "2019 2020"
if "$psid_cds_time_diary_waves" != "" {
    local requested = lower("$psid_cds_time_diary_waves")
    if "`requested'" == "all" {
        local cds_waves "1997 2002 2007 2014 2019 2020"
    }
    else {
        local cds_waves "`requested'"
    }
}

local cds_files "all"
if "$psid_cds_time_diary_files" != "" {
    local cds_files = lower("$psid_cds_time_diary_files")
    local cds_files = subinstr("`cds_files'", "-", "_", .)
}

display as text "Using PSID root: $psid_root"
display as text "Selected CDS time-diary waves: `cds_waves'"
display as text "Selected CDS time-diary files/groups: `cds_files'"

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

capture program drop psid_load_cds_time_diary_file
program define psid_load_cds_time_diary_file
    args wave folder base file_key file_group write_csv_export

    local raw_dir "data/supplemental_studies/child_development_supplement/`folder'"
    local setup_path "`raw_dir'/`base'.do"
    local txt_path "`raw_dir'/`base'.txt"
    if !fileexists("`setup_path'") | !fileexists("`txt_path'") {
        display as error "Missing CDS time-diary files for `base'."
        error 601
    }

    display as text "Reading PSID CDS time diary `wave' `file_key'"
    psid_run_setup "`setup_path'" "`raw_dir'"
    rename _all, lower

    gen str32 source_module = "child_development_supplement"
    gen str24 source_file = "`base'"
    gen int survey_year = `wave'
    gen str40 file_key = "`file_key'"
    gen str40 file_group = "`file_group'"
    order source_module source_file survey_year file_key file_group

    compress
    local out "${psid_cdstime_outdir}/${psid_cdstime_base}_cds_time_diary_`wave'_`file_key'.dta"
    save "`out'", replace
    if `write_csv_export' {
        export delimited using "${psid_cdstime_outdir}/${psid_cdstime_base}_cds_time_diary_`wave'_`file_key'.csv", replace
    }
    display as text "Saved CDS time diary `wave' `file_key': `out'"
end

local write_csv_export = 0
if "$psid_write_csv_export" == "1" {
    local write_csv_export = 1
}

local inventory ///
    `"1997 1997 TD97 activity activity"' ///
    `"1997 1997 TD97_ACT_AGG activity_aggregate aggregate"' ///
    `"1997 1997 TD97MEDIA media media"' ///
    `"1997 1997 TDFUP97 followup followup"' ///
    `"1997 1997 ESDIARY97 elementary_school_diary school_care_diary"' ///
    `"1997 1997 HCDIARY97 homebased_care_diary school_care_diary"' ///
    `"1997 1997 MSDIARY97 middle_school_diary school_care_diary"' ///
    `"1997 1997 PSDIARY97 preschool_daycare_diary school_care_diary"' ///
    `"2002 2002 TD_ACTIVITY activity activity"' ///
    `"2002 2002 TD02_ACT_AGG activity_aggregate aggregate"' ///
    `"2002 2002 TD02MEDIA media media"' ///
    `"2002 2002 TD_FOLLOWUP followup followup"' ///
    `"2007 2007 TD_ACT07 activity activity"' ///
    `"2007 2007 TD_ACTAGG07 activity_aggregate aggregate"' ///
    `"2007 2007 TD07MEDIA media media"' ///
    `"2007 2007 TD_FOLLOW07 followup followup"' ///
    `"2014 2014 TD_ACT14 activity activity"' ///
    `"2014 2014 TD_ACTAGG14 activity_aggregate aggregate"' ///
    `"2014 2014 TD14MEDIA media media"' ///
    `"2014 2014 TD_FOLLOW14 followup followup"' ///
    `"2019 2019 TD_ACT2019 activity activity"' ///
    `"2019 2019 TD_AGG2019 activity_aggregate aggregate"' ///
    `"2019 2019 TD19MEDIA media media"' ///
    `"2019 2019 TD_QN2019 questionnaire questionnaire"' ///
    `"2020 2020 TD_ACT2020 activity activity"' ///
    `"2020 2020 TD_AGG2020 activity_aggregate aggregate"' ///
    `"2020 2020 TD20MEDIA media media"' ///
    `"2020 2020 TD_QN2020 questionnaire questionnaire"'

local loaded_files = 0
foreach rec in `"`inventory'"' {
    tokenize `"`rec'"'
    local wave "`1'"
    local folder "`2'"
    local base "`3'"
    local file_key "`4'"
    local file_group "`5'"

    local wave_match = 0
    foreach selected_wave of local cds_waves {
        if "`wave'" == "`selected_wave'" {
            local wave_match = 1
        }
    }

    local file_match = 0
    if "`cds_files'" == "all" {
        local file_match = 1
    }
    else {
        foreach selected_file of local cds_files {
            if "`file_key'" == "`selected_file'" | "`file_group'" == "`selected_file'" {
                local file_match = 1
            }
        }
    }

    if `wave_match' & `file_match' {
        psid_load_cds_time_diary_file `wave' `folder' `base' `file_key' `file_group' `write_csv_export'
        local loaded_files = `loaded_files' + 1
    }
}

if `loaded_files' == 0 {
    display as error "No CDS time-diary files matched the requested waves and file selection."
    error 2000
}
