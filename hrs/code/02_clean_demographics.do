********************************************************************************
* 02_clean_demographics.do
*
* Purpose: Load the reshaped RAND HRS long-format dataset and demonstrate:
*          (1) Cleaning basic demographic variables for analysis
*          (2) Handling HRS extended missing values
*          (3) Producing descriptive statistics / sanity checks
*          (4) Running a simple regression
*
* Input:   output/hrs_long.dta  (from 01_reshape_and_save.do)
* Output:  Descriptive stats and regression output displayed in Stata window
*
* Usage:   Run from the hrs/ directory:
*            cd "/path/to/hrs"
*            do code/02_clean_demographics.do
*
* Notes:   This is a STARTER script. It demonstrates how to clean a subset
*          of variables. Users should extend this for their own analysis.
*
* Author:  Austin Denteh (combination of old do files and Claude Code)
* Date:    February 2026
********************************************************************************

clear all
set more off

* ============================================================================
* 1. LOAD THE RESHAPED DATA
* ============================================================================

use "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/hrs/output/hrs_long.dta", clear
display as text "Loaded " _N " person-wave observations."

* Set up as panel data
xtset hhidpn wave
display as text "Panel variable: hhidpn | Time variable: wave (1-16)"

* ============================================================================
* 2. UNDERSTAND THE PANEL STRUCTURE
* ============================================================================
* The HRS is an UNBALANCED panel: not all respondents are present in all waves.
* The UNBALANCED panel is not problematic for most analyses.
* This can be because:
*   - Their cohort had not yet entered the study
*   - They died or dropped out (attrition)
*   - They skipped a wave but returned later
*
* The variable `inw` indicates whether the respondent was interviewed in
* a given wave (1 = yes, 0 = no).

display as text _newline "--- Response rates by wave ---"
tabulate wave inw, row

* How many waves does each respondent contribute?
bysort hhidpn: egen total_waves = total(inw)
display as text _newline "--- Distribution of waves responded ---"
tabulate total_waves

* For most analyses, you'll want to restrict to waves where the respondent
* was actually interviewed:
* keep if inw == 1

* ============================================================================
* 3. CLEAN DEMOGRAPHIC VARIABLES
* ============================================================================

* --- 3a. Gender --------------------------------------------------------------
* ragender: 1 = Male, 2 = Female (time-invariant)
gen female = (ragender == 2) if !missing(ragender)
label var female "Female (0/1)"
label define female_lbl 0 "Male" 1 "Female"
label values female female_lbl

display as text _newline "--- Gender distribution ---"
tab female if wave == 1 | (wave > 1 & inw == 1), missing

* --- 3b. Age -----------------------------------------------------------------
* ragey_b: age at interview in years (wave-varying)
* This variable has extended missing values for respondents not interviewed.
label var ragey_b "Age at interview"

display as text _newline "--- Age summary (interviewed respondents only) ---"
summarize ragey_b if inw == 1

display as text _newline "--- Age by wave (interviewed respondents only) ---"
tabstat ragey_b if inw == 1, by(wave) statistics(mean sd min max n) format(%9.1f)

* --- 3c. Education -----------------------------------------------------------
* raeduc: 1=Lt HS, 2=GED, 3=HS grad, 4=Some college, 5=College+ (time-invariant)
* We can create a simpler 4-category version.

gen educ_cat = .
replace educ_cat = 1 if raeduc == 1                    // Less than high school
replace educ_cat = 2 if raeduc == 2 | raeduc == 3      // HS graduate or GED
replace educ_cat = 3 if raeduc == 4                    // Some college
replace educ_cat = 4 if raeduc == 5                    // College and above

label var educ_cat "Education (4 categories)"
label define educ_lbl 1 "Less than HS" 2 "HS/GED" 3 "Some college" 4 "College+"
label values educ_cat educ_lbl

display as text _newline "--- Education distribution ---"
tab educ_cat if inw == 1 & wave == 4, missing
* Using wave 4 because all cohorts through WB are present by then.

* --- 3d. Race/ethnicity ------------------------------------------------------
* raracem: 1=White, 2=Black, 3=Other (time-invariant)
* rahispan: 0=Not Hispanic, 1=Hispanic (time-invariant)
* We create a combined race/ethnicity variable.

gen race_eth = .
replace race_eth = 1 if rahispan == 0 & raracem == 1   // White non-Hispanic
replace race_eth = 2 if rahispan == 0 & raracem == 2   // Black non-Hispanic
replace race_eth = 3 if rahispan == 1                   // Hispanic (any race)
replace race_eth = 4 if rahispan == 0 & raracem == 3   // Other non-Hispanic

label var race_eth "Race/ethnicity"
label define race_lbl 1 "White NH" 2 "Black NH" 3 "Hispanic" 4 "Other NH"
label values race_eth race_lbl

display as text _newline "--- Race/ethnicity distribution ---"
tab race_eth if inw == 1 & wave == 4, missing

* --- 3e. Marital status ------------------------------------------------------
* rmstat: wave-varying marital status
*   1=Married, 2=Married (spouse absent), 3=Partnered,
*   4=Separated, 5=Divorced, 6=Separated/Divorced,
*   7=Widowed, 8=Never married
* We can create a simpler 4-category version.

gen marital = .
replace marital = 1 if inrange(rmstat, 1, 3)            // Married/Partnered
replace marital = 2 if inrange(rmstat, 4, 6)            // Separated/Divorced
replace marital = 3 if rmstat == 7                       // Widowed
replace marital = 4 if rmstat == 8                       // Never married

label var marital "Marital status (4 categories)"
label define mar_lbl 1 "Married/Partnered" 2 "Sep/Divorced" 3 "Widowed" 4 "Never married"
label values marital mar_lbl

display as text _newline "--- Marital status by wave (interviewed respondents) ---"
tab wave marital if inw == 1, row

* --- 3f. Entry cohort --------------------------------------------------------
* hacohort: 0=AHEAD spouse, 1=AHEAD, 2=CODA, 3=HRS, 4=WB, 5=EBB,
*           6=MBB, 7=LBB, 8=EGENX

label define cohort_lbl 0 "AHEAD (spouse)" 1 "AHEAD" 2 "CODA" 3 "HRS" ///
    4 "War Baby" 5 "Early Boomer" 6 "Mid Boomer" 7 "Late Boomer" 8 "Early Gen X"
label values hacohort cohort_lbl

display as text _newline "--- Entry cohort distribution ---"
tab hacohort if inw == 1 & wave == 16

* ============================================================================
* 4. HANDLE MISSING VALUES
* ============================================================================
* The RAND HRS uses Stata extended missing values to record WHY data is missing:
*   .  = did not respond this wave
*   .D = don't know
*   .R = refused
*   .X = does not apply
*   .Q = question not asked
*   .M = other missing
*
* IMPORTANT: In Stata, ALL extended missing values are > any non-missing number.
*   - `if x < 5` correctly excludes all missing values
*   - `if x != 5` INCLUDES missing values (be careful!)
*   - Use `if !missing(x)` or `if x < .` to exclude all missing

* Example: Check the distribution of missing codes for self-rated health
display as text _newline "--- Self-rated health: missing value patterns ---"
* Count each type of missing
gen shlt_status = "Valid" if rshlt >= 1 & rshlt <= 5
replace shlt_status = "Not interviewed (.)" if rshlt == .
replace shlt_status = "Don't know (.D)" if rshlt == .d
replace shlt_status = "Refused (.R)" if rshlt == .r
replace shlt_status = "Other missing" if rshlt > 5 & rshlt < . & shlt_status == ""
replace shlt_status = "Other ext. missing" if rshlt > . & shlt_status == ""
tab shlt_status wave if wave >= 4, missing
drop shlt_status

* ============================================================================
* 5. DESCRIPTIVE STATISTICS
* ============================================================================
* Restrict to interviewed respondents for meaningful statistics.

display as text _newline "=========================================="
display as text "   DESCRIPTIVE STATISTICS (interviewed only)"
display as text "=========================================="

* --- 5a. Summary statistics for key variables --------------------------------
display as text _newline "--- Summary statistics (all waves pooled) ---"
summarize ragey_b female rshlt rcesd rbmi rconde ///
    rhosp radl5a riadl5a rmobila hitot hatotb ///
    if inw == 1, detail

* --- 5b. Summary by wave ----------------------------------------------------
display as text _newline "--- Self-rated health by wave ---"
tabstat rshlt if inw == 1, by(wave) statistics(mean sd n) format(%9.2f)

display as text _newline "--- CES-D depression score by wave ---"
tabstat rcesd if inw == 1, by(wave) statistics(mean sd n) format(%9.2f)

display as text _newline "--- BMI by wave ---"
tabstat rbmi if inw == 1, by(wave) statistics(mean sd n) format(%9.1f)

* --- 5c. Summary by cohort ---------------------------------------------------
display as text _newline "--- Self-rated health by cohort (wave 10, 2010) ---"
tabstat rshlt if inw == 1 & wave == 10, by(hacohort) statistics(mean sd n) format(%9.2f)

* --- 5d. Crosstabs -----------------------------------------------------------
display as text _newline "--- Self-rated health by gender ---"
tab rshlt female if inw == 1, col

display as text _newline "--- Self-rated health by race/ethnicity ---"
tab rshlt race_eth if inw == 1, col

* ============================================================================
* 6. SIMPLE REGRESSION EXAMPLE
* ============================================================================
* OLS regression of self-rated health on demographics.
* This is purely illustrative. For a real analysis you would:
*   - Consider the panel structure (fixed effects, random effects)
*   - Use survey weights
*   - Think carefully about functional form and controls
*
* Self-rated health: 1=excellent, 2=very good, 3=good, 4=fair, 5=poor
* Higher values = worse health

display as text _newline "=========================================="
display as text "   SIMPLE REGRESSION EXAMPLE"
display as text "=========================================="

* --- 6a. OLS (pooled, no panel structure) ------------------------------------
display as text _newline "--- OLS: Self-rated health on demographics ---"
reg rshlt ragey_b female i.educ_cat i.race_eth if inw == 1

* --- 6b. OLS with survey weights ---------------------------------------------
display as text _newline "--- Weighted OLS: Self-rated health on demographics ---"
reg rshlt ragey_b female i.educ_cat i.race_eth if inw == 1 [pw=rwtresp]

* --- 6c. Panel fixed effects (individual FE) ---------------------------------
* This controls for all time-invariant individual characteristics
* (so gender, education, and race drop out).
display as text _newline "--- Fixed effects: Self-rated health on age ---"
xtreg rshlt ragey_b i.marital if inw == 1, fe

display as text _newline(2) "=========================================="
display as text "   STARTER SCRIPT COMPLETE"
display as text "=========================================="
display as text "You now have:"
display as text "  - Cleaned demographic variables: female, educ_cat, race_eth, marital"
display as text "  - Descriptive statistics by wave, cohort, and demographics"
display as text "  - Regression examples (OLS, weighted OLS, panel FE)"
display as text ""
display as text "Next steps for your own analysis:"
display as text "  - Choose your outcome variable(s) and clean them"
display as text "  - Decide on your identification strategy"
display as text "  - Consider panel methods (FE, RE, dynamic models)"
display as text "  - Use appropriate survey weights"
display as text "  - Consult the codebook for variable details"

********************************************************************************
* NOTES FOR USERS:
*
* 1. SURVEY WEIGHTS: The rwtresp weights make estimates representative of the
*    U.S. population aged 50+. For cross-sectional analyses within a single
*    wave, use the wave-specific weight. For longitudinal analyses, weight
*    selection is more complex -- consult the HRS documentation.
*
*
* 2. CLUSTERING: Standard errors should be clustered at the individual level
*    for panel analyses (vce(cluster hhidpn)) or at the household level
*    (create a household ID and cluster on that).
*
* 3. COGNITION: Cognition variables changed in Wave 14 (2018) when some
*    interviews moved to web-based format. Be cautious about trends
*    spanning this change.
********************************************************************************
