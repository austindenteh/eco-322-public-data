********************************************************************************
* 05_load_2014_panel_weights.do
*
* Purpose: Load selected 2014 SIPP panel weight files, keeping cross-sectional
*          replicate, longitudinal final, and longitudinal replicate families
*          separate.
********************************************************************************

clear all
set more off
set maxvar 32767

********************************************************************************
* USER SETTINGS
********************************************************************************

* Optional manual path override:
* global sipp_root "/Users/yourname/path/to/econ-data-starters/sipp"
* do "$sipp_root/code/05_load_2014_panel_weights.do"
*
* Optional output override:
* global sipp_output_dir "/private/tmp/sipp_smoke"
* global sipp_output_basename "sipp_smoke"
*
* Main file choices:
* global sipp_2014_weight_waves "4"
* global sipp_2014_weight_waves "2 3 4"
* global sipp_2014_weight_waves "all"
* global sipp_2014_weight_families "replicate"
* global sipp_2014_weight_families "replicate longitudinal longitudinal_replicate"
* global sipp_2014_weight_families "all"
*
* Replicate columns. Use "all" when you need the full replicate-weight set.
* The 2014 panel files use repwt1-repwt240; there is no repwt0.
* global sipp_2014_replicate_numbers "1 2 3 4"
*
* Longitudinal final panels. Leave blank for every local FINPNL* column.
* global sipp_2014_longitudinal_panels "2 3 4"
*
* Optional row limit for smoke tests. Leave blank for full files.
* global sipp_2014_weight_n_max 1000
*
* Other options:
* global sipp_2014_weight_skip_unreadable 1

********************************************************************************
* PATHS AND OPTIONS
********************************************************************************

local cwd "`c(pwd)'"
if "$sipp_root" != "" & fileexists("$sipp_root/code/05_load_2014_panel_weights.do") {
    global sipp_root "$sipp_root"
}
else if fileexists("code/05_load_2014_panel_weights.do") & fileexists("README.md") {
    global sipp_root "`cwd'"
}
else if fileexists("05_load_2014_panel_weights.do") & fileexists("../README.md") {
    global sipp_root "`cwd'/.."
}
else if fileexists("sipp/code/05_load_2014_panel_weights.do") & fileexists("sipp/README.md") {
    global sipp_root "`cwd'/sipp"
}
else {
    display as error "Could not locate the sipp/ directory."
    error 601
}

cd "$sipp_root"
capture mkdir "output"

local output_dir "output"
if "$sipp_output_dir" != "" {
    local output_dir "$sipp_output_dir"
    capture mkdir "`output_dir'"
}

local output_basename "sipp"
if "$sipp_output_basename" != "" {
    local output_basename "$sipp_output_basename"
}

local waves "4"
if "$sipp_2014_weight_waves" != "" {
    local requested = lower("$sipp_2014_weight_waves")
    if "`requested'" == "all" {
        local waves "1 2 3 4"
    }
    else {
        local waves "`requested'"
    }
}

local families "replicate"
if "$sipp_2014_weight_families" != "" {
    local requested = lower("$sipp_2014_weight_families")
    if "`requested'" == "all" {
        local families "replicate longitudinal longitudinal_replicate"
    }
    else {
        local families "`requested'"
    }
}

local replicate_numbers "1 2 3 4"
if "$sipp_2014_replicate_numbers" != "" {
    local replicate_numbers = lower("$sipp_2014_replicate_numbers")
}

local row_limit ""
if "$sipp_2014_weight_n_max" != "" {
    local row_limit "$sipp_2014_weight_n_max"
}

local skip_unreadable = 0
if "$sipp_2014_weight_skip_unreadable" == "1" {
    local skip_unreadable = 1
}

global sipp_i14_wgt_waves "`waves'"
global sipp_i14_reps "`replicate_numbers'"
global sipp_i14_row_limit "`row_limit'"
global sipp_i14_skip `skip_unreadable'
global sipp_i14_outdir "`output_dir'"
global sipp_i14_base "`output_basename'"

display as text "Using SIPP root: $sipp_root"
display as text "Selected 2014 SIPP weight waves: `waves'"
display as text "Selected 2014 SIPP weight families: `families'"

********************************************************************************
* HELPERS
********************************************************************************

capture program drop sipp_2014_weight_path
program define sipp_2014_weight_path, rclass
    args wave family
    local gz_path ""
    local dta_name ""
    if "`family'" == "replicate" {
        local gz_path "data/2014/panel_wave`wave'/rw14w`wave'_v13.dta.gz"
        local dta_name "rw14w`wave'_v13.dta"
    }
    else if "`family'" == "longitudinal" {
        local gz_path "data/2014/panel_wave`wave'/lgtwgt2014pnl`wave'_v13.dta.gz"
        local dta_name "lgtwgt2014pnl`wave'_v13.dta"
    }
    else if "`family'" == "longitudinal_replicate" {
        local gz_path "data/2014/panel_wave`wave'/lrw2014pnl`wave'_v13.dta.gz"
        local dta_name "lrw2014pnl`wave'_v13.dta"
    }
    return local gz_path "`gz_path'"
    return local dta_name "`dta_name'"
end

capture program drop sipp_add_var_if_present
program define sipp_add_var_if_present, rclass
    args wanted all_vars current
    local matched ""
    foreach raw of local all_vars {
        if lower("`raw'") == lower("`wanted'") & "`matched'" == "" {
            local matched "`raw'"
        }
    }
    if "`matched'" != "" {
        local current "`current' `matched'"
    }
    return local vars "`current'"
end

capture program drop sipp_load_2014_weight_file
program define sipp_load_2014_weight_file
    args wave family output_file skip_unreadable

    sipp_2014_weight_path `wave' `family'
    local gz_path "`r(gz_path)'"
    local dta_name "`r(dta_name)'"

    if !fileexists("`gz_path'") {
        if `skip_unreadable' {
            display as text "Skipping 2014 wave `wave' `family': local weight file not found."
            exit
        }
        display as error "Local 2014 SIPP weight file not found: `gz_path'"
        error 601
    }

    local old_cwd "`c(pwd)'"
    local extract_dir "`c(tmpdir)'/sipp_2014_weight_`wave'_`family'_extract"
    capture mkdir "`extract_dir'"
    local dta_path "`extract_dir'/`dta_name'"
    capture erase "`dta_path'"
    shell gzip -dc "`old_cwd'/`gz_path'" > "`dta_path'"

    capture noisily describe using "`dta_path'", varlist
    if _rc {
        if `skip_unreadable' {
            display as text "Skipping 2014 wave `wave' `family': could not read decompressed file."
            exit
        }
        display as error "Could not read decompressed 2014 SIPP weight file: `gz_path'"
        error 601
    }

    quietly describe using "`dta_path'", varlist
    local all_vars "`r(varlist)'"
    local keep_vars ""

    foreach v in ssuid pnum spanel swave monthcode ctl_date lgtwttyp pnllength {
        sipp_add_var_if_present "`v'" "`all_vars'" "`keep_vars'"
        local keep_vars "`r(vars)'"
    }

    if "`family'" == "replicate" {
        if "$sipp_i14_reps" == "all" {
            foreach raw of local all_vars {
                if regexm(lower("`raw'"), "^repwt[0-9]+$") {
                    local keep_vars "`keep_vars' `raw'"
                }
            }
        }
        else {
            local reps "$sipp_i14_reps"
            foreach n of local reps {
                capture confirm number `n'
                if _rc {
                    display as text "Skipping invalid 2014 replicate number: `n'"
                    continue
                }
                if `n' < 1 {
                    display as text "2014 SIPP replicate weights start at 1; skipping invalid replicate number: `n'"
                    continue
                }
                sipp_add_var_if_present "repwt`n'" "`all_vars'" "`keep_vars'"
                local keep_vars "`r(vars)'"
            }
        }
    }
    else if "`family'" == "longitudinal" {
        local panels "$sipp_2014_longitudinal_panels"
        if "`panels'" == "" {
            foreach raw of local all_vars {
                if regexm(lower("`raw'"), "^finpnl[0-9]+$") {
                    local keep_vars "`keep_vars' `raw'"
                }
            }
        }
        else {
            foreach p of local panels {
                sipp_add_var_if_present "finpnl`p'" "`all_vars'" "`keep_vars'"
                local keep_vars "`r(vars)'"
            }
        }
    }
    else if "`family'" == "longitudinal_replicate" {
        if "$sipp_i14_reps" == "all" {
            foreach raw of local all_vars {
                if regexm(lower("`raw'"), "^repwgt[0-9]+$") {
                    local keep_vars "`keep_vars' `raw'"
                }
            }
        }
        else {
            local reps "$sipp_i14_reps"
            foreach n of local reps {
                capture confirm number `n'
                if _rc {
                    display as text "Skipping invalid 2014 replicate number: `n'"
                    continue
                }
                if `n' < 1 {
                    display as text "2014 SIPP replicate weights start at 1; skipping invalid replicate number: `n'"
                    continue
                }
                sipp_add_var_if_present "repwgt`n'" "`all_vars'" "`keep_vars'"
                local keep_vars "`r(vars)'"
            }
        }
    }

    local keep_vars : list uniq keep_vars
    if "`keep_vars'" == "" {
        display as error "No variables selected from 2014 SIPP `family' weight file."
        error 198
    }

    display as text "Reading 2014 SIPP wave `wave' `family' weights"
    if "$sipp_i14_row_limit" != "" {
        use `keep_vars' using "`dta_path'" in 1/$sipp_i14_row_limit, clear
    }
    else {
        use `keep_vars' using "`dta_path'", clear
    }
    rename _all, lower
    gen str28 source_file = "`dta_name'"
    gen str28 weight_family = "`family'"
    gen int sipp_file_year = 2014
    gen byte panel_wave = `wave'
    order source_file weight_family sipp_file_year panel_wave
    compress
    save "`output_file'", replace
    capture erase "`dta_path'"
    cd "`old_cwd'"
end

capture program drop sipp_append_2014_weight_family
program define sipp_append_2014_weight_family
    args family suffix
    local first_file = 1
    local loaded_files = 0
    tempfile combined

    foreach w in $sipp_i14_wgt_waves {
        tempfile one_file
        capture noisily sipp_load_2014_weight_file `w' `family' "`one_file'" $sipp_i14_skip
        if _rc {
            error _rc
        }
        capture confirm file "`one_file'"
        if !_rc {
            if `first_file' {
                use "`one_file'", clear
                save "`combined'", replace
                local first_file = 0
            }
            else {
                use "`combined'", clear
                append using "`one_file'"
                save "`combined'", replace
            }
            local loaded_files = `loaded_files' + 1
        }
    }

    if `loaded_files' == 0 {
        display as text "No 2014 SIPP `family' weight files were loaded."
        exit
    }

    use "`combined'", clear
    compress
    save "$sipp_i14_outdir/$sipp_i14_base`suffix'.dta", replace
    display as text "Saved 2014 SIPP `family' weights: $sipp_i14_outdir/$sipp_i14_base`suffix'.dta"
end

foreach family of local families {
    if "`family'" == "replicate" {
        sipp_append_2014_weight_family replicate "_2014_replicate_weights_person_month"
    }
    else if "`family'" == "longitudinal" {
        sipp_append_2014_weight_family longitudinal "_2014_longitudinal_weights_person"
    }
    else if "`family'" == "longitudinal_replicate" {
        sipp_append_2014_weight_family longitudinal_replicate "_2014_longitudinal_replicate_weights_person"
    }
}
