********************************************************************************
* 01_load_and_subset.do
*
* Purpose: Load the IPUMS ACS extract, restrict to ACS 1-year samples
*          (2006-2024), create a unique person identifier, validate, and save.
*
* Input:   data/raw/usa_00001.dta.gz   (IPUMS ACS extract, compressed)
* Output:  output/acs_working.dta
*
* Data:    American Community Survey (ACS) 1-year samples via IPUMS USA.
*          Annual cross-sectional survey of approx. 3.5 million individuals
*          per year. Covers demographics, education, employment, income,
*          health insurance, immigration, disability, and housing.
*          The extract also contains decennial census samples (1970-2000)
*          which are dropped here to focus on the ACS period.
*
*          Source: IPUMS USA, University of Minnesota.
*          https://usa.ipums.org
*
* Usage:   Update the global acs_root path below, then:
*            cd "/path/to/ipums_acs_1_year_sample"
*            do code/01_load_and_subset.do
*
* Author:  Austin Denteh (adapted from Kuka et al. 2020 replication code)
* Date:    February 2026
********************************************************************************

clear all
set more off
set maxvar 10000

* ============================================================================
* 1. DEFINE PATHS
* ============================================================================
* Set the working directory to the ipums_acs_1_year_sample/ folder.
* Users should update this path to match their system.

global acs_root "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/ipums_acs_1_year_sample"
cd "$acs_root"

local raw_dta  "data/raw/usa_00001.dta.gz"
local out_dta  "output/acs_working.dta"

* ============================================================================
* 2. LOAD THE RAW DATA
* ============================================================================
* The IPUMS extract is a gzipped .dta file. Stata 16+ can read .dta.gz
* directly. This file is very large (~12 GB compressed) and may take
* several minutes to load.

display as text _newline "============================================"
display as text "   LOADING IPUMS ACS EXTRACT"
display as text "============================================"

display as text _newline "Loading: `raw_dta'"
display as text "This may take several minutes for a large extract..."
use "`raw_dta'", clear

display as text _newline "Raw data loaded."
display as text "  Observations: " _N
display as text "  Variables:    " c(k)

* ============================================================================
* 3. LOWERCASE VARIABLE NAMES
* ============================================================================
* IPUMS variables are uppercase. Lowercase for consistency.

rename *, lower
display as text _newline "Variable names lowercased."

* ============================================================================
* 4. RESTRICT TO ACS 1-YEAR SAMPLES (2006-2024)
* ============================================================================
* The extract may include decennial census samples (1970, 1980, 1990, 2000).
* Drop these to keep only ACS years.

display as text _newline "--- Year distribution (before restriction) ---"
tab year

count if year < 2006
local n_dropped = r(N)
drop if year < 2006

display as text _newline "Dropped `n_dropped' observations from pre-ACS samples."
display as text "Remaining observations: " _N

display as text _newline "--- Year distribution (after restriction) ---"
tab year

* ============================================================================
* 5. CREATE UNIQUE PERSON IDENTIFIER
* ============================================================================
* IPUMS identifies individuals by year + serial (household) + pernum (person
* within household). Create a single unique ID.

gen long individ = serial * 100 + pernum
format individ %20.0f

* Verify uniqueness within year
isid year individ
display as text _newline "Unique ID (individ = serial*100 + pernum) verified."

* ============================================================================
* 6. BASIC VALIDATION
* ============================================================================

display as text _newline "============================================"
display as text "   VALIDATION CHECKS"
display as text "============================================"

* --- 6a. Year range ---
summarize year
assert r(min) >= 2006
assert r(max) <= 2024
display as text "Year range: " r(min) " to " r(max) " [OK]"

* --- 6b. Key variables exist ---
foreach v in year serial pernum perwt statefip age sex race hispan ///
              educ empstat hcovany poverty citizen bpl incwage {
    capture confirm variable `v'
    if _rc != 0 {
        display as error "WARNING: Variable `v' not found in data."
    }
    else {
        display as text "  `v': found [OK]"
    }
}

* --- 6c. Sample sizes by year ---
display as text _newline "--- Observations per year ---"
tab year

* --- 6d. Weight summary ---
display as text _newline "--- Person weight (perwt) summary ---"
summarize perwt, detail

* ============================================================================
* 7. SAVE WORKING COPY
* ============================================================================

compress
save "`out_dta'", replace

display as text _newline "============================================"
display as text "   LOAD AND SUBSET COMPLETE"
display as text "============================================"
display as text "Saved: `out_dta'"
display as text "  Observations: " _N
display as text "  Variables:    " c(k)
display as text _newline "Next step: run 02_clean_demographics.do"

********************************************************************************
* NOTES:
*
* 1. IPUMS EXTRACT CONTENTS:
*    The extract (usa_00001) contains ACS 1-year samples for 2006-2024,
*    plus optional decennial census samples. This script drops the census
*    samples to focus on the ACS period.
*
* 2. SURVEY DESIGN:
*    The ACS is a complex survey with stratification and clustering.
*    - Person weight: perwt (for person-level estimates)
*    - Household weight: hhwt (for household-level estimates)
*    - Replicate weights: repwtp1-repwtp80 (for standard errors)
*    - Strata: strata (for svyset)
*    - Cluster: cluster (for svyset)
*    To set up survey design in Stata:
*      svyset cluster [pw=perwt], strata(strata)
*
* 3. FILE SIZE:
*    The raw extract is very large. If memory is an issue, consider
*    downloading a smaller extract from IPUMS with fewer variables or
*    fewer years.
*
* 4. COVID-19 NOTE (2020):
*    The 2020 ACS had disrupted data collection due to COVID-19.
*    The Census Bureau released experimental weights for 2020 data.
*    See docs/ for guidance on using 2020 data.
*
* 5. CREATING YOUR OWN EXTRACT:
*    Go to https://usa.ipums.org/usa/ to create a custom extract.
*    Select samples (ACS 1-year for desired years) and variables.
*    Download as Stata (.dta) format.
********************************************************************************
