# data.cms.gov API client
# pages of <= 5000 rows

cms_get <- function(dataset_id, filters, size = 5000, pause = 0.3) {
  base <- sprintf("https://data.cms.gov/data-api/v1/dataset/%s/data", dataset_id)
  q <- c(setNames(as.list(filters), sprintf("filter[%s]", names(filters))),
         list(size = size, offset = 0))
  out <- list()
  repeat {
    r <- httr::GET(base, query = q, httr::timeout(60))
    httr::stop_for_status(r)
    page <- jsonlite::fromJSON(httr::content(r, "text", encoding = "UTF-8"))
    Sys.sleep(pause)
    if (length(page) == 0) break
    out[[length(out) + 1]] <- page
    if (nrow(page) < size) break
    q$offset <- q$offset + size
  }
  if (length(out) == 0) return(data.frame())
  do.call(rbind, out)
}

# numbers arrive as strings
as_num_cols <- function(d, cols) {
  for (c in intersect(cols, names(d))) d[[c]] <- as.numeric(d[[c]])
  d
}
