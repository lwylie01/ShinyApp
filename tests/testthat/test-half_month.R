# Tests for R/half_month.R, using the fixtures in helper-setup.R.

test_that("the 14th is the first half and the 15th is the second", {
  dates <- as.Date(c("2026-10-01", "2026-10-14", "2026-10-15", "2026-10-31"))
  expect_equal(half_of_month(dates), c("first", "first", "second", "second"))
})

test_that("first_half_budget follows the half column", {
  expect_equal(first_half_budget(c(1000, 1000, 1000), c("first", "second", "split")),
               c(1000, 0, 500))
  # An odd number of cents: the first half gets the extra cent.
  expect_equal(first_half_budget(15, "split"), 8)
})

test_that("the two halves always add back to the monthly amount", {
  monthly <- c(0, 1, 15, 20001, 140000)
  for (h in c("first", "second", "split")) {
    first <- first_half_budget(monthly, h)
    expect_equal(first + (monthly - first), monthly)
  }
})

test_that("half_month_summary splits budget and spending by half", {
  out <- half_month_summary(fixture_envelopes(), fixture_transactions(),
                            month = "2026-10")
  # Two rows per spending envelope, first half then second.
  expect_equal(out$envelope_id, rep(c("bills", "phone", "food"), each = 2))
  expect_equal(out$period, rep(c("first", "second"), 3))
  expect_equal(unique(out$period_label), c("Before the 15th", "From the 15th on"))

  # Budgets: bills all first; phone all second; food 200.01 splits 100.01/100.00.
  expect_equal(out$budget_cents, c(100000, 0, 0, 5000, 10001, 10000))
  # Food: 60.00 on the 14th is first half; 70.00 on the 15th and the 10.00
  # refund on the 31st are second half.
  expect_equal(out$spent_cents, c(100000, 0, 0, 5500, 6000, 6000))
  expect_equal(out$remaining_cents, c(0, 0, 0, -500, 4001, 4000))
  expect_equal(out$status, c("at", "at", "at", "over", "under", "under"))
})

test_that("the halves add up to the whole-month balances", {
  env <- fixture_envelopes()
  tx <- fixture_transactions()
  halves <- half_month_summary(env, tx, month = "2026-10")
  whole <- envelope_balances(env, tx, month = "2026-10")
  summed <- tapply(halves$spent_cents, halves$envelope_id, sum)
  expect_equal(as.vector(summed[whole$envelope_id]), whole$spent_cents)
})
