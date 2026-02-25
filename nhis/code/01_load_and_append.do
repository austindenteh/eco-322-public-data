********************************************************************************
* 01_load_and_append.do
*
* Purpose: Load NHIS data files, harmonize variable names across the 2019
*          redesign break, and save combined working datasets.
*
*          This script performs the FULL data build pipeline:
*
*          POST-2019 (2019-2024): Flat 2-file design
*            Unzip and import CSV files — simple and fast
*
*          PRE-2019 (2004-2018, optional): 5-file hierarchical design
*            Step 1: Run CDC do-files to create .dta from raw ASCII (.DAT)
*            Step 2: Merge personsx + familyxx + househld + samadult
*            Step 3: Keep sample adults, harmonize variable names
*
*          After loading, variable names are harmonized to a common
*          convention and all years are appended into a single dataset.
*
*          DEFAULT: Loads 2019-2024 only (post-redesign, CSV files).
*          To include pre-2019 years, uncomment the pre2019_years line
*          below. The script auto-detects which year folders are present
*          and skips any missing years.
*
* Input:   data/NHIS 2019/ ... data/NHIS 2024/  (CSV in .zip)
*          data/NHIS 2004/ ... data/NHIS 2014/  (optional: .DAT + CDC do-files)
* Output:  output/nhis_adult.dta  (sample adults, all loaded years)
*          output/nhis_child.dta  (sample children, all loaded years)
*
* Data:    National Health Interview Survey (NHIS).
*          Annual household survey conducted by NCHS/CDC since 1957.
*          Source: https://www.cdc.gov/nchs/nhis/data-questionnaires-documentation.htm
*
* Author:  Austin Denteh (legacy code and Claude Code)
* Date:    February 2026
********************************************************************************

clear all
set more off
set maxvar 32767

* ============================================================================
* 1. DEFINE PATHS AND YEAR RANGE
* ============================================================================

global nhis_root "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/nhis"
cd "$nhis_root"

* --- Post-2019 years (redesigned, CSV format — DEFAULT) ---
* These years use simple CSV files. No special setup needed.
* The script auto-detects which year folders exist and skips missing ones.
local post2019_years "2019 2020 2021 2022 2023 2024"

* --- Pre-2019 years (OPTIONAL — uncomment to include) ---
* Pre-2019 years require .DAT files + CDC do-files in each year folder.
* The script will run the do-files to create .dta files if they don't exist,
* then merge the 5-file hierarchical structure. This is more complex and
* memory-intensive. Leave blank "" to skip pre-2019 entirely (the default).
*
* To include pre-2019 years, uncomment ONE of the lines below:
* local pre2019_years "2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014"
* local pre2019_years "2010 2011 2012 2013 2014"
local pre2019_years ""

* NOTE: Years 2015-2018 follow the pre-2019 design but their data files
*       are in .zip archives that must be extracted first.
*       See the EXTENDING section at the end of this script.

* ============================================================================
* 2. CREATE .DTA FILES FROM RAW ASCII (CDC DO-FILES) — PRE-2019 ONLY
* ============================================================================
* The CDC provides do-files that read the fixed-width ASCII (.DAT) data
* and create .dta files. We need 5 components per year:
*   - personsx  (person-level demographics, ALL household members)
*   - familyxx  (family-level info)
*   - househld  (household-level info)
*   - samadult  (sample adult health module)
*   - samchild  (sample child health module)
*
* The CDC do-files assume the data file is in the working directory.
* They use infix to read the .DAT file and save a .dta file.
*
* We skip this step for components where the .dta file already exists.
* This entire section is skipped if pre2019_years is empty.

if "`pre2019_years'" != "" {

display as text _newline "============================================"
display as text "   STEP 1: CREATING .DTA FILES FROM RAW DATA"
display as text "============================================"

foreach y of local pre2019_years {

    display as text _newline "--- Year `y' ---"

    local ydir "$nhis_root/data/NHIS `y'"

    * Check each component
    foreach comp in personsx familyxx househld samadult samchild {

        * Check if .dta already exists
        capture confirm file "`ydir'/`comp'.dta"
        if _rc == 0 {
            display as text "  `comp'.dta exists — skipping"
            continue
        }

        * .dta does not exist — try to create it from the CDC do-file
        * First check for the do-file (naming convention: YYYYcomp.do)
        local dofile "`ydir'/`y'`comp'.do"
        capture confirm file "`dofile'"
        if _rc != 0 {
            * Try alternate naming (just comp.do)
            local dofile "`ydir'/`comp'.do"
            capture confirm file "`dofile'"
        }

        if _rc != 0 {
            display as error "  No do-file found for `comp' in `y'. Skipping."
            continue
        }

        * Check for the .DAT file (case-insensitive search)
        local dat_found = 0
        foreach ext in ".DAT" ".dat" {
            capture confirm file "`ydir'/`comp'`ext'"
            if _rc == 0 {
                local dat_found = 1
            }
            * Also try uppercase component name
            local COMP = upper("`comp'")
            capture confirm file "`ydir'/`COMP'`ext'"
            if _rc == 0 {
                local dat_found = 1
            }
        }

        if `dat_found' == 0 {
            display as error "  No .DAT file found for `comp' in `y'. Skipping."
            continue
        }

        * Run the CDC do-file to create the .dta
        * Must cd into the year directory because do-files assume local paths
        display as text "  Running `y'`comp'.do to create `comp'.dta..."
        cd "`ydir'"
        capture noisily do "`dofile'"
        cd "$nhis_root"

        * Verify it was created
        capture confirm file "`ydir'/`comp'.dta"
        if _rc == 0 {
            display as text "  Created `comp'.dta successfully"
        }
        else {
            display as error "  FAILED to create `comp'.dta"
        }
    }
}

cd "$nhis_root"

} // end if pre2019_years != ""

* ============================================================================
* 3. MERGE AND LOAD PRE-2019 ADULT FILES (2004-2014)
* ============================================================================
* For each year:
*   1. Load personsx.dta (all household members)
*   2. Merge familyxx.dta (family-level, m:1 on hhx fmx srvy_yr)
*   3. Merge househld.dta (household-level, m:1 on hhx srvy_yr)
*   4. Merge samadult.dta (sample adult, 1:1 on hhx fmx fpx srvy_yr)
*   5. Keep only sample adults (those who matched with samadult)
*
* This mirrors the structure of the legacy "Step 1 Data build.do" from
* the RDC project, adapted for the starter code context.
* Skipped entirely if pre2019_years is empty.

if "`pre2019_years'" != "" {

display as text _newline "============================================"
display as text "   STEP 2: MERGING PRE-2019 FILES"
display as text "============================================"

foreach y of local pre2019_years {

    display as text _newline "--- Year `y' ---"

    local ydir "data/NHIS `y'"

    * Check that required files exist
    capture confirm file "`ydir'/personsx.dta"
    if _rc != 0 {
        display as error "  personsx.dta not found for `y'. Skipping."
        continue
    }
    capture confirm file "`ydir'/samadult.dta"
    if _rc != 0 {
        display as error "  samadult.dta not found for `y'. Skipping."
        continue
    }

    * --- Load person-level file ---
    use "`ydir'/personsx.dta", clear
    quietly describe, short
    display as text "  personsx: " _N " persons"

    * Lowercase all variable names for consistency
    foreach v of varlist _all {
        local lc = lower("`v'")
        if "`lc'" != "`v'" {
            capture rename `v' `lc'
        }
    }

    * Ensure srvy_yr exists
    capture confirm variable srvy_yr
    if _rc != 0 {
        gen srvy_yr = `y'
    }

    * --- Merge familyxx (family-level) ---
    capture confirm file "`ydir'/familyxx.dta"
    if _rc == 0 {
        merge m:1 hhx fmx srvy_yr using "`ydir'/familyxx.dta", ///
            gen(_fammerge) keep(master match)
        display as text "  familyxx merge: " _N " obs"
    }

    * --- Merge househld (household-level) ---
    capture confirm file "`ydir'/househld.dta"
    if _rc == 0 {
        merge m:1 hhx srvy_yr using "`ydir'/househld.dta", ///
            gen(_hhmerge) keep(master match)
        display as text "  househld merge: " _N " obs"
    }

    * --- Merge samadult (sample adult) ---
    merge 1:1 hhx fmx fpx srvy_yr using "`ydir'/samadult.dta", ///
        gen(_samerge)

    * Keep only sample adults (those who matched with samadult)
    quietly count if _samerge == 3
    display as text "  samadult merge: " r(N) " sample adults matched"
    keep if _samerge == 3
    drop _samerge
    capture drop _fammerge _hhmerge

    display as text "  Sample adults: " _N

    * ---------------------------------------------------------------
    * HARMONIZE VARIABLE NAMES TO POST-2019 CONVENTION
    * ---------------------------------------------------------------
    * Rename pre-2019 variables to match 2019+ naming.
    * This allows a clean append across all years.

    * Demographics
    capture rename age_p    agep_a
    capture rename sex      sex_a
    capture rename origin_i hisp_a         // Hispanic origin
    capture rename racerpi2 raceallp_a     // Race
    capture rename educ1    educ_a         // Education
    capture rename citizenp citizenp_a     // Citizenship
    capture rename plborn   plborn_a       // Place of birth

    * Health insurance
    capture rename notcov   notcov_a
    capture rename medicare medicare_a
    capture rename medicaid medicaid_a
    capture rename private  private_a
    capture rename schip    schip_a
    capture rename single   single_a
    capture rename ihs      ihs_a
    capture rename hinotyr  hinotyr_a

    * Harmonize insurance variables that changed names within pre-2019
    * Other gov: othergov (2004-07) -> othgov (2008+) -> othgov_a
    capture confirm variable othergov
    if _rc == 0 {
        capture confirm variable othgov
        if _rc != 0 {
            rename othergov othgov
        }
    }
    capture rename othgov othgov_a

    * Other public: otherpub (2004-07) -> othpub (2008+) -> othpub_a
    capture confirm variable otherpub
    if _rc == 0 {
        capture confirm variable othpub
        if _rc != 0 {
            rename otherpub othpub
        }
    }
    capture rename othpub othpub_a

    * Military: military (2004-07) -> milcare (2008+) -> milcare_a
    capture confirm variable military
    if _rc == 0 {
        capture confirm variable milcare
        if _rc != 0 {
            rename military milcare
        }
    }
    capture rename milcare milcare_a

    * Hospitalization: phospyr (2004-05) -> phospyr2 (2006+) -> phospyr_a
    capture confirm variable phospyr
    if _rc == 0 {
        capture confirm variable phospyr2
        if _rc != 0 {
            rename phospyr phospyr2
        }
    }
    capture rename phospyr2 phospyr_a

    * Food assistance: ffdstyn (2004-10) -> fsnap (2011+) -> fsnap_a
    capture confirm variable ffdstyn
    if _rc == 0 {
        capture confirm variable fsnap
        if _rc != 0 {
            rename ffdstyn fsnap
        }
    }
    capture rename fsnap fsnap_a

    * Income / poverty ratio
    * The poverty ratio category variable changes name across years:
    *   2004-2006: rat_cat  (no suffix)
    *   2007-2013: rat_cat2, rat_cat3  (two imputations)
    *   2014:      rat_cat4, rat_cat5  (two imputations)
    * We pick the first available variant and rename to ratcat_a.
    * Similarly for income group: incgrp -> incgrp2 -> incgrp4
    local ratcat_renamed = 0
    foreach rc in rat_cat rat_cat2 rat_cat4 {
        if `ratcat_renamed' == 0 {
            capture confirm variable `rc'
            if _rc == 0 {
                rename `rc' ratcat_a
                local ratcat_renamed = 1
            }
        }
    }

    local incgrp_renamed = 0
    foreach ig in incgrp incgrp2 incgrp4 {
        if `incgrp_renamed' == 0 {
            capture confirm variable `ig'
            if _rc == 0 {
                rename `ig' incgrp_a
                local incgrp_renamed = 1
            }
        }
    }

    * Drop the alternate imputation versions (keep only the one we renamed)
    capture drop rat_cat3 rat_cat5 incgrp3 incgrp5

    * Personal earnings (from personsx): ernyr_p -> ernyr_a
    capture rename ernyr_p ernyr_a

    * Health status and utilization
    capture rename phstat   phstat_a
    capture rename pdmed12m pdmed12m_a
    capture rename pnmed12m pnmed12m_a

    * Chronic conditions (add _a suffix)
    foreach cv in hypev chlev chdev angev miev strev asev canev dibev copdev arthev depev anxev {
        capture rename `cv' `cv'_a
    }

    * Survey design — harmonize stratum/PSU names
    * 2004-05: stratum/psu  (add 1000 offset to stratum)
    * 2006+:   strat_p/psu_p (add 2000 offset to strat_p)
    * The offsets ensure strata are distinct across design periods
    * (following CDC guidance in NHIS documentation)
    if `y' <= 2005 {
        capture confirm variable stratum
        if _rc == 0 {
            gen pstrat = 1000 + stratum
            drop stratum
        }
        capture confirm variable psu
        if _rc == 0 {
            rename psu ppsu
        }
    }
    else {
        capture confirm variable strat_p
        if _rc == 0 {
            gen pstrat = 2000 + strat_p
            drop strat_p
        }
        capture confirm variable psu_p
        if _rc == 0 {
            rename psu_p ppsu
        }
    }

    * Weight: rename wtfa_sa -> wtfa_a (sample adult weight)
    capture rename wtfa_sa wtfa_a

    * Keep wtfa as person-level weight (different from sample adult weight)
    capture rename wtfa wtfa_person

    * Family weight
    capture rename wtfa_fam wtfa_fam_pre

    * Interview timing
    capture rename intv_mon intv_mon_pre
    capture rename intv_qrt intv_qrt_pre

    * Other
    capture rename regionbr regionbr_a
    capture rename geobrth  geobrth_a
    capture rename frrp     frrp_a

    * Mark era
    gen byte era_post2019 = 0
    label var era_post2019 "Post-2019 redesign era (0=pre, 1=post)"

    * Save temporary year file
    tempfile pre_`y'
    compress
    save `pre_`y'', replace
    display as text "  Saved temp file for `y': " _N " sample adults"
}

} // end if pre2019_years != ""

* ============================================================================
* 4. LOAD POST-2019 ADULT FILES (2019-2024)
* ============================================================================

display as text _newline "============================================"
display as text "   STEP 3: LOADING POST-2019 FILES"
display as text "============================================"

foreach y of local post2019_years {

    display as text _newline "--- Year `y' ---"

    local ydir "data/NHIS `y'"

    * Two-digit year suffix
    local yy = substr("`y'", 3, 2)

    * Check for CSV file first (already extracted)
    local csv_file "`ydir'/adult`yy'.csv"
    local zip_file "`ydir'/adult`yy'csv.zip"

    capture confirm file "`csv_file'"
    if _rc != 0 {
        * CSV not found — try to unzip
        capture confirm file "`zip_file'"
        if _rc != 0 {
            display as error "  Neither CSV nor ZIP found for `y'. Skipping."
            continue
        }
        display as text "  Unzipping `zip_file'..."
        !unzip -o -q "`zip_file'" -d "`ydir'/"
    }

    * Re-check for CSV
    capture confirm file "`csv_file'"
    if _rc != 0 {
        display as error "  CSV file not found after unzip for `y'. Skipping."
        continue
    }

    display as text "  Importing `csv_file'..."
    import delimited using "`csv_file'", clear varnames(1) case(lower)

    * Add survey year if not already present
    capture confirm variable srvy_yr
    if _rc != 0 {
        gen srvy_yr = `y'
    }

    * Mark era
    gen byte era_post2019 = 1

    display as text "  Observations: " _N

    * Save temporary file
    tempfile post_`y'
    compress
    save `post_`y'', replace
}

* ============================================================================
* 5. APPEND ALL YEARS
* ============================================================================

display as text _newline "============================================"
display as text "   STEP 4: APPENDING ALL YEARS"
display as text "============================================"

* Start with the first available pre-2019 year (if any)
local first_done = 0
foreach y of local pre2019_years {
    capture confirm file `pre_`y''
    if _rc == 0 & `first_done' == 0 {
        use `pre_`y'', clear
        local first_done = 1
        display as text "Starting with `y': " _N " obs"
    }
    else if _rc == 0 {
        append using `pre_`y'', force
        display as text "Appended `y': " _N " cumulative obs"
    }
}

* Append post-2019 years
foreach y of local post2019_years {
    capture confirm file `post_`y''
    if _rc == 0 {
        if `first_done' == 0 {
            use `post_`y'', clear
            local first_done = 1
            display as text "Starting with `y': " _N " obs"
        }
        else {
            append using `post_`y'', force
            display as text "Appended `y': " _N " cumulative obs"
        }
    }
}

display as text _newline "Combined adult dataset: " _N " observations"

* ============================================================================
* 6. FINAL HARMONIZATION NOTES
* ============================================================================

* Hispanic origin: Pre-2019 origin_i coded 1=Hispanic, 2=Not Hispanic
* Post-2019 hisp_a coded 1=Hispanic, 2=Not Hispanic. SAME — OK.

* Sex: Both eras code 1=Male, 2=Female. SAME — OK.

* Race: Pre-2019 racerpi2: 1=White, 2=Black, 3=AIAN, 4-15=various.
* Post-2019 raceallp_a: 01=White, 02=Black, 03=AIAN, 04=Asian,
* 05=Not releasable, 06=Multiple. Broad categories (1,2,3) match.
* Asian coding differs. → Handled in cleaning script.

* Education: Pre-2019 educ1 and post-2019 educ_a use different coding
* schemes. → Handled in cleaning script with era-specific logic.

* Insurance: Pre-2019 coding (1=mentioned, 2=probed yes, 3=no) differs
* from post-2019 (1=yes, 2=no). → Handled in cleaning script.

* Income/poverty: Pre-2019 rat_cat/rat_cat2/rat_cat4 renamed to ratcat_a.
* Same 14-category coding in both eras. Pre-2019 incgrp/incgrp2/incgrp4
* renamed to incgrp_a (5 income groups). Personal earnings (ernyr_p ->
* ernyr_a) available pre-2019 only. → Handled in cleaning script.

label var era_post2019 "Post-2019 redesign era (0=pre-2019, 1=2019+)"

* ============================================================================
* 7. SAVE COMBINED DATASET
* ============================================================================

sort srvy_yr hhx
compress

save "output/nhis_adult.dta", replace
display as text "Saved: output/nhis_adult.dta"
display as text "Total observations: " _N

* ============================================================================
* 8. BUILD CHILD FILE (PRE-2019: samchild; POST-2019: child CSV)
* ============================================================================
* Same approach as adults: merge person+family+household+samchild for pre-2019,
* import child CSV for post-2019, harmonize variable names, and append.

display as text _newline "============================================"
display as text "   BUILDING CHILD FILE"
display as text "============================================"

* --- Pre-2019 children (if pre2019_years is not empty) ---
if "`pre2019_years'" != "" {
foreach y of local pre2019_years {

    display as text _newline "--- Year `y' (child) ---"

    local ydir "data/NHIS `y'"

    capture confirm file "`ydir'/personsx.dta"
    if _rc != 0 {
        continue
    }
    capture confirm file "`ydir'/samchild.dta"
    if _rc != 0 {
        display as error "  samchild.dta not found for `y'. Skipping."
        continue
    }

    use "`ydir'/personsx.dta", clear
    foreach v of varlist _all {
        local lc = lower("`v'")
        if "`lc'" != "`v'" {
            capture rename `v' `lc'
        }
    }
    capture confirm variable srvy_yr
    if _rc != 0 gen srvy_yr = `y'

    * Merge familyxx
    capture confirm file "`ydir'/familyxx.dta"
    if _rc == 0 {
        merge m:1 hhx fmx srvy_yr using "`ydir'/familyxx.dta", ///
            gen(_fammerge) keep(master match)
    }

    * Merge househld
    capture confirm file "`ydir'/househld.dta"
    if _rc == 0 {
        merge m:1 hhx srvy_yr using "`ydir'/househld.dta", ///
            gen(_hhmerge) keep(master match)
    }

    * Merge samchild
    merge 1:1 hhx fmx fpx srvy_yr using "`ydir'/samchild.dta", ///
        gen(_scmerge)
    keep if _scmerge == 3
    drop _scmerge
    capture drop _fammerge _hhmerge

    display as text "  Sample children: " _N

    * Harmonize variable names (same as adults where applicable)
    capture rename age_p    agep_c
    capture rename sex      sex_c
    capture rename origin_i hisp_c
    capture rename racerpi2 raceallp_c
    capture rename citizenp citizenp_c
    capture rename plborn   plborn_c

    * Insurance
    capture rename notcov   notcov_c
    capture rename medicare medicare_c
    capture rename medicaid medicaid_c
    capture rename private  private_c
    capture rename schip    schip_c

    * Health status
    capture rename phstat   phstat_c

    * Within pre-2019 harmonization
    capture confirm variable othergov
    if _rc == 0 {
        capture confirm variable othgov
        if _rc != 0 rename othergov othgov
    }
    capture confirm variable otherpub
    if _rc == 0 {
        capture confirm variable othpub
        if _rc != 0 rename otherpub othpub
    }
    capture confirm variable military
    if _rc == 0 {
        capture confirm variable milcare
        if _rc != 0 rename military milcare
    }
    capture confirm variable ffdstyn
    if _rc == 0 {
        capture confirm variable fsnap
        if _rc != 0 rename ffdstyn fsnap
    }

    * Survey design
    if `y' <= 2005 {
        capture confirm variable stratum
        if _rc == 0 {
            gen pstrat = 1000 + stratum
            drop stratum
        }
        capture confirm variable psu
        if _rc == 0 rename psu ppsu
    }
    else {
        capture confirm variable strat_p
        if _rc == 0 {
            gen pstrat = 2000 + strat_p
            drop strat_p
        }
        capture confirm variable psu_p
        if _rc == 0 rename psu_p ppsu
    }

    capture rename wtfa_sc wtfa_c
    capture rename wtfa wtfa_person

    gen byte era_post2019 = 0

    tempfile cpre_`y'
    compress
    save `cpre_`y'', replace
}
} // end if pre2019_years != "" (children)

* --- Post-2019 children ---
foreach y of local post2019_years {

    display as text _newline "--- Year `y' (child) ---"

    local ydir "data/NHIS `y'"
    local yy = substr("`y'", 3, 2)
    local csv_file "`ydir'/child`yy'.csv"
    local zip_file "`ydir'/child`yy'csv.zip"

    capture confirm file "`csv_file'"
    if _rc != 0 {
        capture confirm file "`zip_file'"
        if _rc != 0 {
            display as error "  Neither CSV nor ZIP found for child `y'. Skipping."
            continue
        }
        !unzip -o -q "`zip_file'" -d "`ydir'/"
    }

    capture confirm file "`csv_file'"
    if _rc != 0 {
        continue
    }

    import delimited using "`csv_file'", clear varnames(1) case(lower)
    capture confirm variable srvy_yr
    if _rc != 0 gen srvy_yr = `y'

    gen byte era_post2019 = 1
    display as text "  Child observations: " _N

    tempfile cpost_`y'
    compress
    save `cpost_`y'', replace
}

* --- Append all child years ---
local first_done = 0
foreach y of local pre2019_years {
    capture confirm file `cpre_`y''
    if _rc == 0 & `first_done' == 0 {
        use `cpre_`y'', clear
        local first_done = 1
    }
    else if _rc == 0 {
        append using `cpre_`y'', force
    }
}
foreach y of local post2019_years {
    capture confirm file `cpost_`y''
    if _rc == 0 {
        if `first_done' == 0 {
            use `cpost_`y'', clear
            local first_done = 1
        }
        else {
            append using `cpost_`y'', force
        }
    }
}

display as text "Combined child dataset: " _N " observations"
sort srvy_yr hhx
compress
save "output/nhis_child.dta", replace
display as text "Saved: output/nhis_child.dta"

* ============================================================================
* 9. VALIDATION CHECKS
* ============================================================================

display as text _newline "============================================"
display as text "   VALIDATION CHECKS"
display as text "============================================"

* --- ADULT FILE ---
use "output/nhis_adult.dta", clear

* 9a. Year distribution
display as text _newline "--- Observations by year ---"
tab srvy_yr

* 9b. Era distribution
display as text _newline "--- Observations by era ---"
tab era_post2019

* 9c. Check key harmonized variables exist
local key_vars "srvy_yr hhx agep_a sex_a wtfa_a pstrat ppsu era_post2019"
local all_exist = 1
foreach v of local key_vars {
    capture confirm variable `v'
    if _rc != 0 {
        display as error "[FAIL] Variable `v' not found"
        local all_exist = 0
    }
}
if `all_exist' == 1 {
    display as text "[PASS] All key harmonized variables present"
}

* 9d. Weight check
quietly summarize wtfa_a
display as text "[INFO] Sample adult weight: N=" r(N) " mean=" %10.2f r(mean)

* 9e. Plausibility
* Check plausibility based on number of years
quietly tab srvy_yr
local n_val_years = r(r)
local low_bound = `n_val_years' * 20000
local high_bound = `n_val_years' * 100000
if _N > `low_bound' & _N < `high_bound' {
    display as text "[PASS] Total N (" _N ") plausible for `n_val_years' years"
}
else {
    display as text "[INFO] Total N (" _N ") for `n_val_years' years — verify this matches your download"
}

* 9f. Years present
quietly tab srvy_yr
display as text "[INFO] Unique survey years: " r(r)

* --- CHILD FILE ---
use "output/nhis_child.dta", clear
display as text _newline "--- Child file ---"
display as text "Total child observations: " _N
tab srvy_yr
tab era_post2019

display as text _newline "============================================"
display as text "   DONE"
display as text "============================================"
display as text "Next step: run 02_clean_and_analyze.do"

********************************************************************************
* EXTENDING TO 2015-2018:
*
* Years 2015-2018 follow the pre-2019 design but their data files are in
* .zip archives that must be extracted before the CDC do-files can run.
*
* STEP 1: Extract the zip files for each component:
*   foreach comp in personsx familyxx househld samadult {
*       !unzip -o "data/NHIS `y'/`comp'.zip" -d "data/NHIS `y'/"
*   }
*
*   For 2016-2018, CSV alternatives also exist:
*       !unzip -o "data/NHIS `y'/`comp'csv.zip" -d "data/NHIS `y'/"
*
*   NOTE: The do-files read from fixed-width .DAT files, NOT CSVs.
*         If using CSVs directly, use: import delimited using "comp.csv"
*
* STEP 2: Run the CDC do-files to create .dta from .DAT:
*   cd "data/NHIS `y'"
*   do personsx.do    // reads personsx.dat, saves personsx.dta
*   do familyxx.do
*   do househld.do
*   do samadult.do
*
* STEP 3: Add years to pre2019_years:
*   local pre2019_years "2004 2005 ... 2014 2015 2016 2017 2018"
*
* KNOWN ISSUES:
*   - 2015: samchild.zip is MISSING (not needed for adult analysis)
*   - 2017: familyxx.zip (fixed-width) is MISSING; use familyxxcsv.zip
*           and import via: import delimited using familyxx.csv
*   - CDC do-files may use `set mem` which is ignored in Stata 12+
*
* SPECIAL YEARS:
*   - 2020: COVID-disrupted; extra files (adultlong, adultpart) exist
*   - 2019: First redesign year; has both interim and final weights
*   - 2004-2005: Different stratum/PSU naming (stratum/psu)
*   - 2004-2010: No interview month variable (only quarter + week)
*   - 2011+: Has interview month (intv_mon)
*
* HOW THE CDC DO-FILES WORK:
*   The CDC provides a Stata do-file for each data component. These
*   do-files use `infix` to read fixed-width ASCII data and assign
*   variable names, labels, and value labels. The key structure is:
*
*     infix
*       rectype 1-2  srvy_yr 3-6  str hhx 7-12 ...
*     using "PERSONSX.dat", clear
*
*   They then apply labels and save as .dta. The do-files assume the
*   .DAT file is in the current working directory.
*
* See README.md for full documentation.
********************************************************************************
