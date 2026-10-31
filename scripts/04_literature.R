# Part C: numbers vs PubMed abstracts
# annual rate = cumulative / follow-up
lit <- read.csv("inputs/literature.csv", colClasses = c(pmid = "character"))
dir.create("data/raw/pubmed", recursive = TRUE, showWarnings = FALSE)

abstract <- function(pmid) {
  f <- sprintf("data/raw/pubmed/%s.txt", pmid)
  if (!file.exists(f)) {
    u <- sprintf("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=%s&rettype=abstract&retmode=text", pmid)
    writeLines(readLines(u, warn = FALSE, encoding = "UTF-8"), f, useBytes = TRUE)
    Sys.sleep(0.5)
  }
  gsub("\\s+", " ", paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = " "))
}

lit$text_found <- mapply(function(p, s) grepl(s, abstract(p), fixed = TRUE), lit$pmid, lit$abstract_text)
# quote must hold the number used
lit$number_in_text <- mapply(function(s, x) grepl(sprintf("%g%%", 100 * x), s, fixed = TRUE) ||
                               grepl(sprintf("%g%%", 100 * (1 - x)), s, fixed = TRUE),
                             lit$abstract_text, lit$cum_retreatment)
lit$annual_rate <- lit$cum_retreatment / lit$followup_years
write.csv(lit, "results/literature_checked.csv", row.names = FALSE)
print(lit[, c("family", "role", "pmid", "cum_retreatment", "followup_years", "annual_rate",
              "text_found", "number_in_text")])
stopifnot(all(lit$text_found), all(lit$number_in_text))
