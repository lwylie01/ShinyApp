# load_data.R
# Reading the envelope and transaction CSVs, checking them, and converting them
# to the typed tables every other function expects.
#
# Each file is read with every column as text first. That way nothing is
# guessed: each column is checked and converted on purpose, and a bad value
# stops with a message naming the column and the data row it is on (data row 1
# is the first row after the header).
#
# The clean_*() functions do the checking. They take a data frame of text, so
# tests can call them directly without writing a file.

# The allowed values for the coded columns.
ENVELOPE_TYPES <- c("spending", "sinking")
ENVELOPE_HALVES <- c("first", "second", "split")


# Small helpers ----------------------------------------------------------------

# Stop with a message that lists the offending data rows.
stop_rows <- function(problem, rows) {
  label <- if (length(rows) == 1) "data row" else "data rows"
  stop(sprintf("%s (%s %s).", problem, label, paste(rows, collapse = ", ")),
       call. = FALSE)
}

# Stop if any required column is missing from a table.
check_columns <- function(df, required, what) {
  missing <- setdiff(required, names(df))
  if (length(missing) > 0) {
    stop(sprintf("%s is missing column(s): %s.", what,
                 paste(missing, collapse = ", ")), call. = FALSE)
  }
}

# TRUE where a text value is missing or empty.
is_blank <- function(x) {
  is.na(x) | trimws(x) == ""
}

# Convert a text column of dollar amounts to cents, naming the column and row
# of anything that is not a number or has more than two decimal places.
# Blank values become NA.
parse_dollars <- function(x, column) {
  # Step 1: treat blanks as missing.
  x[is_blank(x)] <- NA
  # Step 2: convert to numbers; anything non-numeric becomes NA.
  num <- suppressWarnings(as.numeric(x))
  not_number <- which(!is.na(x) & is.na(num))
  if (length(not_number) > 0) {
    stop_rows(sprintf("`%s` must be a number", column), not_number)
  }
  # Step 3: refuse fractions of a cent.
  too_precise <- which(!is.na(num) & !is_whole_cents(num))
  if (length(too_precise) > 0) {
    stop_rows(sprintf("`%s` must have at most two decimal places", column),
              too_precise)
  }
  # Step 4: convert to cents (money.R).
  to_cents(num)
}

# Convert a text column of YYYY-MM-DD dates to Date, naming bad rows.
# Blank values become NA.
parse_dates <- function(x, column) {
  x[is_blank(x)] <- NA
  # Step 1: insist on the exact shape, so "9/1/2026" or "2026-9-1" is refused
  # instead of guessed.
  wrong_shape <- which(!is.na(x) & !grepl("^\\d{4}-\\d{2}-\\d{2}$", x))
  if (length(wrong_shape) > 0) {
    stop_rows(sprintf("`%s` must be a date written YYYY-MM-DD", column),
              wrong_shape)
  }
  # Step 2: the shape can be right and the date impossible (2026-02-30).
  dates <- as.Date(x, format = "%Y-%m-%d")
  impossible <- which(!is.na(x) & is.na(dates))
  if (length(impossible) > 0) {
    stop_rows(sprintf("`%s` is not a real calendar date", column), impossible)
  }
  dates
}


# Envelopes --------------------------------------------------------------------

# clean_envelopes() checks a table of envelope text and returns typed columns:
# envelope_id, name, type, half, card, color, monthly_cents, goal_cents,
# goal_date (Date), start_month ("YYYY-MM" text).
clean_envelopes <- function(raw) {
  # Step 1: every expected column is present.
  check_columns(raw, c("envelope_id", "name", "type", "monthly_amount", "half",
                       "card", "color", "goal_amount", "goal_date",
                       "start_month"), "The envelope file")

  # Step 2: trim stray spaces from every text column.
  raw[] <- lapply(raw, function(col) trimws(as.character(col)))

  # Step 3: ids are present, unique, and simple (lowercase, digits, underscore),
  # because transactions refer to envelopes by id.
  bad <- which(is_blank(raw$envelope_id) |
                 !grepl("^[a-z0-9_]+$", raw$envelope_id))
  if (length(bad) > 0) {
    stop_rows("`envelope_id` must use only lowercase letters, digits, and _",
              bad)
  }
  dup <- which(duplicated(raw$envelope_id))
  if (length(dup) > 0) stop_rows("`envelope_id` is repeated", dup)

  # Step 4: names and cards are required.
  bad <- which(is_blank(raw$name))
  if (length(bad) > 0) stop_rows("`name` is blank", bad)
  bad <- which(is_blank(raw$card))
  if (length(bad) > 0) stop_rows("`card` is blank", bad)

  # Step 5: coded columns hold only their allowed values.
  bad <- which(!raw$type %in% ENVELOPE_TYPES)
  if (length(bad) > 0) {
    stop_rows(sprintf("`type` must be one of: %s",
                      paste(ENVELOPE_TYPES, collapse = ", ")), bad)
  }
  bad <- which(!raw$half %in% ENVELOPE_HALVES)
  if (length(bad) > 0) {
    stop_rows(sprintf("`half` must be one of: %s",
                      paste(ENVELOPE_HALVES, collapse = ", ")), bad)
  }

  # Step 6: colors are six-digit hex codes like #0072B2.
  bad <- which(!grepl("^#[0-9A-Fa-f]{6}$", raw$color))
  if (length(bad) > 0) {
    stop_rows("`color` must be a hex code like #0072B2", bad)
  }

  # Step 7: the monthly amount is a required, non-negative dollar amount.
  monthly_cents <- parse_dollars(raw$monthly_amount, "monthly_amount")
  bad <- which(is.na(monthly_cents) | monthly_cents < 0)
  if (length(bad) > 0) {
    stop_rows("`monthly_amount` must be zero or more", bad)
  }

  # Step 8: goal fields. Parse them for every row first, then check that each
  # type has exactly the fields it should.
  goal_cents <- parse_dollars(raw$goal_amount, "goal_amount")
  goal_date  <- parse_dates(raw$goal_date, "goal_date")
  start_month <- raw$start_month
  start_month[is_blank(start_month)] <- NA

  is_sinking <- raw$type == "sinking"

  # A sinking fund needs a positive goal and a start month; a goal date is
  # optional (Car Repairs has none).
  bad <- which(is_sinking & (is.na(goal_cents) | goal_cents <= 0))
  if (length(bad) > 0) {
    stop_rows("A sinking fund needs a `goal_amount` above zero", bad)
  }
  bad <- which(is_sinking & !is_month_key(start_month))
  if (length(bad) > 0) {
    stop_rows("A sinking fund needs a `start_month` written YYYY-MM", bad)
  }

  # A spending envelope leaves all three goal fields blank, so a stray value
  # is caught rather than quietly ignored.
  bad <- which(!is_sinking &
                 (!is.na(goal_cents) | !is.na(goal_date) | !is.na(start_month)))
  if (length(bad) > 0) {
    stop_rows(paste("A spending envelope must leave `goal_amount`,",
                    "`goal_date`, and `start_month` blank"), bad)
  }

  # Step 9: return the typed table.
  data.frame(
    envelope_id   = raw$envelope_id,
    name          = raw$name,
    type          = raw$type,
    half          = raw$half,
    card          = raw$card,
    color         = raw$color,
    monthly_cents = monthly_cents,
    goal_cents    = goal_cents,
    goal_date     = goal_date,
    start_month   = start_month,
    stringsAsFactors = FALSE
  )
}

# read_envelopes() reads the envelope CSV and returns clean_envelopes() output.
read_envelopes <- function(path) {
  raw <- utils::read.csv(path, colClasses = "character", na.strings = "",
                         check.names = FALSE)
  clean_envelopes(raw)
}


# Transactions -----------------------------------------------------------------

# clean_transactions() checks a table of transaction text against the clean
# envelopes and returns typed columns: transaction_id, date (Date),
# envelope_id, amount_cents, note (blank notes become "").
clean_transactions <- function(raw, envelopes) {
  # Step 1: every expected column is present.
  check_columns(raw, c("transaction_id", "date", "envelope_id", "amount",
                       "note"), "The transaction file")

  # Step 2: trim stray spaces.
  raw[] <- lapply(raw, function(col) trimws(as.character(col)))

  # Step 3: ids are present and unique.
  bad <- which(is_blank(raw$transaction_id))
  if (length(bad) > 0) stop_rows("`transaction_id` is blank", bad)
  dup <- which(duplicated(raw$transaction_id))
  if (length(dup) > 0) stop_rows("`transaction_id` is repeated", dup)

  # Step 4: every transaction has a real date.
  date <- parse_dates(raw$date, "date")
  bad <- which(is.na(date))
  if (length(bad) > 0) stop_rows("`date` is blank", bad)

  # Step 5: every transaction points at an envelope that exists.
  bad <- which(!raw$envelope_id %in% envelopes$envelope_id)
  if (length(bad) > 0) {
    stop_rows("`envelope_id` does not match any envelope", bad)
  }

  # Step 6: amounts are required and never zero. Positive is spending;
  # negative is a refund (decision 7).
  amount_cents <- parse_dollars(raw$amount, "amount")
  bad <- which(is.na(amount_cents))
  if (length(bad) > 0) stop_rows("`amount` is blank", bad)
  bad <- which(amount_cents == 0)
  if (length(bad) > 0) stop_rows("`amount` must not be zero", bad)

  # Step 7: notes are optional; store blanks as empty text, not NA.
  note <- raw$note
  note[is_blank(note)] <- ""

  # Step 8: return the typed table.
  data.frame(
    transaction_id = raw$transaction_id,
    date           = date,
    envelope_id    = raw$envelope_id,
    amount_cents   = amount_cents,
    note           = note,
    stringsAsFactors = FALSE
  )
}

# read_transactions() reads the transaction CSV and returns
# clean_transactions() output. It needs the clean envelopes to check ids.
read_transactions <- function(path, envelopes) {
  raw <- utils::read.csv(path, colClasses = "character", na.strings = "",
                         check.names = FALSE)
  clean_transactions(raw, envelopes)
}
