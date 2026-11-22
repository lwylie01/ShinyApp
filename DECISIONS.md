# Decisions

Each design decision for the Envelope Budget app: what was decided, who decided
it, when, and why. Claude Code proposes options and trade-offs; Lindsey E. Wylie
decides. This log is part of the portfolio, because it shows how the work was
directed.

## Stage 1: Data and logic

Claude proposed the Stage 1 plan on 2026-11-20. Lindsey approved every
recommendation on 2026-11-21 ("Go with all your recommendations").

| # | Decision | Choice | Decided by | Date | Why |
|---|---|---|---|---|---|
| 1 | How money is stored | Dollars with two decimals in the CSVs; whole cents inside every function | Lindsey | 2026-11-21 | The CSVs stay readable, and adding whole cents avoids floating-point drift (0.1 + 0.2 is not exactly 0.3 in R). |
| 2 | Which half the 15th belongs to | Days 1 to 14 are "before the 15th"; the 15th to the end of the month is "from the 15th on" | Lindsey | 2026-11-21 | Matches a paycheck that arrives on the 15th. |
| 3 | How a budget splits across the two halves | A `half` column on each envelope: `first`, `second`, or `split` (half the monthly amount in each) | Lindsey | 2026-11-21 | Bills are planned by half-month, so the plan belongs in the data, not only the spending. |
| 4 | Rollover | No rollover. Remaining in a regular envelope is that month's amount minus that month's spending | Lindsey | 2026-11-21 | Confirms the project brief. Sinking funds are the envelopes that carry money forward. |
| 5 | How a sinking fund adds up | Balance = monthly amount x months since `start_month` (counting both ends) - withdrawals. Progress = balance / goal. With a goal date, the fund also reports whether it is on pace | Lindsey | 2026-11-21 | Simple enough to check by hand. |
| 6 | How overspending is shown | Remaining may go negative, and a `status` text column reads "under", "at", or "over" | Lindsey | 2026-11-21 | Overspending is never hidden, and color is never the only signal. |
| 7 | Refunds | Allowed, entered as negative amounts | Lindsey | 2026-11-21 | A refund returns money to the envelope it came from. |
| 8 | Which month the app opens on | The latest month in the data, not today's date | Lindsey | 2026-11-21 | The public demo does not go stale as real time passes. |
| 9 | Packages | Base R plus dplyr only | Lindsey | 2026-11-21 | Shinylive downloads every package into the visitor's browser, so fewer packages means a faster first load. |
| 10 | Project structure | Plain `R/` and `tests/testthat/` folders, not an R package | Lindsey | 2026-11-21 | Shiny sources `R/` automatically; a package adds ceremony a small app does not need. |
| 11 | How the demo data is made | Hand-written CSVs | Lindsey | 2026-11-21 | Every value can be read and reviewed. |
| 12 | Global header-rows-only data rule | The demo CSVs are exempt, so their values can be shown and reviewed in chat | Lindsey | 2026-11-21 | The data is fictional and public by design (see the brief's rule 1). The rule still applies to every other project. |
| 13 | Fictional household | Nine envelopes on three cards (Bills Card, Everyday Card, Debit) with the amounts in `data/demo_envelopes.csv` | Lindsey | 2026-11-21 | Accepted as proposed. |
| 14 | Git | Set this repository's author email to the GitHub no-reply address, then commit each stage on its own branch (Stage 1: `stage-1-data-logic`) and merge to `main` after review | Lindsey | 2026-11-21 | The global git email was a placeholder, and the repository is public; the no-reply address keeps a personal email out of the history. Branches keep `main` to reviewed work only. |

### Implementation details

The approved decisions left these smaller choices open. Claude made them while
building so the code could run, listed them for review, and Lindsey approved
all five on 2026-11-21 ("ok let's do what is left"). Each is easy to change.

| # | Detail | What the code does | Why |
|---|---|---|---|
| A | Sinking funds in the monthly views | `envelope_balances()` and `half_month_summary()` cover spending envelopes only; sinking funds are reported by `sinking_fund_progress()` | "Monthly amount minus this month's spending" does not describe a fund that accumulates. |
| B | Odd cents in a `split` envelope | The first half gets the extra cent (for example, $0.15 splits into $0.08 and $0.07) | The two halves must always add back to the monthly amount exactly. |
| C | When a sinking fund is "on pace" | Projected balance = current balance + the contributions still to come, counting months after the current month up to the month before the goal date's month. On pace means projected >= goal | A goal date of 2027-06-01 means the money is needed by June 1, so May is the last contribution. |
| D | Withdrawals from a sinking fund | Spending logged against a sinking fund counts as a withdrawal; a negative amount puts money back | Same rule as refunds in decision 7. |
| E | Sinking fund `half` value | Both funds carry `split` in the data, but no Stage 1 function uses it yet | Kept from the approved plan; it may matter for the Stage 4 month view. |

## Stage 2: Envelope view

Claude proposed the Stage 2 plan on 2026-11-21. Lindsey approved every
recommendation the same day ("go with your recommendations").

| # | Decision | Choice | Decided by | Date | Why |
|---|---|---|---|---|---|
| 15 | How envelope color is used | A stripe down the card's left edge, with the envelope's name always printed beside it | Lindsey | 2026-11-21 | Filling the card with color would fail text contrast for some palette colors, and the name means color is never the only identifier. |
| 16 | The pale yellow stripe | Every stripe gets a thin dark outline; Beach Trip keeps #F0E442 | Lindsey | 2026-11-21 | #F0E442 nearly disappears against a white card without an edge. |
| 17 | The headline number | Remaining, as "$80.01 left" or "Over by $49.85", with "Spent X of Y" beneath | Lindsey | 2026-11-21 | The question the view answers is how much is left. |
| 18 | How overspending is marked | Three signals besides color: the words "Over by", a dark red "Over budget" badge with white text, and a full bar with diagonal stripes. Exactly at budget gets a neutral "At budget" badge; under budget gets no badge | Lindsey | 2026-11-21 | Overspending is never hidden (brief) and never shown by color alone (conventions). |
| 19 | Cents | Shown everywhere, as in $1,400.00 | Lindsey | 2026-11-21 | The screen matches the data exactly. |
| 20 | Sinking funds | A separate "Sinking Funds" section below the grid, showing saved, percent of goal, and "On pace" or "Behind pace" | Lindsey | 2026-11-21 | A fund that accumulates needs a different card from a monthly envelope. |
| 21 | Month picker | Added in Stage 2 (September, October, November 2026), opening on the latest month | Lindsey | 2026-11-21 | November has no overspending, so without a picker no visitor would see the over-budget card. |
| 22 | Order and grouping | Cards follow the envelope file's order, with the payment card named in small text on each | Lindsey | 2026-11-21 | Simple and predictable; grouping can be added later. |
| 23 | Phone layout | One column on a phone, more on wider screens, from a minimum card width of about 280px | Lindsey | 2026-11-21 | The brief requires the layout to work on a phone. |
| 24 | Look and font | Bootstrap 5 defaults through bslib, with the device's system font | Lindsey | 2026-11-21 | bslib comes with shiny, so nothing extra downloads; web fonts would slow the first Shinylive load. |
| 25 | How the bar is drawn | Plain HTML and CSS, marked as decorative for screen readers, with the same facts in text | Lindsey | 2026-11-21 | A screen reader reads the text; a plotted bar would be invisible to it. |
| 26 | Git | Branch `stage-2-envelope-view`, merged and pushed after review | Lindsey | 2026-11-21 | Same process as Stage 1 (decision 14). |

Lindsey reviewed the running app on 2026-11-21 ("looks good to me for now"),
and Stage 2 was merged and pushed.

## Stage 3: Logging

Claude proposed the Stage 3 plan on 2026-11-21. Lindsey approved every
recommendation the same day ("go with your recommendations").

| # | Decision | Choice | Decided by | Date | Why |
|---|---|---|---|---|---|
| 27 | Where the form sits | A card above the envelope grid | Lindsey | 2026-11-21 | Within reach on a phone, where a sidebar would collapse anyway. |
| 28 | Refunds in the form | A Spending / Refund choice; the amount is always typed as a positive number | Lindsey | 2026-11-21 | A typed minus sign is easy to miss, especially on a phone. |
| 29 | Amount field | A text box that brings up the number keypad and accepts "12.5", "12.50", or "$12.50"; fractions of a cent and zero are refused, as in the CSV | Lindsey | 2026-11-21 | Forgiving about format, strict about value. |
| 30 | Date | Defaults to the latest date in the data (November 20, 2026); only September 1 to November 30, 2026 are allowed | Lindsey | 2026-11-21 | Every entry lands in a month the picker offers, consistent with decision 8. |
| 31 | Sinking funds in the form | Allowed, with the envelope list grouped under "Spending" and "Sinking funds"; an entry there is a withdrawal | Lindsey | 2026-11-21 | Follows implementation detail D. |
| 32 | After saving | A confirmation sentence naming the amount, envelope, and what is left, read aloud by screen readers; the month picker jumps to the entry's month; amount and note clear, envelope and date stay | Lindsey | 2026-11-21 | The result of an entry is visible at once, and repeated entries are quick. |
| 33 | Undoing | A "Logged This Session" list with a Remove button on each entry, plus "Reset to demo data"; the demo's own transactions cannot be removed | Lindsey | 2026-11-21 | Mistakes are easy to fix without breaking the demo. |
| 34 | Saving across reloads | Nothing is saved; entries vanish on reload, and a line under the form says so | Lindsey | 2026-11-21 | Keeps to rule 2: the app never holds a visitor's information. |
| 35 | Notes | Optional, at most 100 characters, always shown as plain text | Lindsey | 2026-11-21 | A note can never inject anything into the page. |
| 36 | Git | Branch `stage-3-logging`, merged and pushed after review | Lindsey | 2026-11-21 | Same process as decisions 14 and 26. |
