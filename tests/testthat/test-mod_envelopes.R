# Tests for R/mod_envelopes.R. shiny::testServer() runs the module's server
# function without a browser, so a test can set the month and read outputs.

test_that("changing the month changes the cards", {
  shiny::testServer(
    envelopesServer,
    args = list(envelopes = fixture_envelopes(),
                transactions = fixture_transactions()),
    {
      # October: Phone is over budget.
      session$setInputs(month = "2026-10")
      expect_equal(output$summary, "October 2026: 1 of 3 envelopes over budget.")
      expect_match(output$spending_cards$html, "Over by $5.00", fixed = TRUE)
      expect_match(output$sinking_cards$html, "$175.00 saved", fixed = TRUE)

      # November: nobody is over, and the fund has grown.
      session$setInputs(month = "2026-11")
      expect_equal(output$summary, "November 2026: 0 of 3 envelopes over budget.")
      expect_false(grepl("Over by", output$spending_cards$html, fixed = TRUE))
      expect_match(output$sinking_cards$html, "$275.00 saved", fixed = TRUE)
    }
  )
})

test_that("the UI offers the months it is given and opens on the latest", {
  html <- as.character(envelopesUI("envelopes",
                                   months = c("2026-09", "2026-10"),
                                   selected = "2026-10"))
  expect_match(html, "September 2026", fixed = TRUE)
  expect_match(html, '<option value="2026-10" selected>', fixed = TRUE)
})
