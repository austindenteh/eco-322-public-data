********************************************************************************
* 09_load_2008_topical_modules.do
*
* Purpose: Load selected 2008 SIPP topical module fixed-width files, writing one
*          output per selected wave because topical module content differs by wave.
********************************************************************************

clear all
set more off
set maxvar 32767

* Note for wrapper scripts: clear all drops Stata programs but preserves globals.
* Family launchers should pass settings through globals and define no pre-loader programs.

********************************************************************************
* USER SETTINGS
********************************************************************************

* Optional manual path override:
* global sipp_root "/Users/yourname/path/to/econ-data-starters/sipp"
* do "$sipp_root/code/09_load_2008_topical_modules.do"
*
* Optional output override:
* global sipp_output_dir "/private/tmp/sipp_smoke"
* global sipp_output_basename "sipp_smoke"
*
* Topical files are available locally for waves 1-11 and 13.
* Wave 12 and waves 14-16 have no topical modules.
* global sipp_2008_tm_waves "13"
* global sipp_2008_tm_waves "4 7 10"
* global sipp_2008_tm_waves "all"
*
* Default keeps all non-allocation variables and skips FILLER fields.
* To keep allocation flags too:
* global sipp_2008_tm_allocs 1
* To keep every non-FILLER field regardless of prefix:
* global sipp_2008_tm_keep_all 1
* To force specific allocation or other variables into the starter set:
* global sipp_2008_tm_extra_vars "AALR AALRB"
*
* Optional row limit for smoke tests. Leave blank for full files.
* global sipp_2008_tm_n_max 1000
* global sipp_2008_tm_skip_missing 1
*
* Optional topic-family metadata used by the family launcher scripts.
* global sipp_2008_tm_family_tag "assets_medical_child_wellbeing"
* global sipp_2008_tm_family_label "Assets, medical expenses, and child well-being"
* global sipp_2008_tm_family_note "Topic-family extract; not a harmonized cleaner."

********************************************************************************
* PATHS AND OPTIONS
********************************************************************************

local cwd "`c(pwd)'"
if "$sipp_root" != "" & fileexists("$sipp_root/code/09_load_2008_topical_modules.do") {
    global sipp_root "$sipp_root"
}
else if fileexists("code/09_load_2008_topical_modules.do") & fileexists("README.md") {
    global sipp_root "`cwd'"
}
else if fileexists("09_load_2008_topical_modules.do") & fileexists("../README.md") {
    global sipp_root "`cwd'/.."
}
else if fileexists("sipp/code/09_load_2008_topical_modules.do") & fileexists("sipp/README.md") {
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

local waves "13"
if "$sipp_2008_tm_waves" != "" {
    local requested = lower("$sipp_2008_tm_waves")
    if "`requested'" == "all" {
        local waves "1 2 3 4 5 6 7 8 9 10 11 13"
    }
    else {
        local waves "`requested'"
    }
}

local row_limit ""
if "$sipp_2008_tm_n_max" != "" {
    local row_limit "$sipp_2008_tm_n_max"
}

local keep_all = 0
if "$sipp_2008_tm_keep_all" == "1" {
    local keep_all = 1
}

local allocs = 0
if "$sipp_2008_tm_allocs" == "1" {
    local allocs = 1
}

local skip_missing = 0
if "$sipp_2008_tm_skip_missing" == "1" {
    local skip_missing = 1
}

global sipp_i08_tm_rows "`row_limit'"
global sipp_i08_tm_keepall `keep_all'
global sipp_i08_tm_allocs `allocs'
global sipp_i08_tm_extras "$sipp_2008_tm_extra_vars"
global sipp_i08_tm_outdir "`output_dir'"
global sipp_i08_tm_base "`output_basename'"
global sipp_i08_tm_skip `skip_missing'
global sipp_i08_tm_family_tag "$sipp_2008_tm_family_tag"
global sipp_i08_tm_family_label "$sipp_2008_tm_family_label"
global sipp_i08_tm_family_note "$sipp_2008_tm_family_note"

display as text "Using SIPP root: $sipp_root"
display as text "Selected 2008 SIPP topical waves: `waves'"
display as text "Topical wave outputs are written separately; do not append unlike modules without harmonizing concepts first."
if "$sipp_i08_tm_family_tag" != "" {
    display as text "Topical family: $sipp_i08_tm_family_tag"
    if "$sipp_i08_tm_family_note" != "" {
        display as text "Family note: $sipp_i08_tm_family_note"
    }
}

********************************************************************************
* HELPERS
********************************************************************************

capture program drop sipp_tm_label
program define sipp_tm_label, rclass
    args wave
    local label ""
    if `wave' == 1 local label "Recipiency History; Employment History; Tax Rebates"
    else if `wave' == 2 local label "Work Disability History; Education and Training History; Marital History; Migration History; Fertility History; Household Relationships; Tax Rebates"
    else if `wave' == 3 local label "Welfare Reform; Retirement and Pension Plan Coverage"
    else if `wave' == 4 local label "Assets and Liabilities; Real Estate, Dependent Care, and Vehicles; Mortgages, Stocks, Interest Accounts, Rental Property, Business Value, Other Assets; Work-Related Expenses/Child Support Paid; Medical Expenses/Health Care Utilization; Child Well-being"
    else if `wave' == 5 local label "Child Care; Work Schedule; Annual Income and Retirement Accounts; Taxes"
    else if `wave' == 6 local label "Adult Well-being; Child Support Agreements; Support for Non-household Members; Functional Limitations and Disability; Employer Provided Health Benefits"
    else if `wave' == 7 local label "Assets and Liabilities; Real Estate, Dependent Care, and Vehicles; Mortgages, Stocks, Interest Accounts, Rental Property, Business Value, Other Assets; Work-Related Expenses/Child Support Paid; Medical Expenses/Health Care Utilization"
    else if `wave' == 8 local label "Child Care; Work Schedule; Annual Income and Retirement Accounts; Taxes"
    else if `wave' == 9 local label "Informal Care-giving; Adult Well-being"
    else if `wave' == 10 local label "Assets and Liabilities; Real Estate, Dependent Care, and Vehicles; Mortgages, Stocks, Interest Accounts, Rental Property, Business Value, Other Assets; Work-Related Expenses/Child Support Paid; Medical Expenses/Health Care Utilization; Child Well-being"
    else if `wave' == 11 local label "Retirement and Pension Plan Coverage"
    else if `wave' == 13 local label "Professional Certificates and Certifications"
    return local label "`label'"
end

capture program drop sipp_tm_keep
program define sipp_tm_keep, rclass
    args name
    local lname = lower("`name'")
    local keep = 0
    if "`lname'" == "filler" {
        return scalar keep = 0
        exit
    }
    if $sipp_i08_tm_keepall {
        local keep = 1
    }
    else if substr("`lname'", 1, 1) != "a" {
        local keep = 1
    }
    else if $sipp_i08_tm_allocs {
        local keep = 1
    }
    foreach extra in $sipp_i08_tm_extras {
        if lower("`extra'") == "`lname'" {
            local keep = 1
        }
    }
    return scalar keep = `keep'
end

capture program drop sipp_tm_write_dict
program define sipp_tm_write_dict, rclass
    args sas_path dat_path dict_path
    local selected_vars ""
    local in_input = 0

    file open dictfile using "`dict_path'", write text replace
    file write dictfile `"dictionary using "`dat_path'" {"' _n

    file open sasfile using "`sas_path'", read text
    file read sasfile line
    while r(eof) == 0 {
        local t = strtrim(`"`line'"')
        if "`t'" == "INPUT" {
            local in_input = 1
        }
        else if `in_input' {
            if substr("`t'", 1, 1) == ";" {
                continue, break
            }
            gettoken name rest : t
            if "`name'" != "" {
                gettoken token rest : rest
                local is_string = 0
                if "`token'" == "$" {
                    local is_string = 1
                    gettoken token rest : rest
                }
                local token = subinstr("`token'", ";", "", .)
                local dash = strpos("`token'", "-")
                if `dash' > 0 {
                    local start = substr("`token'", 1, `dash' - 1)
                    local stop = substr("`token'", `dash' + 1, .)
                    if "`stop'" == "" {
                        gettoken stop rest : rest
                        local stop = subinstr("`stop'", ";", "", .)
                    }
                }
                else {
                    local start "`token'"
                    gettoken stop rest : rest
                    local stop = subinstr("`stop'", ";", "", .)
                }
                capture confirm number `start'
                if !_rc {
                    capture confirm number `stop'
                    if !_rc {
                        sipp_tm_keep "`name'"
                        if r(keep) {
                            local lname = lower("`name'")
                            local width = `stop' - `start' + 1
                            if `is_string' {
                                file write dictfile "_column(`start') str`width' `lname' %`width's" _n
                            }
                            else {
                                file write dictfile "_column(`start') `lname' %`width'f" _n
                            }
                            local selected_vars "`selected_vars' `lname'"
                        }
                    }
                }
            }
        }
        file read sasfile line
    }
    file close sasfile
    file write dictfile "}" _n
    file close dictfile

    if "`selected_vars'" == "" {
        display as error "No variables selected from SAS layout: `sas_path'"
        error 198
    }
    return local selected_vars "`selected_vars'"
end

capture program drop sipp_tm_load_wave
program define sipp_tm_load_wave
    args wave

    local dat_gz "data/2008/wave`wave'/p08putm`wave'.dat.gz"
    local sas_path "data/2008/wave`wave'/p08putm`wave'.sas"
    if !fileexists("`dat_gz'") | !fileexists("`sas_path'") {
        if $sipp_i08_tm_skip {
            display as text "Skipping 2008 topical wave `wave': local data/layout pair not found."
            exit
        }
        display as error "No local 2008 SIPP topical wave `wave' data/layout pair found."
        error 601
    }

    local extract_dir "`c(tmpdir)'/sipp_2008_tm_wave`wave'_extract"
    capture mkdir "`extract_dir'"
    local dat_path "`extract_dir'/p08putm`wave'.dat"
    capture erase "`dat_path'"
    shell gzip -dc "$sipp_root/`dat_gz'" > "`dat_path'"
    capture confirm file "`dat_path'"
    if _rc {
        display as error "Could not decompress `dat_gz'."
        error 601
    }

    tempfile dict_file
    sipp_tm_write_dict "`sas_path'" "`dat_path'" "`dict_file'"

    display as text "Reading 2008 SIPP topical wave `wave'"
    if "$sipp_i08_tm_rows" != "" {
        infile using "`dict_file'" in 1/$sipp_i08_tm_rows, clear
    }
    else {
        infile using "`dict_file'", clear
    }

    capture confirm variable epppnum
    if !_rc {
        gen int pnum = epppnum
    }
    capture confirm variable eeducate
    if !_rc {
        gen byte eeduc = eeducate
    }
    sipp_tm_label `wave'
    gen str16 source_file = "p08putm`wave'.dat"
    gen int sipp_file_year = 2008
    gen byte panel_wave = `wave'
    gen str80 topical_family = "$sipp_i08_tm_family_tag"
    gen str200 topical_family_label = "$sipp_i08_tm_family_label"
    gen str244 topical_family_note = "$sipp_i08_tm_family_note"
    gen str300 topical_modules = "`r(label)'"
    order source_file sipp_file_year panel_wave topical_family topical_family_label topical_family_note topical_modules
    compress
    local suffix "2008_topical_wave`wave'"
    local family "$sipp_i08_tm_family_tag"
    if "`family'" != "" {
        local suffix "2008_topical_`family'_wave`wave'"
    }
    local out_path "$sipp_i08_tm_outdir/${sipp_i08_tm_base}_`suffix'.dta"
    save "`out_path'", replace
    display as text "Saved 2008 SIPP topical wave `wave': `out_path'"
    capture erase "`dat_path'"
end

foreach w of local waves {
    if !inlist(`w', 1, 2, 3, 4, 5, 6, 7, 8, 9, 10) & !inlist(`w', 11, 13) {
        display as error "Invalid 2008 topical wave: `w'. Public topical files are present locally for waves 1-11 and 13."
        error 198
    }
    sipp_tm_load_wave `w'
}
