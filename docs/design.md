# Design: BPH procedures in Medicare and the budget impact of a new office-based therapy

Written before any BPH row was pulled from the claims files. Changes after this point go into the amendments section at the end with the reason.

## Question

A device team developing a new minimally invasive therapy for benign prostatic hyperplasia (BPH) needs three things from real-world data before it can talk to payers: how many procedures Medicare pays for and where they happen, what Medicare pays for each procedure at each site of service, and what adopting the new therapy would do to Medicare's budget over five years. This project answers those three questions with public Medicare fee-for-service claims summaries, the 2026 fee schedules, and a targeted literature review, and builds the budget impact model twice (in R and as a formula-driven Excel workbook) so that each checks the other.

## Data

All files are public. Nothing patient-level is used.

1. Medicare Physician & Other Practitioners, by Geography and Service, 2013-2024 (data.cms.gov). National and state rows per HCPCS/CPT code and place of service (F = facility, O = office): providers, beneficiaries, services, beneficiary-day services, average allowed and paid amounts. Built by CMS from Part B professional claims. Pulled through the data.cms.gov API with a filter on the codes in the code list.
2. Medicare Outpatient Hospitals, by Geography and Service, 2015-2024. HCPCS-level rows give hospital outpatient department (HOPD) services and average allowed amounts for the facility side.
3. Medicare Inpatient Hospitals, by Geography and Service, 2013-2024. Discharges and payments per MS-DRG.
4. CMS Physician Fee Schedule relative value file RVU26D (CY2026, October release) with the CY2026 conversion factor for clinicians not in an advanced APM ($33.4009), copied from the colon-adjuvant-cost-effectiveness project.
5. FY2027 IPPS final rule Table 5 (MS-DRG relative weights) and Table 1A (national standardized amounts).
6. PubMed abstracts for the literature review.

The OPPS Addendum A/B and ASC Addendum AA rate files sit behind the AMA CPT license page on cms.gov, so this project does not use them. HOPD facility payments come from the observed 2024 average allowed amounts in file 2, and ambulatory surgical centers (ASCs) are not modeled as a separate site (their volume is inside the facility rows of file 1). CPT codes are listed by number with descriptions in my own words.

## Code list

Procedure families (CPT unless noted):

| Family | Codes | Counted by |
|---|---|---|
| Transurethral resection (TURP) | 52601 | 52601 |
| Transurethral incision (TUIP) | 52450 | 52450 |
| Laser coagulation | 52647 | 52647 |
| Laser vaporization (PVP) | 52648 | 52648 |
| Laser enucleation (HoLEP) | 52649 | 52649 |
| Prostatic urethral lift | 52441, 52442 | 52441 only (52442 is the add-on per extra implant) |
| Water vapor thermal therapy | 53854 | 53854 |
| Microwave thermotherapy (TUMT) | 53850 | 53850 |
| Radiofrequency thermotherapy (TUNA) | 53852 | 53852 |
| Waterjet ablation (Aquablation) | 0421T | 0421T |
| Open simple prostatectomy | 55821, 55831 | both |
| Resection of regrown tissue | 52630 | 52630 (retreatment marker, not a first procedure) |

The families and the ICD-10 codes for the population and outcomes come from the BPH code sets in the omop-target-trial-emulation project (ICD-10-CM N40.0-N40.3; ICD-10-PCS 0VT08ZZ, 0VB08ZZ, 0V508ZZ, 0V507ZZ, 0VT00ZZ). The public files carry no diagnosis, so the CPT families define the procedures here and the ICD-10-PCS codes are mapped to them in a crosswalk for later patient-level work. Inpatient transurethral prostatectomy is MS-DRG 713 (with CC/MCC) and 714 (without), checked against FY2027 Table 5. MS-DRGs 707-708 (major male pelvic procedures) are mostly radical prostatectomy for cancer and are left out.

Volume measure: beneficiary-day services (Tot_Bene_Day_Srvcs), which counts one procedure per beneficiary per day and so does not double count add-on codes, bilateral billing or two surgeons on one case. Services are reported beside it.

## Part A: volumes, mix and site of service

- National procedures per year by family, 2013-2024, office and facility.
- Mix: each family's share of all first procedures (52630 excluded).
- Site of service: office share from file 1; HOPD services from file 2; inpatient discharges from file 3.
- State rows: procedures per state in 2024, and a check that state rows add up to the national row (small cells are suppressed in state rows, so the sum can be slightly lower).

## Part B: Medicare payment by site of service

For each family, the CY2026 Medicare allowed amount by site:

- Office: Physician Fee Schedule non-facility payment = non-facility total RVU x conversion factor (national, GPCI = 1).
- HOPD: Physician Fee Schedule facility payment plus the 2024 HOPD average allowed amount for the code from file 2 (reported as 2024 dollars, not inflated).
- Inpatient (TURP only): Physician Fee Schedule facility payment plus the FY2027 MS-DRG 714 base payment = relative weight x national standardized amount (labor plus nonlabor share, wage index 1, no IME, DSH or outlier add-ons), with DRG 713 shown beside it.

## Part C: targeted literature review

PubMed search for the longest-follow-up randomized or large prospective studies reporting surgical retreatment after each family (TURP, PVP, HoLEP, urethral lift, water vapor, Aquablation). For each: PMID, design, patients, follow-up, surgical retreatment rate, and the annual rate implied by spreading the cumulative rate evenly over follow-up. Numbers are taken from the abstracts only, and every number is checked against the abstract text by a script.

## Part D: budget impact model

Built to the ISPOR 2012 Budget Impact Analysis Good Practice II Task Force report (Sullivan et al., Value Health 2014).

- Perspective: Medicare fee-for-service, allowed amounts (Medicare payment plus beneficiary cost sharing).
- Population: Medicare beneficiaries receiving a first procedural BPH treatment each year, from the 2024 national volume by family and site, held flat in the base case (trend from 2019-2024 as a scenario).
- Horizon: 5 years.
- Current world: 2024 mix by family and site.
- New world: a hypothetical office-based therapy ("new therapy") whose share of first procedures rises 2%, 4%, 6%, 8%, 10% in years 1-5, taken from the other families in proportion to their shares.
- Costs: index procedure payment by family and site from Part B. The new therapy is paid like an office urethral lift (payment parity) in the base case. Retreatment: annual surgical retreatment rate by family from Part C applied to the cohorts treated in earlier model years, each retreatment paid as a facility TURP. The new therapy uses the water vapor retreatment rate in the base case.
- Outputs: total annual spending in the current and new world, net budget impact per year and over 5 years, and per new-therapy patient.
- One-way sensitivity: uptake x0.5 and x1.5, new-therapy payment -30% and +30%, new-therapy retreatment at the lowest and highest family rate, displacement from minimally invasive families only, volume trend.
- Two implementations: R functions (R/bim.R) and an Excel workbook built cell by cell with formulas through Excel's COM interface (scripts/06_build_excel.ps1), so a reviewer can change any input in Excel and see the result.

## Predictions (written before the BPH data were pulled)

- P1. TURP (52601) beneficiary-day services fall by at least 20% from 2015 to 2024.
- P2. Urethral lift plus water vapor make up a larger share of first procedures in 2024 than in 2016, and at least 20% in 2024.
- P3. The office share of urethral lift procedures is higher in 2024 than in 2016.
- P4. Inpatient discharges in MS-DRGs 713-714 fall by at least 30% from 2015 to 2024.
- P5. For every family billed in both settings, the total Medicare payment is lower in the office than in the HOPD (professional plus facility).
- P6. In the one-way sensitivity analysis, new-therapy payment moves the 5-year net budget impact more than any other input.

## Checks (must pass before results are reported)

- K1. The R model and the Excel workbook agree to within $1 for every year in the base case and every sensitivity case.
- K2. For each code with at least 1,000 facility services in 2024, the 2024 average allowed amount in file 1 is within 20% of the CY2026 facility fee schedule payment (loose because the years and locality mix differ; this catches wrong codes and wrong site mapping).
- K3. The same for office services and the non-facility payment.
- K4. Every code in the list appears in file 1 in at least one year, and the CMS description matches the intended family (listed in the results for review).
- K5. State rows add up to at least 95% and at most 100% of the national row for each family in 2024.

The inpatient check (FY2027 base payment vs 2024 average payment per discharge) is reported but not pass/fail, because the base payment leaves out add-ons that the claims include.

## Amendments

1. Post hoc, after the first Part A run. Open simple prostatectomy (55821 + 55831) fell from 2,214 to 792 procedures between 2022 and 2023, and a search of the 2024 file found CPT 55867 (laparoscopic simple subtotal prostatectomy, robotic assistance included when performed) with 5,264 facility procedures. It is added as the family "Laparoscopic simple prostatectomy" (robotic included), pulled from all years of files 1 and 2. All pre-registered predictions and checks are computed on the planned code list; results that include 55867 are labeled post hoc.
2. Clarification before Part B was run. The inpatient base payment adds the FY2027 capital federal rate ($539.95 x relative weight, Table 1D) to the operating standardized amount ($6,848.00 x relative weight, Table 1A/1B total), because Medicare pays both. The Correction Notice versions of Tables 1A-1E and 5 are used.
3. After K2 and K3 failed. K2 failed for 52601, 52648, 52649, 53854 and 52630 (claims average 27-80% above the CY2026 facility rate) and K3 for 53854 (claims average 52% below the CY2026 office rate). Two causes were found. (a) The facility rows of file 1 include facility claims billed by ambulatory surgical centers (provider type "Ambulatory Surgical Center", entity type O), so a procedure done in an ASC is counted twice (surgeon and ASC) and the ASC facility fee raises the average. (b) Several codes were revalued between 2024 and 2026 (52601 facility total RVU 21.73 in CY2024, 15.75 in CY2026; 52648 lost its office rate; 53854 office RVU went from 49.69 to 101.66). Changes, all labeled post hoc: ASC facility rows are pulled from the provider-level file (Medicare Physician & Other Practitioners, by Provider and Service) for each code and year and subtracted from the national facility rows. Rows for ASCs with fewer than 11 beneficiaries for a code are suppressed in that file and cannot be removed, so the corrected counts are upper bounds. The ASC rows also give an observed ASC facility payment, so the ASC becomes a fourth site of service in Part B and Part D. K2 and K3 are re-run on professional claims only against the CY2024 fee schedule (RVU24D, conversion factor $33.2875), which tests the code and site mapping in the same year. The pre-registered K2 and K3 verdicts stay as failed, and P1-P4 are reported both as planned and on the corrected counts. The same check showed that hospitals and ASCs bill urethral lift as HCPCS C9739 (1 to 3 implants) or C9740 (4 or more) instead of CPT 52441, so the outpatient file has no 52441 rows; both C-codes are added as facility codes for 52441 and pulled from files 2 and the provider-level file.
4. Clarification before Part D was run. Costs per family weight the 2024 site mix by the payment at each site. Cases in the "inpatient or other" group are paid at the inpatient rate where the family has one (TURP at MS-DRG 714, open simple prostatectomy at MS-DRG 708, major male pelvic procedures without CC/MCC) and otherwise at the HOPD total; a site without a rate falls back to the HOPD total. Retreatments are paid at the average cost of a TURP across its sites. Families without a retreatment study use the TURP rate.
