********************************************************************************
* 04_load_2014_panel_primary.do
*
* Purpose: Load selected 2014 SIPP panel public-use primary files
*          into a compact person-month starter file.
*
* Output: output/sipp_2014_panel_primary_person_month.dta
********************************************************************************

clear all
set more off
set maxvar 32767

********************************************************************************
* USER SETTINGS
********************************************************************************

* Optional manual path override:
* global sipp_root "/Users/yourname/path/to/econ-data-starters/sipp"
* do "$sipp_root/code/04_load_2014_panel_primary.do"
*
* Optional output override:
* global sipp_output_dir "/private/tmp/sipp_smoke"
* global sipp_output_basename "sipp_smoke"
*
* Main file choices:
* global sipp_2014_waves "4"
* global sipp_2014_waves "2 3 4"
* global sipp_2014_waves "all"
* global sipp_2014_skip_unreadable 1
*
* Optional row limit for smoke tests. Leave blank for full files.
* global sipp_2014_n_max 1000
*
* Optional extra variables:
* global sipp_2014_extra_vars "TSSSAMT TSNAP_AMT"
* global sipp_2014_extra_var_families `" "person_earnings_custom:TPEARN TPEARN_ALT" "'

********************************************************************************
* PATHS AND OPTIONS
********************************************************************************

local cwd "`c(pwd)'"
if "$sipp_root" != "" & fileexists("$sipp_root/code/04_load_2014_panel_primary.do") {
    global sipp_root "$sipp_root"
}
else if fileexists("code/04_load_2014_panel_primary.do") & fileexists("README.md") {
    global sipp_root "`cwd'"
}
else if fileexists("04_load_2014_panel_primary.do") & fileexists("../README.md") {
    global sipp_root "`cwd'/.."
}
else if fileexists("sipp/code/04_load_2014_panel_primary.do") & fileexists("sipp/README.md") {
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

local waves "4"
if "$sipp_2014_waves" != "" {
    local requested = lower("$sipp_2014_waves")
    if "`requested'" == "all" {
        local waves "1 2 3 4"
    }
    else {
        local waves "`requested'"
    }
}

foreach w of local waves {
    local valid_wave = 0
    foreach allowed in 1 2 3 4 {
        if "`w'" == "`allowed'" {
            local valid_wave = 1
        }
    }
    if !`valid_wave' {
        display as error "Invalid 2014 SIPP panel wave: `w'"
        error 198
    }
}

local skip_unreadable = 0
if "$sipp_2014_skip_unreadable" == "1" {
    local skip_unreadable = 1
}

local row_limit ""
if "$sipp_2014_n_max" != "" {
    local row_limit "$sipp_2014_n_max"
}

global sipp_internal_2014_row_limit "`row_limit'"

display as text "Using SIPP root: $sipp_root"
display as text "Selected 2014 SIPP panel waves: `waves'"

********************************************************************************
* HELPERS
********************************************************************************

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

capture program drop sipp_load_2014_wave
program define sipp_load_2014_wave
    args wave output_file skip_unreadable

    local gz_path "data/2014/panel_wave`wave'/pu2014w`wave'.dta.gz"
    local csv_gz_path "data/2014/panel_wave`wave'/pu2014w`wave'.csv.gz"
    if !fileexists("`gz_path'") & !fileexists("`csv_gz_path'") {
        if `skip_unreadable' {
            display as text "Skipping 2014 SIPP wave `wave': local primary file not found."
            exit
        }
        display as error "No local 2014 SIPP primary file found: `gz_path' or `csv_gz_path'"
        error 601
    }

    local old_cwd "`c(pwd)'"
    local extract_dir "`c(tmpdir)'/sipp_2014_wave`wave'_extract"
    capture mkdir "`extract_dir'"
    local dta_path "`extract_dir'/pu2014w`wave'.dta"
    local csv_path "`extract_dir'/pu2014w`wave'.csv"
    capture erase "`dta_path'"
    capture erase "`csv_path'"
    local source_format ""
    local source_file ""

    if fileexists("`gz_path'") {
        shell gzip -dc "`old_cwd'/`gz_path'" > "`dta_path'"
        capture noisily describe using "`dta_path'", varlist
        if !_rc {
            local source_format "dta"
            local source_file "pu2014w`wave'.dta"
            quietly describe using "`dta_path'", varlist
            local all_vars "`r(varlist)'"
        }
        else {
            display as text "Could not read 2014 SIPP wave `wave' Stata gzip; trying pipe-delimited CSV fallback."
        }
    }

    if "`source_format'" == "" & fileexists("`csv_gz_path'") {
        shell gzip -dc "`old_cwd'/`csv_gz_path'" > "`csv_path'"
        if "$sipp_internal_2014_row_limit" != "" {
            local csv_row_end = $sipp_internal_2014_row_limit + 1
            capture import delimited using "`csv_path'", delimiters("|") varnames(1) stringcols(_all) rowrange(1:`csv_row_end') clear
        }
        else {
            capture import delimited using "`csv_path'", delimiters("|") varnames(1) stringcols(_all) clear
        }
        if !_rc {
            local source_format "csv"
            local source_file "pu2014w`wave'.csv.gz"
            ds
            local all_vars "`r(varlist)'"
        }
    }

    if "`source_format'" == "" {
        if `skip_unreadable' {
            display as text "Skipping 2014 SIPP wave `wave': no readable Stata or pipe-delimited primary file."
            exit
        }
        display as error "Could not read 2014 SIPP wave `wave' from Stata gzip or pipe-delimited CSV."
        error 601
    }

    local starter_vars "ssuid pnum monthcode shhadid spanel swave ghlfsam gvarstr wpfinwgt rregion_intv tmetro_intv tst_intv tehc_st tehc_metro rhnumper rhnumu18 rhnum65over rfamnum rfamref rfpersons rfrelu18 rfamkind etenure erentsub evoucher tage tdob_byear esex eorigin ehispan erace trace eeduc ems erelrpe ebornus ecitizen rmesr rwksperm rmwkwjb rmnumjobs tmwkhrs tpearn tpearn_alt tptotinc thtotinc tftotinc tftotinct2 thtotinct2 rfpov rhpov tfincpov thincpov tsssamt tssi_amt ttanf_amt tsnap_amt twic_amt tga_amt tva1amt tuc1amt rsnap_mnyn rtanf_mnyn rssi_mnyn rwic_mnyn rhlthmth rhicovann rprivann rpubann rmedcareann rmcaidann rvacareann tval_home thval_home tnetworth thnetworth tdebt_cc thdebt_cc"
    local keep_vars ""

    foreach v of local starter_vars {
        sipp_add_var_if_present "`v'" "`all_vars'" "`keep_vars'"
        local keep_vars "`r(vars)'"
    }

    foreach v in $sipp_2014_extra_vars {
        sipp_add_var_if_present "`v'" "`all_vars'" "`keep_vars'"
        local keep_vars "`r(vars)'"
    }

    local alias_raws ""
    local alias_targets ""
    foreach famspec in $sipp_2014_extra_var_families {
        local colon = strpos(`"`famspec'"', ":")
        if `colon' > 1 {
            local std = lower(substr(`"`famspec'"', 1, `colon' - 1))
            local candidates = lower(substr(`"`famspec'"', `colon' + 1, .))
            local matched ""
            foreach candidate of local candidates {
                foreach raw of local all_vars {
                    if lower("`raw'") == "`candidate'" & "`matched'" == "" {
                        local matched "`raw'"
                    }
                }
            }
            if "`matched'" != "" {
                local keep_vars "`keep_vars' `matched'"
                local alias_raws "`alias_raws' `matched'"
                local alias_targets `"`alias_targets' "`std'""'
            }
            else {
                display as text "2014 SIPP wave `wave' has no match for alias family: `std'"
            }
        }
    }

    local keep_vars : list uniq keep_vars
    if "`keep_vars'" == "" {
        display as error "No variables selected for 2014 SIPP wave `wave'."
        error 198
    }

    if "`source_format'" == "dta" {
        display as text "Reading 2014 SIPP panel wave `wave': `gz_path'"
        if "$sipp_internal_2014_row_limit" != "" {
            capture use `keep_vars' using "`dta_path'" in 1/$sipp_internal_2014_row_limit, clear
        }
        else {
            capture use `keep_vars' using "`dta_path'", clear
        }
        if _rc & fileexists("`csv_gz_path'") {
            display as text "Could not read 2014 SIPP wave `wave' Stata observations; using pipe-delimited CSV fallback."
            shell gzip -dc "`old_cwd'/`csv_gz_path'" > "`csv_path'"
            if "$sipp_internal_2014_row_limit" != "" {
                local csv_row_end = $sipp_internal_2014_row_limit + 1
                import delimited using "`csv_path'", delimiters("|") varnames(1) stringcols(_all) rowrange(1:`csv_row_end') clear
            }
            else {
                import delimited using "`csv_path'", delimiters("|") varnames(1) stringcols(_all) clear
            }
            local csv_keep_vars = lower("`keep_vars'")
            keep `csv_keep_vars'
            local source_format "csv"
            local source_file "pu2014w`wave'.csv.gz"
        }
        else if _rc {
            error _rc
        }
    }
    else {
        display as text "Reading 2014 SIPP panel wave `wave': `csv_gz_path'"
        keep `keep_vars'
    }
    rename _all, lower
    if "`source_format'" == "csv" {
        foreach v of varlist _all {
            if !inlist("`v'", "ssuid", "shhadid", "ghlfsam", "gvarstr", "tst_intv") {
                capture destring `v', replace
            }
        }
    }

    local i = 1
    foreach raw of local alias_raws {
        local target : word `i' of `alias_targets'
        local raw_lower = lower("`raw'")
        capture confirm variable `raw_lower'
        if !_rc {
            capture confirm variable `target'
            if _rc {
                clonevar `target' = `raw_lower'
            }
        }
        local ++i
    }

    gen str18 source_file = "`source_file'"
    gen str12 design_era = "2014_panel"
    gen int sipp_file_year = 2014
    gen byte panel_wave = `wave'
    order source_file design_era sipp_file_year panel_wave
    compress
    save "`output_file'", replace
    capture erase "`dta_path'"
    capture erase "`csv_path'"
    cd "`old_cwd'"
end

local first_wave = 1
local loaded_waves = 0
tempfile combined
foreach w of local waves {
    tempfile one_wave
    capture noisily sipp_load_2014_wave `w' "`one_wave'" `skip_unreadable'
    if _rc {
        error _rc
    }
    capture confirm file "`one_wave'"
    if !_rc {
        if `first_wave' {
            use "`one_wave'", clear
            save "`combined'", replace
            local first_wave = 0
        }
        else {
            use "`combined'", clear
            append using "`one_wave'"
            save "`combined'", replace
        }
        local loaded_waves = `loaded_waves' + 1
    }
}

if `loaded_waves' == 0 {
    display as error "No 2014 SIPP panel primary files were loaded."
    error 2000
}

use "`combined'", clear
sort panel_wave ssuid pnum monthcode
compress
save "`output_dir'/`output_basename'_2014_panel_primary_person_month.dta", replace
display as text "Saved 2014 SIPP panel primary person-month file: `output_dir'/`output_basename'_2014_panel_primary_person_month.dta"
