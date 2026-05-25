********************************************************************************
* 06_load_cds_child_caregiver.do
*
* Purpose: Load selected PSID Child Development Supplement (CDS) child,
*          caregiver, roster, demographic, and support files as separate outputs.
*
* Outputs: output/psid_cds_child_caregiver_YYYY_filekey.dta
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
* do "$psid_root/code/06_load_cds_child_caregiver.do"
*
* Output and file-selection options:
* global psid_output_dir "/private/tmp/psid_cds_cc_smoke"
* global psid_output_basename "psid_cds_cc"
* global psid_write_csv_export 1
* global psid_cds_child_caregiver_waves "2019 2020"
* global psid_cds_child_caregiver_waves "all"
* global psid_cds_child_caregiver_files "child pcg_child"
* global psid_cds_child_caregiver_files "all"

local cwd "`c(pwd)'"
if "$psid_root" != "" & fileexists("$psid_root/code/06_load_cds_child_caregiver.do") {
    global psid_root "$psid_root"
}
else if fileexists("code/06_load_cds_child_caregiver.do") & fileexists("README.md") {
    global psid_root "`cwd'"
}
else if fileexists("06_load_cds_child_caregiver.do") & fileexists("../README.md") {
    global psid_root "`cwd'/.."
}
else if fileexists("psid/code/06_load_cds_child_caregiver.do") & fileexists("psid/README.md") {
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

global psid_cdscc_outdir "`output_dir'"
global psid_cdscc_base "`output_basename'"

local cds_waves "2019 2020 2021"
if "$psid_cds_child_caregiver_waves" != "" {
    local requested = lower("$psid_cds_child_caregiver_waves")
    if "`requested'" == "all" {
        local cds_waves "1997 2002 2007 2014 2019 2020 2021"
    }
    else {
        local cds_waves "`requested'"
    }
}

local cds_files "all"
if "$psid_cds_child_caregiver_files" != "" {
    local cds_files = lower("$psid_cds_child_caregiver_files")
    local cds_files = subinstr("`cds_files'", "-", "_", .)
}

display as text "Using PSID root: $psid_root"
display as text "Selected CDS child/caregiver waves: `cds_waves'"
display as text "Selected CDS child/caregiver files/groups: `cds_files'"

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

capture program drop psid_load_cds_cc_file
program define psid_load_cds_cc_file
    args wave folder base file_key file_group write_csv_export

    local raw_dir "data/supplemental_studies/child_development_supplement/`folder'"
    local setup_path "`raw_dir'/`base'.do"
    local txt_path "`raw_dir'/`base'.txt"
    if !fileexists("`setup_path'") | !fileexists("`txt_path'") {
        display as error "Missing CDS child/caregiver files for `base'."
        error 601
    }

    display as text "Reading PSID CDS `wave' `file_key'"
    psid_run_setup "`setup_path'" "`raw_dir'"
    rename _all, lower

    gen str32 source_module = "child_development_supplement"
    gen str24 source_file = "`base'"
    gen int survey_year = `wave'
    gen str40 file_key = "`file_key'"
    gen str40 file_group = "`file_group'"
    order source_module source_file survey_year file_key file_group

    compress
    local out "${psid_cdscc_outdir}/${psid_cdscc_base}_cds_child_caregiver_`wave'_`file_key'.dta"
    save "`out'", replace
    if `write_csv_export' {
        export delimited using "${psid_cdscc_outdir}/${psid_cdscc_base}_cds_child_caregiver_`wave'_`file_key'.csv", replace
    }
    display as text "Saved CDS child/caregiver `wave' `file_key': `out'"
end

local write_csv_export = 0
if "$psid_write_csv_export" == "1" {
    local write_csv_export = 1
}

local inventory ///
    `"1997 1997 DEMOG1997 demog demographic"' ///
    `"1997 1997 IDMAP97 id_map support"' ///
    `"1997 1997 PCG97_CHLD pcg_child primary_caregiver_child"' ///
    `"1997 1997 PCG97_HH pcg_household primary_caregiver_household"' ///
    `"1997 1997 OCG_CHLD97 ocg_child other_caregiver_child"' ///
    `"1997 1997 OCG_HHLD97 ocg_household other_caregiver_household"' ///
    `"1997 1997 FOH_CHLD97 foh_child father_outside_home_child"' ///
    `"1997 1997 FOH_HHLD97 foh_household father_outside_home_household"' ///
    `"2002 2002 DEMOG demog demographic"' ///
    `"2002 2002 GEN_MAP generational_map support"' ///
    `"2002 2002 IDMAP02 id_map support"' ///
    `"2002 2002 CHILD child child_interview"' ///
    `"2002 2002 PCG_CHLD pcg_child primary_caregiver_child"' ///
    `"2002 2002 PCG_HHLD pcg_household primary_caregiver_household"' ///
    `"2002 2002 OCG_CHLD ocg_child other_caregiver_child"' ///
    `"2002 2002 OCG_HHLD ocg_household other_caregiver_household"' ///
    `"2007 2007 DEMOG07 demog demographic"' ///
    `"2007 2007 GENMAP07 generational_map support"' ///
    `"2007 2007 IDMAP07 id_map support"' ///
    `"2007 2007 CHILD07 child child_interview"' ///
    `"2007 2007 PCG_CHILD07 pcg_child primary_caregiver_child"' ///
    `"2007 2007 PCG_HH07 pcg_household primary_caregiver_household"' ///
    `"2007 2007 OCG_CHILD07 ocg_child other_caregiver_child"' ///
    `"2007 2007 OCG_HH07 ocg_household other_caregiver_household"' ///
    `"2014 2014 DEMOG14 demog demographic"' ///
    `"2014 2014 HHROSTER14 household_roster household_roster"' ///
    `"2014 2014 IDMAP14 id_map support"' ///
    `"2014 2014 CHILD14 child child_interview"' ///
    `"2014 2014 PCGCHILD14 pcg_child primary_caregiver_child"' ///
    `"2014 2014 PCGHH14 pcg_household primary_caregiver_household"' ///
    `"2019 2019 DEMOG2019 demog demographic"' ///
    `"2019 2019 HHROSTER2019 household_roster household_roster"' ///
    `"2019 2019 CHILD2019 child child_interview"' ///
    `"2019 2019 PCGCHILD2019 pcg_child primary_caregiver_child"' ///
    `"2019 2019 PCGHH2019 pcg_household primary_caregiver_household"' ///
    `"2020 2020 DEMOG2019 demog_2019_carryover demographic"' ///
    `"2020 2020 HHROSTER2019 household_roster_2019_carryover household_roster"' ///
    `"2020 2020 CVH2020 covid_health covid_health"' ///
    `"2020 2020 PCGCHILD2020 pcg_child primary_caregiver_child"' ///
    `"2020 2020 PCGHH2020 pcg_household primary_caregiver_household"' ///
    `"2021 2021 DEMOG2021 demog demographic"' ///
    `"2021 2021 HHROSTER2021 household_roster household_roster"' ///
    `"2021 2021 CHILD2021 child child_interview"' ///
    `"2021 2021 PCGCHILD2021 pcg_child primary_caregiver_child"' ///
    `"2021 2021 PCGHH2021 pcg_household primary_caregiver_household"'

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
        psid_load_cds_cc_file `wave' `folder' `base' `file_key' `file_group' `write_csv_export'
        local loaded_files = `loaded_files' + 1
    }
}

if `loaded_files' == 0 {
    display as error "No CDS child/caregiver files matched the requested waves and file selection."
    error 2000
}
