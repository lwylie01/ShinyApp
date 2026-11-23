# month_view.R
# Plain functions behind the month view: totals for each half of the month,
# the text in each table cell, and the day-by-day spending pace that the
# trend figure draws.
#
# Like the rest of R/, these take tables and return tables or text, so tests
# can check them without the app running.


# Dates ------------------------------------------------------------------------

# month_end_date("2026-11") returns 2026-11-30.
month_end_date <- function(month) {
  month_bounds(month)$max
}

# data_as_of() is the latest date in the transactions: the "today" of the
# demo (decision 8). Logging a later entry moves it forward.
data_as_of <- function(transactions) {
  max(transactions$date)
}


# Half-month totals ------------------------------------------------------------

# half_month_totals() adds up half_month_summary() output into two rows, one
# per half, with columns: period, period_label, budget_cents, spent_cents,
# remaining_cents, status.
half_month_totals <- function(half_summary) {
  half_summary |>
    dplyr::group_by(period, period_label) |>
    dplyr::summarise(budget_cents = sum(budget_cents),
                     spent_cents  = sum(spent_cents), .groups = "drop") |>
    dplyr::mutate(remaining_cents = budget_cents - spent_cents,
                  status = budget_status(remaining_cents)) |>
    dplyr::arrange(match(period, c("first", "second")))
}

# half_cell_text() is the main text of one table cell: "$31.25 of $75.00",
# or "Not planned" for a half with nothing planned and nothing spent
# (decision 39). Overspending is added separately by over_text().
half_cell_text <- function(budget_cents, spent_cents) {
  ifelse(budget_cents == 0 & spent_cents == 0,
         "Not planned",
         paste(format_money(spent_cents), "of", format_money(budget_cents)))
}

# over_text() is "Over by $4.10" for overspent cells and NA otherwise.
over_text <- function(remaining_cents) {
  ifelse(remaining_cents < 0,
         paste("Over by", format_money(-remaining_cents)),
         NA_character_)
}


# Spending pace ----------------------------------------------------------------

# month_pace() builds the data for the trend figure (decision 40): one row per
# day of `month`, with columns date, spent_cents (cumulative spending in
# spending envelopes up to and including that day) and planned_cents (the
# money planned so far: the first-half budget from the 1st, the whole monthly
# budget from the 15th).
#
# The days run to the end of the month, or only to `as_of` when `as_of`
# falls inside the month, so the line never runs past the data (decision 44).
month_pace <- function(envelopes, transactions, month,
                       as_of = data_as_of(transactions)) {
  check_month(month)

  # Step 1: the days to draw.
  first_day <- as.Date(paste0(month, "-01"))
  last_day  <- month_end_date(month)
  if (as_of >= first_day && as_of < last_day) last_day <- as_of
  days <- seq(first_day, last_day, by = "day")

  # Step 2: spending envelopes only (detail A), and each half's budget.
  spending <- envelopes[envelopes$type == "spending", ]
  first_half  <- sum(first_half_budget(spending$monthly_cents, spending$half))
  whole_month <- sum(spending$monthly_cents)

  # Step 3: each day's total spending. Refunds are negative, so a refund makes
  # the running total dip (decision 45).
  in_month <- transactions[transactions$envelope_id %in% spending$envelope_id &
                             transactions$date >= first_day &
                             transactions$date <= last_day, ]
  # (Loop over positions, not the dates themselves: vapply() would strip the
  # Date class and hand over bare numbers.)
  daily <- vapply(seq_along(days),
                  function(i) sum(in_month$amount_cents[in_month$date == days[i]]),
                  numeric(1))

  # Step 4: running totals and the planned amount for each day.
  data.frame(
    date          = days,
    spent_cents   = cumsum(daily),
    planned_cents = ifelse(half_of_month(days) == "first", first_half, whole_month)
  )
}

# pace_summary_text() is one sentence describing the figure, used as its alt
# text and printed beneath it (decision 43). For example:
# "By November 20, 2026, $2,066.39 had been spent of $2,655.00 planned so far.
#  Spending stayed within the plan every day."
pace_summary_text <- function(pace) {
  # Step 1: where things stood on the last day drawn.
  last <- pace[nrow(pace), ]
  first_sentence <- sprintf(
    "By %s, %s had been spent of %s planned so far.",
    format_long_date(last$date), format_money(last$spent_cents),
    format_money(last$planned_cents)
  )

  # Step 2: whether spending ever ran ahead of the plan, and when first.
  ahead <- pace$spent_cents > pace$planned_cents
  second_sentence <- if (!any(ahead)) {
    "Spending stayed within the plan every day."
  } else {
    sprintf("Spending was ahead of the plan on %d of %d days, starting %s.",
            sum(ahead), nrow(pace), format_long_date(pace$date[which(ahead)[1]]))
  }
  paste(first_sentence, second_sentence)
}
