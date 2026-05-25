********************************************************************************
* 12_load_web_mixed_mode.do
*
* Purpose: Load selected PSID web/mixed-mode supplement public-use files as
*          separate outputs.
*
* Outputs: output/psid_web_*.dta
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
* do "$psid_root/code/12_load_web_mixed_mode.do"
*
* Output and supplement-selection options:
* global psid_output_dir "/private/tmp/psid_web_smoke"
* global psid_output_basename "psid_web"
* global psid_write_csv_export 1
* global psid_web_supplements "crcs14"
* global psid_web_supplements "all"

local cwd "`c(pwd)'"
if "$psid_root" != "" & fileexists("$psid_root/code/12_load_web_mixed_mode.do") {
    global psid_root "$psid_root"
}
else if fileexists("code/12_load_web_mixed_mode.do") & fileexists("README.md") {
    global psid_root "`cwd'"
}
else if fileexists("12_load_web_mixed_mode.do") & fileexists("../README.md") {
    global psid_root "`cwd'/.."
}
else if fileexists("psid/code/12_load_web_mixed_mode.do") & fileexists("psid/README.md") {
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

global psid_web_outdir "`output_dir'"
global psid_web_base "`output_basename'"

local web_supplements "crcs14 wb2016"
if "$psid_web_supplements" != "" {
    local requested = lower("$psid_web_supplements")
    if "`requested'" != "all" {
        local web_supplements ""
        foreach s of local requested {
            local s = subinstr("`s'", "-", "_", .)
            if "`s'" == "crcs" | "`s'" == "childhood_retrospective" | "`s'" == "childhood_retrospective_circumstances" {
                local s "crcs14"
            }
            else if "`s'" == "wb" | "`s'" == "wellbeing" | "`s'" == "wellbeing_daily_life" {
                local s "wb2016"
            }
            local web_supplements "`web_supplements' `s'"
        }
    }
}

foreach s of local web_supplements {
    local valid_supplement = 0
    foreach allowed in crcs14 wb2016 {
        if "`s'" == "`allowed'" {
            local valid_supplement = 1
        }
    }
    if !`valid_supplement' {
        display as error "Invalid web/mixed-mode supplement: `s'"
        display as error "Choose from crcs14 wb2016."
        error 198
    }
}

local write_csv_export = 0
if "$psid_write_csv_export" == "1" {
    local write_csv_export = 1
}

display as text "Using PSID root: $psid_root"
display as text "Selected web/mixed-mode supplements: `web_supplements'"

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

capture program drop psid_load_web_supplement
program define psid_load_web_supplement
    args supplement_key write_csv_export

    local folder ""
    local base ""
    local supplement_year .
    local file_group ""
    local suffix ""

    if "`supplement_key'" == "crcs14" {
        local folder "CRCS14"
        local base "CRCS14"
        local supplement_year 2014
        local file_group "childhood_retrospective_circumstances"
        local suffix "crcs14"
    }
    else if "`supplement_key'" == "wb2016" {
        local folder "WB2016"
        local base "WB2016"
        local supplement_year 2016
        local file_group "wellbeing_daily_life"
        local suffix "wb2016"
    }

    if "`base'" == "" {
        display as error "Could not resolve web/mixed-mode supplement: `supplement_key'"
        error 198
    }

    local raw_dir "data/supplemental_studies/web_mixed_mode_supplement/`folder'"
    local setup_path "`raw_dir'/`base'.do"
    local txt_path "`raw_dir'/`base'.txt"
    if !fileexists("`setup_path'") | !fileexists("`txt_path'") {
        display as error "Missing web/mixed-mode supplement files for `base'."
        error 601
    }

    display as text "Reading PSID web/mixed-mode supplement: `supplement_key'"
    psid_run_setup "`setup_path'" "`raw_dir'"
    rename _all, lower

    gen str32 source_module = "web_mixed_mode_supplement"
    gen str20 source_file = "`base'"
    gen int supplement_year = `supplement_year'
    gen str48 file_group = "`file_group'"
    order source_module source_file supplement_year file_group

    compress
    local out "${psid_web_outdir}/${psid_web_base}_web_`suffix'.dta"
    save "`out'", replace
    if `write_csv_export' {
        export delimited using "${psid_web_outdir}/${psid_web_base}_web_`suffix'.csv", replace
    }
    display as text "Saved web/mixed-mode supplement `supplement_key': `out'"
end

foreach s of local web_supplements {
    psid_load_web_supplement `s' `write_csv_export'
}
