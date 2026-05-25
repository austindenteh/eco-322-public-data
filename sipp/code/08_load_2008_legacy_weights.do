********************************************************************************
* 08_load_2008_legacy_weights.do
*
* Purpose: Load selected 2008 SIPP legacy fixed-width weight files.
********************************************************************************

clear all
set more off

********************************************************************************
* USER SETTINGS
********************************************************************************

* Optional manual path override:
* global sipp_root "/Users/yourname/path/to/econ-data-starters/sipp"
* do "$sipp_root/code/08_load_2008_legacy_weights.do"
*
* Optional output override:
* global sipp_output_dir "/private/tmp/sipp_smoke"
* global sipp_output_basename "sipp_smoke"
*
* Families: replicate, longitudinal, longitudinal_replicate, or all.
* global sipp_2008_weight_families "replicate"
* global sipp_2008_weight_waves "16"
* global sipp_2008_replicate_numbers "1 2 3 4"
*
* Longitudinal replicate type: panel_year or calendar_year.
* global sipp_2008_lrw_type "panel_year"
* global sipp_2008_lrw_indices "5"
*
* Optional row limit for smoke tests. Leave blank for full files.
* global sipp_2008_weight_n_max 1000
* global sipp_2008_weight_skip_unreadable 1

********************************************************************************
* PATHS AND OPTIONS
********************************************************************************

local cwd "`c(pwd)'"
if "$sipp_root" != "" & fileexists("$sipp_root/code/08_load_2008_legacy_weights.do") {
    global sipp_root "$sipp_root"
}
else if fileexists("code/08_load_2008_legacy_weights.do") & fileexists("README.md") {
    global sipp_root "`cwd'"
}
else if fileexists("08_load_2008_legacy_weights.do") & fileexists("../README.md") {
    global sipp_root "`cwd'/.."
}
else if fileexists("sipp/code/08_load_2008_legacy_weights.do") & fileexists("sipp/README.md") {
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

local families "replicate"
if "$sipp_2008_weight_families" != "" {
    local requested = lower("$sipp_2008_weight_families")
    if "`requested'" == "all" {
        local families "replicate longitudinal longitudinal_replicate"
    }
    else {
        local families "`requested'"
    }
}

local waves "16"
if "$sipp_2008_weight_waves" != "" {
    local requested = lower("$sipp_2008_weight_waves")
    if "`requested'" == "all" {
        local waves "1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16"
    }
    else {
        local waves "`requested'"
    }
}

local reps "1 2 3 4"
if "$sipp_2008_replicate_numbers" != "" {
    local reps = lower("$sipp_2008_replicate_numbers")
}

local row_limit ""
if "$sipp_2008_weight_n_max" != "" {
    local row_limit "$sipp_2008_weight_n_max"
}
global sipp_i08_wgt_rows "`row_limit'"

local skip_unreadable = 0
if "$sipp_2008_weight_skip_unreadable" == "1" {
    local skip_unreadable = 1
}

global sipp_i08_wgt_waves "`waves'"
global sipp_i08_reps "`reps'"
global sipp_i08_skip `skip_unreadable'
global sipp_i08_outdir "`output_dir'"
global sipp_i08_base "`output_basename'"

********************************************************************************
* HELPERS
********************************************************************************

capture program drop sipp_decompress_gz
program define sipp_decompress_gz, rclass
    args source output
    capture erase "`output'"
    shell gzip -dc "`source'" > "`output'"
    capture confirm file "`output'"
    if _rc {
        return scalar ok = 0
    }
    else {
        return scalar ok = 1
    }
end

capture program drop sipp_2008_replicate_spec
program define sipp_2008_replicate_spec, rclass
    args prefix start width maxrep
    local spec ""
    if "$sipp_i08_reps" == "all" {
        forvalues n = 1/`maxrep' {
            local a = `start' + (`n' - 1) * `width'
            local b = `a' + `width' - 1
            local spec "`spec' `prefix'`n' `a'-`b'"
        }
    }
    else {
        foreach n in $sipp_i08_reps {
            if `n' >= 1 & `n' <= `maxrep' {
                local a = `start' + (`n' - 1) * `width'
                local b = `a' + `width' - 1
                local spec "`spec' `prefix'`n' `a'-`b'"
            }
        }
    }
    return local spec "`spec'"
end

capture program drop sipp_load_2008_replicate_wave
program define sipp_load_2008_replicate_wave
    args wave output_file skip_unreadable
    local dat_gz "$sipp_root/data/2008/wave`wave'/rw08w`wave'.dat.gz"
    if !fileexists("`dat_gz'") {
        if `skip_unreadable' exit
        display as error "No 2008 replicate-weight file found: `dat_gz'"
        error 601
    }
    local extract_dir "`c(tmpdir)'/sipp_2008_rep_wave`wave'_extract"
    capture mkdir "`extract_dir'"
    local dat_path "`extract_dir'/rw08w`wave'.dat"
    sipp_decompress_gz "`dat_gz'" "`dat_path'"
    if !r(ok) {
        if `skip_unreadable' exit
        display as error "Could not decompress `dat_gz'."
        error 601
    }
    sipp_2008_replicate_spec repwgt 24 10 120
    local rep_spec "`r(spec)'"
    local infix_spec "str ssuid 1-12 spanel 13-16 swave 17-18 srefmon 19-19 epppnum 20-23 `rep_spec'"
    if "$sipp_i08_wgt_rows" != "" {
        infix `infix_spec' using "`dat_path'" in 1/$sipp_i08_wgt_rows, clear
    }
    else {
        infix `infix_spec' using "`dat_path'", clear
    }
    gen int pnum = epppnum
    gen str12 source_file = "rw08w`wave'.dat"
    gen str24 weight_family = "replicate"
    gen int sipp_file_year = 2008
    gen byte panel_wave = `wave'
    order source_file weight_family sipp_file_year panel_wave
    compress
    save "`output_file'", replace
end

capture program drop sipp_load_2008_longitudinal
program define sipp_load_2008_longitudinal
    args output_file
    local dat_gz "$sipp_root/data/2008/lgtwgt2008w16.dat.gz"
    local extract_dir "`c(tmpdir)'/sipp_2008_lgtwgt_extract"
    capture mkdir "`extract_dir'"
    local dat_path "`extract_dir'/lgtwgt2008w16.dat"
    sipp_decompress_gz "`dat_gz'" "`dat_path'"
    if !r(ok) {
        display as error "Could not decompress `dat_gz'."
        error 601
    }
    local infix_spec "lgtkey 1-8 spanel 9-12 str ssuid 13-24 epppnum 25-28 lgtpn1wt 29-38 lgtpn2wt 39-48 lgtpn3wt 49-58 lgtpn4wt 59-68 lgtpn5wt 69-78 lgtcy1wt 79-88 lgtcy2wt 89-98 lgtcy3wt 99-108 lgtcy4wt 109-118 lgtcy5wt 119-128"
    if "$sipp_i08_wgt_rows" != "" {
        infix `infix_spec' using "`dat_path'" in 1/$sipp_i08_wgt_rows, clear
    }
    else {
        infix `infix_spec' using "`dat_path'", clear
    }
    gen int pnum = epppnum
    gen str18 source_file = "lgtwgt2008w16.dat"
    gen str24 weight_family = "longitudinal"
    gen int sipp_file_year = 2008
    order source_file weight_family sipp_file_year
    compress
    save "`output_file'", replace
end

capture program drop sipp_load_2008_lrw
program define sipp_load_2008_lrw
    args index output_file
    local rep_type "$sipp_2008_lrw_type"
    if "`rep_type'" == "" local rep_type "panel_year"
    if "`rep_type'" == "calendar_year" {
        local dat_gz "$sipp_root/data/2008/longitudinal_replicate_weight/lrw08cy`index'.dat.gz"
        local src "lrw08cy`index'.dat"
    }
    else {
        local dat_gz "$sipp_root/data/2008/longitudinal_replicate_weight_for_panel_year/lrw08pn`index'.dat.gz"
        local src "lrw08pn`index'.dat"
    }
    local extract_dir "`c(tmpdir)'/sipp_2008_lrw_`index'_extract"
    capture mkdir "`extract_dir'"
    local dat_path "`extract_dir'/`src'"
    sipp_decompress_gz "`dat_gz'" "`dat_path'"
    if !r(ok) {
        display as error "Could not decompress `dat_gz'."
        error 601
    }
    sipp_2008_replicate_spec repwgt 33 10 120
    local rep_spec "`r(spec)'"
    local infix_spec "str ssuid 1-12 spanel 13-16 str ctl_date 17-23 str lgtwttyp 24-26 pnllength 27-28 epppnum 29-32 `rep_spec'"
    if "$sipp_i08_wgt_rows" != "" {
        infix `infix_spec' using "`dat_path'" in 1/$sipp_i08_wgt_rows, clear
    }
    else {
        infix `infix_spec' using "`dat_path'", clear
    }
    gen int pnum = epppnum
    gen str12 source_file = "`src'"
    gen str24 weight_family = "longitudinal_replicate"
    gen int sipp_file_year = 2008
    gen str14 longitudinal_replicate_type = "`rep_type'"
    gen byte longitudinal_index = `index'
    order source_file weight_family sipp_file_year longitudinal_replicate_type longitudinal_index
    compress
    save "`output_file'", replace
end

capture program drop sipp_append_2008_rep_weights
program define sipp_append_2008_rep_weights
    args suffix
    local first_file = 1
    local loaded_files = 0
    tempfile combined
    foreach w in $sipp_i08_wgt_waves {
        tempfile one_file
        capture noisily sipp_load_2008_replicate_wave `w' "`one_file'" $sipp_i08_skip
        if _rc error _rc
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
    if `loaded_files' == 0 exit
    use "`combined'", clear
    save "$sipp_i08_outdir/$sipp_i08_base`suffix'.dta", replace
end

foreach family of local families {
    if "`family'" == "replicate" {
        sipp_append_2008_rep_weights "_2008_replicate_weights_person_month"
        display as text "Saved 2008 SIPP replicate weights."
    }
    else if "`family'" == "longitudinal" {
        tempfile lg
        sipp_load_2008_longitudinal "`lg'"
        use "`lg'", clear
        save "`output_dir'/`output_basename'_2008_longitudinal_weights_person.dta", replace
        display as text "Saved 2008 SIPP longitudinal final weights."
    }
    else if "`family'" == "longitudinal_replicate" {
        local indices "$sipp_2008_lrw_indices"
        if "`indices'" == "" local indices "5"
        local first_file = 1
        tempfile combined
        foreach idx of local indices {
            tempfile one
            sipp_load_2008_lrw `idx' "`one'"
            if `first_file' {
                use "`one'", clear
                save "`combined'", replace
                local first_file = 0
            }
            else {
                use "`combined'", clear
                append using "`one'"
                save "`combined'", replace
            }
        }
        use "`combined'", clear
        save "`output_dir'/`output_basename'_2008_longitudinal_replicate_weights_person.dta", replace
        display as text "Saved 2008 SIPP longitudinal replicate weights."
    }
}
