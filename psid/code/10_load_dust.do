********************************************************************************
* 10_load_dust.do
*
* Purpose: Load selected PSID Disability and Use of Time Supplement (DUST)
*          public-use files as separate file-group outputs.
*
* Outputs: output/psid_dust_YYYY_group.dta
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
* do "$psid_root/code/10_load_dust.do"
*
* Output and DUST options:
* global psid_output_dir "/private/tmp/psid_dust_smoke"
* global psid_output_basename "psid_dust"
* global psid_write_csv_export 1
* global psid_dust_years "2013"
* global psid_dust_years "all"
* global psid_dust_files "household activity"
* global psid_dust_files "all"

local cwd "`c(pwd)'"
if "$psid_root" != "" & fileexists("$psid_root/code/10_load_dust.do") {
    global psid_root "$psid_root"
}
else if fileexists("code/10_load_dust.do") & fileexists("README.md") {
    global psid_root "`cwd'"
}
else if fileexists("10_load_dust.do") & fileexists("../README.md") {
    global psid_root "`cwd'/.."
}
else if fileexists("psid/code/10_load_dust.do") & fileexists("psid/README.md") {
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

global psid_dust_outdir "`output_dir'"
global psid_dust_base "`output_basename'"

local dust_years "2009 2013"
if "$psid_dust_years" != "" {
    local requested = lower("$psid_dust_years")
    if "`requested'" == "all" {
        local dust_years "2009 2013"
    }
    else {
        local dust_years "`requested'"
    }
}

foreach y of local dust_years {
    local valid_year = 0
    foreach allowed in 2009 2013 {
        if "`y'" == "`allowed'" {
            local valid_year = 1
        }
    }
    if !`valid_year' {
        display as error "Invalid DUST year: `y'"
        display as error "Choose from 2009 2013."
        error 198
    }
}

local dust_files "household flat observations activity parent_child"
if "$psid_dust_files" != "" {
    local requested = lower("$psid_dust_files")
    if "`requested'" != "all" {
        local dust_files ""
        foreach fg of local requested {
            local fg = subinstr("`fg'", "-", "_", .)
            if "`fg'" == "hh" {
                local fg "household"
            }
            else if "`fg'" == "obs" | "`fg'" == "observation" {
                local fg "observations"
            }
            else if "`fg'" == "act" {
                local fg "activity"
            }
            else if "`fg'" == "who" | "`fg'" == "parentchild" {
                local fg "parent_child"
            }
            local dust_files "`dust_files' `fg'"
        }
    }
}

foreach fg of local dust_files {
    local valid_file = 0
    foreach allowed in household flat observations activity parent_child {
        if "`fg'" == "`allowed'" {
            local valid_file = 1
        }
    }
    if !`valid_file' {
        display as error "Invalid DUST file group: `fg'"
        display as error "Choose from household flat observations activity parent_child."
        error 198
    }
}

local write_csv_export = 0
if "$psid_write_csv_export" == "1" {
    local write_csv_export = 1
}

display as text "Using PSID root: $psid_root"
display as text "Selected DUST years: `dust_years'"
display as text "Selected DUST file groups: `dust_files'"

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

capture program drop psid_load_dust_file
program define psid_load_dust_file
    args year file_group write_csv_export

    local folder ""
    local base ""
    local suffix ""

    if "`year'" == "2009" {
        local folder "dust09"
        if "`file_group'" == "household" {
            local base "DUST09_HH"
            local suffix "household"
        }
        else if "`file_group'" == "flat" {
            local base "DUST09_FLAT"
            local suffix "flat"
        }
        else if "`file_group'" == "observations" {
            local base "DUST09_OBS"
            local suffix "observations"
        }
        else if "`file_group'" == "activity" {
            local base "DUST09_ACT"
            local suffix "activity"
        }
        else if "`file_group'" == "parent_child" {
            display as text "Skipping DUST 2009 parent_child; that file group is available only in 2013."
            exit
        }
    }
    else if "`year'" == "2013" {
        local folder "dust13"
        if "`file_group'" == "household" {
            local base "DUST13_HH"
            local suffix "household"
        }
        else if "`file_group'" == "flat" {
            local base "DUST13_FLAT"
            local suffix "flat"
        }
        else if "`file_group'" == "observations" {
            local base "DUST13_OBS"
            local suffix "observations"
        }
        else if "`file_group'" == "activity" {
            local base "DUST13_ACT"
            local suffix "activity"
        }
        else if "`file_group'" == "parent_child" {
            local base "DUST13_WHO"
            local suffix "parent_child"
        }
    }

    if "`base'" == "" {
        display as error "Could not resolve DUST year/file group: `year' `file_group'"
        error 198
    }

    local raw_dir "data/supplemental_studies/disability_and_time_use/`folder'"
    local setup_path "`raw_dir'/`base'.do"
    local txt_path "`raw_dir'/`base'.txt"
    if !fileexists("`setup_path'") | !fileexists("`txt_path'") {
        display as error "Missing DUST files for `base'."
        error 601
    }

    display as text "Reading PSID DUST `year' `file_group'"
    psid_run_setup "`setup_path'" "`raw_dir'"
    rename _all, lower

    gen str32 source_module = "disability_and_time_use"
    gen str20 source_file = "`base'"
    gen int supplement_year = `year'
    gen str20 file_group = "`file_group'"
    order source_module source_file supplement_year file_group

    compress
    local out "${psid_dust_outdir}/${psid_dust_base}_dust_`year'_`suffix'.dta"
    save "`out'", replace
    if `write_csv_export' {
        export delimited using "${psid_dust_outdir}/${psid_dust_base}_dust_`year'_`suffix'.csv", replace
    }
    display as text "Saved DUST `year' `file_group': `out'"
end

local loaded_files = 0
foreach y of local dust_years {
    foreach fg of local dust_files {
        if "`y'" == "2009" & "`fg'" == "parent_child" {
            display as text "Skipping DUST 2009 parent_child; that file group is available only in 2013."
        }
        else {
            psid_load_dust_file `y' `fg' `write_csv_export'
            local loaded_files = `loaded_files' + 1
        }
    }
}

if `loaded_files' == 0 {
    display as error "No DUST files matched the requested years and file groups."
    error 2000
}
