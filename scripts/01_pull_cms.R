# BPH rows, three CMS geography files
source("R/cms_api.R")

ds <- read.csv("inputs/cms_datasets.csv", colClasses = "character")
codes <- read.csv("inputs/procedure_codes.csv", colClasses = "character")$code
drgs <- c("713", "714")
dir.create("data/raw/cms_api", recursive = TRUE, showWarnings = FALSE)
# codes as args -> pull and merge
only <- commandArgs(trailingOnly = TRUE)
if (length(only)) { codes <- only; drgs <- character(0) }

pull <- function(file, key, values) {
  f <- sprintf("data/raw/cms_api/%s.csv", file)
  if (!length(values)) return(read.csv(f, colClasses = "character"))
  rows <- list()
  for (i in which(ds$file == file)) {
    for (v in values) {
      d <- cms_get(ds$dataset_id[i], setNames(list(v), key))
      if (nrow(d)) rows[[length(rows) + 1]] <- cbind(year = as.integer(ds$year[i]), d)
    }
    cat(file, ds$year[i], "\n")
  }
  out <- do.call(rbind, rows)
  if (length(only) && file.exists(f)) {
    old <- read.csv(f, colClasses = "character")
    out <- rbind(old[!old[[key]] %in% values, ], out[, names(old)])
  }
  write.csv(out, f, row.names = FALSE)
  out
}

phy <- pull("physician", "HCPCS_Cd", codes)
opd <- pull("outpatient", "HCPCS_Cd", codes)
inp <- pull("inpatient", "DRG_Cd", drgs)
cat(nrow(phy), nrow(opd), nrow(inp), "rows\n")
