# balances.R
# How much is left in each spending envelope for one month.
#
# Remaining = the envelope's monthly amount - that month's transactions.
# Nothing rolls over from the month before (decision 4). Remaining may go
# negative, and a text status says "under", "at", or "over" so the app never
# relies on color alone (decision 6).
#
# Months are written as "YYYY-MM" text, for example "2026-10". Text in that
# shape sorts in calendar order, so "2026-09" < "2026-10" works as expected.


# month_key() ------------------------------------------------------------------
# The "YYYY-MM" month a date falls in: month_key(as.Date("2026-10-31")) is
# "2026-10".
month_key <- function(date) {
  format(date, "%Y-%m")
}


# is_month_key() ---------------------------------------------------------------
# TRUE where a value is a valid "YYYY-MM" month (month 01 to 12). NA is FALSE.
is_month_key <- function(x) {
  !is.na(x) & grepl("^\\d{4}-(0[1-9]|1[0-2])$", x)
}


# check_month() ----------------------------------------------------------------
# Stop unless `month` is a single valid "YYYY-MM" value.
check_month <- function(month) {
  if (length(month) != 1 || !is_month_key(month)) {
    stop("`month` must be one month written YYYY-MM, such as \"2026-10\".",
         call. = FALSE)
  }
  invisible(month)
}


# latest_month() ---------------------------------------------------------------
# The most recent month that has any transaction. The app opens on this month
# rather than today's date, so the demo never goes stale (decision 8).
latest_month <- function(transactions) {
  if (nrow(transactions) == 0) {
    stop("There are no transactions, so there is no latest month.",
         call. = FALSE)
  }
  month_key(max(transactions$date))
}


# budget_status() --------------------------------------------------------------
# Plain-language status for remaining cents: above zero is "under" budget,
# exactly zero is "at" budget, below zero is "over" budget.
budget_status <- function(remaining_cents) {
  dplyr::case_when(
    remaining_cents > 0  ~ "under",
    remaining_cents == 0 ~ "at",
    remaining_cents < 0  ~ "over"
  )
}


# envelope_balances() ----------------------------------------------------------
# One row per spending envelope for `month`, in the same order as the envelope
# file, with columns: month, envelope_id, name, card, color, monthly_cents,
# spent_cents, remaining_cents, status.
#
# Sinking funds are left out here; sinking_fund_progress() reports them.
envelope_balances <- function(envelopes, transactions,
                              month = latest_month(transactions)) {
  # Step 1: make sure the month is well formed.
  check_month(month)

  # Step 2: keep only spending envelopes.
  spending <- envelopes |>
    dplyr::filter(type == "spending")

  # Step 3: total each envelope's transactions in this month. Refunds are
  # negative, so they reduce the total automatically.
  spent <- transactions |>
    dplyr::filter(month_key(date) == month) |>
    dplyr::group_by(envelope_id) |>
    dplyr::summarise(spent_cents = sum(amount_cents), .groups = "drop")

  # Step 4: attach the totals to the envelopes. An envelope with no spending
  # this month gets NA from the join, which becomes 0.
  # Step 5: remaining and status.
  spending |>
    dplyr::left_join(spent, by = "envelope_id") |>
    dplyr::mutate(
      month           = month,
      spent_cents     = dplyr::coalesce(spent_cents, 0),
      remaining_cents = monthly_cents - spent_cents,
      status          = budget_status(remaining_cents)
    ) |>
    dplyr::select(month, envelope_id, name, card, color, monthly_cents,
                  spent_cents, remaining_cents, status)
}
