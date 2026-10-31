# amendment 3: ASC facility rows
# from the provider-level file
source("R/cms_api.R")

ds <- read.csv("inputs/cms_datasets.csv", colClasses = "character")
codes <- read.csv("inputs/procedure_codes.csv", colClasses = "character")$code
only <- commandArgs(trailingOnly = TRUE)
if (length(only)) codes <- only
keep <- c("Rndrng_NPI", "Rndrng_Prvdr_Ent_Cd", "Rndrng_Prvdr_Type", "Rndrng_Prvdr_State_Abrvtn",
          "HCPCS_Cd", "Place_Of_Srvc", "Tot_Benes", "Tot_Srvcs", "Tot_Bene_Day_Srvcs",
          "Avg_Mdcr_Alowd_Amt", "Avg_Mdcr_Pymt_Amt")

rows <- list()
for (i in which(ds$file == "provider")) {
  for (cd in codes) {
    d <- cms_get(ds$dataset_id[i], list(HCPCS_Cd = cd, Rndrng_Prvdr_Type = "Ambulatory Surgical Center"))
    if (nrow(d)) rows[[length(rows) + 1]] <- cbind(year = as.integer(ds$year[i]), d[, intersect(keep, names(d))])
  }
  cat("provider", ds$year[i], "\n")
}
asc <- do.call(rbind, rows)
f <- "data/raw/cms_api/asc_provider_rows.csv"
if (length(only) && file.exists(f)) {
  old <- read.csv(f, colClasses = "character")
  asc <- rbind(old[!old$HCPCS_Cd %in% only, ], asc[, names(old)])
}
write.csv(asc, f, row.names = FALSE)
cat(nrow(asc), "ASC rows\n")
