# Part D: base case + one-way sensitivity
suppressPackageStartupMessages(library(dplyr))
source("R/bim.R")

vol <- read.csv("results/corrected_volume_by_family.csv") |> filter(list == "plan")
pay <- read.csv("results/payment_by_site_2026.csv") |> filter(list == "plan")
lit <- read.csv("results/literature_checked.csv")

v24 <- vol |> filter(year == 2024)
cost <- family_cost(v24, pay)
base_rate <- lit |> filter(role == "base") |> select(family, retreat = annual_rate)
turp_rate <- base_rate$retreat[base_rate$family == "TURP"]
mist <- c("Urethral lift", "Water vapor", "TUMT", "TUNA")

fam <- v24 |> transmute(family, procedures, share = procedures / sum(procedures)) |>
  mutate(cost = unname(cost[family])) |>
  left_join(base_rate, by = "family") |>
  mutate(retreat_source = ifelse(is.na(retreat), "TURP rate (no study)", "literature"),
         retreat = coalesce(retreat, turp_rate), mist = as.integer(family %in% mist)) |>
  arrange(desc(share))

n <- sum(v24$procedures)
n19 <- sum(vol$procedures[vol$year == 2019])
scal <- list(
  n = n,
  uptake = c(0.02, 0.04, 0.06, 0.08, 0.10),
  c_new = pay$office_total[pay$family == "Urethral lift"],  # payment parity
  r_new = base_rate$retreat[base_rate$family == "Water vapor"],
  c_ret = fam$cost[fam$family == "TURP"],  # retreat paid as a TURP
  growth_trend = (n / n19)^(1 / 5) - 1)

run <- function(case, uptake = scal$uptake, c_new = scal$c_new, r_new = scal$r_new,
                growth = 0, displace = "all") {
  b <- bim(fam, scal$n, uptake, c_new, r_new, scal$c_ret, growth, displace)
  cbind(case = case, b)
}
cases <- list(
  run("base"),
  run("uptake x0.5", uptake = 0.5 * scal$uptake),
  run("uptake x1.5", uptake = 1.5 * scal$uptake),
  run("new-therapy payment -30%", c_new = 0.7 * scal$c_new),
  run("new-therapy payment +30%", c_new = 1.3 * scal$c_new),
  run("new-therapy retreatment lowest", r_new = min(fam$retreat)),
  run("new-therapy retreatment highest", r_new = max(fam$retreat)),
  run("displaces minimally invasive only", displace = "mist"),
  run("volume trend 2019-2024", growth = scal$growth_trend))
res <- do.call(rbind, cases)
summ <- res |> group_by(case) |>
  summarise(net_impact_5y = sum(net_impact), new_therapy_patients = sum(new_therapy_patients),
            per_new_patient = net_impact_5y / new_therapy_patients, .groups = "drop")
base5 <- summ$net_impact_5y[summ$case == "base"]
summ <- summ |> mutate(change_vs_base = net_impact_5y - base5)

write.csv(fam, "results/bim_family_inputs.csv", row.names = FALSE)
jsonlite::write_json(scal, "results/bim_scalars.json", digits = NA, auto_unbox = TRUE, pretty = TRUE)
write.csv(res, "results/bim_r_by_year.csv", row.names = FALSE)
write.csv(summ, "results/bim_r_summary.csv", row.names = FALSE)

# P6: largest swing = payment?
inputs <- c(uptake = "uptake", payment = "payment", retreat = "retreatment", displace = "displaces",
            trend = "trend")
swing <- sapply(inputs, function(k) max(abs(summ$change_vs_base[grepl(k, summ$case)])))
p6 <- names(which.max(swing)) == "payment"

options(width = 160)
print(fam |> mutate(across(c(share, retreat), ~ round(.x, 4)), cost = round(cost)))
str(scal)
print(as.data.frame(res |> filter(case == "base") |> mutate(across(where(is.numeric), round))))
print(as.data.frame(summ |> mutate(across(where(is.numeric), round))))
print(round(swing)); cat("P6 met:", p6, "\n")
