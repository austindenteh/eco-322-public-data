********************************************************************************
* 11_load_intergenerational_transfers.do
*
* Purpose: Load selected PSID intergenerational transfer public-use files as
*          separate outputs.
*
* Outputs: output/psid_intergen_*.dta
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
* do "$psid_root/code/11_load_intergenerational_transfers.do"
*
* Output and file-selection options:
* global psid_output_dir "/private/tmp/psid_intergen_smoke"
* global psid_output_basename "psid_intergen"
* global psid_write_csv_export 1
* global psid_intergen_files "tmt88 rt13_family"
* global psid_intergen_files "all"

local cwd "`c(pwd)'"
if "$psid_root" != "" & fileexists("$psid_root/code/11_load_intergenerational_transfers.do") {
    global psid_root "$psid_root"
}
else if fileexists("code/11_load_intergenerational_transfers.do") & fileexists("README.md") {
    global psid_root "`cwd'"
}
else if fileexists("11_load_intergenerational_transfers.do") & fileexists("../README.md") {
    global psid_root "`cwd'/.."
}
else if fileexists("psid/code/11_load_intergenerational_transfers.do") & fileexists("psid/README.md") {
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

global psid_igen_outdir "`output_dir'"
global psid_igen_base "`output_basename'"

local intergen_files "tmt88 rt13_family rt13_parent_child"
if "$psid_intergen_files" != "" {
    local requested = lower("$psid_intergen_files")
    if "`requested'" != "all" {
        local intergen_files ""
        foreach f of local requested {
            local f = subinstr("`f'", "-", "_", .)
            if "`f'" == "tmt" | "`f'" == "time_money" {
                local f "tmt88"
            }
            else if "`f'" == "rt13fam" | "`f'" == "rt13_fam" | "`f'" == "family" {
                local f "rt13_family"
            }
            else if "`f'" == "rt13parchd" | "`f'" == "rt13_parentchild" | "`f'" == "parent_child" {
                local f "rt13_parent_child"
            }
            local intergen_files "`intergen_files' `f'"
        }
    }
}

foreach f of local intergen_files {
    local valid_file = 0
    foreach allowed in tmt88 rt13_family rt13_parent_child {
        if "`f'" == "`allowed'" {
            local valid_file = 1
        }
    }
    if !`valid_file' {
        display as error "Invalid intergenerational-transfer file: `f'"
        display as error "Choose from tmt88 rt13_family rt13_parent_child."
        error 198
    }
}

local write_csv_export = 0
if "$psid_write_csv_export" == "1" {
    local write_csv_export = 1
}

display as text "Using PSID root: $psid_root"
display as text "Selected intergenerational-transfer files: `intergen_files'"

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

capture program drop psid_load_intergen_file
program define psid_load_intergen_file
    args file_key write_csv_export

    local folder ""
    local base ""
    local supplement_year .
    local file_group ""
    local suffix ""

    if "`file_key'" == "tmt88" {
        local folder "tmt88"
        local base "TMT88"
        local supplement_year 1988
        local file_group "time_money_transfers"
        local suffix "tmt88"
    }
    else if "`file_key'" == "rt13_family" {
        local folder "RT13"
        local base "RT13FAM"
        local supplement_year 2013
        local file_group "family_roster"
        local suffix "rt13_family"
    }
    else if "`file_key'" == "rt13_parent_child" {
        local folder "RT13"
        local base "RT13PARCHD"
        local supplement_year 2013
        local file_group "parent_child"
        local suffix "rt13_parent_child"
    }

    if "`base'" == "" {
        display as error "Could not resolve intergenerational-transfer file: `file_key'"
        error 198
    }

    local raw_dir "data/supplemental_studies/intergenerational_transfers/`folder'"
    local setup_path "`raw_dir'/`base'.do"
    local txt_path "`raw_dir'/`base'.txt"
    if !fileexists("`setup_path'") | !fileexists("`txt_path'") {
        display as error "Missing intergenerational-transfer files for `base'."
        error 601
    }

    display as text "Reading PSID intergenerational transfers: `file_key'"
    psid_run_setup "`setup_path'" "`raw_dir'"
    rename _all, lower

    gen str32 source_module = "intergenerational_transfers"
    gen str20 source_file = "`base'"
    gen int supplement_year = `supplement_year'
    gen str24 file_group = "`file_group'"
    order source_module source_file supplement_year file_group

    compress
    local out "${psid_igen_outdir}/${psid_igen_base}_intergen_`suffix'.dta"
    save "`out'", replace
    if `write_csv_export' {
        export delimited using "${psid_igen_outdir}/${psid_igen_base}_intergen_`suffix'.csv", replace
    }
    display as text "Saved intergenerational transfers `file_key': `out'"
end

foreach f of local intergen_files {
    psid_load_intergen_file `f' `write_csv_export'
}
