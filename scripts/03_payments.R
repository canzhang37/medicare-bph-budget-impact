# Part B: payment by site; K2, K3, P5
suppressPackageStartupMessages(library(dplyr))
source("R/payments.R")

codes <- read.csv("inputs/procedure_codes.csv", colClasses = "character")
rvu26 <- read_rvu("data/raw/pfs/PPRRVU2026_Oct_nonQPP.csv", codes$code)
rvu24 <- read_rvu("data/raw/pfs/PPRRVU24_OCT.csv", codes$code)
stopifnot(all(abs(rvu26$cf - 33.4009) < 1e-9), all(abs(rvu24$cf - 33.2875) < 1e-9))

drg <- read_drg("data/raw/ipps/CMS-1849-CN Table 5.txt", c("707", "708", "713", "714"))

num <- function(d, cols) { for (c in cols) d[[c]] <- as.numeric(d[[c]]); d }
phy <- read.csv("data/raw/cms_api/physician.csv", colClasses = "character") |>
  filter(Rndrng_Prvdr_Geo_Lvl == "National", year == "2024") |>
  num(c("Tot_Srvcs", "Tot_Bene_Day_Srvcs", "Avg_Mdcr_Alowd_Amt"))
asc <- read.csv("results/asc_by_code.csv", colClasses = c(HCPCS_Cd = "character")) |> filter(year == 2024)
hop <- read.csv("results/hopd_by_code.csv", colClasses = c(HCPCS_Cd = "character")) |> filter(year == 2024)

# K2/K3 planned: 2024 claims vs CY2026 rate
k_plan <- phy |> inner_join(rvu26, by = c("HCPCS_Cd" = "code")) |>
  mutate(rate = ifelse(Place_Of_Srvc == "F", facility, office)) |>
  filter(Tot_Srvcs >= 1000) |>
  transmute(check = ifelse(Place_Of_Srvc == "F", "K2", "K3"), code = HCPCS_Cd,
            services_2024 = Tot_Srvcs, claims_avg = Avg_Mdcr_Alowd_Amt, fee_2026 = rate,
            ratio = claims_avg / fee_2026, pass = abs(ratio - 1) <= 0.20)

# amendment 3: prof claims only vs CY2024
prof <- phy |> left_join(select(asc, HCPCS_Cd, asc_services, asc_allowed), by = "HCPCS_Cd") |>
  mutate(asc_services = ifelse(Place_Of_Srvc == "F", coalesce(asc_services, 0), 0),
         asc_allowed = coalesce(asc_allowed, 0),
         prof_services = Tot_Srvcs - asc_services,
         prof_avg = (Tot_Srvcs * Avg_Mdcr_Alowd_Amt - asc_services * asc_allowed) / prof_services)
k_post <- prof |> inner_join(rvu24, by = c("HCPCS_Cd" = "code")) |>
  mutate(rate = ifelse(Place_Of_Srvc == "F", facility, office)) |>
  filter(prof_services >= 1000, !is.na(rate), rate > 0) |>
  transmute(check = paste0(ifelse(Place_Of_Srvc == "F", "K2", "K3"), " amended"), code = HCPCS_Cd,
            services_2024 = prof_services, claims_avg = prof_avg, fee_2024 = rate,
            ratio = claims_avg / fee_2024, pass = abs(ratio - 1) <= 0.20)
write.csv(k_plan, "results/k2_k3_planned.csv", row.names = FALSE)
write.csv(k_post, "results/k2_k3_amended.csv", row.names = FALSE)

# fee schedule change 2024 -> 2026
change <- rvu24 |> select(code, facility_2024 = facility, office_2024 = office) |>
  inner_join(select(rvu26, code, facility_2026 = facility, office_2026 = office), by = "code") |>
  mutate(facility_change = facility_2026 / facility_2024 - 1, office_change = office_2026 / office_2024 - 1)
write.csv(change, "results/fee_schedule_change_2024_2026.csv", row.names = FALSE)

# prof fee 2026; lift adds mean extra implants
addon <- phy |> filter(HCPCS_Cd %in% c("52441", "52442")) |> group_by(Place_Of_Srvc) |>
  summarise(extra = sum(Tot_Srvcs[HCPCS_Cd == "52442"]) / sum(Tot_Bene_Day_Srvcs[HCPCS_Cd == "52441"]))
r26 <- function(code, col) rvu26[[col]][rvu26$code == code]
pro <- codes |> filter(count_as_procedure == "1") |> select(family, code, list) |>
  left_join(select(rvu26, code, pro_facility = facility, pro_office = office), by = "code")
lift <- pro$code == "52441"
pro$pro_facility[lift] <- r26("52441", "facility") + addon$extra[addon$Place_Of_Srvc == "F"] * r26("52442", "facility")
pro$pro_office[lift] <- r26("52441", "office") + addon$extra[addon$Place_Of_Srvc == "O"] * r26("52442", "office")
# 0421T contractor priced -> 2024 claims avg
aq <- prof |> filter(HCPCS_Cd == "0421T")
pro$pro_facility[pro$code == "0421T"] <- aq$prof_avg[aq$Place_Of_Srvc == "F"]

# 2024 facility fees, C9739/C9740 -> 52441
fac_map <- codes |> filter(facility_code_for != "") |> select(HCPCS_Cd = code, prof = facility_code_for)
map_prof <- function(d) d |> left_join(fac_map, by = "HCPCS_Cd") |> mutate(code = coalesce(prof, HCPCS_Cd))
hopd_fee <- map_prof(hop) |> group_by(code) |>
  summarise(hopd_fee = weighted.mean(hopd_allowed, hopd_services), hopd_services = sum(hopd_services))
asc_fee <- map_prof(asc) |> group_by(code) |>
  summarise(asc_fee = weighted.mean(asc_allowed, asc_services), asc_services = sum(asc_services))

w <- read.csv("results/corrected_site_by_code.csv", colClasses = c(HCPCS_Cd = "character")) |>
  filter(year == 2024) |> select(code = HCPCS_Cd, w = procedures)
site_pay <- pro |> left_join(hopd_fee, by = "code") |> left_join(asc_fee, by = "code") |>
  left_join(w, by = "code") |>
  mutate(office_total = pro_office,
         hopd_total = pro_facility + hopd_fee,
         asc_total = pro_facility + asc_fee)
pay_fam <- site_pay |> group_by(family, list) |>
  summarise(across(c(pro_facility, pro_office, hopd_fee, asc_fee, office_total, hopd_total, asc_total),
                   ~ if (all(is.na(.x))) NA_real_ else weighted.mean(.x, w, na.rm = TRUE)),
            .groups = "drop")
pay_fam$inpatient_total <- NA_real_
turp <- pay_fam$family == "TURP"
pay_fam$inpatient_total[turp] <- pay_fam$pro_facility[turp] + drg$ipps_base[drg$drg == "714"]
# open simple -> DRG 708 (male pelvic)
open <- pay_fam$family == "Open prostatectomy"
pay_fam$inpatient_total[open] <- pay_fam$pro_facility[open] + drg$ipps_base[drg$drg == "708"]
write.csv(pay_fam, "results/payment_by_site_2026.csv", row.names = FALSE)
write.csv(drg, "results/ipps_fy2027_drg.csv", row.names = FALSE)
write.csv(addon, "results/urethral_lift_addon_implants.csv", row.names = FALSE)

# P5: office < HOPD where both exist
p5 <- pay_fam |> filter(list == "plan", !is.na(office_total), !is.na(hopd_total)) |>
  transmute(family, office_total, hopd_total, office_lower = office_total < hopd_total)
write.csv(p5, "results/p5_office_vs_hopd.csv", row.names = FALSE)

options(width = 180)
print(as.data.frame(k_plan)); print(as.data.frame(k_post))
print(as.data.frame(change |> mutate(across(where(is.numeric), ~ round(.x, 2)))))
print(as.data.frame(addon)); print(as.data.frame(drg))
print(as.data.frame(pay_fam |> mutate(across(where(is.numeric), round))))
print(as.data.frame(p5))
