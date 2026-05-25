********************************************************************************
* 01_load_modern_primary.do
*
* Purpose: Load selected modern SIPP annual primary public-use files
*          (2018-2024 design era) into a compact person-month starter file.
*
* Output: output/sipp_modern_primary_person_month.dta
********************************************************************************

clear all
set more off
set maxvar 32767

* Note for wrapper scripts: clear all drops Stata programs but preserves globals.
* Define wrapper helper programs after this loader is called.

********************************************************************************
* USER SETTINGS
********************************************************************************

* Optional manual path override:
* global sipp_root "/Users/yourname/path/to/econ-data-starters/sipp"
* do "$sipp_root/code/01_load_modern_primary.do"
*
* Optional output override:
* global sipp_output_dir "/private/tmp/sipp_smoke"
* global sipp_output_basename "sipp_smoke"
*
* Main file choices:
* global sipp_modern_years "2024"
* global sipp_modern_years "2023 2024"
* global sipp_modern_years "all"
* global sipp_modern_skip_unreadable 1
*
* Optional row limit for smoke tests. Leave blank for full files.
* global sipp_modern_n_max 1000
*
* Optional extra variables:
* global sipp_modern_extra_vars "TSSSAMT TSNAP_AMT"
* global sipp_modern_extra_var_families `" "person_earnings_custom:TPEARN TPEARN_ALT" "'

********************************************************************************
* PATHS AND OPTIONS
********************************************************************************

local cwd "`c(pwd)'"
if "$sipp_root" != "" & fileexists("$sipp_root/code/01_load_modern_primary.do") {
    global sipp_root "$sipp_root"
}
else if fileexists("code/01_load_modern_primary.do") & fileexists("README.md") {
    global sipp_root "`cwd'"
}
else if fileexists("01_load_modern_primary.do") & fileexists("../README.md") {
    global sipp_root "`cwd'/.."
}
else if fileexists("sipp/code/01_load_modern_primary.do") & fileexists("sipp/README.md") {
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

local modern_years "2024"
if "$sipp_modern_years" != "" {
    local requested = lower("$sipp_modern_years")
    if "`requested'" == "all" {
        local modern_years "2018 2019 2020 2021 2022 2023 2024"
    }
    else {
        local modern_years "`requested'"
    }
}

foreach y of local modern_years {
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

local skip_unreadable = 0
if "$sipp_modern_skip_unreadable" == "1" {
    local skip_unreadable = 1
}

local write_csv_export = 0
if "$sipp_write_csv_export" == "1" {
    local write_csv_export = 1
}

local row_limit ""
if "$sipp_modern_n_max" != "" {
    local row_limit "$sipp_modern_n_max"
}

display as text "Using SIPP root: $sipp_root"
display as text "Selected modern SIPP years: `modern_years'"

capture program drop sipp_primary_zip_path
program define sipp_primary_zip_path, rclass
    args year
    local zip_path "data/`year'/pu`year'_dta.zip"
    if fileexists("`zip_path'") {
        return local zip_path "`zip_path'"
        exit
    }
    local zip_path "data/`year'/pu`year'_dta.zip.download/pu`year'_dta.zip"
    if fileexists("`zip_path'") {
        return local zip_path "`zip_path'"
        exit
    }
    return local zip_path ""
end

capture program drop sipp_load_modern_year
program define sipp_load_modern_year
    args year output_file skip_unreadable write_csv_export row_limit

    sipp_primary_zip_path `year'
    local zip_path "`r(zip_path)'"
    if "`zip_path'" == "" {
        if `skip_unreadable' {
            display as text "Skipping SIPP `year': no local primary Stata zip found."
            exit
        }
        display as error "No local primary Stata zip found for SIPP `year'."
        error 601
    }

    local old_cwd "`c(pwd)'"
    local extract_dir "`c(tmpdir)'/sipp_modern_`year'_extract"
    capture mkdir "`extract_dir'"
    cd "`extract_dir'"
    capture erase "pu`year'.dta"
    capture noisily unzipfile "`old_cwd'/`zip_path'", replace
    if _rc | !fileexists("pu`year'.dta") {
        display as text "Stata unzipfile could not extract `zip_path'; trying system unzip."
        shell unzip -j -o "`old_cwd'/`zip_path'" "pu`year'.dta" -d "`extract_dir'"
    }
    if !fileexists("pu`year'.dta") {
        cd "`old_cwd'"
        if `skip_unreadable' {
            display as text "Skipping SIPP `year': pu`year'.dta was not found after unzip."
            exit
        }
        display as error "Expected pu`year'.dta inside `zip_path' but did not find it."
        error 601
    }

    quietly describe using "pu`year'.dta", varlist
    local all_vars "`r(varlist)'"
    local starter_vars "ssuid pnum monthcode shhadid spanel swave ghlfsam gvarstr wpfinwgt rregion_intv tmetro_intv tst_intv tehc_st tehc_metro rhnumper rhnumu18 rhnum65over rfamnum rfamref rfpersons rfrelu18 rfamkind etenure erentsub evoucher tage tdob_byear esex eorigin ehispan erace trace eeduc ems erelrpe ebornus ecitizen rmesr rwksperm rmwkwjb rmnumjobs tmwkhrs tpearn tpearn_alt tptotinc thtotinc tftotinc tftotinct2 thtotinct2 rfpov rhpov tfincpov thincpov tsssamt tssi_amt ttanf_amt tsnap_amt twic_amt tga_amt tva1amt tuc1amt rsnap_mnyn rtanf_mnyn rssi_mnyn rwic_mnyn rhlthmth rhicovann rprivann rpubann rmedcareann rmcaidann rvacareann tval_home thval_home tnetworth thnetworth tdebt_cc thdebt_cc"
    local extra_vars = lower("$sipp_modern_extra_vars")
    local keep_vars ""

    foreach v of local starter_vars {
        local matched ""
        foreach raw of local all_vars {
            if lower("`raw'") == "`v'" & "`matched'" == "" {
                local matched "`raw'"
            }
        }
        if "`matched'" != "" {
            local keep_vars "`keep_vars' `matched'"
        }
        else {
            display as text "SIPP `year' missing starter variable; skipping: `v'"
        }
    }

    foreach v of local extra_vars {
        local matched ""
        foreach raw of local all_vars {
            if lower("`raw'") == "`v'" & "`matched'" == "" {
                local matched "`raw'"
            }
        }
        if "`matched'" != "" {
            local keep_vars "`keep_vars' `matched'"
        }
        else {
            display as text "SIPP `year' missing requested extra variable; skipping: `v'"
        }
    }

    local alias_raws ""
    local alias_targets ""
    foreach famspec in $sipp_modern_extra_var_families {
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
                display as text "SIPP `year' has no match for alias family: `std'"
            }
        }
    }

    local keep_vars : list uniq keep_vars
    if "`keep_vars'" == "" {
        cd "`old_cwd'"
        display as error "No variables selected for SIPP `year'."
        error 198
    }

    display as text "Reading SIPP `year' primary file: `zip_path'"
    if "`row_limit'" != "" {
        use `keep_vars' using "pu`year'.dta" in 1/`row_limit', clear
    }
    else {
        use `keep_vars' using "pu`year'.dta", clear
    }
    rename _all, lower

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

    gen str12 source_file = "pu`year'.dta"
    gen int sipp_file_year = `year'
    gen int reference_year = `year' - 1
    order source_file sipp_file_year reference_year
    compress
    save "`output_file'", replace
    capture erase "pu`year'.dta"
    cd "`old_cwd'"
end

local first_year = 1
local loaded_years 0
tempfile combined
foreach y of local modern_years {
    tempfile one_year
    capture noisily sipp_load_modern_year `y' "`one_year'" `skip_unreadable' `write_csv_export' "`row_limit'"
    if _rc {
        error _rc
    }
    capture confirm file "`one_year'"
    if !_rc {
        if `first_year' {
            use "`one_year'", clear
            save "`combined'", replace
            local first_year = 0
        }
        else {
            use "`combined'", clear
            append using "`one_year'"
            save "`combined'", replace
        }
        local loaded_years = `loaded_years' + 1
    }
}

if `loaded_years' == 0 {
    display as error "No SIPP modern primary files were loaded."
    error 2000
}

use "`combined'", clear
sort sipp_file_year ssuid pnum monthcode
compress
save "`output_dir'/`output_basename'_modern_primary_person_month.dta", replace
if `write_csv_export' {
    export delimited using "`output_dir'/`output_basename'_modern_primary_person_month.csv", replace
}
display as text "Saved modern SIPP primary person-month file: `output_dir'/`output_basename'_modern_primary_person_month.dta"
