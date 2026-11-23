# transactions.R
# Adding and removing transactions logged during a visit.
#
# Entries from the form go through the same clean_transactions() checks as
# the demo CSV, so one set of rules covers both. Entries logged in the
# session get ids starting with "s" (s001, s002, ...); the demo's own
# transactions start with "t" and cannot be removed (decision 33).
#
# Nothing here saves anything: these functions take a table and return a new
# table, and the app keeps that table only for the current visit (decision 34).

# The longest note the form accepts (decision 35).
NOTE_MAX_CHARS <- 100


# month_bounds() ---------------------------------------------------------------
# The first and last day covered by a set of "YYYY-MM" months:
# month_bounds(c("2026-09", "2026-11")) gives 2026-09-01 and 2026-11-30.
month_bounds <- function(months) {
  months <- sort(months)
  first <- as.Date(paste0(months[1], "-01"))
  # The last day of the last month is the day before the next month begins.
  last_start <- as.Date(paste0(months[length(months)], "-01"))
  last <- seq(last_start, by = "month", length.out = 2)[2] - 1
  list(min = first, max = last)
}


# is_session_entry() -----------------------------------------------------------
# TRUE for ids of entries logged during this visit.
is_session_entry <- function(transaction_id) {
  grepl("^s\\d+$", transaction_id)
}

# session_entries() returns only the rows logged during this visit.
session_entries <- function(transactions) {
  transactions[is_session_entry(transactions$transaction_id), , drop = FALSE]
}

# next_session_id() ------------------------------------------------------------
# The next unused session id. It counts up from the highest one ever used, so
# an id is never reused after a removal and a confirmation message never
# points at the wrong entry.
next_session_id <- function(transactions, used_max = 0) {
  ids <- transactions$transaction_id[is_session_entry(transactions$transaction_id)]
  current <- if (length(ids) == 0) 0 else max(as.integer(sub("^s", "", ids)))
  sprintf("s%03d", max(current, used_max) + 1)
}


# parse_amount_input() ---------------------------------------------------------
# Turn what someone typed in the amount box into cents, accepting "12.5",
# "12.50", "$12.50", or "1,250.00". Stops with a message meant for the
# person using the form.
parse_amount_input <- function(text) {
  # Step 1: drop dollar signs, commas, and spaces.
  cleaned <- gsub("[$,[:space:]]", "", if (is.null(text)) "" else text)
  if (cleaned == "") stop("Enter an amount.", call. = FALSE)

  # Step 2: it must be a number.
  dollars <- suppressWarnings(as.numeric(cleaned))
  if (is.na(dollars) || !is.finite(dollars)) {
    stop("Enter the amount as a number, such as 12.50.", call. = FALSE)
  }

  # Step 3: positive only; refunds are chosen with the Refund button
  # (decision 28), never typed with a minus sign.
  if (dollars < 0) {
    stop("Type the amount without a minus sign. To return money to an ",
         "envelope, choose Refund.", call. = FALSE)
  }
  if (dollars == 0) stop("The amount must be more than $0.00.", call. = FALSE)

  # Step 4: no fractions of a cent.
  if (!is_whole_cents(dollars)) {
    stop("The amount can have at most two decimal places.", call. = FALSE)
  }
  to_cents(dollars)
}


# add_transaction() ------------------------------------------------------------
# Add one entry from the form and return the new transactions table, with the
# new entry as its last row. Stops with a plain message if anything is wrong.
#   transactions, envelopes: the clean tables
#   envelope_id: from the envelope list
#   amount_text: what was typed in the amount box
#   kind: "spending" or "refund"
#   date: a Date; must fall within date_range
#   note: optional text
#   date_range: list(min, max) from month_bounds()
#   used_max: the highest session id number used so far this visit
add_transaction <- function(transactions, envelopes, envelope_id, amount_text,
                            kind, date, note, date_range, used_max = 0) {
  # Step 1: the envelope must exist.
  if (is.null(envelope_id) || !envelope_id %in% envelopes$envelope_id) {
    stop("Choose an envelope.", call. = FALSE)
  }

  # Step 2: the amount, made negative for a refund (decision 7).
  cents <- parse_amount_input(amount_text)
  if (identical(kind, "refund")) cents <- -cents

  # Step 3: the date, inside the months the picker offers (decision 30).
  if (length(date) != 1 || is.na(date)) stop("Choose a date.", call. = FALSE)
  if (date < date_range$min || date > date_range$max) {
    stop(sprintf("Choose a date from %s to %s.",
                 format_long_date(date_range$min),
                 format_long_date(date_range$max)), call. = FALSE)
  }

  # Step 4: the note is optional and short (decision 35).
  note <- if (is.null(note)) "" else trimws(note)
  if (nchar(note) > NOTE_MAX_CHARS) {
    stop(sprintf("Keep the note to %d characters or fewer.", NOTE_MAX_CHARS),
         call. = FALSE)
  }

  # Step 5: build the new row as text, exactly like a row of the CSV, and run
  # it through the same checks as the demo data. This is a safety net: the
  # steps above should already have caught any problem.
  raw <- data.frame(
    transaction_id = next_session_id(transactions, used_max),
    date           = format(date, "%Y-%m-%d"),
    envelope_id    = envelope_id,
    amount         = sprintf("%.2f", from_cents(cents)),
    note           = note,
    stringsAsFactors = FALSE
  )
  new_row <- clean_transactions(raw, envelopes)

  # Step 6: append it.
  rbind(transactions, new_row)
}


# remove_transaction() ---------------------------------------------------------
# Remove one entry logged this visit. The demo's own rows cannot be removed.
remove_transaction <- function(transactions, transaction_id) {
  if (!is_session_entry(transaction_id)) {
    stop("Only entries logged during this visit can be removed.", call. = FALSE)
  }
  transactions[transactions$transaction_id != transaction_id, , drop = FALSE]
}


# confirmation_text() ----------------------------------------------------------
# The sentence shown after a save (decision 32), for example
# "Added $12.50 to Dining Out. $107.45 left in November 2026." It reads the
# entry back from the updated table so it always reports what was saved.
#   entry: the new row (the last row returned by add_transaction())
confirmation_text <- function(entry, envelopes, transactions) {
  env <- envelopes[envelopes$envelope_id == entry$envelope_id, ]
  month <- month_key(entry$date)
  amount <- format_money(abs(entry$amount_cents))
  refund <- entry$amount_cents < 0

  if (env$type == "spending") {
    # Spending envelope: what is left this month, or how far over.
    bal <- envelope_balances(envelopes, transactions, month)
    bal <- bal[bal$envelope_id == env$envelope_id, ]
    action <- if (refund) sprintf("Refunded %s to %s.", amount, env$name)
              else sprintf("Added %s to %s.", amount, env$name)
    sprintf("%s %s in %s.", action, remaining_headline(bal$remaining_cents),
            month_label(month))
  } else {
    # Sinking fund: spending is a withdrawal; a refund puts money back.
    fund <- sinking_fund_progress(envelopes, transactions, month)
    fund <- fund[fund$envelope_id == env$envelope_id, ]
    action <- if (refund) sprintf("Returned %s to %s.", amount, env$name)
              else sprintf("Withdrew %s from %s.", amount, env$name)
    sprintf("%s %s saved as of %s.", action, format_money(fund$balance_cents),
            month_label(month))
  }
}


# form_message() ---------------------------------------------------------------
# Turn an error into a message for the form. If one of the CSV checks fired,
# its "(data row 1)" ending means nothing to someone using the form, so it is
# removed.
form_message <- function(error) {
  sub(" \\(data rows? [0-9, ]+\\)", "", conditionMessage(error))
}
