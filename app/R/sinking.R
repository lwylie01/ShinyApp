# sinking.R
# Progress of sinking funds: envelopes that build up across months toward a
# goal, such as a trip.
#
# The rule (decision 5):
#   balance  = monthly amount x months since start_month, counting both ends
#              - withdrawals (transactions against the fund) up to that month
#   progress = balance / goal
# With a goal date, the fund also reports whether it is on pace: if the
# contributions still to come would bring the balance to the goal by then.


# month_index() ----------------------------------------------------------------
# Turn "YYYY-MM" into a running month count so months can be subtracted:
# month_index("2026-11") - month_index("2026-06") is 5.
month_index <- function(month) {
  year <- as.integer(substr(month, 1, 4))
  mon  <- as.integer(substr(month, 6, 7))
  year * 12 + (mon - 1)
}


# months_contributed() ---------------------------------------------------------
# How many monthly contributions have been made from start_month through
# as_of_month, counting both ends. June through November is 6. A fund that has
# not started yet has 0.
months_contributed <- function(start_month, as_of_month) {
  pmax(month_index(as_of_month) - month_index(start_month) + 1, 0)
}


# months_still_to_come() -------------------------------------------------------
# How many contributions remain between the month after as_of_month and the
# month before the goal date's month. A goal date of 2027-06-01 means the money
# is needed by June 1, so May is the last contribution. If the fund has not
# started yet, counting begins at its start month. NA goal dates give NA.
months_still_to_come <- function(start_month, as_of_month, goal_date) {
  goal_month   <- month_key(goal_date)
  first_future <- pmax(month_index(as_of_month) + 1, month_index(start_month))
  pmax(month_index(goal_month) - first_future, 0)
}


# sinking_fund_progress() ------------------------------------------------------
# One row per sinking fund as of `as_of_month`, with columns: as_of_month,
# envelope_id, name, card, color, monthly_cents, goal_cents, goal_date,
# contributed_cents, withdrawn_cents, balance_cents, progress (a proportion,
# 0.5 is halfway; not capped, so it can pass 1 or fall below 0),
# to_goal_cents (never below 0), projected_cents and on_pace (NA without a
# goal date).
sinking_fund_progress <- function(envelopes, transactions,
                                  as_of_month = latest_month(transactions)) {
  # Step 1: make sure the month is well formed.
  check_month(as_of_month)

  # Step 2: keep only sinking funds.
  funds <- envelopes |>
    dplyr::filter(type == "sinking")

  # Step 3: total withdrawals through the as-of month. Later transactions are
  # ignored, so looking back at an earlier month gives that month's balance.
  # A negative amount puts money back, like a refund.
  withdrawn <- transactions |>
    dplyr::filter(month_key(date) <= as_of_month) |>
    dplyr::group_by(envelope_id) |>
    dplyr::summarise(withdrawn_cents = sum(amount_cents), .groups = "drop")

  # Step 4: contributions, balance, progress, and pace.
  funds |>
    dplyr::left_join(withdrawn, by = "envelope_id") |>
    dplyr::mutate(
      as_of_month       = as_of_month,
      withdrawn_cents   = dplyr::coalesce(withdrawn_cents, 0),
      contributed_cents = monthly_cents *
        months_contributed(start_month, as_of_month),
      balance_cents     = contributed_cents - withdrawn_cents,
      progress          = balance_cents / goal_cents,
      to_goal_cents     = pmax(goal_cents - balance_cents, 0),
      projected_cents   = balance_cents + monthly_cents *
        months_still_to_come(start_month, as_of_month, goal_date),
      on_pace           = projected_cents >= goal_cents
    ) |>
    dplyr::select(as_of_month, envelope_id, name, card, color, monthly_cents,
                  goal_cents, goal_date, contributed_cents, withdrawn_cents,
                  balance_cents, progress, to_goal_cents, projected_cents,
                  on_pace)
}
