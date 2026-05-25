********************************************************************************
* 12_load_2008_welfare_retirement_pension.do
*
* Purpose: Load 2008 SIPP topical waves with welfare reform and retirement or
*          pension-plan coverage content.
********************************************************************************

********************************************************************************
* USER SETTINGS
********************************************************************************

* Optional manual path override:
* global sipp_root "/Users/yourname/path/to/econ-data-starters/sipp"
*
* Optional output override:
* global sipp_output_dir "/private/tmp/sipp_smoke"
* global sipp_output_basename "sipp_smoke"
*
* Wave 3 includes welfare reform and pensions; wave 11 is pensions only.
* global sipp_tm_welfare_pension_waves "3 11"
*
* Optional settings passed to the shared topical loader:
* global sipp_2008_tm_n_max 1000
* global sipp_2008_tm_allocs 1
* global sipp_2008_tm_extra_vars "A1YRSINC"

if "$sipp_tm_welfare_pension_waves" == "" {
    global sipp_tm_welfare_pension_waves "3 11"
}

global sipp_2008_tm_waves "$sipp_tm_welfare_pension_waves"
global sipp_2008_tm_family_tag "welfare_retirement_pension"
global sipp_2008_tm_family_label "Welfare reform and retirement or pension-plan coverage"
global sipp_2008_tm_family_note "Family-tagged topical extract for waves 3 and 11; wave 3 includes welfare reform content, and neither wave is a harmonized cleaner."

local cwd "`c(pwd)'"
if "$sipp_root" != "" & fileexists("$sipp_root/code/09_load_2008_topical_modules.do") {
    local loader "$sipp_root/code/09_load_2008_topical_modules.do"
}
else if fileexists("code/09_load_2008_topical_modules.do") {
    local loader "code/09_load_2008_topical_modules.do"
}
else if fileexists("09_load_2008_topical_modules.do") {
    local loader "09_load_2008_topical_modules.do"
}
else if fileexists("sipp/code/09_load_2008_topical_modules.do") {
    local loader "sipp/code/09_load_2008_topical_modules.do"
}
else {
    display as error "Could not locate 09_load_2008_topical_modules.do. Run from sipp/, sipp/code/, repo root, or set sipp_root."
    error 601
}

do "`loader'"
