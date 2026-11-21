# Tests that the demo CSVs load cleanly and contain the edge cases they were
# written to show. If someone edits the demo data and removes an edge case,
# these tests say so.

demo_envelopes <- function() {
  read_envelopes(testthat::test_path("..", "..", "data", "demo_envelopes.csv"))
}
demo_transactions <- function() {
  read_transactions(testthat::test_path("..", "..", "data",
                                        "demo_transactions.csv"),
                    demo_envelopes())
}

test_that("both demo files pass validation", {
  expect_equal(nrow(demo_envelopes()), 9)
  expect_equal(nrow(demo_transactions()), 51)
})

test_that("the demo opens on November 2026", {
  expect_equal(latest_month(demo_transactions()), "2026-11")
})

test_that("Dining Out is over budget in October", {
  out <- envelope_balances(demo_envelopes(), demo_transactions(), "2026-10")
  dining <- out[out$envelope_id == "dining", ]
  # 36.40 + 52.80 + 27.15 + 44.90 + 38.60 = 199.85 against 150.00.
  expect_equal(dining$spent_cents, 19985)
  expect_equal(dining$remaining_cents, -4985)
  expect_equal(dining$status, "over")
})

test_that("the October grocery refund reduces spending", {
  out <- envelope_balances(demo_envelopes(), demo_transactions(), "2026-10")
  # 134.21 + 119.54 - 18.99 + 127.90 + 121.33 + 58.12 = 542.11.
  expect_equal(out$spent_cents[out$envelope_id == "groceries"], 54211)
})

test_that("Phone is exactly at budget each month", {
  for (m in c("2026-09", "2026-10", "2026-11")) {
    out <- envelope_balances(demo_envelopes(), demo_transactions(), m)
    expect_equal(out$status[out$envelope_id == "phone"], "at")
  }
})

test_that("the demo covers the 14th, the 15th, and the 31st", {
  days <- format(demo_transactions()$date, "%d")
  expect_true(all(c("14", "15", "31") %in% days))
})

test_that("sinking funds as of November 2026", {
  out <- sinking_fund_progress(demo_envelopes(), demo_transactions(), "2026-11")
  trip <- out[out$envelope_id == "trip", ]
  car  <- out[out$envelope_id == "car_repair", ]
  # Beach Trip: June-November = 6 x 200.00 = 1,200.00, less the 350.00 deposit.
  expect_equal(trip$balance_cents, 85000)
  # December-May still to come: 850.00 + 6 x 200.00 = 2,050.00 >= 1,800.00.
  expect_equal(trip$projected_cents, 205000)
  expect_true(trip$on_pace)
  # Car Repairs: April-November = 8 x 75.00 = 600.00, less the 68.50 oil change.
  expect_equal(car$balance_cents, 53150)
  expect_true(is.na(car$on_pace))
})
