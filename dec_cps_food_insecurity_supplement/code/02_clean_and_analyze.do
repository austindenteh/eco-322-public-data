/*==============================================================================
    02_clean_and_analyze.do

    Author:   Austin Denteh
    Date:     March 2026
    Purpose:  Clean demographics, construct food security outcomes, SNAP and
              other food assistance variables, produce descriptive statistics,
              and run an example regression using the December CPS Food Security
              Supplement.

    Input:    ${dec_cps_root}/output/dec_cps_working.dta
    Output:   ${dec_cps_root}/output/dec_cps_clean.dta

    Notes:
    - Assumes 01_load_and_append.do has already been run and produced
      dec_cps_working.dta.
    - All variable names follow IPUMS CPS conventions (lowercase).
    - Food security variables use the CPS Food Security Supplement coding:
        fsstatusd: 1=high, 2=marginal, 3=low, 4=very low, 98=no response, 99=NIU
        fsstatusa: same coding (adult scale)
        fsstatusc: 1=high/marginal, 2=low, 3=very low, 98=no response, 99=NIU
    - SNAP (fsfdstmp): 0=NIU, 1=Yes, 2=No
    - Weight: fshwtscale (food security supplement household weight, scaled)
    - Household-level analyses should be restricted to one record per household
      (e.g., the household respondent via hhrespln == lineno).
==============================================================================*/

clear all
set more off

* ---------------------------------------------------------------------------- *
* SECTION 1: Setup and Load Data
* ---------------------------------------------------------------------------- *

* --- Set root path (edit this to match your system) ---
global dec_cps_root "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/dec_cps_food_insecurity_supplement"

* --- Load working dataset ---
use "${dec_cps_root}/output/dec_cps_working.dta", clear

display _newline(2)
display "============================================================"
display " SECTION 1: Data Loaded"
display "============================================================"
display "Observations: " _N
describe, short


* ---------------------------------------------------------------------------- *
* SECTION 2: Demographics — Race/Ethnicity
* ---------------------------------------------------------------------------- *

display _newline(2)
display "============================================================"
display " SECTION 2: Race/Ethnicity"
display "============================================================"

* --- Female indicator ---
gen female = (sex == 2)
label var female "Female (1=yes)"

* --- Hispanic indicator ---
*     IPUMS CPS hispan: 0=Not Hispanic, 100-412=Hispanic origin groups,
*     901=Unknown, 902=NA
gen hisp = 1
replace hisp = 0 if inlist(hispan, 0, 901, 902)
label var hisp "Hispanic (any origin)"

* --- Race indicators (non-Hispanic only) ---
*     IPUMS CPS race codes:
*       100 = White
*       200 = Black
*       300 = American Indian/Aleut/Eskimo
*       650 = Asian only, 651 = Hawaiian/Pacific Islander only,
*       652 = Asian and/or Pacific Islander (pre-2003)
*       700-830 = Two or more races

gen white = (race == 100 & hisp == 0)
label var white "White, non-Hispanic"

gen black = (race == 200 & hisp == 0)
label var black "Black, non-Hispanic"

gen amind = (race == 300 & hisp == 0)
label var amind "American Indian, non-Hispanic"

capture drop asian   // IPUMS CPS may include an 'asian' flag variable
gen asian = (inlist(race, 650, 651, 652) & hisp == 0)
label var asian "Asian/Pacific Islander, non-Hispanic"

gen otherrace = (hisp == 0 & white == 0 & black == 0 & amind == 0 & asian == 0)
label var otherrace "Other/multiracial, non-Hispanic"

* --- Mutually exclusive race/ethnicity variable ---
gen race_eth = .
replace race_eth = 1 if white == 1
replace race_eth = 2 if black == 1
replace race_eth = 3 if hisp == 1
replace race_eth = 4 if asian == 1
replace race_eth = 5 if (amind == 1 | otherrace == 1)
label var race_eth "Race/ethnicity (mutually exclusive)"

label define race_eth_lbl 1 "White NH" 2 "Black NH" 3 "Hispanic" ///
    4 "Asian NH" 5 "Other NH"
label values race_eth race_eth_lbl

tab race_eth, missing
tab race_eth female, row


* ---------------------------------------------------------------------------- *
* SECTION 3: Demographics — Age and Marital Status
* ---------------------------------------------------------------------------- *

display _newline(2)
display "============================================================"
display " SECTION 3: Age and Marital Status"
display "============================================================"

* --- Age groups ---
gen age_grp = .
replace age_grp = 1 if age >= 18 & age <= 24
replace age_grp = 2 if age >= 25 & age <= 34
replace age_grp = 3 if age >= 35 & age <= 44
replace age_grp = 4 if age >= 45 & age <= 54
replace age_grp = 5 if age >= 55 & age <= 64
replace age_grp = 6 if age >= 65 & age < .
label var age_grp "Age group"

label define age_grp_lbl 1 "18-24" 2 "25-34" 3 "35-44" 4 "45-54" ///
    5 "55-64" 6 "65+"
label values age_grp age_grp_lbl

tab age_grp, missing

* --- Senior indicator (60+ per FSS convention) ---
gen senior = (age >= 60) if age < .
label var senior "Senior (age 60+, FSS convention)"

* --- Married indicator ---
*     IPUMS CPS marst: 1=Married, spouse present; 2=Married, spouse absent
gen married = inlist(marst, 1, 2)
label var married "Married (1=yes)"

tab married, missing

* --- Foreign-born indicator (guarded) ---
capture confirm variable nativity
if _rc == 0 {
    gen foreignborn = (nativity == 5)
    label var foreignborn "Foreign-born (1=yes)"
    tab foreignborn, missing
}
else {
    display "  Note: nativity not available in this extract."
}


* ---------------------------------------------------------------------------- *
* SECTION 4: Education
* ---------------------------------------------------------------------------- *

display _newline(2)
display "============================================================"
display " SECTION 4: Education"
display "============================================================"

* --- Education categories from educ99 (IPUMS CPS detailed education) ---
*     educ99 codes:
*       0-9   = Less than high school
*       10    = High school diploma/GED
*       11    = Some college, no degree
*       12-14 = Associate degrees
*       15    = Bachelor's degree
*       16    = Master's degree
*       17    = Professional degree
*       18    = Doctorate degree

capture confirm variable educ99
if _rc == 0 {
    gen educ_lths  = (educ99 < 10)              if educ99 < .
    gen educ_hs    = inlist(educ99, 10, 11)      if educ99 < .
    gen educ_assoc = inlist(educ99, 12, 13, 14)  if educ99 < .
    gen educ_bach  = (educ99 == 15)              if educ99 < .
    gen educ_advdeg = inlist(educ99, 16, 17, 18) if educ99 < .

    label var educ_lths  "Less than high school"
    label var educ_hs    "HS diploma/GED or some college"
    label var educ_assoc "Associate degree"
    label var educ_bach  "Bachelor's degree"
    label var educ_advdeg "Advanced degree (MA/Prof/PhD)"

    tab educ_lths,  missing
    tab educ_hs,    missing
    tab educ_bach,  missing
    tab educ_advdeg, missing
}
else {
    display "  Note: educ99 not available — skipping education variables."
}


* ---------------------------------------------------------------------------- *
* SECTION 5: Employment Status
* ---------------------------------------------------------------------------- *

display _newline(2)
display "============================================================"
display " SECTION 5: Employment Status"
display "============================================================"

* --- Employment indicators from empstat (IPUMS CPS detailed codes) ---
*     1, 10, 12 = At work / Has job, not at work / Armed Forces
*     20, 21, 22 = Unemployed (new/experienced/etc.)
*     30-36      = Not in labor force

capture confirm variable empstat
if _rc == 0 {
    gen employed    = inlist(empstat, 1, 10, 12) if empstat > 0 & empstat < .
    gen unemployed  = inlist(empstat, 20, 21, 22) if empstat > 0 & empstat < .
    gen not_in_lf   = inlist(empstat, 30, 31, 32, 33, 34, 35, 36) if empstat > 0 & empstat < .

    label var employed   "Employed (1=yes)"
    label var unemployed "Unemployed (1=yes)"
    label var not_in_lf  "Not in labor force (1=yes)"

    tab employed,   missing
    tab unemployed, missing
    tab not_in_lf,  missing
}
else {
    display "  Note: empstat not available — skipping employment variables."
}


* ---------------------------------------------------------------------------- *
* SECTION 6: Household Composition
* ---------------------------------------------------------------------------- *

display _newline(2)
display "============================================================"
display " SECTION 6: Household Composition"
display "============================================================"

* --- Any children in household ---
capture confirm variable nchild
if _rc == 0 {
    gen any_child = (nchild > 0) if nchild < .
    label var any_child "Any own children in household (1=yes)"
    tab any_child, missing
}
else {
    display "  Note: nchild not available — skipping child indicator."
}

* --- Household-level senior indicators ---
*     Requires a household ID variable. Try serial (IPUMS household serial).
capture confirm variable serial
if _rc == 0 {
    local hhid_var "serial"
}
else {
    * Fall back to cpsid if serial is not available
    capture confirm variable cpsid
    if _rc == 0 {
        local hhid_var "cpsid"
    }
    else {
        local hhid_var ""
    }
}

if "`hhid_var'" != "" {
    bysort year `hhid_var': egen hh_anysenior = max(senior)
    label var hh_anysenior "Household has any member age 60+ (1=yes)"

    bysort year `hhid_var': egen hh_allsenior = min(senior)
    label var hh_allsenior "All household members age 60+ (1=yes)"

    tab hh_anysenior, missing
    tab hh_allsenior, missing
}
else {
    display "  Note: No household ID found — skipping HH-level senior indicators."
}


* ---------------------------------------------------------------------------- *
* SECTION 7: Food Security Outcomes
* ---------------------------------------------------------------------------- *

display _newline(2)
display "============================================================"
display " SECTION 7: Food Security Outcomes"
display "============================================================"
display "  This is the core value of the December CPS FSS."

* --- Household food security status (detailed, fsstatusd) ---
*     1 = High food security
*     2 = Marginal food security
*     3 = Low food security
*     4 = Very low food security
*     98 = No response
*     99 = NIU (not in universe)

capture confirm variable fsstatusd
if _rc == 0 {
    gen fs_high    = (fsstatusd == 1) if !inlist(fsstatusd, 98, 99, .)
    gen fs_marginal = (fsstatusd == 2) if !inlist(fsstatusd, 98, 99, .)
    gen fs_low     = (fsstatusd == 3) if !inlist(fsstatusd, 98, 99, .)
    gen fs_verylow = (fsstatusd == 4) if !inlist(fsstatusd, 98, 99, .)
    gen food_insecure = (inlist(fsstatusd, 3, 4)) if !inlist(fsstatusd, 98, 99, .)

    label var fs_high       "High food security (1=yes)"
    label var fs_marginal   "Marginal food security (1=yes)"
    label var fs_low        "Low food security (1=yes)"
    label var fs_verylow    "Very low food security (1=yes)"
    label var food_insecure "Food insecure (low or very low, 1=yes)"

    display _newline
    display "--- Household Food Security Status ---"
    tab fsstatusd if !inlist(fsstatusd, 98, 99), missing

    display _newline
    display "--- Food Insecurity Rate ---"
    summarize food_insecure
}
else {
    display "  WARNING: fsstatusd not found — cannot create food security outcomes."
}

* --- Adult food security status (fsstatusa) ---
capture confirm variable fsstatusa
if _rc == 0 {
    gen fsa_high    = (fsstatusa == 1) if !inlist(fsstatusa, 98, 99, .)
    gen fsa_low     = (fsstatusa == 3) if !inlist(fsstatusa, 98, 99, .)
    gen fsa_verylow = (fsstatusa == 4) if !inlist(fsstatusa, 98, 99, .)
    gen adult_food_insecure = (inlist(fsstatusa, 3, 4)) if !inlist(fsstatusa, 98, 99, .)

    label var fsa_high           "Adult high food security (1=yes)"
    label var fsa_low            "Adult low food security (1=yes)"
    label var fsa_verylow        "Adult very low food security (1=yes)"
    label var adult_food_insecure "Adult food insecure (low or very low, 1=yes)"

    display _newline
    display "--- Adult Food Security Status ---"
    tab fsstatusa if !inlist(fsstatusa, 98, 99), missing
}
else {
    display "  Note: fsstatusa not available — skipping adult food security."
}

* --- Child food security status (fsstatusc) ---
*     Only relevant for households with children.
*     Coding differs slightly: 1=high/marginal, 2=low, 3=very low
capture confirm variable fsstatusc
if _rc == 0 {
    gen fsc_low     = (fsstatusc == 2) if !inlist(fsstatusc, 98, 99, .)
    gen fsc_verylow = (fsstatusc == 3) if !inlist(fsstatusc, 98, 99, .)
    gen child_food_insecure = (inlist(fsstatusc, 2, 3)) if !inlist(fsstatusc, 98, 99, .)

    label var fsc_low             "Child low food security (1=yes)"
    label var fsc_verylow         "Child very low food security (1=yes)"
    label var child_food_insecure "Child food insecure (low or very low, 1=yes)"

    display _newline
    display "--- Child Food Security Status ---"
    tab fsstatusc if !inlist(fsstatusc, 98, 99), missing
}
else {
    display "  Note: fsstatusc not available — skipping child food security."
}

* --- Raw food security scores (label existing variables) ---
capture label var fsrawscr  "Food security raw score (18-item, household)"
capture label var fsrawscra "Food security raw score (10-item, adult)"
capture label var fsrawscrc "Food security raw score (8-item, child)"

* --- Display food security rates by year ---
display _newline
display "--- Food Security Rates by Year ---"
capture confirm variable food_insecure
if _rc == 0 {
    table year, stat(mean food_insecure) stat(count food_insecure) nformat(%9.3f)
}


* ---------------------------------------------------------------------------- *
* SECTION 8: SNAP Participation
* ---------------------------------------------------------------------------- *

display _newline(2)
display "============================================================"
display " SECTION 8: SNAP Participation"
display "============================================================"

* --- SNAP receipt (fsfdstmp) ---
*     IPUMS CPS coding: 0=NIU, 1=Yes, 2=No
capture confirm variable fsfdstmp
if _rc == 0 {
    gen snap_participant = (fsfdstmp == 1) if fsfdstmp > 0 & fsfdstmp < 98
    label var snap_participant "Received SNAP/food stamps (1=yes)"

    display _newline
    display "--- SNAP Participation ---"
    tab snap_participant, missing

    display _newline
    display "--- SNAP Participation by Year ---"
    table year, stat(mean snap_participant) stat(count snap_participant) nformat(%9.3f)
}
else {
    display "  Note: fsfdstmp not available — skipping SNAP participation."
}

* --- Monthly SNAP indicators (guarded, available 2002+) ---
capture confirm variable fsstmpjan
if _rc == 0 {
    display _newline
    display "--- Monthly SNAP variables detected (fsstmpjan-fsstmpdec) ---"
    display "  These indicate SNAP receipt in each month of the prior year."
    display "  Coding: 0=NIU, 1=Yes, 2=No"

    foreach m in jan feb mar apr may jun jul aug sep oct nov dec {
        capture gen snap_`m' = (fsstmp`m' == 1) if fsstmp`m' > 0 & fsstmp`m' < 98
        capture label var snap_`m' "SNAP receipt in `m' (1=yes)"
    }

    display "  Created snap_jan through snap_dec."
}
else {
    display "  Note: Monthly SNAP variables not available."
}


* ---------------------------------------------------------------------------- *
* SECTION 9: Other Food Assistance Programs
* ---------------------------------------------------------------------------- *

display _newline(2)
display "============================================================"
display " SECTION 9: Other Food Assistance Programs"
display "============================================================"

* --- School lunch (free/reduced) ---
*     fslnchfrc: 0=NIU, 1=Yes, 2=No
capture confirm variable fslnchfrc
if _rc == 0 {
    gen school_lunch = (fslnchfrc == 1) if fslnchfrc > 0 & fslnchfrc < 98
    label var school_lunch "Received free/reduced school lunch (1=yes)"
    tab school_lunch, missing
}
else {
    display "  Note: fslnchfrc not available — skipping school lunch."
}

* --- WIC ---
*     fswic: 0=NIU, 1=Yes, 2=No
capture confirm variable fswic
if _rc == 0 {
    gen wic = (fswic == 1) if fswic > 0 & fswic < 98
    label var wic "Received WIC (1=yes)"
    tab wic, missing
}
else {
    display "  Note: fswic not available — skipping WIC."
}

* --- Food bank ---
*     fsfdbnk: 0=NIU, 1=Yes, 2=No
capture confirm variable fsfdbnk
if _rc == 0 {
    gen food_bank = (fsfdbnk == 1) if fsfdbnk > 0 & fsfdbnk < 98
    label var food_bank "Used food bank/pantry (1=yes)"
    tab food_bank, missing
}
else {
    display "  Note: fsfdbnk not available — skipping food bank."
}

* --- Soup kitchen ---
*     fssoupk: 0=NIU, 1=Yes, 2=No
capture confirm variable fssoupk
if _rc == 0 {
    gen soup_kitchen = (fssoupk == 1) if fssoupk > 0 & fssoupk < 98
    label var soup_kitchen "Used soup kitchen (1=yes)"
    tab soup_kitchen, missing
}
else {
    display "  Note: fssoupk not available — skipping soup kitchen."
}


* ---------------------------------------------------------------------------- *
* SECTION 10: Descriptive Statistics
* ---------------------------------------------------------------------------- *

display _newline(2)
display "============================================================"
display " SECTION 10: Descriptive Statistics"
display "============================================================"

* --- Demographics summary ---
display _newline
display "--- Demographics Summary ---"
summarize female age senior married

capture confirm variable foreignborn
if _rc == 0 {
    summarize foreignborn
}

capture confirm variable employed
if _rc == 0 {
    summarize employed unemployed not_in_lf
}

capture confirm variable educ_lths
if _rc == 0 {
    summarize educ_lths educ_hs educ_assoc educ_bach educ_advdeg
}

* --- Food security rates by year ---
display _newline
display "--- Food Insecurity Rate by Year ---"
capture confirm variable food_insecure
if _rc == 0 {
    table year, stat(mean food_insecure) stat(count food_insecure) nformat(%9.3f)
}

* --- SNAP participation by year ---
display _newline
display "--- SNAP Participation Rate by Year ---"
capture confirm variable snap_participant
if _rc == 0 {
    table year, stat(mean snap_participant) stat(count snap_participant) nformat(%9.3f)
}

* --- Food security by race/ethnicity ---
display _newline
display "--- Food Insecurity Rate by Race/Ethnicity ---"
capture confirm variable food_insecure
if _rc == 0 {
    table race_eth, stat(mean food_insecure) stat(count food_insecure) nformat(%9.3f)
}

* --- SNAP participation by race/ethnicity ---
display _newline
display "--- SNAP Participation by Race/Ethnicity ---"
capture confirm variable snap_participant
if _rc == 0 {
    table race_eth, stat(mean snap_participant) stat(count snap_participant) nformat(%9.3f)
}


* ---------------------------------------------------------------------------- *
* SECTION 11: Example Regression
* ---------------------------------------------------------------------------- *

display _newline(2)
display "============================================================"
display " SECTION 11: Example Regression"
display "============================================================"
display "  Linear probability model: food insecurity determinants"
display "  Note: For household-level analysis, restrict to one record per"
display "  household (e.g., where lineno == hhrespln). This example uses"
display "  person-level data with FSS supplement weights."

* --- Check for required variables ---
capture confirm variable food_insecure
if _rc != 0 {
    display "  ERROR: food_insecure not created — cannot run regression."
}
else {
    * --- LPM: food insecurity on demographics + SNAP ---
    capture confirm variable fshwtscale
    if _rc == 0 {
        local wt "[pw=fshwtscale]"
        display "  Using fshwtscale (food security supplement weight)."
    }
    else {
        * Fall back to fssuppwth if fshwtscale is not available
        capture confirm variable fssuppwth
        if _rc == 0 {
            local wt "[pw=fssuppwth]"
            display "  Using fssuppwth (FSS supplement weight)."
        }
        else {
            local wt ""
            display "  WARNING: No FSS weight found — running unweighted."
        }
    }

    * Build the regression command with available variables
    local rhs "female age i.race_eth"

    capture confirm variable educ_hs
    if _rc == 0 {
        local rhs "`rhs' educ_hs educ_bach"
    }

    local rhs "`rhs' married"

    capture confirm variable snap_participant
    if _rc == 0 {
        local rhs "`rhs' snap_participant"
    }

    display _newline
    display "  Dependent variable: food_insecure"
    display "  Covariates: `rhs' i.year"
    display ""

    reg food_insecure `rhs' i.year `wt', robust
}


* ---------------------------------------------------------------------------- *
* SECTION 12: Save Clean Dataset
* ---------------------------------------------------------------------------- *

display _newline(2)
display "============================================================"
display " SECTION 12: Save Clean Dataset"
display "============================================================"

compress
save "${dec_cps_root}/output/dec_cps_clean.dta", replace

display _newline
display "============================================================"
display " DONE: dec_cps_clean.dta saved to output/"
display "============================================================"


* ---------------------------------------------------------------------------- *
* NOTES
* ---------------------------------------------------------------------------- *
/*
    WEIGHT GUIDANCE:
    - fshwtscale: Food security supplement household weight (scaled).
      Use for household-level food security analyses.
    - fssuppwth: Alternative supplement household weight (check your extract).
    - wtfinl: CPS final person weight (for basic demographics, not FSS-specific).
    - For household-level analysis, keep one record per household.
      The FSS household respondent is identified when lineno == hhrespln.

    FOOD SECURITY CODING:
    - The USDA uses a 3-category classification: food secure (high + marginal),
      low food security, very low food security.
    - The "food_insecure" indicator here combines low + very low.
    - Raw scores (fsrawscr, fsrawscra, fsrawscrc) count affirmative responses
      to the food security questions. Higher = more food insecure.
    - Household scale: 18 items (0-2 = high, 3-5 = marginal, 6-8 = low, 9-18 = very low)
    - Adult scale: 10 items (0-1 = high, 2 = marginal, 3-5 = low, 6-10 = very low)
    - Child scale: 8 items (0-1 = high/marginal, 2-4 = low, 5-8 = very low)

    SNAP CODING:
    - fsfdstmp: 0=NIU, 1=Yes received SNAP, 2=No.
    - Monthly indicators (fsstmpjan-fsstmpdec): same coding, by calendar month.
    - SNAP amounts: fsstmpamo (monthly amount, available in some years).

    HOUSEHOLD vs. PERSON LEVEL:
    - Food security status is measured at the household level but assigned
      to all persons in the household in the IPUMS CPS extract.
    - For person-level regressions, standard errors should be clustered at
      the household level (serial or cpsid).
    - For household-level tabulations, keep only one person per household
      (lineno == hhrespln, or keep if pernum == 1).
*/
