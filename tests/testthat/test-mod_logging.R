# Tests for R/mod_logging.R, driven with shiny::testServer().

logging_args <- function() {
  list(envelopes = fixture_envelopes(),
       transactions = shiny::reactiveVal(fixture_transactions()),
       demo_transactions = fixture_transactions(),
       date_range = month_bounds(c("2026-09", "2026-10", "2026-11")))
}

test_that("saving adds the entry, confirms it, clears, and asks to jump", {
  shiny::testServer(loggingServer, args = logging_args(), {
    session$setInputs(envelope = "food", amount = "$12.50", kind = "spending",
                      date = as.Date("2026-10-20"), note = "Lunch", save = 1)

    # The shared table gained the entry.
    expect_equal(nrow(transactions()), nrow(fixture_transactions()) + 1)
    # Food in October: 200.01 - 120.00 - 12.50 = 67.51 left.
    expect_match(output$message$html,
                 "Added $12.50 to Food. $67.51 left in October 2026.",
                 fixed = TRUE)
    # The module asks the envelope view to show October.
    expect_equal(session$returned()$month, "2026-10")
    # The entry is listed for this visit, with a Remove button.
    expect_match(output$session_list$html, "Lunch", fixed = TRUE)
    expect_match(output$session_list$html, "Remove", fixed = TRUE)
  })
})

test_that("a bad entry is not saved and says why in words", {
  shiny::testServer(loggingServer, args = logging_args(), {
    session$setInputs(envelope = "food", amount = "-5", kind = "spending",
                      date = as.Date("2026-10-20"), note = "", save = 1)
    expect_equal(nrow(transactions()), nrow(fixture_transactions()))
    expect_match(output$message$html, "Not saved:", fixed = TRUE)
    expect_match(output$message$html, "choose Refund", fixed = TRUE)
    expect_match(output$session_list$html, "Nothing logged yet", fixed = TRUE)
  })
})

test_that("a note is shown as plain text, never as HTML", {
  shiny::testServer(loggingServer, args = logging_args(), {
    session$setInputs(envelope = "food", amount = "1", kind = "spending",
                      date = as.Date("2026-10-20"),
                      note = "<b>bold</b>", save = 1)
    expect_match(output$session_list$html, "&lt;b&gt;bold&lt;/b&gt;", fixed = TRUE)
  })
})

test_that("Remove and Reset undo entries from this visit", {
  shiny::testServer(loggingServer, args = logging_args(), {
    session$setInputs(envelope = "food", amount = "5", kind = "spending",
                      date = as.Date("2026-11-02"), note = "", save = 1)
    session$setInputs(amount = "6", save = 2)
    expect_equal(session_entries(transactions())$transaction_id, c("s001", "s002"))

    session$setInputs(remove = "s001")
    expect_equal(session_entries(transactions())$transaction_id, "s002")

    # A new save after a removal does not reuse an id.
    session$setInputs(amount = "7", save = 3)
    expect_equal(session_entries(transactions())$transaction_id, c("s002", "s003"))

    session$setInputs(reset = 1)
    expect_equal(transactions(), fixture_transactions())
    expect_match(output$message$html, "Reset to the demo data", fixed = TRUE)
  })
})

test_that("the form offers grouped envelopes and the allowed dates", {
  html <- as.character(loggingUI(
    "logging", fixture_envelopes(), default_date = as.Date("2026-11-20"),
    date_range = month_bounds(c("2026-09", "2026-11"))
  ))
  expect_match(html, '<optgroup label="Sinking funds">', fixed = TRUE)
  expect_match(html, 'inputmode="decimal"', fixed = TRUE)
  expect_match(html, 'maxlength="100"', fixed = TRUE)
  expect_match(html, 'data-min-date="2026-09-01"', fixed = TRUE)
  expect_match(html, 'data-max-date="2026-11-30"', fixed = TRUE)
  expect_match(html, "Entries stay only until you close or reload this page.",
               fixed = TRUE)
})
