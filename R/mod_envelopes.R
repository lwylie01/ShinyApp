# mod_envelopes.R
# The envelope view as a Shiny module: a month picker, a grid of spending
# envelope cards, and a section of sinking fund cards.
#
# A module is a self-contained piece of a Shiny app with its own UI function
# and server function. The id ("envelopes" in app.R) keeps its input and
# output names separate from any other module's, so later stages can add
# modules without name clashes.


# envelopesUI() ----------------------------------------------------------------
#   id:       the module's id
#   months:   the "YYYY-MM" months to offer in the picker
#   selected: the month to open on (decision 8: the latest month in the data)
envelopesUI <- function(id, months, selected) {
  ns <- shiny::NS(id)   # ns("month") becomes "envelopes-month", and so on

  # Picker choices: the label is shown ("October 2026"), the value is used.
  choices <- stats::setNames(months, month_label(months))

  htmltools::tagList(
    # Step 1: the month picker.
    shiny::selectInput(ns("month"), "Month", choices = choices,
                       selected = selected, width = "240px"),

    # Step 2: spending envelopes, with a one-line summary above the grid.
    # aria-live="polite" asks screen readers to read the summary aloud when
    # the month changes.
    htmltools::h2("Spending Envelopes"),
    htmltools::p(class = "env-summary", `aria-live` = "polite",
                 shiny::textOutput(ns("summary"), inline = TRUE)),
    shiny::uiOutput(ns("spending_cards")),

    # Step 3: sinking funds, which build up across months.
    htmltools::h2("Sinking Funds"),
    htmltools::p(class = "env-summary",
                 shiny::textOutput(ns("sinking_note"), inline = TRUE)),
    shiny::uiOutput(ns("sinking_cards"))
  )
}


# envelopesServer() ------------------------------------------------------------
#   envelopes, transactions: the clean tables from read_envelopes() and
#   read_transactions(). They do not change in Stage 2; Stage 3 will make
#   transactions reactive so new entries appear on the cards.
envelopesServer <- function(id, envelopes, transactions) {
  shiny::moduleServer(id, function(input, output, session) {

    # Step 1: the numbers for the chosen month. Each reactive() recalculates
    # only when input$month changes.
    balances <- shiny::reactive({
      shiny::req(input$month)
      envelope_balances(envelopes, transactions, input$month)
    })
    funds <- shiny::reactive({
      shiny::req(input$month)
      sinking_fund_progress(envelopes, transactions, input$month)
    })

    # Step 2: the text above each section.
    output$summary <- shiny::renderText(budget_summary_text(balances()))
    output$sinking_note <- shiny::renderText(
      sprintf("Balances as of the end of %s.", month_label(input$month))
    )

    # Step 3: the cards.
    output$spending_cards <- shiny::renderUI(card_grid(balances(), envelope_card))
    output$sinking_cards  <- shiny::renderUI(card_grid(funds(), sinking_card))
  })
}
