********************************************************************************
* 13_load_2008_assets_medical_child_wellbeing.do
*
* Purpose: Load 2008 SIPP topical waves with assets/liabilities, medical
*          expenses/health-care utilization, and related recurring content.
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
* Waves 4, 7, and 10 repeat broad assets/medical themes; waves 4 and 10 also
* include child well-being content.
* global sipp_tm_assets_med_waves "4 7 10"
*
* Optional settings passed to the shared topical loader:
* global sipp_2008_tm_n_max 1000
* global sipp_2008_tm_allocs 1
* global sipp_2008_tm_extra_vars "AALR"

if "$sipp_tm_assets_med_waves" == "" {
    global sipp_tm_assets_med_waves "4 7 10"
}

global sipp_2008_tm_waves "$sipp_tm_assets_med_waves"
global sipp_2008_tm_family_tag "assets_medical_child_wellbeing"
global sipp_2008_tm_family_label "Assets, liabilities, medical expenses, health-care utilization, and child well-being"
global sipp_2008_tm_family_note "Family-tagged topical extract for waves 4, 7, and 10. Waves 4 and 10 include child well-being; wave 7 does not. This is not a harmonized cleaner."

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
