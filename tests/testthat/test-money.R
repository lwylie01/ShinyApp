# Tests for R/money.R

test_that("to_cents converts dollars to whole cents", {
  expect_equal(to_cents(19.99), 1999)
  expect_equal(to_cents(c(0, 1, 1400)), c(0, 100, 140000))
  expect_equal(to_cents(-18.99), -1899)
  expect_equal(to_cents(NA_real_), NA_real_)
})

test_that("adding in cents avoids floating-point drift", {
  # In dollars, 0.1 + 0.2 is not exactly 0.3. In cents it is exactly 30.
  expect_false(0.1 + 0.2 == 0.3)
  expect_identical(sum(to_cents(c(0.1, 0.2))), 30)
})

test_that("to_cents refuses bad input instead of guessing", {
  expect_error(to_cents("12.50"), "must be numeric")
  expect_error(to_cents(Inf), "infinite")
  expect_error(to_cents(c(1, 19.995)), "two decimal places \\(position 2\\)")
})

test_that("from_cents converts back to dollars", {
  expect_equal(from_cents(1999), 19.99)
  expect_equal(from_cents(-1899), -18.99)
})

test_that("format_money shows sign, dollar sign, commas, two decimals", {
  expect_equal(format_money(140000), "$1,400.00")
  expect_equal(format_money(-1250), "-$12.50")
  expect_equal(format_money(0), "$0.00")
  expect_equal(format_money(c(5, NA)), c("$0.05", NA))
})
