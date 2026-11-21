# envelope_card.R
# Plain functions that turn one row of envelope_balances() or
# sinking_fund_progress() into the HTML for one card.
#
# These do not need a running app: each takes numbers and returns text or
# HTML, so tests can check exactly what a card says. The Shiny module
# (mod_envelopes.R) only arranges the cards.
#
# Accessibility rules applied here (decisions 15, 18 and 25):
#   - the envelope's color is a stripe, and its name is always printed;
#   - every status is spelled out in words, never shown by color alone;
#   - the bar is decorative (aria-hidden) because the text says the same thing.


# Text helpers -----------------------------------------------------------------

# month_label("2026-10") returns "October 2026".
month_label <- function(month) {
  format(as.Date(paste0(month, "-01")), "%B %Y")
}

# format_long_date(as.Date("2027-06-01")) returns "June 1, 2027".
# (Built by hand because the "%-d" day format does not work on Windows.)
format_long_date <- function(date) {
  paste0(format(date, "%B"), " ", as.integer(format(date, "%d")), ", ",
         format(date, "%Y"))
}

# The headline for a spending envelope: "$80.01 left", "$0.00 left", or
# "Over by $49.85". Overspending is stated outright, never as a negative
# number someone has to notice.
remaining_headline <- function(remaining_cents) {
  ifelse(remaining_cents < 0,
         paste("Over by", format_money(-remaining_cents)),
         paste(format_money(remaining_cents), "left"))
}

# The share of the bar to fill, from 0 to 1. Spending past the budget fills
# the bar completely; a net refund leaves it empty. An envelope with a zero
# budget is full as soon as anything is spent.
bar_share <- function(spent_cents, budget_cents) {
  # ifelse() returns one answer per value of its first argument, so repeat
  # a single budget to match the spending amounts first.
  budget_cents <- rep_len(budget_cents, length(spent_cents))
  share <- ifelse(budget_cents > 0, spent_cents / budget_cents,
                  ifelse(spent_cents > 0, 1, 0))
  pmin(pmax(share, 0), 1)
}

# One sentence summing up the month for the top of the grid, for example
# "October 2026: 1 of 7 envelopes over budget." The page announces it to
# screen readers when the month changes.
budget_summary_text <- function(balances) {
  n_over <- sum(balances$status == "over")
  sprintf("%s: %d of %d envelopes over budget.",
          month_label(balances$month[1]), n_over, nrow(balances))
}


# HTML pieces ------------------------------------------------------------------

# A text badge for a status, or NULL for none.
#   kind: "over", "at", "on_pace", or "behind"
status_badge <- function(kind) {
  labels <- c(over = "Over budget", at = "At budget",
              on_pace = "On pace", behind = "Behind pace")
  if (is.na(kind) || !kind %in% names(labels)) return(NULL)
  htmltools::span(class = paste0("env-badge env-badge-", kind),
                  labels[[kind]])
}

# The decorative bar. `striped` marks overspending with a pattern, so the bar
# itself does not rely on color either.
progress_bar <- function(share, striped = FALSE) {
  htmltools::div(
    class = "env-bar", `aria-hidden` = "true",
    htmltools::div(
      class = paste("env-bar-fill", if (striped) "env-bar-over"),
      style = sprintf("width: %.1f%%;", share * 100)
    )
  )
}

# The shared outer shell of every card: the color stripe, the name, and the
# payment card in small text.
card_shell <- function(row, ...) {
  htmltools::tags$article(
    class = "env-card",
    # The color travels as a CSS variable, used by the stripe and the bar.
    style = sprintf("--env-color: %s;", row$color),
    htmltools::div(
      class = "env-card-header",
      htmltools::h3(class = "env-name", row$name),
      htmltools::span(class = "env-payment", row$card)
    ),
    ...
  )
}


# Cards ------------------------------------------------------------------------

# envelope_card() builds one spending envelope card from one row of
# envelope_balances().
envelope_card <- function(row) {
  # Step 1: work out the words and the bar.
  over  <- row$status == "over"
  badge <- if (row$status %in% c("over", "at")) row$status else NA

  # Step 2: assemble the card.
  card_shell(
    row,
    htmltools::div(
      class = "env-card-main",
      htmltools::p(class = "env-headline", remaining_headline(row$remaining_cents)),
      status_badge(badge)
    ),
    progress_bar(bar_share(row$spent_cents, row$monthly_cents), striped = over),
    htmltools::p(
      class = "env-detail",
      sprintf("Spent %s of %s", format_money(row$spent_cents),
              format_money(row$monthly_cents))
    )
  )
}

# sinking_card() builds one sinking fund card from one row of
# sinking_fund_progress().
sinking_card <- function(row) {
  # Step 1: the pace badge (none without a goal date).
  pace <- if (is.na(row$on_pace)) NA else if (row$on_pace) "on_pace" else "behind"

  # Step 2: the goal line, with the date when there is one.
  goal_text <- sprintf("%d%% of a %s goal",
                       round(row$progress * 100), format_money(row$goal_cents))
  date_text <- if (is.na(row$goal_date)) {
    "No goal date"
  } else {
    paste("Goal date", format_long_date(row$goal_date))
  }

  # Step 3: assemble the card.
  card_shell(
    row,
    htmltools::div(
      class = "env-card-main",
      htmltools::p(class = "env-headline",
                   paste(format_money(row$balance_cents), "saved")),
      status_badge(pace)
    ),
    progress_bar(pmin(pmax(row$progress, 0), 1)),
    htmltools::p(class = "env-detail", goal_text),
    htmltools::p(class = "env-detail", sprintf("%s. Adding %s a month.",
                                               date_text,
                                               format_money(row$monthly_cents)))
  )
}

# card_grid() lays cards out in a grid that is one column on a phone and more
# on wider screens (decision 23; the widths live in www/styles.css).
#   rows: a data frame; make_card: envelope_card or sinking_card
card_grid <- function(rows, make_card) {
  cards <- lapply(seq_len(nrow(rows)), function(i) make_card(rows[i, ]))
  htmltools::div(class = "env-grid", cards)
}
