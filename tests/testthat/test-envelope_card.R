# Tests for R/envelope_card.R: what each card says.

# Render a card to plain HTML text so tests can search it.
as_html <- function(tag) as.character(tag)

# One row shaped like envelope_balances() output.
balance_row <- function(spent, monthly = 15000, status = NULL) {
  remaining <- monthly - spent
  data.frame(month = "2026-10", envelope_id = "dining", name = "Dining Out",
             card = "Everyday Card", color = "#D55E00",
             monthly_cents = monthly, spent_cents = spent,
             remaining_cents = remaining,
             status = budget_status(remaining), stringsAsFactors = FALSE)
}

test_that("text helpers", {
  expect_equal(month_label(c("2026-09", "2026-10")),
               c("September 2026", "October 2026"))
  expect_equal(format_long_date(as.Date("2027-06-01")), "June 1, 2027")
  expect_equal(remaining_headline(c(8001, 0, -4985)),
               c("$80.01 left", "$0.00 left", "Over by $49.85"))
})

test_that("bar_share stays between 0 and 1", {
  expect_equal(bar_share(c(7500, 19985, -500, 0), 15000), c(0.5, 1, 0, 0))
  expect_equal(bar_share(c(0, 100), 0), c(0, 1))   # zero budget
})

test_that("an over-budget card says so in words, badge, and pattern", {
  html <- as_html(envelope_card(balance_row(19985)))
  expect_match(html, "Over by $49.85", fixed = TRUE)
  expect_match(html, "Over budget", fixed = TRUE)
  expect_match(html, "env-bar-over", fixed = TRUE)
  expect_match(html, "Spent $199.85 of $150.00", fixed = TRUE)
  expect_match(html, "width: 100.0%", fixed = TRUE)
})

test_that("an at-budget card gets the neutral badge", {
  html <- as_html(envelope_card(balance_row(15000)))
  expect_match(html, "$0.00 left", fixed = TRUE)
  expect_match(html, "At budget", fixed = TRUE)
  expect_false(grepl("env-bar-over", html, fixed = TRUE))
})

test_that("an under-budget card has no badge", {
  html <- as_html(envelope_card(balance_row(7500)))
  expect_match(html, "$75.00 left", fixed = TRUE)
  expect_false(grepl("env-badge", html, fixed = TRUE))
  expect_match(html, "width: 50.0%", fixed = TRUE)
})

test_that("every card prints its name, payment card, and color stripe", {
  html <- as_html(envelope_card(balance_row(7500)))
  expect_match(html, "Dining Out", fixed = TRUE)
  expect_match(html, "Everyday Card", fixed = TRUE)
  expect_match(html, "--env-color: #D55E00;", fixed = TRUE)
  expect_match(html, 'aria-hidden="true"', fixed = TRUE)   # the bar
})

test_that("budget_summary_text counts envelopes over budget", {
  balances <- rbind(balance_row(19985), balance_row(7500))
  expect_equal(budget_summary_text(balances),
               "October 2026: 1 of 2 envelopes over budget.")
})

test_that("sinking cards show saved, goal, date, and pace", {
  funds <- sinking_fund_progress(fixture_envelopes(), fixture_transactions(),
                                 "2026-10")
  html <- as_html(sinking_card(funds[1, ]))
  expect_match(html, "$175.00 saved", fixed = TRUE)
  expect_match(html, "29% of a $600.00 goal", fixed = TRUE)
  expect_match(html, "Goal date January 1, 2027", fixed = TRUE)
  expect_match(html, "Behind pace", fixed = TRUE)

  funds$goal_date <- as.Date(NA)
  funds$on_pace <- NA
  html <- as_html(sinking_card(funds[1, ]))
  expect_match(html, "No goal date", fixed = TRUE)
  expect_false(grepl("env-badge", html, fixed = TRUE))
})
