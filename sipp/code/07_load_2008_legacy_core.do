********************************************************************************
* 07_load_2008_legacy_core.do
*
* Purpose: Load selected 2008 SIPP legacy fixed-width core waves into a compact
*          person-month starter file.
********************************************************************************

clear all
set more off

********************************************************************************
* USER SETTINGS
********************************************************************************

* Optional manual path override:
* global sipp_root "/Users/yourname/path/to/econ-data-starters/sipp"
* do "$sipp_root/code/07_load_2008_legacy_core.do"
*
* Optional output override:
* global sipp_output_dir "/private/tmp/sipp_smoke"
* global sipp_output_basename "sipp_smoke"
*
* Main file choices:
* global sipp_2008_waves "16"
* global sipp_2008_waves "1 16"
* global sipp_2008_waves "all"
* global sipp_2008_skip_unreadable 1
*
* Optional row limit for smoke tests. Leave blank for full files.
* global sipp_2008_n_max 1000

********************************************************************************
* PATHS AND OPTIONS
********************************************************************************

local cwd "`c(pwd)'"
if "$sipp_root" != "" & fileexists("$sipp_root/code/07_load_2008_legacy_core.do") {
    global sipp_root "$sipp_root"
}
else if fileexists("code/07_load_2008_legacy_core.do") & fileexists("README.md") {
    global sipp_root "`cwd'"
}
else if fileexists("07_load_2008_legacy_core.do") & fileexists("../README.md") {
    global sipp_root "`cwd'/.."
}
else if fileexists("sipp/code/07_load_2008_legacy_core.do") & fileexists("sipp/README.md") {
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

local waves "16"
if "$sipp_2008_waves" != "" {
    local requested = lower("$sipp_2008_waves")
    if "`requested'" == "all" {
        local waves "1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16"
    }
    else {
        local waves "`requested'"
    }
}

local row_limit ""
if "$sipp_2008_n_max" != "" {
    local row_limit "$sipp_2008_n_max"
}
global sipp_internal_2008_row_limit "`row_limit'"

local skip_unreadable = 0
if "$sipp_2008_skip_unreadable" == "1" {
    local skip_unreadable = 1
}

display as text "Using SIPP root: $sipp_root"
display as text "Selected 2008 SIPP legacy waves: `waves'"

********************************************************************************
* LOAD HELPERS
********************************************************************************

capture program drop sipp_load_2008_core_wave
program define sipp_load_2008_core_wave
    args wave output_file skip_unreadable

    local dat_gz "data/2008/wave`wave'/l08puw`wave'.dat.gz"
    if !fileexists("`dat_gz'") {
        if `skip_unreadable' {
            display as text "Skipping 2008 SIPP core wave `wave': local file not found."
            exit
        }
        display as error "No local 2008 SIPP core file found: `dat_gz'"
        error 601
    }

    local old_cwd "`c(pwd)'"
    local extract_dir "`c(tmpdir)'/sipp_2008_core_wave`wave'_extract"
    capture mkdir "`extract_dir'"
    local dat_path "`extract_dir'/l08puw`wave'.dat"
    capture erase "`dat_path'"
    shell gzip -dc "`old_cwd'/`dat_gz'" > "`dat_path'"
    capture confirm file "`dat_path'"
    if _rc {
        if `skip_unreadable' {
            display as text "Skipping 2008 SIPP core wave `wave': could not decompress file."
            exit
        }
        display as error "Could not decompress `dat_gz'."
        error 601
    }

    display as text "Reading 2008 SIPP legacy core wave `wave'"
    if "$sipp_internal_2008_row_limit" != "" {
        infix ///
            str ssuid 6-17 spanel 18-21 swave 22-23 srefmon 25-25 ///
            rhcalmn 26-27 rhcalyr 28-31 str shhadid 32-34 str gvarstr 35-37 ///
            str ghlfsam 38-38 tfipsst 42-43 tmovrflg 44-45 ehhnumpp 59-61 ///
            whfnwgt 63-72 tmetro 73-73 etenure 77-77 thtotinc 166-173 ///
            rhnbrf 174-175 thsocsec 206-211 thssi 212-217 thunemp 218-223 ///
            thfdstp 236-241 rfid 242-244 rfnkids 263-264 wffinwgt 271-280 ///
            tftotinc 310-317 rfpov 318-322 tfsocsec 338-343 tfssi 344-349 ///
            tfunemp 350-355 tffdstp 368-373 epppnum 503-506 epopstat 509-509 ///
            esex 518-518 erace 520-520 eorigin 522-523 ebornus 525-526 ///
            ecitizen 528-529 wpfinwgt 567-576 tage 579-580 errp 582-583 ///
            ems 585-585 tpearn 619-625 tptotinc 648-655 eeducate 786-787 ///
            rmesr 859-860 ehimth 2230-2231 ehiallcv 2306-2307 ///
            using "`dat_path'" in 1/$sipp_internal_2008_row_limit, clear
    }
    else {
        infix ///
            str ssuid 6-17 spanel 18-21 swave 22-23 srefmon 25-25 ///
            rhcalmn 26-27 rhcalyr 28-31 str shhadid 32-34 str gvarstr 35-37 ///
            str ghlfsam 38-38 tfipsst 42-43 tmovrflg 44-45 ehhnumpp 59-61 ///
            whfnwgt 63-72 tmetro 73-73 etenure 77-77 thtotinc 166-173 ///
            rhnbrf 174-175 thsocsec 206-211 thssi 212-217 thunemp 218-223 ///
            thfdstp 236-241 rfid 242-244 rfnkids 263-264 wffinwgt 271-280 ///
            tftotinc 310-317 rfpov 318-322 tfsocsec 338-343 tfssi 344-349 ///
            tfunemp 350-355 tffdstp 368-373 epppnum 503-506 epopstat 509-509 ///
            esex 518-518 erace 520-520 eorigin 522-523 ebornus 525-526 ///
            ecitizen 528-529 wpfinwgt 567-576 tage 579-580 errp 582-583 ///
            ems 585-585 tpearn 619-625 tptotinc 648-655 eeducate 786-787 ///
            rmesr 859-860 ehimth 2230-2231 ehiallcv 2306-2307 ///
            using "`dat_path'", clear
    }

    gen int pnum = epppnum
    gen byte eeduc = eeducate
    gen str14 source_file = "l08puw`wave'.dat"
    gen str12 design_era = "2008_legacy"
    gen int sipp_file_year = 2008
    gen byte panel_wave = `wave'
    order source_file design_era sipp_file_year panel_wave
    compress
    save "`output_file'", replace
    capture erase "`dat_path'"
    cd "`old_cwd'"
end

local first_wave = 1
local loaded_waves = 0
tempfile combined
foreach w of local waves {
    tempfile one_wave
    capture noisily sipp_load_2008_core_wave `w' "`one_wave'" `skip_unreadable'
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
    display as error "No 2008 SIPP legacy core files were loaded."
    error 2000
}

use "`combined'", clear
sort panel_wave ssuid pnum rhcalmn
compress
save "`output_dir'/`output_basename'_2008_legacy_core_person_month.dta", replace
display as text "Saved 2008 SIPP legacy core person-month file: `output_dir'/`output_basename'_2008_legacy_core_person_month.dta"
