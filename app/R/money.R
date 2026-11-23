# money.R
# Converting between dollars and whole cents, and formatting money for display.
#
# Why cents? Computers store most decimal numbers approximately. In R,
# 0.1 + 0.2 == 0.3 is FALSE. Adding up many transactions in dollars can drift by
# a fraction of a cent. Whole numbers of cents add exactly, so every function in
# this app does its arithmetic in cents and converts to dollars only for display.
#
# Cents are stored as whole-number doubles (for example 1999, not 1999L).
# Doubles hold whole numbers exactly up to about 9 quadrillion, and, unlike R
# integers, their sums never overflow to NA.


# is_whole_cents() -------------------------------------------------------------
# TRUE where a dollar amount has at most two decimal places.
#   dollars: numeric vector. NA values return NA.
is_whole_cents <- function(dollars) {
  # Step 1: scale to cents and round to the nearest whole cent.
  scaled  <- dollars * 100
  rounded <- round(scaled)
  # Step 2: an amount like 19.99 scales to 1998.9999999998, not exactly 1999,
  # so allow a tiny tolerance. A real third decimal (19.995) is far outside it.
  abs(scaled - rounded) < 1e-6
}


# to_cents() -------------------------------------------------------------------
# Convert dollars to whole cents: to_cents(19.99) returns 1999.
#   dollars: numeric vector. NA stays NA.
# Stops with an error for non-numbers, infinite values, or fractions of a cent.
to_cents <- function(dollars) {
  # Step 1: the input must be numeric.
  if (!is.numeric(dollars)) {
    stop("`dollars` must be numeric.", call. = FALSE)
  }
  # Step 2: Inf and -Inf are not money.
  if (any(is.infinite(dollars))) {
    stop("`dollars` contains an infinite value.", call. = FALSE)
  }
  # Step 3: refuse amounts with more than two decimal places, rather than
  # silently rounding them, and say where they are.
  bad <- which(!is_whole_cents(dollars))
  if (length(bad) > 0) {
    stop(
      "Amounts must have at most two decimal places (position ",
      paste(bad, collapse = ", "), ").",
      call. = FALSE
    )
  }
  # Step 4: scale and round to a whole number of cents.
  round(dollars * 100)
}


# from_cents() -----------------------------------------------------------------
# Convert whole cents back to dollars: from_cents(1999) returns 19.99.
# Use this only at the very end, for display or plotting, never before adding.
from_cents <- function(cents) {
  cents / 100
}


# format_money() ---------------------------------------------------------------
# Format cents as dollar text: format_money(140000) returns "$1,400.00" and
# format_money(-1250) returns "-$12.50". NA returns NA.
format_money <- function(cents) {
  # Step 1: remember which amounts are negative, then work with the size only.
  sign <- ifelse(cents < 0, "-", "")
  # Step 2: two decimals and a comma every three digits.
  dollars <- formatC(abs(cents) / 100, format = "f", digits = 2, big.mark = ",")
  # Step 3: put the sign before the dollar sign, the usual US style.
  out <- paste0(sign, "$", dollars)
  # Step 4: keep missing values missing instead of printing "$NA".
  out[is.na(cents)] <- NA_character_
  out
}
