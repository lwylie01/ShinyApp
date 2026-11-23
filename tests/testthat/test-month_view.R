# Tests for R/month_view.R, using the fixtures in helper-setup.R.
# Fixture budgets: Bills 1000.00 (first half), Phone 50.00 (second half),
# Food 200.01 (split: 100.01 first, 100.00 second).

test_that("month_end_date and data_as_of", {
  expect_equal(month_end_date("2026-11"), as.Date("2026-11-30"))
  expect_equal(month_end_date("2028-02"), as.Date("2028-02-29"))
  expect_equal(data_as_of(fixture_transactions()), as.Date("2026-11-02"))
})

test_that("half_month_totals adds each half across envelopes", {
  halves <- half_month_summary(fixture_envelopes(), fixture_transactions(), "2026-10")
  totals <- half_month_totals(halves)
  expect_equal(totals$period, c("first", "second"))
  # First half: 1000.00 + 0 + 100.01 planned; 1000.00 + 0 + 60.00 spent.
  expect_equal(totals$budget_cents, c(110001, 15000))
  expect_equal(totals$spent_cents, c(106000, 11500))
  expect_equal(totals$remaining_cents, c(4001, 3500))
  expect_equal(totals$status, c("under", "under"))
})

test_that("cell text reads naturally, and 'Not planned' only when empty", {
  expect_equal(half_cell_text(c(7500, 0, 0), c(3125, 0, 500)),
               c("$31.25 of $75.00", "Not planned", "$5.00 of $0.00"))
  expect_equal(over_text(c(100, 0, -410)), c(NA, NA, "Over by $4.10"))
})

test_that("month_pace runs to the month's end for a past month", {
  pace <- month_pace(fixture_envelopes(), fixture_transactions(), "2026-10")
  expect_equal(nrow(pace), 31)
  expect_equal(pace$date[c(1, 31)], as.Date(c("2026-10-01", "2026-10-31")))
  # Planned: 1100.01 through the 14th, the full 1250.01 from the 15th.
  expect_equal(pace$planned_cents[c(14, 15)], c(110001, 125001))
  # Spending: Bills 1000.00 on the 1st; Food 60.00 on the 14th, 70.00 on the
  # 15th, Phone 55.00 on the 20th, and a 10.00 refund on the 31st. The trip
  # withdrawal (a sinking fund) is left out.
  expect_equal(pace$spent_cents[c(1, 13, 14, 15, 20, 30, 31)],
               c(100000, 100000, 106000, 113000, 118500, 118500, 117500))
})

test_that("a refund makes the line dip", {
  pace <- month_pace(fixture_envelopes(), fixture_transactions(), "2026-10")
  expect_lt(pace$spent_cents[31], pace$spent_cents[30])
})

test_that("month_pace stops at the latest date in the data", {
  pace <- month_pace(fixture_envelopes(), fixture_transactions(), "2026-11")
  expect_equal(max(pace$date), as.Date("2026-11-02"))
  expect_equal(nrow(pace), 2)
})

test_that("pace_summary_text describes the figure in words", {
  pace <- month_pace(fixture_envelopes(), fixture_transactions(), "2026-10")
  expect_equal(
    pace_summary_text(pace),
    paste("By October 31, 2026, $1,175.00 had been spent of $1,250.01",
          "planned so far. Spending stayed within the plan every day.")
  )

  # Push spending ahead of plan from the 3rd onward: 1,200.00 spent by the
  # 3rd against 1,100.01 planned, and it stays ahead through the 31st.
  tx <- fixture_transactions()
  tx$amount_cents[tx$transaction_id == "x2"] <- 20000
  tx$date[tx$transaction_id == "x2"] <- as.Date("2026-10-03")
  pace <- month_pace(fixture_envelopes(), tx, "2026-10")
  expect_match(pace_summary_text(pace),
               "ahead of the plan on 29 of 31 days, starting October 3, 2026.",
               fixed = TRUE)
})
