library(testthat)
source("../R/bim.R")
source("../R/payments.R")

fam <- data.frame(family = c("a", "b"), share = c(0.5, 0.5), cost = c(100, 200),
                  retreat = c(0.1, 0), mist = c(1, 0))

test_that("budget impact matches a hand calculation", {
  b <- bim(fam, n = 10, uptake = c(0.5, 0.5), c_new = 50, r_new = 0, c_ret = 1000)
  expect_equal(b$total_current, c(1500, 2000))
  expect_equal(b$total_new, c(1000, 1250))
  expect_equal(b$net_impact, c(-500, -750))
})

test_that("no uptake means no budget impact", {
  b <- bim(fam, n = 10, uptake = c(0, 0, 0), c_new = 1e6, r_new = 1, c_ret = 1000)
  expect_equal(b$net_impact, c(0, 0, 0))
})

test_that("displacing minimally invasive families takes share only from them", {
  b <- bim(fam, n = 10, uptake = 0.5, c_new = 50, r_new = 0, c_ret = 0, displace = "mist")
  expect_equal(b$total_new, 10 * (150 - 0.5 * 100 + 0.5 * 50))
})

test_that("growth compounds from year 1", {
  b <- bim(fam, n = 100, uptake = c(0, 0, 0), c_new = 0, r_new = 0, c_ret = 0, growth = 0.1)
  expect_equal(b$procedures, c(100, 110, 121))
})

test_that("family cost weights sites and falls back to HOPD", {
  counts <- data.frame(family = "a", office = 1, asc = 1, hopd = 2, inpatient_or_other = 0)
  pay <- data.frame(family = "a", office_total = 100, asc_total = NA, hopd_total = 400,
                    inpatient_total = NA, hopd_fee = 300)
  expect_equal(unname(family_cost(counts, pay)), (100 + 400 + 2 * 400) / 4)
})

test_that("RVU reader finds columns by header text", {
  f <- tempfile(fileext = ".csv")
  writeLines(c("title,,,", ",,,STATUS,,WORK,NON-FAC,NA,FACILITY,NA,MP,NON-FACILITY,FACILITY,PCTC,GLOB,CONV",
               "HCPCS,MOD,DESCRIPTION,CODE,PAYMENT,RVU,PE RVU,INDICATOR,PE RVU,INDICATOR,RVU,TOTAL,TOTAL,IND,DAYS,FACTOR",
               "11111,,toy,A,,1,2,,1,,0.1,3.1,2.1,0,090,10",
               "22222,,toy,A,,1,2,NA,1,,0.1,3.1,2.1,0,090,10"), f)
  r <- read_rvu(f, c("11111", "22222"))
  expect_equal(r$facility, c(21, 21))
  expect_equal(r$office, c(31, NA))
})
