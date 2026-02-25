********************************************************************************
* 01_reshape_and_save.do
*
* Purpose: Load the RAND HRS Longitudinal File 2022 (V1) in wide format,
*          reshape ALL wave-varying variables from wide to long panel format,
*          and save.
*
* Input:   data/raw/randhrs1992_2022v1.dta  (wide format, one row per person)
* Output:  output/hrs_long.dta              (long format, one row per person-wave)
*          output/hrs_long.csv
*
* Usage:   Run this script from the hrs/ directory:
*            cd "/path/to/hrs"
*            do code/01_reshape_and_save.do
*
* Data:    RAND HRS Longitudinal File 2022 (V1), May 2025
*          16 waves (1992-2022), 45,234 respondents, 8 entry cohorts
*
* Approach:
*   This script reshapes ALL wave-varying variables (r*, s*, h* prefixed),
*   not just a curated subset. It programmatically discovers all variable
*   stubs using Stata's `ds` command. 
*
*   The key challenge is that wave numbers can be 1 or 2 digits:
*     - Waves 1-9:  variable names have 2-char prefix (e.g., r1shlt, r9bmi)
*     - Waves 10-16: variable names have 3-char prefix (e.g., r10shlt, r16bmi)
*   We handle both cases separately and then union the stub lists.
*
* Author:  Austin Denteh (combination of old do files and Claude Code)
* Date:    February 2026
********************************************************************************

clear all
set more off
set maxvar 32767

* ============================================================================
* 1. DEFINE PATHS
* ============================================================================
* Set the working directory to the hrs/ folder.
* Users should update this path to match their system.

* Uncomment and edit ONE of the following lines:
 global hrs_root "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/hrs"
cd "$hrs_root"

* If you opened Stata from the hrs/ directory, the relative paths below
* will work without setting a global.

local raw_data  "data/raw/randhrs1992_2022v1.dta"
local out_dta   "output/hrs_long.dta"
local out_csv   "output/hrs_long.csv"

* ============================================================================
* 2. LOAD THE RAW DATA
* ============================================================================
* Load the entire RAND HRS file — all variables.
* The file has 45,234 observations (one per respondent) and thousands of
* wave-prefixed variables.

use "`raw_data'", clear

display as text "Loaded " _N " respondents from raw RAND HRS file."
display as text "Variables in memory: " c(k)

* ============================================================================
* 3. RENAME PROBLEMATIC VARIABLES
* ============================================================================
* Some s-prefix variables have naming patterns that conflict with the
* reshape stub detection. We append an underscore to move them out of the
* way of the programmatic stub-building below.
*
* These are spouse (s-prefix) word recall variables where the naming doesn't
* follow the standard [prefix][wave][concept] convention cleanly.

capture rename s1tr40  s1tr40_
capture rename s2htr40 s2htr40_
capture rename s2atr20 s2atr20_

forvalues w = 3/16 {
    capture rename s`w'tr20 s`w'tr20_
}

display as text "Renamed problematic s-prefix variables."

* ============================================================================
* 4. PROGRAMMATICALLY BUILD RESHAPE STUB LISTS
* ============================================================================
* Strategy (from legacy code, extended for 16 waves):
*
* For each prefix (r, h, s):
*   (a) Use `ds` to list all SINGLE-digit wave variables (waves 1-9)
*       by excluding double-digit waves and all other prefixes.
*       Strip the first 2 characters to get the concept name,
*       and build stubs like "r@shlt".
*
*   (b) Use `ds` to list all DOUBLE-digit wave variables (waves 10-16).
*       Strip the first 3 characters to get the concept name,
*       and build stubs like "r@shlt".
*
*   (c) Union the two stub lists.

* --- 4a. R-prefix variables (respondent) ------------------------------------
* For R-prefix: we want single-digit wave vars (r1*-r9*) only.
* We exclude: double-digit r-waves (r10*-r16*), time-invariant r-prefixes
* (ra*, re*), and everything non-r (s*, h*, hhidpn, pn, filever, inw*).
*
* NOTE: Stata's `ds ..., not` will error if a pattern matches no variables.
* We only include patterns that exist in the data.

local stublist_r1
ds r10* r11* r12* r13* r14* r15* r16* hhidpn hhid pn filever ra* re* h* s* inw*, not
foreach v of varlist `r(varlist)' {
    local vv1 = "r@" + substr("`v'", 3, .)
    local stublist_r1 `stublist_r1' `vv1'
}
local stublist_r1: list uniq stublist_r1
display as text "R-prefix stubs (waves 1-9): " wordcount("`stublist_r1'") " unique stubs"

* Double-digit waves (r10* through r16*)
local stublist_r2
ds r10* r11* r12* r13* r14* r15* r16*
foreach v of varlist `r(varlist)' {
    local vv2 = "r@" + substr("`v'", 4, .)
    local stublist_r2 `stublist_r2' `vv2'
}
local stublist_r2: list uniq stublist_r2
display as text "R-prefix stubs (waves 10-16): " wordcount("`stublist_r2'") " unique stubs"

* Union
local stublist_r: list stublist_r1 | stublist_r2
display as text "R-prefix stubs (all waves): " wordcount("`stublist_r'") " unique stubs"

* --- 4b. H-prefix variables (household) -------------------------------------
* For H-prefix: we want single-digit wave vars (h1*-h9*) only.
* Exclude: double-digit h-waves (h10*-h16*), time-invariant h-prefixes
* (ha*, hhidpn, hhid), and everything non-h (r*, s*, pn, filever, inw*).

local stublist_h1
ds h10* h11* h12* h13* h14* h15* h16* hhidpn hhid ha* r* s* pn filever inw*, not
foreach v of varlist `r(varlist)' {
    local vv5 = "h@" + substr("`v'", 3, .)
    local stublist_h1 `stublist_h1' `vv5'
}
local stublist_h1: list uniq stublist_h1
display as text "H-prefix stubs (waves 1-9): " wordcount("`stublist_h1'") " unique stubs"

local stublist_h2
ds h10* h11* h12* h13* h14* h15* h16*
foreach v of varlist `r(varlist)' {
    local vv6 = "h@" + substr("`v'", 4, .)
    local stublist_h2 `stublist_h2' `vv6'
}
local stublist_h2: list uniq stublist_h2
display as text "H-prefix stubs (waves 10-16): " wordcount("`stublist_h2'") " unique stubs"

local stublist_h: list stublist_h1 | stublist_h2
display as text "H-prefix stubs (all waves): " wordcount("`stublist_h'") " unique stubs"

* --- 4c. S-prefix variables (spouse) ----------------------------------------
* For S-prefix: we want single-digit wave vars (s1*-s9*) only.
* Exclude: double-digit s-waves (s10*-s16*), time-invariant s-prefixes
* (sa*), and everything non-s (r*, h*, hhidpn, hhid, pn, filever, inw*).

local stublist_s1
ds s10* s11* s12* s13* s14* s15* s16* sa* hhidpn hhid pn filever r* h* inw*, not
foreach v of varlist `r(varlist)' {
    local vv3 = "s@" + substr("`v'", 3, .)
    local stublist_s1 `stublist_s1' `vv3'
}
local stublist_s1: list uniq stublist_s1
display as text "S-prefix stubs (waves 1-9): " wordcount("`stublist_s1'") " unique stubs"

local stublist_s2
ds s10* s11* s12* s13* s14* s15* s16*
foreach v of varlist `r(varlist)' {
    local vv4 = "s@" + substr("`v'", 4, .)
    local stublist_s2 `stublist_s2' `vv4'
}
local stublist_s2: list uniq stublist_s2
display as text "S-prefix stubs (waves 10-16): " wordcount("`stublist_s2'") " unique stubs"

local stublist_s: list stublist_s1 | stublist_s2
display as text "S-prefix stubs (all waves): " wordcount("`stublist_s'") " unique stubs"

* ============================================================================
* 5. RESHAPE FROM WIDE TO LONG
* ============================================================================
* Reshape ALL wave-varying variables at once.
* The time-invariant variables (hhidpn, hhid, pn, hacohort, ragender,
* rabyear, raeduc, etc.) are automatically carried along.
*
* The `inw` variable (in-wave indicator) and `radtype`/`radstat` etc.
* (death-related administrative variables) also need to be included
* as they follow the wave-numbering convention.

display as text _newline "Reshaping from wide to long — this may take several minutes..."

reshape long `stublist_r' `stublist_s' `stublist_h' ///
    inw radtype radappm radappy radream radreay ///
    radrecm radrecy radendm radendy radstat radappd ///
    radread radrecd radendd ///
    , i(hhidpn) j(wave)

display as text "Reshaped to long format: " _N " person-wave observations."

* ============================================================================
* 6. CREATE SURVEY YEAR VARIABLE
* ============================================================================
* Map wave numbers to the primary survey year.
* Note: Waves 1-3 have different years for HRS vs. AHEAD cohorts.
* We use the HRS year as the primary year here.

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

* ============================================================================
* 7. SORT AND SAVE
* ============================================================================

sort hhidpn wave

* Save as Stata .dta
save "`out_dta'", replace
display as text "Saved: `out_dta'"

* Save as CSV (for use in R, Python, etc.)
* NOTE: The CSV will be very large given we reshaped all variables.
export delimited using "`out_csv'", replace
display as text "Saved: `out_csv'"

display as text _newline "Done! Long-format panel has " _N " observations."

* ============================================================================
* 8. VALIDATION CHECKS
* ============================================================================
* Verify the reshape produced the expected output. These checks will flag
* any problems with an error message but will not stop execution.

display as text _newline "============================================"
display as text "   VALIDATION CHECKS"
display as text "============================================"

* --- 8a. Check total observations ---
* Expected: 45,234 respondents × 16 waves = 723,744 person-wave obs.
local expected_N = 45234 * 16
if _N == `expected_N' {
    display as text "[PASS] Observation count: " _N " (= 45,234 × 16)"
}
else {
    display as error "[FAIL] Expected `expected_N' observations but found " _N
}

* --- 8b. Check wave range ---
quietly summarize wave
if r(min) == 1 & r(max) == 16 {
    display as text "[PASS] Wave range: " r(min) " to " r(max)
}
else {
    display as error "[FAIL] Expected wave range 1-16 but found " r(min) " to " r(max)
}

* --- 8c. Check number of unique respondents ---
quietly distinct hhidpn
if r(ndistinct) == 45234 {
    display as text "[PASS] Unique respondents: " r(ndistinct)
}
else {
    display as error "[FAIL] Expected 45,234 unique respondents but found " r(ndistinct)
}

* --- 8d. Check each respondent has exactly 16 rows ---
quietly {
    tempvar wave_count
    bysort hhidpn: gen `wave_count' = _N
    summarize `wave_count'
}
if r(min) == 16 & r(max) == 16 {
    display as text "[PASS] All respondents have exactly 16 rows"
}
else {
    display as error "[FAIL] Some respondents have != 16 rows (min=" r(min) ", max=" r(max) ")"
}

* --- 8e. Check year variable was created correctly ---
quietly count if missing(year)
if r(N) == 0 {
    display as text "[PASS] Year variable has no missing values"
}
else {
    display as error "[FAIL] Year variable has " r(N) " missing values"
}

* --- 8f. Check key variables exist ---
local key_vars "hhidpn wave year inw ragender rabyear raeduc rshlt rcesd rbmi hitot hatotb"
local all_exist = 1
local missing_vars ""
foreach v of local key_vars {
    capture confirm variable `v'
    if _rc != 0 {
        local all_exist = 0
        local missing_vars "`missing_vars' `v'"
    }
}
if `all_exist' == 1 {
    display as text "[PASS] All key variables present: `key_vars'"
}
else {
    display as error "[FAIL] Missing key variable(s):`missing_vars'"
}

* --- 8g. Check self-rated health (rshlt) has valid values ---
* rshlt should be 1-5 when non-missing (for interviewed respondents)
quietly count if rshlt < 1 | (rshlt > 5 & rshlt < .)
if r(N) == 0 {
    display as text "[PASS] Self-rated health (rshlt) values in expected range 1-5"
}
else {
    display as error "[FAIL] rshlt has " r(N) " observations outside range 1-5"
}

* --- 8h. Check in-wave indicator (inw) ---
* inw should be 0 or 1 when non-missing
quietly count if inw != 0 & inw != 1 & !missing(inw)
if r(N) == 0 {
    display as text "[PASS] In-wave indicator (inw) is 0/1 as expected"
}
else {
    display as error "[FAIL] inw has " r(N) " observations that are not 0 or 1"
}

* --- 8i. Check response rates are plausible ---
* Total interviewed person-waves should be roughly 250,000-400,000
quietly count if inw == 1
local n_interviewed = r(N)
if `n_interviewed' > 200000 & `n_interviewed' < 500000 {
    display as text "[PASS] Total interviewed person-waves: `n_interviewed' (plausible)"
}
else {
    display as error "[FAIL] Total interviewed person-waves: `n_interviewed' (implausible)"
}

* --- 8j. Spot check: Wave 16 (2022) should have all 8 cohorts ---
quietly {
    tab hacohort if wave == 16 & inw == 1
}
display as text "[INFO] Cohort distribution in Wave 16 shown above"

* --- 8k. Check variable count ---
display as text "[INFO] Total variables in long dataset: " c(k)
if c(k) > 500 {
    display as text "[PASS] Variable count (" c(k) ") indicates all wave-varying variables were reshaped"
}
else {
    display as error "[FAIL] Variable count (" c(k) ") seems too low — some variables may not have been reshaped"
}

* --- 8l. Summary of key health variables for sanity check ---
display as text _newline "--- Quick summary of key variables (interviewed respondents only) ---"
quietly {
    summarize ragey_b rshlt rcesd rbmi if inw == 1
}
summarize ragey_b rshlt rcesd rbmi if inw == 1

display as text _newline "============================================"
display as text "   VALIDATION COMPLETE"
display as text "============================================"

********************************************************************************
* NOTES FOR USERS:
*
* 1. ALL VARIABLES RESHAPED: This script reshapes every wave-varying variable 
*	 in the RAND HRS file.
*
* 3. RENAMED VARIABLES: Some s-prefix word recall variables (s*tr20, s*tr40)
*    were renamed with a trailing underscore in Section 3 to avoid conflicts
*    with the programmatic stub detection. After the reshape, these appear
*    as str20_, str40_ etc. You can rename them back if needed.
*
* 4. MISSING VALUES: The RAND HRS uses Stata extended missing values
*    (.D = don't know, .R = refused, .X = does not apply, etc.).
*    These are preserved in the reshape. See the README for the full list.
*
* 5. WAVE 1 DIFFERENCES: Some variables are defined differently or not
*    available in Wave 1 (1992). For example, CES-D is not derived for
*    Wave 1 because the response options differed. The codebook documents
*    all cross-wave differences.
*
* 6. UPDATING FOR NEW WAVES: When Wave 17 data becomes available:
*    - Update the filename in Section 2
*    - In Section 4, add r17* to the double-digit exclusion list in the
*      single-digit `ds` commands, and add r17* to the double-digit
*      `ds` commands. Same for h17* and s17*.
*    - Add any new problematic variable renames in Section 3 if needed.
*    - Add year = 2024 for wave == 17 in Section 6.
*
* 7. HOW THE STUB DETECTION WORKS:
*    The key challenge is that variable names like r1shlt (wave 1) have a
*    2-character prefix, while r10shlt (wave 10) has a 3-character prefix.
*    We handle this by:
*    (a) Listing single-digit-wave vars (r1*-r9*) by excluding r10*-r16*
*        and all non-r-prefix variables, then stripping 2 chars.
*    (b) Listing double-digit-wave vars (r10*-r16*), then stripping 3 chars.
*    (c) Taking the union of both stub lists.
*    This is the same logic used in Austin Denteh's legacy code. 
*
*    IMPORTANT: The `ds ..., not` command errors if any exclusion pattern
*    matches zero variables. The exclusion lists in Section 4 are tailored
*    to the 2022 file's actual variable prefixes (r, s, h, inw, pn, filever,
*    ra, re, ha, sa, hh). If future releases add new prefixes, you may
*    need to update the exclusion patterns.
********************************************************************************
