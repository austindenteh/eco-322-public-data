********************************************************************************
* 08_load_cds_assessments.do
*
* Purpose: Load selected PSID Child Development Supplement (CDS) assessment,
*          school, teacher, administrator, and provider files as separate outputs.
*
* Outputs: output/psid_cds_assessments_YYYY_filekey.dta
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
* do "$psid_root/code/08_load_cds_assessments.do"
*
* Output and file-selection options:
* global psid_output_dir "/private/tmp/psid_cds_assess_smoke"
* global psid_output_basename "psid_cds_assess"
* global psid_write_csv_export 1
* global psid_cds_assessment_waves "2014 2019"
* global psid_cds_assessment_waves "all"
* global psid_cds_assessment_files "assessment teacher"
* global psid_cds_assessment_files "all"

local cwd "`c(pwd)'"
if "$psid_root" != "" & fileexists("$psid_root/code/08_load_cds_assessments.do") {
    global psid_root "$psid_root"
}
else if fileexists("code/08_load_cds_assessments.do") & fileexists("README.md") {
    global psid_root "`cwd'"
}
else if fileexists("08_load_cds_assessments.do") & fileexists("../README.md") {
    global psid_root "`cwd'/.."
}
else if fileexists("psid/code/08_load_cds_assessments.do") & fileexists("psid/README.md") {
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

global psid_cdsas_outdir "`output_dir'"
global psid_cdsas_base "`output_basename'"

local cds_waves "2014 2019"
if "$psid_cds_assessment_waves" != "" {
    local requested = lower("$psid_cds_assessment_waves")
    if "`requested'" == "all" {
        local cds_waves "1997 2002 2007 2014 2019"
    }
    else {
        local cds_waves "`requested'"
    }
}

local cds_files "all"
if "$psid_cds_assessment_files" != "" {
    local cds_files = lower("$psid_cds_assessment_files")
    local cds_files = subinstr("`cds_files'", "-", "_", .)
}

display as text "Using PSID root: $psid_root"
display as text "Selected CDS assessment/school waves: `cds_waves'"
display as text "Selected CDS assessment/school files/groups: `cds_files'"

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

capture program drop psid_load_cds_assessment_file
program define psid_load_cds_assessment_file
    args wave folder base file_key file_group write_csv_export

    local raw_dir "data/supplemental_studies/child_development_supplement/`folder'"
    local setup_path "`raw_dir'/`base'.do"
    local txt_path "`raw_dir'/`base'.txt"
    if !fileexists("`setup_path'") | !fileexists("`txt_path'") {
        display as error "Missing CDS assessment/school files for `base'."
        error 601
    }

    display as text "Reading PSID CDS assessment/school `wave' `file_key'"
    psid_run_setup "`setup_path'" "`raw_dir'"
    rename _all, lower

    gen str32 source_module = "child_development_supplement"
    gen str24 source_file = "`base'"
    gen int survey_year = `wave'
    gen str40 file_key = "`file_key'"
    gen str40 file_group = "`file_group'"
    order source_module source_file survey_year file_key file_group

    compress
    local out "${psid_cdsas_outdir}/${psid_cdsas_base}_cds_assessments_`wave'_`file_key'.dta"
    save "`out'", replace
    if `write_csv_export' {
        export delimited using "${psid_cdsas_outdir}/${psid_cdsas_base}_cds_assessments_`wave'_`file_key'.csv", replace
    }
    display as text "Saved CDS assessment/school `wave' `file_key': `out'"
end

local write_csv_export = 0
if "$psid_write_csv_export" == "1" {
    local write_csv_export = 1
}

local inventory ///
    `"1997 1997 CHILD97 child_assessment assessment"' ///
    `"1997 1997 EMSADMIN97 elementary_middle_school_admin school_administrator"' ///
    `"1997 1997 EMSTEACH97 elementary_middle_school_teacher teacher"' ///
    `"1997 1997 HB_CPROV97 homebased_care_provider provider"' ///
    `"1997 1997 PDADMIN97 preschool_daycare_administrator school_administrator"' ///
    `"1997 1997 PDTEACH97 preschool_daycare_teacher teacher"' ///
    `"2002 2002 ASSESSMT assessment assessment"' ///
    `"2002 2002 EMSTEACH elementary_middle_school_teacher teacher"' ///
    `"2007 2007 ASSESS07 assessment assessment"' ///
    `"2014 2014 ASSESS14 assessment assessment"' ///
    `"2019 2019 ASSESS2019 assessment assessment"'

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
        psid_load_cds_assessment_file `wave' `folder' `base' `file_key' `file_group' `write_csv_export'
        local loaded_files = `loaded_files' + 1
    }
}

if `loaded_files' == 0 {
    display as error "No CDS assessment/school files matched the requested waves and file selection."
    error 2000
}
