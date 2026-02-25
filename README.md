# ECO 322: Public Data Starter Repositories

Starter code (Stata + R) and documentation for publicly available datasets used in health economics research at Davidson College.

> **📥 Data files are too large for GitHub.** Each dataset README links to a shared Dropbox folder where you can download the raw data.

## Datasets

| Dataset | Folder | Description |
|---|---|---|
| **BRFSS** | [`brfss/`](brfss/) | Behavioral Risk Factor Surveillance System — adult health behaviors, chronic conditions (2011–2024) |
| **IPUMS ACS** | [`ipums_acs_1_year_sample/`](ipums_acs_1_year_sample/) | American Community Survey — insurance, education, immigration (2006–2024) |
| **March CPS** | [`march_cps/`](march_cps/) | Current Population Survey ASEC — insurance, income, labor market (2005–2025) |
| **NHIS** | [`nhis/`](nhis/) | National Health Interview Survey — insurance, health status, utilization (2019–2024) |
| **YRBSS** | [`yrbs/`](yrbs/) | Youth Risk Behavior Surveillance System — youth mental health, substance use (1991–2023) |
| **RAND HRS** | [`hrs/`](hrs/) | Health and Retirement Study — aging, chronic conditions, cognition (1992–2022) |

## How to Use

1. Clone this repo (or download it)
2. Pick a dataset folder and read its `README.md`
3. Download the data from the Dropbox link in that README
4. Run `01_*` to load/append, then `02_*` to clean — in Stata or R
