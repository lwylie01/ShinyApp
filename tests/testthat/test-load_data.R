# Tests for R/load_data.R
# Each test starts from a valid table of text, breaks one thing, and checks
# that the error names the problem and the row.

valid_envelope_text <- function() {
  data.frame(
    envelope_id    = c("rent", "trip"),
    name           = c("Rent", "Trip"),
    type           = c("spending", "sinking"),
    monthly_amount = c("1400.00", "200"),
    half           = c("first", "split"),
    card           = c("Bills Card", "Debit"),
    color          = c("#0072B2", "#F0E442"),
    goal_amount    = c(NA, "1800.00"),
    goal_date      = c(NA, "2027-06-01"),
    start_month    = c(NA, "2026-06"),
    stringsAsFactors = FALSE
  )
}

valid_transaction_text <- function() {
  data.frame(
    transaction_id = c("t1", "t2"),
    date           = c("2026-10-01", "2026-10-12"),
    envelope_id    = c("rent", "trip"),
    amount         = c("1400.00", "-18.99"),
    note           = c("October rent", NA),
    stringsAsFactors = FALSE
  )
}

test_that("clean_envelopes returns typed columns in cents", {
  env <- clean_envelopes(valid_envelope_text())
  expect_equal(env$monthly_cents, c(140000, 20000))
  expect_equal(env$goal_cents, c(NA, 180000))
  expect_s3_class(env$goal_date, "Date")
  expect_equal(env$start_month, c(NA, "2026-06"))
})

test_that("clean_envelopes trims stray spaces", {
  raw <- valid_envelope_text()
  raw$type[1] <- " spending "
  expect_equal(clean_envelopes(raw)$type[1], "spending")
})

test_that("clean_envelopes catches each kind of bad value", {
  break_one <- function(column, value, row = 1) {
    raw <- valid_envelope_text()
    raw[[column]][row] <- value
    raw
  }
  expect_error(clean_envelopes(valid_envelope_text()[, -1]),
               "missing column\\(s\\): envelope_id")
  expect_error(clean_envelopes(break_one("envelope_id", "trip")),
               "repeated \\(data row 2\\)")
  expect_error(clean_envelopes(break_one("envelope_id", "Rent Money")),
               "lowercase")
  expect_error(clean_envelopes(break_one("name", "")), "`name` is blank")
  expect_error(clean_envelopes(break_one("type", "savings")),
               "`type` must be one of")
  expect_error(clean_envelopes(break_one("half", "both")),
               "`half` must be one of")
  expect_error(clean_envelopes(break_one("color", "blue")), "hex code")
  expect_error(clean_envelopes(break_one("monthly_amount", "lots")),
               "must be a number \\(data row 1\\)")
  expect_error(clean_envelopes(break_one("monthly_amount", "10.005")),
               "two decimal places")
  expect_error(clean_envelopes(break_one("monthly_amount", "-5")),
               "zero or more")
})

test_that("clean_envelopes enforces the goal fields by type", {
  raw <- valid_envelope_text()
  raw$goal_amount[2] <- NA
  expect_error(clean_envelopes(raw), "needs a `goal_amount`")

  raw <- valid_envelope_text()
  raw$start_month[2] <- "2026-13"
  expect_error(clean_envelopes(raw), "needs a `start_month`")

  raw <- valid_envelope_text()
  raw$goal_date[2] <- NA          # a goal date is optional
  expect_true(is.na(clean_envelopes(raw)$goal_date[2]))

  raw <- valid_envelope_text()
  raw$goal_amount[1] <- "500"     # a spending envelope with a goal
  expect_error(clean_envelopes(raw), "spending envelope must leave")
})

test_that("clean_transactions returns typed columns in cents", {
  env <- clean_envelopes(valid_envelope_text())
  tx <- clean_transactions(valid_transaction_text(), env)
  expect_equal(tx$amount_cents, c(140000, -1899))
  expect_s3_class(tx$date, "Date")
  expect_equal(tx$note, c("October rent", ""))
})

test_that("clean_transactions catches each kind of bad value", {
  env <- clean_envelopes(valid_envelope_text())
  break_one <- function(column, value, row = 2) {
    raw <- valid_transaction_text()
    raw[[column]][row] <- value
    raw
  }
  expect_error(clean_transactions(break_one("transaction_id", "t1"), env),
               "repeated \\(data row 2\\)")
  expect_error(clean_transactions(break_one("date", "10/12/2026"), env),
               "YYYY-MM-DD")
  expect_error(clean_transactions(break_one("date", "2026-02-30"), env),
               "not a real calendar date")
  expect_error(clean_transactions(break_one("date", NA), env),
               "`date` is blank")
  expect_error(clean_transactions(break_one("envelope_id", "groceries"), env),
               "does not match any envelope")
  expect_error(clean_transactions(break_one("amount", "0.00"), env),
               "must not be zero")
  expect_error(clean_transactions(break_one("amount", NA), env),
               "`amount` is blank")
})
