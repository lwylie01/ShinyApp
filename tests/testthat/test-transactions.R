# Tests for R/transactions.R, using the fixtures in helper-setup.R.
# The fixture data covers September to November 2026.

range_fixture <- function() month_bounds(c("2026-09", "2026-10", "2026-11"))

# Add one entry with sensible defaults; override any argument by name.
add_one <- function(transactions = fixture_transactions(), envelope_id = "food",
                    amount_text = "12.50", kind = "spending",
                    date = as.Date("2026-11-10"), note = "Lunch", ...) {
  add_transaction(transactions, fixture_envelopes(), envelope_id, amount_text,
                  kind, date, note, range_fixture(), ...)
}

test_that("month_bounds runs from the first to the last day", {
  r <- range_fixture()
  expect_equal(r$min, as.Date("2026-09-01"))
  expect_equal(r$max, as.Date("2026-11-30"))
  # February in a leap year ends on the 29th.
  expect_equal(month_bounds("2028-02")$max, as.Date("2028-02-29"))
})

test_that("parse_amount_input accepts common ways of typing money", {
  expect_equal(parse_amount_input("12.5"), 1250)
  expect_equal(parse_amount_input("12.50"), 1250)
  expect_equal(parse_amount_input("$12.50"), 1250)
  expect_equal(parse_amount_input(" 1,250.00 "), 125000)
  expect_equal(parse_amount_input("7"), 700)
})

test_that("parse_amount_input refuses bad amounts with a plain message", {
  expect_error(parse_amount_input(""), "Enter an amount")
  expect_error(parse_amount_input(NULL), "Enter an amount")
  expect_error(parse_amount_input("ten"), "as a number")
  expect_error(parse_amount_input("-5"), "choose Refund")
  expect_error(parse_amount_input("0.00"), "more than \\$0.00")
  expect_error(parse_amount_input("1.005"), "two decimal places")
})

test_that("add_transaction appends a typed row with a session id", {
  out <- add_one()
  expect_equal(nrow(out), nrow(fixture_transactions()) + 1)
  new <- out[nrow(out), ]
  expect_equal(new$transaction_id, "s001")
  expect_equal(new$amount_cents, 1250)
  expect_equal(new$date, as.Date("2026-11-10"))
  expect_equal(new$note, "Lunch")
})

test_that("a refund is stored as a negative amount", {
  out <- add_one(amount_text = "18.99", kind = "refund")
  expect_equal(out$amount_cents[nrow(out)], -1899)
})

test_that("add_transaction refuses bad input", {
  expect_error(add_one(envelope_id = "nope"), "Choose an envelope")
  expect_error(add_one(amount_text = "-3"), "minus sign")
  expect_error(add_one(date = as.Date("2026-12-01")),
               "Choose a date from September 1, 2026 to November 30, 2026")
  expect_error(add_one(date = as.Date(NA)), "Choose a date")
  expect_error(add_one(note = strrep("a", 101)), "100 characters")
  expect_silent(add_one(note = strrep("a", 100)))
})

test_that("session ids count up and are never reused", {
  tx <- add_one()                          # s001
  tx <- add_one(transactions = tx)         # s002
  expect_equal(session_entries(tx)$transaction_id, c("s001", "s002"))
  tx <- remove_transaction(tx, "s002")
  # Without memory, s002 would be reused; used_max prevents that.
  tx <- add_one(transactions = tx, used_max = 2)
  expect_equal(tx$transaction_id[nrow(tx)], "s003")
})

test_that("only entries from this visit can be removed", {
  tx <- add_one()
  expect_equal(nrow(remove_transaction(tx, "s001")), nrow(fixture_transactions()))
  expect_error(remove_transaction(tx, "x1"), "during this visit")
})

test_that("confirmation_text reports what is left after the entry", {
  env <- fixture_envelopes()

  # Food in November: 200.01 - 3.00 - 12.50 = 184.51 left.
  tx <- add_one()
  expect_equal(confirmation_text(tx[nrow(tx), ], env, tx),
               "Added $12.50 to Food. $184.51 left in November 2026.")

  # Overspending is stated outright.
  tx <- add_one(amount_text = "250")
  expect_equal(confirmation_text(tx[nrow(tx), ], env, tx),
               "Added $250.00 to Food. Over by $52.99 in November 2026.")

  # A refund: 200.01 - 3.00 + 3.00 = 200.01 left.
  tx <- add_one(amount_text = "3", kind = "refund")
  expect_equal(confirmation_text(tx[nrow(tx), ], env, tx),
               "Refunded $3.00 to Food. $200.01 left in November 2026.")

  # A sinking fund withdrawal: 3 x 100.00 - 25.00 - 40.00 = 235.00 saved.
  tx <- add_one(envelope_id = "trip", amount_text = "40")
  expect_equal(confirmation_text(tx[nrow(tx), ], env, tx),
               "Withdrew $40.00 from Trip. $235.00 saved as of November 2026.")
})

test_that("form_message drops the CSV row reference", {
  e <- simpleError("`amount` must not be zero (data row 1).")
  expect_equal(form_message(e), "`amount` must not be zero.")
  expect_equal(form_message(simpleError("Choose an envelope.")),
               "Choose an envelope.")
})
