# Tests for R/mod_envelopes.R. shiny::testServer() runs the module's server
# function without a browser. The month now comes from the shared picker,
# so tests pass it in as a reactiveVal they can change.

test_that("changing the month changes the cards", {
  month <- shiny::reactiveVal("2026-10")
  shiny::testServer(
    envelopesServer,
    args = list(envelopes = fixture_envelopes(),
                transactions = shiny::reactiveVal(fixture_transactions()),
                month = month),
    {
      # October: Phone is over budget.
      expect_equal(output$summary, "October 2026: 1 of 3 envelopes over budget.")
      expect_match(output$spending_cards$html, "Over by $5.00", fixed = TRUE)
      expect_match(output$sinking_cards$html, "$175.00 saved", fixed = TRUE)

      # November: nobody is over, and the fund has grown.
      month("2026-11")
      session$flushReact()
      expect_equal(output$summary, "November 2026: 0 of 3 envelopes over budget.")
      expect_false(grepl("Over by", output$spending_cards$html, fixed = TRUE))
      expect_match(output$sinking_cards$html, "$275.00 saved", fixed = TRUE)
    }
  )
})

test_that("the cards redraw when the transactions change", {
  tx <- shiny::reactiveVal(fixture_transactions())
  shiny::testServer(
    envelopesServer,
    args = list(envelopes = fixture_envelopes(), transactions = tx,
                month = shiny::reactiveVal("2026-11")),
    {
      expect_match(output$spending_cards$html, "$197.01 left", fixed = TRUE)

      # Add a 300.00 Food purchase in November: Food goes over budget.
      extra <- fixture_transactions()[8, ]
      extra$transaction_id <- "s001"
      extra$amount_cents <- 30000
      tx(rbind(tx(), extra))
      session$flushReact()
      expect_equal(output$summary, "November 2026: 1 of 3 envelopes over budget.")
      expect_match(output$spending_cards$html, "Over by $102.99", fixed = TRUE)
    }
  )
})
