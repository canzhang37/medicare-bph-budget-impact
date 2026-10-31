# figures: trend, sites, payment, tornado
suppressPackageStartupMessages({ library(dplyr); library(ggplot2) })
dir.create("figures", showWarnings = FALSE)
okabe <- c("#0072B2", "#E69F00", "#009E73", "#CC79A7", "#56B4E9", "#D55E00", "#999999", "#000000")
theme_set(theme_minimal(base_size = 10) +
            theme(panel.grid.minor = element_blank(), legend.title = element_blank()))
save <- function(p, f, w = 6.5, h = 3.6) ggsave(file.path("figures", f), p, width = w, height = h, dpi = 150, bg = "white")

cor <- read.csv("results/corrected_volume_by_family.csv")
top <- c("TURP", "Urethral lift", "PVP", "HoLEP", "Aquablation", "Water vapor")
tr <- cor |> mutate(group = case_when(list != "plan" ~ "Laparoscopic simple (post hoc)",
                                      family %in% top ~ family, TRUE ~ "Other planned")) |>
  group_by(year, group) |> summarise(procedures = sum(procedures), .groups = "drop") |>
  mutate(group = factor(group, c(top, "Other planned", "Laparoscopic simple (post hoc)")))
p1 <- ggplot(tr, aes(year, procedures / 1000, colour = group)) +
  geom_line(linewidth = 0.9) + geom_point(size = 1.3) +
  scale_colour_manual(values = okabe) + scale_x_continuous(breaks = seq(2013, 2024, 2)) +
  labs(x = NULL, y = "Medicare FFS procedures (thousands)",
       caption = "Beneficiary-day services, ASC facility claims removed (amendment 3).")
save(p1, "volume_trend.png")

site <- cor |> filter(year == 2024, list == "plan", family %in% top) |>
  select(family, Office = office, ASC = asc, HOPD = hopd, `Inpatient or other` = inpatient_or_other) |>
  tidyr::pivot_longer(-family, names_to = "site", values_to = "n") |>
  mutate(family = factor(family, rev(top)), site = factor(site, c("Office", "ASC", "HOPD", "Inpatient or other")))
p2 <- ggplot(site, aes(n / 1000, family, fill = site)) + geom_col(width = 0.7) +
  scale_fill_manual(values = okabe[c(3, 2, 1, 7)]) +
  labs(x = "2024 procedures (thousands)", y = NULL) + theme(legend.position = "top")
save(p2, "site_of_service_2024.png", h = 3.2)

pay <- read.csv("results/payment_by_site_2026.csv") |> filter(family %in% top) |>
  select(family, Office = office_total, ASC = asc_total, HOPD = hopd_total, Inpatient = inpatient_total) |>
  tidyr::pivot_longer(-family, names_to = "site", values_to = "usd") |> filter(!is.na(usd)) |>
  mutate(family = factor(family, rev(top)), site = factor(site, c("Office", "ASC", "HOPD", "Inpatient")))
p3 <- ggplot(pay, aes(usd, family, colour = site)) + geom_point(size = 2.6) +
  scale_colour_manual(values = okabe[c(3, 2, 1, 6)]) + scale_x_continuous(labels = scales::dollar) +
  labs(x = "Medicare allowed per procedure (2026 professional + facility)", y = NULL) +
  theme(legend.position = "top")
save(p3, "payment_by_site.png", h = 3.2)

s <- read.csv("results/bim_r_summary.csv")
base <- s$net_impact_5y[s$case == "base"]
lab <- c("uptake" = "Uptake x0.5 / x1.5", "payment" = "New-therapy payment -30% / +30%",
         "retreatment" = "New-therapy retreatment low / high", "displaces" = "Displaces minimally invasive only",
         "volume" = "Volume trend 2019-2024")
tor <- s |> filter(case != "base") |>
  mutate(key = sub(" .*", "", sub("new-therapy ", "", case))) |>
  group_by(key) |> summarise(lo = min(net_impact_5y, base), hi = max(net_impact_5y, base)) |>
  mutate(label = factor(lab[key], lab[key][order(hi - lo)]))
p4 <- ggplot(tor) + geom_segment(aes(x = lo / 1e6, xend = hi / 1e6, y = label, yend = label),
                                 linewidth = 6, colour = okabe[1]) +
  geom_vline(xintercept = base / 1e6, linetype = 2) + geom_vline(xintercept = 0, colour = "grey50") +
  labs(x = "5-year net budget impact, $ million (dashed = base case)", y = NULL)
save(p4, "tornado.png", h = 2.8)
cat("figures written\n")
