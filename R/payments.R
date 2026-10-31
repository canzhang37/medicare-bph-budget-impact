# CMS fee schedule readers

# PPRRVU: columns found by header text
# national = total RVU x CF (GPCI 1)
read_rvu <- function(path, codes) {
  lines <- readLines(path, warn = FALSE)
  h <- grep("^HCPCS,", lines)
  head <- strsplit(lines[h], ",")[[1]]
  d <- read.csv(path, skip = h, header = FALSE, colClasses = "character")
  pos <- function(token, k = 1) which(trimws(head) == token)[k]
  out <- data.frame(code = d[[1]], mod = d[[2]], status = d[[4]],
                    office_na = trimws(d[[pos("INDICATOR", 1)]]),
                    office_rvu = suppressWarnings(as.numeric(d[[pos("TOTAL", 1)]])),
                    facility_rvu = suppressWarnings(as.numeric(d[[pos("TOTAL", 2)]])),
                    global = d[[pos("DAYS")]],
                    cf = suppressWarnings(as.numeric(d[[pos("FACTOR")]])))
  out <- out[out$code %in% codes & out$mod == "", ]
  out$facility <- out$facility_rvu * out$cf
  out$office <- ifelse(out$office_na == "NA", NA, out$office_rvu * out$cf)
  out
}

# IPPS Table 5: DRG rows matched directly
# weight x (operating + capital), FY2027 CN
read_drg <- function(path, drgs, operating = 4245.76 + 2602.24, capital = 539.95) {
  x <- readLines(path, warn = FALSE, encoding = "latin1")
  x <- iconv(x, "latin1", "UTF-8")
  rows <- strsplit(x[grepl(sprintf("^(%s)\t", paste(drgs, collapse = "|")), x)], "\t")
  data.frame(drg = sapply(rows, `[`, 1), title = sapply(rows, `[`, 6),
             weight = as.numeric(sapply(rows, `[`, 8))) |>
    transform(ipps_base = weight * (operating + capital))
}
