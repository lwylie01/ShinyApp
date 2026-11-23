# testthat runs files named helper-*.R before the tests.
#
# Step 1: load the app's logic from app/R. This project is not an R package
# (decision 10), so the functions are sourced here, the same way Shiny
# sources app/R/ when the app starts. The tests live outside app/ so that the
# Shinylive export, which bundles everything in app/, never includes them.
for (f in list.files(testthat::test_path("..", "..", "app", "R"),
                     pattern = "\\.R$", full.names = TRUE)) {
  source(f, local = FALSE)
}

# Step 2: small, typed fixtures that tests can build on. Amounts are chosen so
# every expected answer can be worked out by hand.

# Three spending envelopes (one per `half` value) and one sinking fund.
fixture_envelopes <- function() {
  data.frame(
    envelope_id   = c("bills", "phone", "food", "trip"),
    name          = c("Bills", "Phone", "Food", "Trip"),
    type          = c("spending", "spending", "spending", "sinking"),
    half          = c("first", "second", "split", "split"),
    card          = c("Card A", "Card A", "Card B", "Card B"),
    color         = c("#0072B2", "#999999", "#009E73", "#F0E442"),
    monthly_cents = c(100000, 5000, 20001, 10000),
    goal_cents    = c(NA, NA, NA, 60000),
    goal_date     = as.Date(c(NA, NA, NA, "2027-01-01")),
    start_month   = c(NA, NA, NA, "2026-09"),
    stringsAsFactors = FALSE
  )
}

# Transactions across two months, including a refund and the 14th/15th edge.
fixture_transactions <- function() {
  data.frame(
    transaction_id = paste0("x", 1:8),
    date = as.Date(c("2026-10-01", "2026-10-14", "2026-10-15", "2026-10-31",
                     "2026-10-20", "2026-10-05", "2026-09-30", "2026-11-02")),
    envelope_id  = c("bills", "food", "food", "food",
                     "phone", "trip", "food", "food"),
    amount_cents = c(100000, 6000, 7000, -1000,
                     5500, 2500, 9999, 300),
    note = "",
    stringsAsFactors = FALSE
  )
}
