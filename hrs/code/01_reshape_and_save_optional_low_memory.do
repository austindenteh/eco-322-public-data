********************************************************************************
* 01_reshape_and_save_optional_low_memory.do
*
* Purpose: Standalone low-memory HRS loader. Reads only selected RAND HRS raw
*          columns, reshapes selected waves from wide to long, and saves the
*          compact long starter dataset.
*
* Input:   data/raw/randhrs1992_2022v1.dta
* Output:  output/hrs_long.dta
*          output/hrs_long.csv (optional; off by default)
*
* Usage:   Run from hrs/, hrs/code/, from the repo root, or set global hrs_root.
********************************************************************************

clear all
set more off
set maxvar 32767

* ============================================================================
* 1. DEFINE PATHS AND OPTIONS
* ============================================================================
* Optional manual path override. Uncomment and edit if auto-detection fails:
* global hrs_root "/Users/yourname/path/to/econ-data-starters/hrs"
* Then run: do "$hrs_root/code/01_reshape_and_save_optional_low_memory.do"

local cwd "`c(pwd)'"
if "$hrs_root" != "" & fileexists("$hrs_root/code/01_reshape_and_save_optional_low_memory.do") {
    global hrs_root "$hrs_root"
}
else if fileexists("code/01_reshape_and_save_optional_low_memory.do") & fileexists("README.md") {
    global hrs_root "`cwd'"
}
else if fileexists("01_reshape_and_save_optional_low_memory.do") & fileexists("../README.md") {
    global hrs_root "`cwd'/.."
}
else if fileexists("hrs/code/01_reshape_and_save_optional_low_memory.do") & fileexists("hrs/README.md") {
    global hrs_root "`cwd'/hrs"
}
else {
    display as error "Could not locate the hrs/ directory."
    display as error "Run from hrs/, hrs/code/, from the repo root, or set global hrs_root."
    display as error `"Manual override: global hrs_root "/path/to/hrs""'
    error 601
}

cd "$hrs_root"
capture mkdir "output"

local raw_data "data/raw/randhrs1992_2022v1.dta"
if !fileexists("`raw_data'") {
    display as error "Could not find `raw_data'."
    display as error "Download randhrs1992_2022v1.dta and place it in hrs/data/raw/."
    error 601
}

local output_basename "hrs_long"
if "$hrs_output_basename" != "" {
    local output_basename "$hrs_output_basename"
}

local output_dir "output"
if "$hrs_output_dir" != "" {
    local output_dir "$hrs_output_dir"
    capture mkdir "`output_dir'"
}

local out_dta "`output_dir'/`output_basename'.dta"
local out_csv "`output_dir'/`output_basename'.csv"

* --- USER SETTINGS: waves, years, and extras -------------------------------
* Recommended for most student projects that do not need every RAND HRS raw
* column. Select the waves and extra stubs required by the project.
* Leave hrs_waves and hrs_years blank to keep all 16 RAND HRS waves.
*
* Select by survey year:
*   global hrs_years "2018 2020 2022"
*
* Or select directly by RAND wave number:
*   global hrs_waves "14 15 16"
*
* Add stable person-level variables beyond the starter set:
*   global hrs_extra_time_invariant_vars "raedyrs"
*
* Add wave-varying variables by long-format stub. The loader expands each
* stub only for selected waves, e.g. rcovrt -> r14covrt r15covrt r16covrt.
*   global hrs_extra_wave_stubs "rcovrt scovrt"
*
* Optional output controls:
*   global hrs_output_dir "/path/to/output"
*   global hrs_output_basename "hrs_selected_waves"
*   global hrs_write_csv_export 1

* Low-memory mode is always on in this standalone optional loader.
local keep_starter_vars_only = 1

* Low-memory starter builds skip the very large CSV unless explicitly requested.
local write_csv_export = 0
if "$hrs_write_csv_export" == "1" {
    local write_csv_export = 1
}

local starter_time_invariant_vars "hhidpn hhid pn hacohort ragender rabyear raeduc raracem rahispan"
local starter_wave_stubs "inw ragey_b rmstat rshlt rcesd rbmi rconde rhosp radl5a riadl5a rmobila hitot hatotb rwtresp"
local suffix_wave_stubs "inw radtype radappm radappy radream radreay radrecm radrecy radendm radendy radstat radappd radread radrecd radendd"

local requested_waves "$hrs_waves"
if "$hrs_years" != "" {
    foreach y of global hrs_years {
        local mapped_wave
        if "`y'" == "1992" local mapped_wave 1
        else if "`y'" == "1994" local mapped_wave 2
        else if "`y'" == "1996" local mapped_wave 3
        else if "`y'" == "1998" local mapped_wave 4
        else if "`y'" == "2000" local mapped_wave 5
        else if "`y'" == "2002" local mapped_wave 6
        else if "`y'" == "2004" local mapped_wave 7
        else if "`y'" == "2006" local mapped_wave 8
        else if "`y'" == "2008" local mapped_wave 9
        else if "`y'" == "2010" local mapped_wave 10
        else if "`y'" == "2012" local mapped_wave 11
        else if "`y'" == "2014" local mapped_wave 12
        else if "`y'" == "2016" local mapped_wave 13
        else if "`y'" == "2018" local mapped_wave 14
        else if "`y'" == "2020" local mapped_wave 15
        else if "`y'" == "2022" local mapped_wave 16
        else {
            display as error "[WARN] Year `y' does not map to a RAND HRS wave in this starter."
        }
        if "`mapped_wave'" != "" {
            local requested_waves `requested_waves' `mapped_wave'
        }
    }
}
if trim("`requested_waves'") == "" {
    local requested_waves "1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16"
}
local requested_waves: list uniq requested_waves
foreach w of local requested_waves {
    if real("`w'") < 1 | real("`w'") > 16 | missing(real("`w'")) {
        display as error "Invalid HRS wave: `w'. Valid waves are 1-16."
        error 198
    }
}
display as text "Using HRS waves: `requested_waves'"

* ============================================================================
* 2. LOAD THE RAW DATA
* ============================================================================

if `keep_starter_vars_only' {
    display as text "Reading RAND HRS metadata to select low-memory columns..."
    quietly describe using "`raw_data'", varlist
    local raw_vars `r(varlist)'

    local requested_vars
    foreach v of local starter_time_invariant_vars {
        local v = lower("`v'")
        local requested_vars `requested_vars' `v'
    }
    foreach v of global hrs_extra_time_invariant_vars {
        local v = lower("`v'")
        local requested_vars `requested_vars' `v'
    }

    local requested_wave_stubs `starter_wave_stubs' $hrs_extra_wave_stubs
    foreach stub_raw of local requested_wave_stubs {
        local stub = lower("`stub_raw'")
        if "`stub'" == "inw" {
            foreach w of local requested_waves {
                local requested_vars `requested_vars' inw`w'
            }
        }
        else {
            local is_suffix_stub: list stub in suffix_wave_stubs
            if `is_suffix_stub' {
                foreach w of local requested_waves {
                    local requested_vars `requested_vars' `stub'`w'
                }
            }
            else if inlist(substr("`stub'", 1, 1), "r", "s", "h") & length("`stub'") > 1 {
                local prefix = substr("`stub'", 1, 1)
                local concept = substr("`stub'", 2, .)
                foreach w of local requested_waves {
                    local requested_vars `requested_vars' `prefix'`w'`concept'
                }
            }
            else {
                foreach w of local requested_waves {
                    local requested_vars `requested_vars' `stub'`w'
                }
            }
        }
    }
    local requested_vars: list uniq requested_vars

    local present_vars
    local missing_vars
    foreach v of local requested_vars {
        local found: list v in raw_vars
        if `found' {
            local present_vars `present_vars' `v'
        }
        else {
            local missing_vars `missing_vars' `v'
        }
    }
    local present_vars: list uniq present_vars
    local missing_vars: list uniq missing_vars

    local has_hhidpn: list posof "hhidpn" in present_vars
    if `has_hhidpn' == 0 {
        display as error "The required identifier hhidpn was not found in the raw file."
        error 111
    }

    display as text "Loading selected raw variables from RAND HRS: " wordcount("`present_vars'") " variables"
    if wordcount("`missing_vars'") > 0 {
        local missing_preview
        local i = 0
        foreach v of local missing_vars {
            local ++i
            if `i' <= 12 {
                local missing_preview `missing_preview' `v'
            }
        }
        display as text "[INFO] Requested raw variables not found: `missing_preview'"
    }

    use `present_vars' using "`raw_data'", clear
}
else {
    display as text "Loading full RAND HRS data. This may take a few minutes..."
    use "`raw_data'", clear
}

display as text "Loaded " _N " respondents from raw RAND HRS file."
display as text "Variables in memory: " c(k)

* ============================================================================
* 3. RENAME PROBLEMATIC VARIABLES
* ============================================================================
* Some s-prefix word recall variables have naming patterns that can conflict
* with reshape stub detection. Rename only if present.

capture rename s1tr40  s1tr40_
capture rename s2htr40 s2htr40_
capture rename s2atr20 s2atr20_
forvalues w = 3/16 {
    capture rename s`w'tr20 s`w'tr20_
}

display as text "Renamed problematic s-prefix variables where present."

* ============================================================================
* 4. BUILD RESHAPE STUB LISTS
* ============================================================================
* R/H/S wave variables use names like r1shlt and r10shlt. Stata reshape needs
* stubs like r@shlt so single- and double-digit waves are handled together.

local stublist_r
local stublist_h
local stublist_s

ds
foreach v of varlist `r(varlist)' {
    if regexm("`v'", "^r([0-9]+)(.+)$") {
        local wave_part = regexs(1)
        local concept = regexs(2)
        local wave_num = real("`wave_part'")
        if inrange(`wave_num', 1, 16) {
            local stublist_r `stublist_r' r@`concept'
        }
    }
    else if regexm("`v'", "^h([0-9]+)(.+)$") {
        local wave_part = regexs(1)
        local concept = regexs(2)
        local wave_num = real("`wave_part'")
        if inrange(`wave_num', 1, 16) {
            local stublist_h `stublist_h' h@`concept'
        }
    }
    else if regexm("`v'", "^s([0-9]+)(.+)$") {
        local wave_part = regexs(1)
        local concept = regexs(2)
        local wave_num = real("`wave_part'")
        if inrange(`wave_num', 1, 16) {
            local stublist_s `stublist_s' s@`concept'
        }
    }
}

local stublist_r: list uniq stublist_r
local stublist_h: list uniq stublist_h
local stublist_s: list uniq stublist_s

display as text "R-prefix stubs: " wordcount("`stublist_r'") " unique stubs"
display as text "H-prefix stubs: " wordcount("`stublist_h'") " unique stubs"
display as text "S-prefix stubs: " wordcount("`stublist_s'") " unique stubs"

local stublist_suffix
foreach stub of local suffix_wave_stubs {
    local found_any = 0
    foreach w of local requested_waves {
        capture confirm variable `stub'`w'
        if !_rc {
            local found_any = 1
        }
    }
    if `found_any' {
        local stublist_suffix `stublist_suffix' `stub'
    }
}
local stublist_suffix: list uniq stublist_suffix
display as text "Suffix-numbered stubs: " wordcount("`stublist_suffix'") " unique stubs"

if wordcount("`stublist_r' `stublist_h' `stublist_s' `stublist_suffix'") == 0 {
    display as error "No wave-varying variables were found to reshape."
    error 111
}

* ============================================================================
* 5. RESHAPE FROM WIDE TO LONG
* ============================================================================

display as text _newline "Reshaping from wide to long. This may take several minutes..."
reshape long `stublist_r' `stublist_s' `stublist_h' `stublist_suffix', i(hhidpn) j(wave)

display as text "Reshaped to long format: " _N " person-wave observations."

* ============================================================================
* 6. CREATE SURVEY YEAR VARIABLE
* ============================================================================

gen year = .
replace year = 1992 if wave == 1
replace year = 1994 if wave == 2
replace year = 1996 if wave == 3
replace year = 1998 if wave == 4
replace year = 2000 if wave == 5
replace year = 2002 if wave == 6
replace year = 2004 if wave == 7
replace year = 2006 if wave == 8
replace year = 2008 if wave == 9
replace year = 2010 if wave == 10
replace year = 2012 if wave == 11
replace year = 2014 if wave == 12
replace year = 2016 if wave == 13
replace year = 2018 if wave == 14
replace year = 2020 if wave == 15
replace year = 2022 if wave == 16
label var year "Survey year (primary)"
label var wave "HRS wave number (1-16)"

tempvar requested_wave_flag
gen byte `requested_wave_flag' = 0
foreach w of local requested_waves {
    replace `requested_wave_flag' = 1 if wave == `w'
}
quietly count if `requested_wave_flag' == 0
if r(N) > 0 {
    keep if `requested_wave_flag' == 1
}

* ============================================================================
* 7. SORT, SAVE, AND VALIDATE
* ============================================================================

sort hhidpn wave

save "`out_dta'", replace
display as text "Saved: `out_dta'"

if `write_csv_export' {
    export delimited using "`out_csv'", replace
    display as text "Saved: `out_csv'"
}
else {
    display as text "Skipped CSV export. Set global hrs_write_csv_export 1 to create it."
}

display as text _newline "============================================"
display as text "   VALIDATION CHECKS"
display as text "============================================"

local n_requested_waves = wordcount("`requested_waves'")
local expected_N = 45234 * `n_requested_waves'
if _N == `expected_N' {
    display as text "[PASS] Observation count: " _N " (= 45,234 x `n_requested_waves' selected wave(s))"
}
else {
    display as error "[WARN] Expected `expected_N' observations but found " _N
}

tempvar observed_requested_wave
quietly gen byte `observed_requested_wave' = 0
foreach w of local requested_waves {
    quietly replace `observed_requested_wave' = 1 if wave == `w'
}
quietly count if `observed_requested_wave' == 0
if r(N) == 0 {
    display as text "[PASS] Wave selection matches requested waves: `requested_waves'"
}
else {
    display as error "[WARN] Found observations outside requested waves: `requested_waves'"
}

tempvar respondent_tag
quietly egen `respondent_tag' = tag(hhidpn)
quietly count if `respondent_tag'
local n_unique = r(N)
if `n_unique' == 45234 {
    display as text "[PASS] Unique respondents: `n_unique'"
}
else {
    display as error "[WARN] Expected 45,234 unique respondents but found `n_unique'"
}

quietly {
    tempvar wave_count
    bysort hhidpn: gen `wave_count' = _N
    summarize `wave_count'
}
if r(min) == `n_requested_waves' & r(max) == `n_requested_waves' {
    display as text "[PASS] All respondents have exactly `n_requested_waves' selected wave row(s)"
}
else {
    display as error "[WARN] Some respondents have unexpected row counts (min=" r(min) ", max=" r(max) ")"
}

quietly count if missing(year)
if r(N) == 0 {
    display as text "[PASS] Year variable has no missing values"
}
else {
    display as error "[WARN] Year variable has " r(N) " missing values"
}

local key_vars "hhidpn wave year inw ragender rabyear raeduc rshlt rcesd rbmi hitot hatotb"
local all_exist = 1
local missing_vars
foreach v of local key_vars {
    capture confirm variable `v'
    if _rc != 0 {
        local all_exist = 0
        local missing_vars "`missing_vars' `v'"
    }
}
if `all_exist' == 1 {
    display as text "[PASS] Starter key variables present"
}
else {
    display as error "[WARN] Missing starter key variable(s):`missing_vars'"
}

capture confirm variable rshlt
if !_rc {
    quietly count if rshlt < 1 | (rshlt > 5 & rshlt < .)
    if r(N) == 0 {
        display as text "[PASS] Self-rated health (rshlt) values in expected range 1-5"
    }
    else {
        display as error "[WARN] rshlt has " r(N) " observations outside range 1-5"
    }
}

capture confirm variable inw
if !_rc {
    quietly count if inw != 0 & inw != 1 & !missing(inw)
    if r(N) == 0 {
        display as text "[PASS] In-wave indicator (inw) is 0/1 as expected"
    }
    else {
        display as error "[WARN] inw has " r(N) " observations that are not 0 or 1"
    }
}

if `keep_starter_vars_only' {
    display as text "[INFO] Low-memory mode intentionally keeps a compact starter variable set."
}
else if c(k) > 500 {
    display as text "[PASS] Variable count (" c(k) ") indicates broad wave-varying coverage"
}
else {
    display as error "[WARN] Variable count (" c(k) ") seems low for the full build"
}

display as text _newline "Done. Long-format panel has " _N " observations and " c(k) " variables."
display as text "Next step: run code/02_clean_demographics.do"

********************************************************************************
* NOTES FOR USERS:
*
* 1. This standalone optional script reads only the selected starter columns,
*    requested extras, and selected waves before reshaping.
*
* 2. Use long-format stubs for wave-varying extras, for example:
*      global hrs_extra_wave_stubs "rcovrt scovrt"
*
* 3. Low-memory Stata builds skip the very large CSV unless you set:
*      global hrs_write_csv_export 1
********************************************************************************
