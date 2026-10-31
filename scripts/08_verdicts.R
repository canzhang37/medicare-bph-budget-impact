# verdicts P1-P6, K1-K5
suppressPackageStartupMessages(library(dplyr))
fam <- read.csv("results/volume_by_family.csv")  # planned measure
cor <- read.csv("results/corrected_volume_by_family.csv") |> filter(list == "plan")
ip <- read.csv("results/inpatient_drg.csv")
p5 <- read.csv("results/p5_office_vs_hopd.csv")
k1 <- read.csv("results/k1_r_vs_excel.csv")
k_plan <- read.csv("results/k2_k3_planned.csv", colClasses = c(code = "character"))
k_post <- read.csv("results/k2_k3_amended.csv", colClasses = c(code = "character"))
k4 <- read.csv("results/k4_codes_found.csv")
k5 <- read.csv("results/k5_state_vs_national.csv")
sens <- read.csv("results/bim_r_summary.csv")
codes <- read.csv("inputs/procedure_codes.csv", colClasses = "character")

g <- function(d, y, f, col = "bene_day") sum(d[[col]][d$year == y & d$family %in% f])
pct <- function(x) sprintf("%.1f%%", 100 * x)

turp <- c(plan = g(fam, 2024, "TURP") / g(fam, 2015, "TURP") - 1,
          cor = g(cor, 2024, "TURP", "procedures") / g(cor, 2015, "TURP", "procedures") - 1)
mist <- c("Urethral lift", "Water vapor")
sh <- function(d, y, col) g(d, y, mist, col) / sum(d[[col]][d$year == y])
p2 <- c(s16 = sh(fam, 2016, "bene_day"), s24 = sh(fam, 2024, "bene_day"),
        c16 = sh(cor, 2016, "procedures"), c24 = sh(cor, 2024, "procedures"))
lift_office <- fam$office_share[fam$family == "Urethral lift" & fam$year %in% c(2016, 2024)]
drg <- c(sum(ip$Tot_Dschrgs[ip$year == 2015]), sum(ip$Tot_Dschrgs[ip$year == 2024]))
swing <- sens |> filter(case != "base") |> mutate(input = sub(" .*", "", sub("new-therapy ", "", case))) |>
  group_by(input) |> summarise(swing = max(abs(change_vs_base)))
plan_codes <- codes$code[codes$list == "plan"]
k_plan <- filter(k_plan, code %in% plan_codes)  # 55867 = amendment 1

v <- tribble(
  ~id, ~statement, ~result, ~met,
  "P1", "TURP falls >= 20%, 2015-2024",
  sprintf("%s as planned (%s after removing ASC facility claims)", pct(turp["plan"]), pct(turp["cor"])),
  turp["plan"] <= -0.20,
  "P2", "Urethral lift + water vapor share higher in 2024 than 2016 and >= 20%",
  sprintf("%s in 2016, %s in 2024 (corrected %s, %s)", pct(p2["s16"]), pct(p2["s24"]), pct(p2["c16"]), pct(p2["c24"])),
  p2["s24"] > p2["s16"] && p2["s24"] >= 0.20,
  "P3", "Office share of urethral lift higher in 2024 than 2016",
  sprintf("%s in 2016, %s in 2024", pct(lift_office[1]), pct(lift_office[2])), lift_office[2] > lift_office[1],
  "P4", "MS-DRG 713-714 discharges fall >= 30%, 2015-2024",
  sprintf("%d to %d (%s)", drg[1], drg[2], pct(drg[2] / drg[1] - 1)), drg[2] / drg[1] - 1 <= -0.30,
  "P5", "Office total below HOPD total for every family billed in both",
  paste(sprintf("%s $%s vs $%s", p5$family, format(round(p5$office_total), big.mark = ","),
                format(round(p5$hopd_total), big.mark = ",")), collapse = "; "), all(p5$office_lower),
  "P6", "New-therapy payment moves the 5-year result most",
  paste(sprintf("%s $%.1fM", swing$input, swing$swing / 1e6), collapse = "; "),
  swing$input[which.max(swing$swing)] == "payment",
  "K1", "R and Excel agree within $1", sprintf("max gap $%.2g", max(k1$max_abs_difference)), all(k1$pass),
  "K2", "Facility claims average within 20% of CY2026 rate (planned)",
  sprintf("%d of %d codes pass", sum(k_plan$pass[k_plan$check == "K2"]), sum(k_plan$check == "K2")),
  all(k_plan$pass[k_plan$check == "K2"]),
  "K3", "Office claims average within 20% of CY2026 rate (planned)",
  sprintf("%d of %d codes pass", sum(k_plan$pass[k_plan$check == "K3"]), sum(k_plan$check == "K3")),
  all(k_plan$pass[k_plan$check == "K3"]),
  "K2/K3 amended", "Professional claims only vs CY2024 rate (post hoc)",
  paste(sprintf("%s %s %.2f", k_post$check, k_post$code, k_post$ratio), collapse = "; "), all(k_post$pass),
  "K4", "Every planned code found in file 1",
  sprintf("%d of %d", sum(plan_codes %in% k4$HCPCS_Cd), length(plan_codes)), all(plan_codes %in% k4$HCPCS_Cd),
  "K5", "State rows sum to 95-100% of national, every family",
  paste(sprintf("%s %s", k5$family, ifelse(is.na(k5$ratio), "no state rows", sprintf("%.2f", k5$ratio))), collapse = "; "),
  isTRUE(all(k5$pass)))
write.csv(v, "results/verdicts.csv", row.names = FALSE)
options(width = 200)
print(as.data.frame(v))
