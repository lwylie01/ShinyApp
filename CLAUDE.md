# Envelope Budget: a Shiny portfolio app

Read this first in every session.

## What this is

A Shiny app, written in R, that demonstrates an envelope budget: each spending
envelope is one card, spending is logged against an envelope, and the app shows
at a glance how much is left in each one. It is a public portfolio project on
GitHub, built by Lindsey E. Wylie directing Claude Code from RStudio. The goal is
to show careful, well-documented, AI-assisted development, and to learn Shiny
along the way.

## Non-negotiable rules

1. **Fictional data only.** Every name, card, amount, and transaction is invented.
   No real financial information belongs in this repository, ever, including in
   commits, test fixtures, screenshots, or the README.
2. **No one else's data.** The app never asks a visitor for an account, a bank
   connection, or anything that would mean storing their information on a server.
3. **Browser-only demo.** The public version runs entirely in the visitor's browser
   (Shinylive on GitHub Pages), so there is no server holding anyone's data.
4. **I decide; you build.** Propose design choices and explain the trade-offs,
   then wait for my decision. Record each decision in `DECISIONS.md`.

## Conventions

- R with the native pipe (`|>`), tidyverse style, and ggplot2 for any figures.
- Heavily commented code, with each step labeled, so a reader can learn from it.
- Keep the app modular: one Shiny module per feature, with logic in plain R
  functions under `R/` that can be tested without the app running.
- Tests with testthat for every function that does arithmetic on money.
- Accessible by default: color is never the only way information is shown, text
  has sufficient contrast, and the layout works on a phone screen.
- The README is written in plain, formal prose, without marketing language.

## The envelope model

- An **envelope** has a name, a color, a monthly amount, and a payment card.
- A **transaction** has a date, an amount, an envelope, and an optional note.
- **Remaining** in an envelope is its monthly amount minus that month's
  transactions. Overspending is shown plainly and never hidden.
- A month splits into **before the 15th** and **after the 15th**, because bills
  are planned that way.
- A **sinking fund** is an envelope that accumulates across months toward a goal,
  such as a trip.

## Build order (one stage at a time, each reviewed before the next)

1. **Data and logic.** A fictional starter dataset (`data/demo_envelopes.csv`,
   `data/demo_transactions.csv`) and tested R functions for remaining balances,
   the before-and-after-the-15th split, and sinking-fund progress.
2. **Envelope view.** A grid of colored envelope cards showing remaining and
   spent, readable on a phone.
3. **Logging.** A quick form to add a transaction to an envelope, held in the
   session (nothing saved to a server).
4. **Month view.** The before-and-after-the-15th picture and a simple trend figure.
5. **Deploy.** Export with Shinylive and publish to GitHub Pages.
6. **Write-up.** A README covering what the app does, how it was built with
   Claude Code, and what `DECISIONS.md` shows about the process.

## Files

- `DECISIONS.md` records each design decision, who made it, the date, and why.
  This log is part of the portfolio, because it shows how the work was directed.
- `R/` holds the logic functions, `tests/` holds the testthat tests, and
  `app.R` (or `app/`) holds the Shiny app.
