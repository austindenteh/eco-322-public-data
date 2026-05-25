# Econ Data Starters

Starter code in Stata and R, plus documentation, for public-use datasets commonly used in economics, health policy, demography, and applied microeconomics research.

These folders are lightweight starting points for reproducible analysis workflows. Each reviewed dataset folder includes a README, runnable starter scripts, path-override examples, and notes on the raw files needed locally.

> Data files are too large for GitHub. Most reviewed dataset READMEs include a shared Dropbox folder or direct source instructions. Restricted sources, such as DHS, require official registration and cannot be redistributed here.

## Reviewed Dataset Folders

| Dataset | Folder | Coverage | Starter focus |
|---|---|---:|---|
| BRFSS | [`brfss/`](brfss/) | 2011-2024 | Adult health behaviors, chronic conditions, preventive care, insurance, and survey design variables |
| IPUMS ACS | [`ipums_acs_1_year_sample/`](ipums_acs_1_year_sample/) | 2006-2024 | ACS 1-year microdata on insurance, education, immigration, demographics, and employment |
| December CPS Food Security Supplement | [`dec_cps_food_insecurity_supplement/`](dec_cps_food_insecurity_supplement/) | 2001-2025 | Food insecurity, SNAP, food assistance, household resources, and CPS weights |
| March CPS / ASEC | [`march_cps/`](march_cps/) | 2005-2025 | Income, insurance, labor-market outcomes, demographics, and IPUMS CPS extract workflows |
| NHIS | [`nhis/`](nhis/) | 2004-2024 | Adult and child health, insurance, utilization, mental health, and pre/post-2019 redesign handling |
| YRBS | [`yrbs/`](yrbs/) | 1991-2023 | Youth mental health, substance use, risk behaviors, state/national samples, and survey design variables |
| RAND HRS | [`hrs/`](hrs/) | 1992-2022 | Aging, chronic conditions, cognition, retirement, income, wealth, and selected HRS waves |
| Ghana DHS | [`dhs/`](dhs/) | 1988-2022 | Ghana DHS recode files for fertility, nutrition, insurance, demographics, wealth, and wave-combining guidance |
| PSID | [`psid/`](psid/) | 1968-2023 | Main family/person panel files, cross-year individual data, selected supplemental studies, and public-use geography caveats |
| SIPP | [`sipp/`](sipp/) | 2008, 2014, 2018-2024 | Modern annual SIPP, 2014 panel files, 2014 SSA supplement, 2008 legacy core files, weights, and topical modules |

This table lists the reviewed starter folders currently intended for users; start from the dataset README before running any scripts.

## How to Use

1. Clone this repo (or download it)
2. Pick a dataset folder and read its `README.md`
3. Download the raw files from the Dropbox link or official source named in that README
4. Put raw files under that dataset's `data/` folder, unless the README says otherwise
5. Run the `01_*` loader, then the `02_*` cleaner or harmonizer, in Stata or R
6. Keep raw data, logs, and generated outputs out of Git unless a dataset README explicitly says an example file is meant to be committed
