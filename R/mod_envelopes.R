# mod_envelopes.R
# The envelope view as a Shiny module: a grid of spending envelope cards and a
# section of sinking fund cards for the chosen month.
#
# A module is a self-contained piece of a Shiny app with its own UI function
# and server function. The id ("envelopes" in app.R) keeps its input and
# output names separate from any other module's.
#
# The month comes from the shared picker (mod_month_picker.R), so this tab
# and the Month View tab always show the same month (decision 37).


# envelopesUI() ----------------------------------------------------------------
envelopesUI <- function(id) {
  ns <- shiny::NS(id)   # ns("summary") becomes "envelopes-summary", and so on

  htmltools::tagList(
    # Step 1: spending envelopes, with a one-line summary above the grid.
    # aria-live="polite" asks screen readers to read the summary aloud when
    # the month changes.
    htmltools::h2("Spending Envelopes"),
    htmltools::p(class = "env-summary", `aria-live` = "polite",
                 shiny::textOutput(ns("summary"), inline = TRUE)),
    shiny::uiOutput(ns("spending_cards")),

    # Step 2: sinking funds, which build up across months.
    htmltools::h2("Sinking Funds"),
    htmltools::p(class = "env-summary",
                 shiny::textOutput(ns("sinking_note"), inline = TRUE)),
    shiny::uiOutput(ns("sinking_cards"))
  )
}


# envelopesServer() ------------------------------------------------------------
#   envelopes:    the clean table from read_envelopes()
#   transactions: a reactive returning the current transactions (the shared
#                 reactiveVal in app.R), so new entries appear at once
#   month:        a reactive returning the chosen "YYYY-MM" month
envelopesServer <- function(id, envelopes, transactions, month) {
  shiny::moduleServer(id, function(input, output, session) {

    # Step 1: the numbers for the chosen month. Each reactive() recalculates
    # when the month changes or a transaction is added or removed.
    balances <- shiny::reactive(
      envelope_balances(envelopes, transactions(), month())
    )
    funds <- shiny::reactive(
      sinking_fund_progress(envelopes, transactions(), month())
    )

    # Step 2: the text above each section.
    output$summary <- shiny::renderText(budget_summary_text(balances()))
    output$sinking_note <- shiny::renderText(
      sprintf("Balances as of the end of %s.", month_label(month()))
    )

    # Step 3: the cards.
    output$spending_cards <- shiny::renderUI(card_grid(balances(), envelope_card))
    output$sinking_cards  <- shiny::renderUI(card_grid(funds(), sinking_card))
  })
}
