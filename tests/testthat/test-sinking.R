# Tests for R/sinking.R, using the fixtures in helper-setup.R.
# The fixture fund "trip" saves 100.00 a month from 2026-09 toward 600.00 by
# 2027-01-01, with one 25.00 withdrawal on 2026-10-05.

test_that("months_contributed counts both ends and never goes negative", {
  expect_equal(months_contributed("2026-06", "2026-11"), 6)
  expect_equal(months_contributed("2026-11", "2026-11"), 1)
  expect_equal(months_contributed("2026-12", "2027-01"), 2)   # across a year
  expect_equal(months_contributed("2027-01", "2026-11"), 0)   # not started
})

test_that("months_still_to_come stops the month before the goal date", {
  # Goal 2027-06-01, as of 2026-11: December through May is 6 months.
  expect_equal(months_still_to_come("2026-06", "2026-11", as.Date("2027-06-01")), 6)
  # Past the goal month: none left.
  expect_equal(months_still_to_come("2026-06", "2027-08", as.Date("2027-06-01")), 0)
  # Not started yet: count from the start month (Feb through May is 4).
  expect_equal(months_still_to_come("2027-02", "2026-11", as.Date("2027-06-01")), 4)
  # No goal date.
  expect_true(is.na(months_still_to_come("2026-06", "2026-11", as.Date(NA))))
})

test_that("sinking_fund_progress works out balance and progress", {
  out <- sinking_fund_progress(fixture_envelopes(), fixture_transactions(),
                               as_of_month = "2026-10")
  expect_equal(out$envelope_id, "trip")        # sinking funds only
  # September and October: 2 x 100.00 = 200.00, less 25.00 = 175.00.
  expect_equal(out$contributed_cents, 20000)
  expect_equal(out$withdrawn_cents, 2500)
  expect_equal(out$balance_cents, 17500)
  expect_equal(out$progress, 17500 / 60000)
  expect_equal(out$to_goal_cents, 42500)
  # November and December still to come: 175.00 + 200.00 = 375.00 < 600.00.
  expect_equal(out$projected_cents, 37500)
  expect_false(out$on_pace)
})

test_that("withdrawals after the as-of month are ignored", {
  out <- sinking_fund_progress(fixture_envelopes(), fixture_transactions(),
                               as_of_month = "2026-09")
  expect_equal(out$withdrawn_cents, 0)
  expect_equal(out$balance_cents, 10000)
})

test_that("a fund can be on pace, and a fund without a goal date has no pace", {
  env <- fixture_envelopes()
  env$monthly_cents[env$envelope_id == "trip"] <- 20000
  out <- sinking_fund_progress(env, fixture_transactions(), as_of_month = "2026-10")
  # 2 x 200 - 25 = 375; plus 2 x 200 still to come = 775 >= 600.
  expect_true(out$on_pace)

  env$goal_date <- as.Date(NA)
  out <- sinking_fund_progress(env, fixture_transactions(), as_of_month = "2026-10")
  expect_true(is.na(out$on_pace))
  expect_true(is.na(out$projected_cents))
})

test_that("to_goal never goes below zero once the goal is passed", {
  env <- fixture_envelopes()
  env$goal_cents[env$envelope_id == "trip"] <- 10000
  out <- sinking_fund_progress(env, fixture_transactions(), as_of_month = "2026-10")
  expect_equal(out$to_goal_cents, 0)
  expect_gt(out$progress, 1)
})
