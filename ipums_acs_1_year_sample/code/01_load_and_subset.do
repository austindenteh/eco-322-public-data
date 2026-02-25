********************************************************************************
* 01_load_and_subset.do
*
* Purpose: Load an IPUMS ACS extract, restrict to ACS 1-year samples
*          (drop any pre-2006 census samples), create a unique person
*          identifier, validate, and save.
*
* Input:   data/raw/<any IPUMS .dta or .dta.gz file>
*          The script auto-detects whichever file is present.
*          You can also specify a file manually (see Section 2).
*
* Output:  output/acs_working.dta
*
* Data:    American Community Survey (ACS) 1-year samples via IPUMS USA.
*          Annual cross-sectional survey of approx. 3.5 million individuals
*          per year. Covers demographics, education, employment, income,
*          health insurance, immigration, disability, and housing.
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

local out_dta  "output/acs_working.dta"

* ============================================================================
* 2. IDENTIFY DATA FILE
* ============================================================================
* Specify your data file below, OR leave blank to auto-detect.
* The script will look for the first .dta or .dta.gz file in data/raw/.
*
* Examples:
*   local data_file "data/raw/usa_00003_2023_2024.dta"   // smallest (11 GB)
*   local data_file "data/raw/usa_00002_2020_2024.dta"   // medium (17 GB)
*   local data_file "data/raw/usa_00001_2006_2024.dta"   // full (45 GB)
*   local data_file "data/raw/my_custom_extract.dta.gz"   // your own IPUMS extract

local data_file ""

* --- Auto-detect if not specified ---
if "`data_file'" == "" {
    * Look for .dta.gz files first (compressed IPUMS extracts)
    local gz_files : dir "data/raw" files "*.dta.gz"
    if `"`gz_files'"' != "" {
        local first_gz : word 1 of `gz_files'
        local data_file "data/raw/`first_gz'"
    }
    else {
        * Look for .dta files
        local dta_files : dir "data/raw" files "*.dta"
        if `"`dta_files'"' != "" {
            local first_dta : word 1 of `dta_files'
            local data_file "data/raw/`first_dta'"
        }
        else {
            display as error "ERROR: No .dta or .dta.gz file found in data/raw/"
            display as error "Download data from Dropbox or IPUMS and place in data/raw/"
            display as error "See README.md for instructions."
            error 601
        }
    }
    display as text "Auto-detected data file: `data_file'"
}

* ============================================================================
* 3. LOAD THE RAW DATA
* ============================================================================
* The IPUMS extract may be a .dta or .dta.gz file. Stata 16+ can read
* .dta.gz directly. Large files may take several minutes to load.

display as text _newline "============================================"
display as text "   LOADING IPUMS ACS EXTRACT"
display as text "============================================"

display as text _newline "Loading: `data_file'"
display as text "This may take several minutes for a large extract..."
use "`data_file'", clear

display as text _newline "Raw data loaded."
display as text "  Observations: " _N
display as text "  Variables:    " c(k)

* ============================================================================
* 4. LOWERCASE VARIABLE NAMES
* ============================================================================
* IPUMS variables are uppercase. Lowercase for consistency.

rename *, lower
display as text _newline "Variable names lowercased."

* ============================================================================
* 5. RESTRICT TO ACS 1-YEAR SAMPLES (2006+)
* ============================================================================
* Some extracts include decennial census samples (1970, 1980, 1990, 2000).
* Drop these to keep only ACS years. If your extract only contains ACS
* years, this step does nothing.

display as text _newline "--- Year distribution (before restriction) ---"
tab year

count if year < 2006
local n_dropped = r(N)
if `n_dropped' > 0 {
    drop if year < 2006
    display as text _newline "Dropped `n_dropped' observations from pre-ACS samples."
}
else {
    display as text _newline "No pre-ACS samples found — all observations retained."
}
display as text "Remaining observations: " _N

display as text _newline "--- Year distribution (after restriction) ---"
tab year

* ============================================================================
* 6. CREATE UNIQUE PERSON IDENTIFIER
* ============================================================================
* IPUMS identifies individuals by year + serial (household) + pernum (person
* within household). Create a single unique ID.

gen long individ = serial * 100 + pernum
format individ %20.0f

* Verify uniqueness within year
isid year individ
display as text _newline "Unique ID (individ = serial*100 + pernum) verified."

* ============================================================================
* 7. BASIC VALIDATION
* ============================================================================

display as text _newline "============================================"
display as text "   VALIDATION CHECKS"
display as text "============================================"

* --- 7a. Year range ---
summarize year
display as text "Year range: " r(min) " to " r(max)
if r(min) >= 2006 {
    display as text "  [OK] All years are ACS (2006+)."
}
else {
    display as error "  [WARN] Found years before 2006 — check data."
}

* --- 7b. Key variables exist ---
* These are common IPUMS variables. Custom extracts may have fewer.
display as text _newline "Checking key variables:"
local n_found = 0
local n_missing = 0
foreach v in year serial pernum perwt statefip age sex race hispan ///
              educ empstat hcovany poverty citizen bpl incwage {
    capture confirm variable `v'
    if _rc != 0 {
        display as text "  `v': not in extract"
        local n_missing = `n_missing' + 1
    }
    else {
        display as text "  `v': found [OK]"
        local n_found = `n_found' + 1
    }
}
display as text _newline "  Found `n_found' of 16 key variables."
if `n_missing' > 0 {
    display as text "  `n_missing' variable(s) not in this extract."
    display as text "  Sections using missing variables will be skipped in 02_clean_demographics.do."
}

* --- 7c. Sample sizes by year ---
display as text _newline "--- Observations per year ---"
tab year

* --- 7d. Weight summary ---
capture confirm variable perwt
if _rc == 0 {
    display as text _newline "--- Person weight (perwt) summary ---"
    summarize perwt, detail
}
else {
    display as text _newline "[INFO] perwt not found — weight summary skipped."
}

* ============================================================================
* 8. SAVE WORKING COPY
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
* 1. DATA FILE AUTO-DETECTION:
*    The script scans data/raw/ for .dta.gz and .dta files. If multiple
*    files are present, it uses the first one found (alphabetically).
*    You can override this by setting `data_file' in Section 2.
*
* 2. PRE-BUILT EXTRACTS ON DROPBOX:
*    Three extract options are available (see README):
*    - usa_00001_2006_2024.dta  (45 GB, full 19-year range)
*    - usa_00002_2020_2024.dta  (17 GB, 5 recent years)
*    - usa_00003_2023_2024.dta  (11 GB, 2 recent years)
*
* 3. CUSTOM IPUMS EXTRACTS:
*    Go to https://usa.ipums.org/usa/ to create a custom extract.
*    Select samples (ACS 1-year for desired years) and variables.
*    Download as Stata (.dta) format and place in data/raw/.
*    The 02_clean_demographics.do script gracefully skips sections
*    that require variables not in your extract.
*
* 4. SURVEY DESIGN:
*    The ACS is a complex survey with stratification and clustering.
*    - Person weight: perwt (for person-level estimates)
*    - Household weight: hhwt (for household-level estimates)
*    - Replicate weights: repwtp1-repwtp80 (for standard errors)
*    - Strata: strata (for svyset)
*    - Cluster: cluster (for svyset)
*    To set up survey design in Stata:
*      svyset cluster [pw=perwt], strata(strata)
*
* 5. COVID-19 NOTE (2020):
*    The 2020 ACS had disrupted data collection due to COVID-19.
*    The Census Bureau released experimental weights for 2020 data.
*    See docs/ for guidance on using 2020 data.
********************************************************************************
