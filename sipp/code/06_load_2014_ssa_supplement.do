********************************************************************************
* 06_load_2014_ssa_supplement.do
*
* Purpose: Load the 2014 SIPP SSA Supplement primary file and, optionally, its
*          fixed-width replicate-weight file.
********************************************************************************

clear all
set more off
set maxvar 32767

********************************************************************************
* USER SETTINGS
********************************************************************************

* Optional manual path override:
* global sipp_root "/Users/yourname/path/to/econ-data-starters/sipp"
* do "$sipp_root/code/06_load_2014_ssa_supplement.do"
*
* Optional output override:
* global sipp_output_dir "/private/tmp/sipp_smoke"
* global sipp_output_basename "sipp_smoke"
*
* Families: primary, replicate, or all.
* global sipp_ssa_families "primary"
* global sipp_ssa_families "primary replicate"
*
* Optional row limit for smoke tests. Leave blank for full files.
* global sipp_ssa_n_max 1000
*
* Replicate columns. Use "all" when you need all 240 replicate weights.
* global sipp_ssa_replicate_numbers "1 2 3 4"
*
* Optional extra primary variables:
* global sipp_ssa_extra_vars "T1YRSINC"

********************************************************************************
* PATHS AND OPTIONS
********************************************************************************

local cwd "`c(pwd)'"
if "$sipp_root" != "" & fileexists("$sipp_root/code/06_load_2014_ssa_supplement.do") {
    global sipp_root "$sipp_root"
}
else if fileexists("code/06_load_2014_ssa_supplement.do") & fileexists("README.md") {
    global sipp_root "`cwd'"
}
else if fileexists("06_load_2014_ssa_supplement.do") & fileexists("../README.md") {
    global sipp_root "`cwd'/.."
}
else if fileexists("sipp/code/06_load_2014_ssa_supplement.do") & fileexists("sipp/README.md") {
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

local families "primary"
if "$sipp_ssa_families" != "" {
    local requested = lower("$sipp_ssa_families")
    if "`requested'" == "all" {
        local families "primary replicate"
    }
    else {
        local families "`requested'"
    }
}

local row_limit ""
if "$sipp_ssa_n_max" != "" {
    local row_limit "$sipp_ssa_n_max"
}
global sipp_i_ssa_rows "`row_limit'"

local replicate_numbers "1 2 3 4"
if "$sipp_ssa_replicate_numbers" != "" {
    local replicate_numbers = lower("$sipp_ssa_replicate_numbers")
}
global sipp_i_ssa_reps "`replicate_numbers'"

display as text "Using SIPP root: $sipp_root"
display as text "Selected 2014 SSA families: `families'"

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

capture program drop sipp_load_ssa_primary
program define sipp_load_ssa_primary
    args output_file

    local archive "data/2014/ssa_supplement/pu2014ssa.dta.gz"
    if !fileexists("`archive'") {
        display as error "No local 2014 SSA primary file found: `archive'"
        error 601
    }

    local old_cwd "`c(pwd)'"
    local extract_dir "`c(tmpdir)'/sipp_2014_ssa_primary_extract"
    capture mkdir "`extract_dir'"
    cd "`extract_dir'"
    capture erase "pu2014ssa.dta"
    capture noisily unzipfile "`old_cwd'/`archive'", replace
    if _rc | !fileexists("pu2014ssa.dta") {
        cd "`old_cwd'"
        display as error "Could not unzip 2014 SSA primary file. It is a zip archive despite the .gz suffix."
        error 601
    }

    quietly describe using "pu2014ssa.dta", varlist
    local all_vars "`r(varlist)'"
    local primary_vars "ssuid pnum spanel swave monthcode ssa_pfinwgt ghlfsam gvarstr rfamnum tmetro_intv tst_intv aage_s tage_s esex_s eorigin erace eeduc ems_s eintype ssaintstat rssmc emainjobid ermnjbbs tjobhrs t1yrsinc epensnyn eincpens tpayamt tiraamt tthftamt tlumptot tpenamt1 tpensamt rdisab rkdisab"
    local keep_vars ""

    foreach v of local primary_vars {
        sipp_add_var_if_present "`v'" "`all_vars'" "`keep_vars'"
        local keep_vars "`r(vars)'"
    }
    foreach v in $sipp_ssa_extra_vars {
        sipp_add_var_if_present "`v'" "`all_vars'" "`keep_vars'"
        local keep_vars "`r(vars)'"
    }

    local keep_vars : list uniq keep_vars
    if "`keep_vars'" == "" {
        cd "`old_cwd'"
        display as error "No variables selected from 2014 SSA primary file."
        error 198
    }

    display as text "Reading 2014 SIPP SSA Supplement primary file"
    if "$sipp_i_ssa_rows" != "" {
        use `keep_vars' using "pu2014ssa.dta" in 1/$sipp_i_ssa_rows, clear
    }
    else {
        use `keep_vars' using "pu2014ssa.dta", clear
    }
    rename _all, lower
    gen str14 source_file = "pu2014ssa.dta"
    gen str14 file_family = "ssa_primary"
    gen int sipp_file_year = 2014
    order source_file file_family sipp_file_year
    compress
    save "`output_file'", replace
    capture erase "pu2014ssa.dta"
    cd "`old_cwd'"
end

capture program drop sipp_load_ssa_replicates
program define sipp_load_ssa_replicates
    args output_file

    local dat_gz "data/2014/ssa_supplement/rw14SSA.dat.gz"
    if !fileexists("`dat_gz'") {
        display as error "No local 2014 SSA replicate-weight file found: `dat_gz'"
        error 601
    }

    local old_cwd "`c(pwd)'"
    local extract_dir "`c(tmpdir)'/sipp_2014_ssa_replicate_extract"
    capture mkdir "`extract_dir'"
    local dat_path "`extract_dir'/rw14SSA.dat"
    capture erase "`dat_path'"
    shell gzip -dc "`old_cwd'/`dat_gz'" > "`dat_path'"
    capture confirm file "`dat_path'"
    if _rc {
        display as error "Could not decompress 2014 SSA replicate-weight file."
        error 601
    }

    local infix_spec "str ssuid 1-12 swave 13-15 spanel 16-19 monthcode 20-21 pnum 22-25"
    if "$sipp_i_ssa_reps" == "all" {
        forvalues n = 1/240 {
            local start = 26 + (`n' - 1) * 12
            local end = `start' + 11
            local infix_spec "`infix_spec' repwgt`n' `start'-`end'"
        }
    }
    else {
        local reps "$sipp_i_ssa_reps"
        foreach n of local reps {
            if `n' >= 1 & `n' <= 240 {
                local start = 26 + (`n' - 1) * 12
                local end = `start' + 11
                local infix_spec "`infix_spec' repwgt`n' `start'-`end'"
            }
        }
    }

    display as text "Reading 2014 SIPP SSA Supplement replicate weights"
    if "$sipp_i_ssa_rows" != "" {
        infix `infix_spec' using "`dat_path'" in 1/$sipp_i_ssa_rows, clear
    }
    else {
        infix `infix_spec' using "`dat_path'", clear
    }
    gen str12 source_file = "rw14SSA.dat"
    gen str14 file_family = "ssa_replicate"
    gen int sipp_file_year = 2014
    order source_file file_family sipp_file_year
    compress
    save "`output_file'", replace
    capture erase "`dat_path'"
    cd "`old_cwd'"
end

foreach family of local families {
    if "`family'" == "primary" {
        tempfile ssa_primary
        sipp_load_ssa_primary "`ssa_primary'"
        use "`ssa_primary'", clear
        save "`output_dir'/`output_basename'_2014_ssa_primary.dta", replace
        display as text "Saved 2014 SIPP SSA primary file: `output_dir'/`output_basename'_2014_ssa_primary.dta"
    }
    else if "`family'" == "replicate" {
        tempfile ssa_replicate
        sipp_load_ssa_replicates "`ssa_replicate'"
        use "`ssa_replicate'", clear
        save "`output_dir'/`output_basename'_2014_ssa_replicate_weights.dta", replace
        display as text "Saved 2014 SIPP SSA replicate weights: `output_dir'/`output_basename'_2014_ssa_replicate_weights.dta"
    }
}
