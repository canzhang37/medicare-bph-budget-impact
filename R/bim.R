# budget impact model, Medicare FFS
# fam: share, cost, retreat, mist per family
# new therapy takes share pro rata
# (all families, or mist families only)

bim <- function(fam, n, uptake, c_new, r_new, c_ret, growth = 0, displace = "all") {
  s <- fam$share
  d <- if (displace == "mist") s * fam$mist else s
  d <- d / sum(d)
  yrs <- seq_along(uptake)
  n_t <- n * (1 + growth)^(yrs - 1)
  cost_cur <- sum(s * fam$cost)
  cost_new <- cost_cur - uptake * sum(d * fam$cost) + uptake * c_new
  rate_cur <- sum(s * fam$retreat)
  rate_new <- rate_cur - uptake * sum(d * fam$retreat) + uptake * r_new
  # retreats come from earlier cohorts
  prior <- function(rate) c(0, cumsum(n_t * rate)[-length(yrs)])
  cur <- n_t * cost_cur + c_ret * prior(rep(rate_cur, length(yrs)))
  new <- n_t * cost_new + c_ret * prior(rate_new)
  data.frame(year = yrs, procedures = n_t, new_therapy_patients = n_t * uptake,
             index_current = n_t * cost_cur, retreat_current = c_ret * prior(rep(rate_cur, length(yrs))),
             index_new = n_t * cost_new, retreat_new = c_ret * prior(rate_new),
             total_current = cur, total_new = new, net_impact = new - cur)
}

# index cost: 2024 site mix x 2026 payment
# inpatient/other -> inpatient rate, else HOPD
# no rate at a site -> HOPD, office, inpatient
family_cost <- function(counts, pay) {
  j <- merge(counts, pay, by = "family")
  pick <- function(...) { x <- c(...); x[!is.na(x)][1] }
  sapply(seq_len(nrow(j)), function(i) {
    r <- j[i, ]
    fb <- pick(r$hopd_total, r$office_total, r$inpatient_total, r$hopd_fee)
    cst <- c(office = pick(r$office_total, fb), asc = pick(r$asc_total, fb),
             hopd = pick(r$hopd_total, fb), other = pick(r$inpatient_total, fb))
    cnt <- c(r$office, r$asc, r$hopd, r$inpatient_or_other)
    sum(cnt * cst) / sum(cnt)
  }) |> setNames(j$family)
}
