# Part A: volumes, mix, site; K4, K5
suppressPackageStartupMessages(library(dplyr))
source("R/cms_api.R")

codes <- read.csv("inputs/procedure_codes.csv", colClasses = "character")
num <- c("Tot_Rndrng_Prvdrs", "Tot_Benes", "Tot_Srvcs", "Tot_Bene_Day_Srvcs",
         "Avg_Sbmtd_Chrg", "Avg_Mdcr_Alowd_Amt", "Avg_Mdcr_Pymt_Amt", "Avg_Mdcr_Stdzd_Amt",
         "Bene_Cnt", "CAPC_Srvcs", "Avg_Tot_Sbmtd_Chrgs", "Outlier_Srvcs", "Avg_Mdcr_Outlier_Amt",
         "Tot_Dschrgs", "Avg_Submtd_Cvrd_Chrg", "Avg_Tot_Pymt_Amt")
rd <- function(f) as_num_cols(read.csv(f, colClasses = "character"), num) |>
  mutate(year = as.integer(year))

phy <- rd("data/raw/cms_api/physician.csv") |>
  left_join(codes, by = c("HCPCS_Cd" = "code"))
opd <- rd("data/raw/cms_api/outpatient.csv") |>
  left_join(codes, by = c("HCPCS_Cd" = "code"))
inp <- rd("data/raw/cms_api/inpatient.csv")

nat <- phy |> filter(Rndrng_Prvdr_Geo_Lvl == "National")

# K4: codes found + CMS descriptions
k4 <- nat |> group_by(family, HCPCS_Cd) |>
  summarise(first_year = min(year), last_year = max(year),
            cms_description = last(HCPCS_Desc), .groups = "drop")
missing <- setdiff(codes$code, k4$HCPCS_Cd)
write.csv(k4, "results/k4_codes_found.csv", row.names = FALSE)

# national procedures by family, year, POS
vol <- nat |> filter(count_as_procedure == "1") |>
  group_by(year, list, family, pos = Place_Of_Srvc) |>
  summarise(bene_day = sum(Tot_Bene_Day_Srvcs), services = sum(Tot_Srvcs),
            benes = sum(Tot_Benes), providers = sum(Tot_Rndrng_Prvdrs),
            allowed = sum(Avg_Mdcr_Alowd_Amt * Tot_Srvcs) / sum(Tot_Srvcs), .groups = "drop")
write.csv(vol, "results/volume_by_family_pos.csv", row.names = FALSE)

# planned list; post hoc adds 55867
family_table <- function(v) v |> group_by(year, family) |>
  summarise(office = sum(bene_day[pos == "O"]), bene_day = sum(bene_day), .groups = "drop") |>
  group_by(year) |> mutate(share = bene_day / sum(bene_day), office_share = office / bene_day) |>
  ungroup()
fam <- family_table(filter(vol, list == "plan"))
fam_posthoc <- family_table(vol)
write.csv(fam, "results/volume_by_family.csv", row.names = FALSE)
write.csv(fam_posthoc, "results/posthoc_volume_by_family_with_55867.csv", row.names = FALSE)

tot <- fam |> group_by(year) |> summarise(procedures = sum(bene_day))
retreat <- nat |> filter(HCPCS_Cd == "52630") |> group_by(year) |>
  summarise(regrowth_resections = sum(Tot_Bene_Day_Srvcs))

# HOPD facility side by code
hop <- opd |> filter(Rndrng_Prvdr_Geo_Lvl == "National", !is.na(family)) |>
  group_by(year, family, HCPCS_Cd) |>
  summarise(hopd_services = sum(CAPC_Srvcs), hopd_allowed = weighted.mean(Avg_Mdcr_Alowd_Amt, CAPC_Srvcs),
            hopd_paid = weighted.mean(Avg_Mdcr_Pymt_Amt, CAPC_Srvcs), .groups = "drop")
write.csv(hop, "results/hopd_by_code.csv", row.names = FALSE)

# amendment 3: drop same-code ASC claims
# (ASCs w/ < 11 benes stay in)
asc <- read.csv("data/raw/cms_api/asc_provider_rows.csv", colClasses = "character") |>
  mutate(across(c(Tot_Srvcs, Tot_Bene_Day_Srvcs, Avg_Mdcr_Alowd_Amt), as.numeric),
         year = as.integer(year)) |>
  filter(Place_Of_Srvc == "F") |>
  group_by(year, HCPCS_Cd) |>
  summarise(asc_bene_day = sum(Tot_Bene_Day_Srvcs), asc_services = sum(Tot_Srvcs),
            asc_allowed = sum(Avg_Mdcr_Alowd_Amt * Tot_Srvcs) / sum(Tot_Srvcs),
            asc_centers = n(), .groups = "drop")
write.csv(asc, "results/asc_by_code.csv", row.names = FALSE)

# lift facility claims are C9739/C9740,
# matched to 52441, not inside its rows
fac_map <- codes |> filter(facility_code_for != "") |> select(HCPCS_Cd = code, prof = facility_code_for)
to_prof <- function(d) d |> left_join(fac_map, by = "HCPCS_Cd") |>
  mutate(same_code = is.na(prof), prof = coalesce(prof, HCPCS_Cd))
asc_site <- to_prof(asc) |> group_by(year, prof) |>
  summarise(asc_same = sum(asc_bene_day[same_code]), asc = sum(asc_bene_day), .groups = "drop")
hop_site <- to_prof(ungroup(hop)) |> group_by(year, prof) |>
  summarise(hopd = sum(hopd_services), .groups = "drop")

site <- nat |> filter(count_as_procedure == "1") |>
  group_by(year, list, family, HCPCS_Cd) |>
  summarise(office = sum(Tot_Bene_Day_Srvcs[Place_Of_Srvc == "O"]),
            facility_rows = sum(Tot_Bene_Day_Srvcs[Place_Of_Srvc == "F"]), .groups = "drop") |>
  left_join(asc_site, by = c("year", "HCPCS_Cd" = "prof")) |>
  left_join(hop_site, by = c("year", "HCPCS_Cd" = "prof")) |>
  mutate(across(c(asc_same, asc, hopd), ~ coalesce(.x, 0)),
         facility = facility_rows - asc_same,  # one surgeon claim per case
         procedures = office + facility,
         inpatient_or_other = facility - asc - hopd)
write.csv(site, "results/corrected_site_by_code.csv", row.names = FALSE)

fam_corr <- site |> group_by(year, list, family) |>
  summarise(across(c(office, asc, hopd, inpatient_or_other, facility, procedures), sum),
            .groups = "drop") |>
  group_by(year, list) |> mutate(share = procedures / sum(procedures)) |> ungroup() |>
  mutate(office_share = office / procedures)
write.csv(fam_corr, "results/corrected_volume_by_family.csv", row.names = FALSE)

ip <- inp |> filter(Rndrng_Prvdr_Geo_Lvl == "National") |>
  select(year, DRG_Cd, DRG_Desc, Tot_Dschrgs, Avg_Tot_Pymt_Amt, Avg_Mdcr_Pymt_Amt)
write.csv(ip, "results/inpatient_drg.csv", row.names = FALSE)

# K5: state rows vs national, 2024
st <- phy |> filter(year == 2024, Rndrng_Prvdr_Geo_Lvl == "State", count_as_procedure == "1",
                    list == "plan") |>
  group_by(family) |> summarise(state_sum = sum(Tot_Bene_Day_Srvcs))
k5 <- fam |> filter(year == 2024) |> select(family, national = bene_day) |>
  left_join(st, by = "family") |> mutate(ratio = state_sum / national,
                                         pass = ratio >= 0.95 & ratio <= 1.0 + 1e-9)
write.csv(k5, "results/k5_state_vs_national.csv", row.names = FALSE)

state24 <- phy |> filter(year == 2024, Rndrng_Prvdr_Geo_Lvl == "State", count_as_procedure == "1") |>
  group_by(state = Rndrng_Prvdr_Geo_Desc) |> summarise(procedures = sum(Tot_Bene_Day_Srvcs)) |>
  arrange(desc(procedures))
write.csv(state24, "results/state_2024.csv", row.names = FALSE)

options(width = 160)
cat("missing codes:", if (length(missing)) missing else "none", "\n")
print(as.data.frame(k4))
print(as.data.frame(tidyr::pivot_wider(fam |> select(year, family, bene_day), names_from = family, values_from = bene_day)))
print(as.data.frame(left_join(tot, retreat, by = "year")))
print(as.data.frame(k5))
print(as.data.frame(ip))
