# Tests for R/balances.R, using the fixtures in helper-setup.R.

test_that("month_key and is_month_key", {
  expect_equal(month_key(as.Date(c("2026-10-01", "2026-10-31"))),
               c("2026-10", "2026-10"))
  expect_equal(is_month_key(c("2026-10", "2026-13", "2026-1", NA)),
               c(TRUE, FALSE, FALSE, FALSE))
})

test_that("latest_month finds the newest transaction's month", {
  expect_equal(latest_month(fixture_transactions()), "2026-11")
  expect_error(latest_month(fixture_transactions()[0, ]), "no transactions")
})

test_that("budget_status uses words, not just numbers", {
  expect_equal(budget_status(c(1, 0, -1)), c("under", "at", "over"))
})

test_that("envelope_balances works out remaining for one month", {
  out <- envelope_balances(fixture_envelopes(), fixture_transactions(),
                           month = "2026-10")
  # Spending envelopes only, in file order; the sinking fund is left out.
  expect_equal(out$envelope_id, c("bills", "phone", "food"))
  # Bills: 1000.00 - 1000.00 = 0, exactly at budget.
  # Phone: 50.00 - 55.00 = -5.00, over budget, shown as negative.
  # Food: 200.01 - (60 + 70 - 10 refund) = 80.01. September's 99.99 and
  #       November's 3.00 do not count toward October.
  expect_equal(out$spent_cents, c(100000, 5500, 12000))
  expect_equal(out$remaining_cents, c(0, -500, 8001))
  expect_equal(out$status, c("at", "over", "under"))
})

test_that("an envelope with no spending keeps its whole amount", {
  out <- envelope_balances(fixture_envelopes(), fixture_transactions(),
                           month = "2026-11")
  expect_equal(out$spent_cents, c(0, 0, 300))
  expect_equal(out$remaining_cents, c(100000, 5000, 19701))
})

test_that("nothing rolls over from the month before", {
  # September leaves 100.02 unspent in Food. October's remaining is still the
  # full 200.01 less October's spending only, not 200.01 + 100.02.
  sep <- envelope_balances(fixture_envelopes(), fixture_transactions(),
                           month = "2026-09")
  oct <- envelope_balances(fixture_envelopes(), fixture_transactions(),
                           month = "2026-10")
  expect_equal(sep$remaining_cents[sep$envelope_id == "food"], 10002)
  expect_equal(oct$remaining_cents[oct$envelope_id == "food"], 20001 - 12000)
})

test_that("envelope_balances defaults to the latest month", {
  out <- envelope_balances(fixture_envelopes(), fixture_transactions())
  expect_equal(unique(out$month), "2026-11")
})

test_that("envelope_balances refuses a malformed month", {
  expect_error(envelope_balances(fixture_envelopes(), fixture_transactions(),
                                 month = "October"), "YYYY-MM")
})
