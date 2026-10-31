# BPH procedures in Medicare: volumes, payment by site of service, and a budget impact model

How many procedures for benign prostatic hyperplasia (BPH) does Medicare pay for, where are they done, what does Medicare pay for each one at each site, and what would a new office-based therapy do to Medicare's budget? This project answers those questions from public Medicare fee-for-service claims summaries (2013-2024), the 2026 fee schedules and a targeted literature review, and builds the budget impact model twice, in R and as a formula-driven Excel workbook, so each checks the other.

The analysis plan, predictions and checks were written down before the BPH data were pulled ([docs/design.md](docs/design.md)), and the results are in [docs/readout.md](docs/readout.md). In short: about 90,500 first procedures in 2024, with urethral lift falling since 2021, waterjet ablation and laser enucleation growing, and a new laparoscopic (including robotic) simple prostatectomy code taking over from open surgery; the same urethral lift costs Medicare $5,245 in the office and $8,677 in a hospital outpatient department; and a hypothetical office therapy paid like an office urethral lift saves Medicare $25.8 million over five years, breaking even at $6,196 per procedure.

## Running it

R 4.4 with dplyr, ggplot2, httr, jsonlite and testthat; Windows with Excel for the workbook step.

```
Rscript scripts/01_pull_cms.R         # data.cms.gov API, BPH codes only (a few minutes)
Rscript scripts/01b_pull_asc.R        # ASC facility rows from the provider-level file
Rscript scripts/02_volumes.R          # Part A: volumes, mix, site of service, checks K4-K5
Rscript scripts/03_payments.R         # Part B: payment by site, checks K2-K3, prediction P5
Rscript scripts/04_literature.R       # Part C: retreatment rates checked against PubMed abstracts
Rscript scripts/05_bim.R              # Part D: budget impact model and sensitivity in R
powershell -ExecutionPolicy Bypass -File scripts/06_build_excel.ps1   # the Excel workbook
Rscript scripts/07_check_excel.R      # K1: R vs Excel
Rscript scripts/08_verdicts.R
Rscript scripts/09_figures.R
```

Tests: `cd tests && Rscript -e "testthat::test_file('test_core.R')"`.

Scripts 03 and 05 expect the fee schedule and IPPS files in `data/raw/pfs` and `data/raw/ipps` (see Data). `data/` is not in the repository.

## Layout

- `inputs/`: the code list (CPT/HCPCS families, with the C-codes hospitals use for urethral lift), an ICD-10-PCS crosswalk, the literature table with the abstract text each number comes from, and the CMS dataset IDs by year.
- `R/`: the data.cms.gov client, fee schedule readers, and the budget impact model.
- `results/`: every table behind the readout, the verdicts, and `bph_budget_impact_model.xlsx`.
- `figures/`, `docs/`, `tests/`.

## Data

- Medicare Physician & Other Practitioners by Geography and Service and by Provider and Service, Medicare Outpatient Hospitals by Geography and Service, and Medicare Inpatient Hospitals by Geography and Service, 2013-2024, from data.cms.gov.
- CMS Physician Fee Schedule relative value files RVU24D and RVU26D, and FY2027 IPPS final rule Tables 1A-1E and 5 (correction notice), from cms.gov.
- PubMed abstracts through the NCBI E-utilities.

CPT codes are listed by number with descriptions in my own words; CPT is a registered trademark of the American Medical Association. The data are public summaries with small cells suppressed by CMS; no patient-level data are used.

## License

MIT, see [LICENSE](LICENSE). Can Zhang, zhan8639@umn.edu.
