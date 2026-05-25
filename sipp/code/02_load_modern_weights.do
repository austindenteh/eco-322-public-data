********************************************************************************
* 02_load_modern_weights.do
*
* Purpose: Load selected modern SIPP public-use weight files
*          (2018-2024 design era), keeping weight families separate.
*
* Outputs:
*   output/sipp_modern_replicate_weights_person_month.dta
*   output/sipp_modern_longitudinal_weights_person.dta
*   output/sipp_modern_longitudinal_replicate_weights_person.dta
********************************************************************************

clear all
set more off
set maxvar 32767

********************************************************************************
* USER SETTINGS
********************************************************************************

* Optional manual path override:
* global sipp_root "/Users/yourname/path/to/econ-data-starters/sipp"
* do "$sipp_root/code/02_load_modern_weights.do"
*
* Optional output override:
* global sipp_output_dir "/private/tmp/sipp_smoke"
* global sipp_output_basename "sipp_smoke"
*
* Main file choices:
* global sipp_weight_years "2024"
* global sipp_weight_years "2023 2024"
* global sipp_weight_years "all"
*
* Supported families:
* global sipp_weight_families "replicate"
* global sipp_weight_families "replicate longitudinal longitudinal_replicate"
* global sipp_weight_families "all"
*
* Longitudinal horizons. Leave blank for every local horizon.
* global sipp_longitudinal_horizons "2 3 4"
*
* Replicate columns. Use "all" when you need the full replicate-weight set.
* global sipp_replicate_numbers "0 1 2 3 4"
*
* Optional row limit for smoke tests. Leave blank for full files.
* global sipp_weight_n_max 1000
*
* Other options:
* global sipp_weight_skip_unreadable 1
* global sipp_weight_extra_vars "CTL_DATE"

********************************************************************************
* PATHS AND OPTIONS
********************************************************************************

local cwd "`c(pwd)'"
if "$sipp_root" != "" & fileexists("$sipp_root/code/02_load_modern_weights.do") {
    global sipp_root "$sipp_root"
}
else if fileexists("code/02_load_modern_weights.do") & fileexists("README.md") {
    global sipp_root "`cwd'"
}
else if fileexists("02_load_modern_weights.do") & fileexists("../README.md") {
    global sipp_root "`cwd'/.."
}
else if fileexists("sipp/code/02_load_modern_weights.do") & fileexists("sipp/README.md") {
    global sipp_root "`cwd'/sipp"
}
else {
    display as error "Could not locate the sipp/ directory."
    display as error "Run from sipp/, sipp/code/, repo root, or set global sipp_root."
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

local weight_years "2024"
if "$sipp_weight_years" != "" {
    local requested = lower("$sipp_weight_years")
    if "`requested'" == "all" {
        local weight_years "2018 2019 2020 2021 2022 2023 2024"
    }
    else {
        local weight_years "`requested'"
    }
}

foreach y of local weight_years {
    local valid_year = 0
    foreach allowed in 2018 2019 2020 2021 2022 2023 2024 {
        if "`y'" == "`allowed'" {
            local valid_year = 1
        }
    }
    if !`valid_year' {
        display as error "Invalid modern SIPP year: `y'"
        display as error "Choose from 2018 2019 2020 2021 2022 2023 2024."
        error 198
    }
}

local weight_families "replicate"
if "$sipp_weight_families" != "" {
    local requested = lower("$sipp_weight_families")
    if "`requested'" == "all" {
        local weight_families "replicate longitudinal longitudinal_replicate"
    }
    else {
        local weight_families "`requested'"
    }
}

foreach family of local weight_families {
    local valid_family = 0
    foreach allowed in replicate longitudinal longitudinal_replicate {
        if "`family'" == "`allowed'" {
            local valid_family = 1
        }
    }
    if !`valid_family' {
        display as error "Invalid SIPP weight family: `family'"
        display as error "Choose from replicate longitudinal longitudinal_replicate."
        error 198
    }
}

local replicate_numbers "0 1 2 3 4"
if "$sipp_replicate_numbers" != "" {
    local replicate_numbers = lower("$sipp_replicate_numbers")
}

local row_limit ""
if "$sipp_weight_n_max" != "" {
    local row_limit "$sipp_weight_n_max"
}

local skip_unreadable = 0
if "$sipp_weight_skip_unreadable" == "1" {
    local skip_unreadable = 1
}

global sipp_internal_weight_years "`weight_years'"
global sipp_internal_replicate_numbers "`replicate_numbers'"
global sipp_internal_row_limit "`row_limit'"
global sipp_internal_skip_unreadable `skip_unreadable'
global sipp_internal_output_dir "`output_dir'"
global sipp_internal_output_basename "`output_basename'"

display as text "Using SIPP root: $sipp_root"
display as text "Selected modern SIPP weight years: `weight_years'"
display as text "Selected weight families: `weight_families'"

********************************************************************************
* HELPERS
********************************************************************************

capture program drop sipp_weight_zip_path
program define sipp_weight_zip_path, rclass
    args year family horizon

    local zip_path ""
    local expected ""

    if "`family'" == "replicate" {
        local zip_path "data/`year'/rw`year'_dta.zip"
        local expected "rw`year'.dta"
    }
    else if "`family'" == "longitudinal" {
        if "`year'" == "2019" & "`horizon'" == "2" & fileexists("data/`year'/lgtwgt`year'_dta.zip") {
            local zip_path "data/`year'/lgtwgt`year'_dta.zip"
            local expected "lgtwgt`year'.dta"
        }
        else {
            local zip_path "data/`year'/lgtwgt`year'yr`horizon'_dta.zip"
            local expected "lgtwgt`year'yr`horizon'.dta"
        }
    }
    else if "`family'" == "longitudinal_replicate" {
        local zip_path "data/`year'/lgtrw`year'yr`horizon'_dta.zip"
        local expected "lgtrw`year'yr`horizon'.dta"
    }

    return local zip_path "`zip_path'"
    return local expected "`expected'"
end

capture program drop sipp_find_extracted_dta
program define sipp_find_extracted_dta, rclass
    args year expected

    local candidates `"`expected'"'
    local candidates `"`candidates' "hhesshare/sipp_public_use_data/`year'/STATA/optimized/`expected'""'
    local candidates `"`candidates' "data/sehsd7/hhesshare/sipp_public_use_data/`year'/STATA/`expected'""'
    local candidates `"`candidates' "data/sehsd7/hhesshare/sipp_public_use_data/`year'/STATA/optimized/`expected'""'

    foreach path of local candidates {
        if fileexists("`path'") {
            return local dta_path "`path'"
            exit
        }
    }

    return local dta_path ""
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

capture program drop sipp_load_weight_file
program define sipp_load_weight_file
    args year family horizon output_file skip_unreadable

    sipp_weight_zip_path `year' `family' `horizon'
    local zip_path "`r(zip_path)'"
    local expected "`r(expected)'"

    if "`zip_path'" == "" | !fileexists("`zip_path'") {
        if `skip_unreadable' {
            display as text "Skipping SIPP `year' `family' horizon `horizon': local zip not found."
            exit
        }
        display as error "Local SIPP weight zip not found: `zip_path'"
        error 601
    }

    local old_cwd "`c(pwd)'"
    local extract_dir "`c(tmpdir)'/sipp_weight_`year'_`family'_`horizon'_extract"
    capture mkdir "`extract_dir'"
    cd "`extract_dir'"
    capture noisily unzipfile "`old_cwd'/`zip_path'", replace
    if _rc {
        cd "`old_cwd'"
        if `skip_unreadable' {
            display as text "Skipping SIPP `year' `family' horizon `horizon': could not unzip `zip_path'."
            exit
        }
        display as error "Could not unzip `zip_path'."
        error 601
    }

    sipp_find_extracted_dta `year' "`expected'"
    local dta_path "`r(dta_path)'"
    if "`dta_path'" == "" {
        cd "`old_cwd'"
        if `skip_unreadable' {
            display as text "Skipping SIPP `year' `family' horizon `horizon': `expected' not found after unzip."
            exit
        }
        display as error "Expected `expected' inside `zip_path' but did not find it."
        error 601
    }

    quietly describe using "`dta_path'", varlist
    local all_vars "`r(varlist)'"
    local keep_vars ""

    foreach v in ssuid pnum spanel panel swave monthcode ctl_date lgtwttyp initial_year final_year {
        sipp_add_var_if_present "`v'" "`all_vars'" "`keep_vars'"
        local keep_vars "`r(vars)'"
    }

    if "`family'" == "longitudinal" {
        sipp_add_var_if_present "finyr`horizon'" "`all_vars'" "`keep_vars'"
        local keep_vars "`r(vars)'"
    }
    else {
        if "$sipp_internal_replicate_numbers" == "all" {
            foreach raw of local all_vars {
                if regexm(lower("`raw'"), "^repwgt[0-9]+$") {
                    local keep_vars "`keep_vars' `raw'"
                }
            }
        }
        else {
            local replicate_numbers "$sipp_internal_replicate_numbers"
            foreach n of local replicate_numbers {
                sipp_add_var_if_present "repwgt`n'" "`all_vars'" "`keep_vars'"
                local keep_vars "`r(vars)'"
            }
        }
    }

    foreach v in $sipp_weight_extra_vars {
        sipp_add_var_if_present "`v'" "`all_vars'" "`keep_vars'"
        local keep_vars "`r(vars)'"
    }

    local keep_vars : list uniq keep_vars
    if "`keep_vars'" == "" {
        cd "`old_cwd'"
        if `skip_unreadable' {
            display as text "Skipping SIPP `year' `family' horizon `horizon': no selected variables."
            exit
        }
        display as error "No variables selected from `zip_path'."
        error 198
    }

    display as text "Reading SIPP `year' `family' weights, horizon `horizon': `zip_path'"
    if "$sipp_internal_row_limit" != "" {
        use `keep_vars' using "`dta_path'" in 1/$sipp_internal_row_limit, clear
    }
    else {
        use `keep_vars' using "`dta_path'", clear
    }
    rename _all, lower

    capture confirm variable panel
    if !_rc {
        capture confirm variable spanel
        if _rc {
            rename panel spanel
        }
    }

    gen str40 source_file = "`expected'"
    gen str28 weight_family = "`family'"
    gen int sipp_file_year = `year'
    if "`family'" == "replicate" {
        gen int reference_year = `year' - 1
    }
    else {
        gen byte longitudinal_horizon = `horizon'
    }

    order source_file weight_family sipp_file_year
    compress
    save "`output_file'", replace
    cd "`old_cwd'"
end

capture program drop sipp_append_weight_family
program define sipp_append_weight_family
    args family suffix

    local first_file = 1
    local loaded_files = 0
    tempfile combined

    foreach y in $sipp_internal_weight_years {
        local horizons "."
        if "`family'" != "replicate" {
            local horizons "$sipp_longitudinal_horizons"
            if "`horizons'" == "" {
                local horizons ""
                foreach h in 2 3 4 {
                    sipp_weight_zip_path `y' `family' `h'
                    if fileexists("`r(zip_path)'") {
                        local horizons "`horizons' `h'"
                    }
                }
            }
        }

        if "`family'" != "replicate" & "`horizons'" == "" {
            if $sipp_internal_skip_unreadable {
                display as text "Skipping SIPP `y' `family': no local longitudinal horizons found."
                continue
            }
            display as error "No local longitudinal horizons found for SIPP `y' `family'."
            error 601
        }

        foreach h of local horizons {
            tempfile one_file
            capture noisily sipp_load_weight_file `y' `family' `h' "`one_file'" $sipp_internal_skip_unreadable
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
    }

    if `loaded_files' == 0 {
        display as text "No SIPP `family' weight files were loaded."
        exit
    }

    use "`combined'", clear
    compress
    save "$sipp_internal_output_dir/$sipp_internal_output_basename`suffix'.dta", replace
    display as text "Saved SIPP `family' weights: $sipp_internal_output_dir/$sipp_internal_output_basename`suffix'.dta"
end

foreach family of local weight_families {
    if "`family'" == "replicate" {
        sipp_append_weight_family replicate "_modern_replicate_weights_person_month"
    }
    else if "`family'" == "longitudinal" {
        sipp_append_weight_family longitudinal "_modern_longitudinal_weights_person"
    }
    else if "`family'" == "longitudinal_replicate" {
        sipp_append_weight_family longitudinal_replicate "_modern_longitudinal_replicate_weights_person"
    }
}
