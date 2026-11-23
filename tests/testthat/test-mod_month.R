# Tests for R/mod_month.R, driven with shiny::testServer().

test_that("the month view shows totals, the table, and the figure text", {
  month <- shiny::reactiveVal("2026-10")
  shiny::testServer(
    monthServer,
    args = list(envelopes = fixture_envelopes(),
                transactions = shiny::reactiveVal(fixture_transactions()),
                month = month),
    {
      totals <- output$totals$html
      expect_match(totals, "Before the 15th", fixed = TRUE)
      expect_match(totals, "$1,100.01 planned", fixed = TRUE)
      expect_match(totals, "$1,060.00 spent", fixed = TRUE)

      table <- output$half_table$html
      expect_match(table, "Spending by half of the month, October 2026", fixed = TRUE)
      expect_match(table, '<th scope="row">Phone</th>', fixed = TRUE)
      expect_match(table, "Not planned", fixed = TRUE)       # Phone, first half
      expect_match(table, "Over by $5.00", fixed = TRUE)     # Phone, second half

      expect_match(output$trend_text, "By October 31, 2026", fixed = TRUE)
      # The figure renders, with the same sentence as its alt text.
      expect_match(output$trend$alt, "By October 31, 2026", fixed = TRUE)

      # Changing the month updates everything.
      month("2026-11")
      session$flushReact()
      expect_match(output$trend_text, "By November 2, 2026", fixed = TRUE)
    }
  )
})

test_that("an overspent half says so in its summary box", {
  row <- data.frame(period = "first", period_label = "Before the 15th",
                    budget_cents = 1000, spent_cents = 1500,
                    remaining_cents = -500, status = "over")
  html <- as.character(half_tile(row))
  expect_match(html, "Over by $5.00", fixed = TRUE)
})
