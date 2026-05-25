********************************************************************************
* 15_load_2008_wellbeing_disability_support_caregiving.do
*
* Purpose: Load 2008 SIPP topical waves with adult well-being, disability,
*          support, employer health benefits, and caregiving content.
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
* Wave 6 includes well-being/disability/support/benefit content; wave 9 includes
* caregiving and adult well-being.
* global sipp_tm_wellbeing_care_waves "6 9"
*
* Optional settings passed to the shared topical loader:
* global sipp_2008_tm_n_max 1000
* global sipp_2008_tm_allocs 1
* global sipp_2008_tm_extra_vars "AYNOAB"

if "$sipp_tm_wellbeing_care_waves" == "" {
    global sipp_tm_wellbeing_care_waves "6 9"
}

global sipp_2008_tm_waves "$sipp_tm_wellbeing_care_waves"
global sipp_2008_tm_family_tag "wellbeing_disability_support_caregiving"
global sipp_2008_tm_family_label "Adult well-being, disability, support, employer health benefits, and caregiving"
global sipp_2008_tm_family_note "Family-tagged topical extract for waves 6 and 9. Wave content is related but not identical, so this is not a harmonized cleaner."

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
