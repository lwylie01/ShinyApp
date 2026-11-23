# half_month.R
# Splitting a month into "before the 15th" and "from the 15th on".
#
# Days 1 to 14 are the first half; the 15th through the end of the month is
# the second half (decision 2). Each envelope's `half` column says where its
# money is planned (decision 3):
#   first  - the whole monthly amount in the first half (Rent)
#   second - the whole monthly amount in the second half (Phone)
#   split  - half in each


# Display labels for the two halves, used by the summary and later by the app.
HALF_LABELS <- c(first = "Before the 15th", second = "From the 15th on")


# half_of_month() --------------------------------------------------------------
# "first" for days 1 to 14 and "second" for the 15th onward.
half_of_month <- function(date) {
  day <- as.integer(format(date, "%d"))
  ifelse(day < 15, "first", "second")
}


# first_half_budget() ----------------------------------------------------------
# How much of each monthly amount is planned for the first half, in cents.
# The second half is always monthly_cents minus this, so the two halves add
# back to the monthly amount exactly. For an odd number of cents in a `split`
# envelope, the first half gets the extra cent.
first_half_budget <- function(monthly_cents, half) {
  # Repeat a single `half` value to match the amounts, so one call can ask
  # "what if all of these were split?" without a warning from case_when().
  half <- rep_len(half, length(monthly_cents))
  dplyr::case_when(
    half == "first"  ~ monthly_cents,
    half == "second" ~ 0,
    half == "split"  ~ ceiling(monthly_cents / 2)
  )
}


# half_month_summary() ---------------------------------------------------------
# Two rows per spending envelope for `month` (first half, then second half),
# with columns: month, envelope_id, name, period ("first" or "second"),
# period_label, budget_cents, spent_cents, remaining_cents, status.
#
# Each half is judged on its own: overspending in the first half is not taken
# out of the second half's budget here.
half_month_summary <- function(envelopes, transactions,
                               month = latest_month(transactions)) {
  # Step 1: make sure the month is well formed.
  check_month(month)

  # Step 2: keep spending envelopes and work out each half's budget.
  spending <- envelopes |>
    dplyr::filter(type == "spending") |>
    dplyr::mutate(
      first  = first_half_budget(monthly_cents, half),
      second = monthly_cents - first
    )

  # Step 3: reshape to one row per envelope per half (base R, no tidyr needed).
  plan <- data.frame(
    envelope_id  = rep(spending$envelope_id, each = 2),
    name         = rep(spending$name, each = 2),
    period       = rep(c("first", "second"), times = nrow(spending)),
    budget_cents = as.vector(rbind(spending$first, spending$second)),
    stringsAsFactors = FALSE
  )

  # Step 4: total this month's transactions by envelope and half.
  spent <- transactions |>
    dplyr::filter(month_key(date) == month) |>
    dplyr::mutate(period = half_of_month(date)) |>
    dplyr::group_by(envelope_id, period) |>
    dplyr::summarise(spent_cents = sum(amount_cents), .groups = "drop")

  # Step 5: join, fill halves with no spending with 0, and work out remaining
  # and status the same way envelope_balances() does.
  plan |>
    dplyr::left_join(spent, by = c("envelope_id", "period")) |>
    dplyr::mutate(
      month           = month,
      period_label    = unname(HALF_LABELS[period]),
      spent_cents     = dplyr::coalesce(spent_cents, 0),
      remaining_cents = budget_cents - spent_cents,
      status          = budget_status(remaining_cents)
    ) |>
    dplyr::select(month, envelope_id, name, period, period_label,
                  budget_cents, spent_cents, remaining_cents, status)
}
