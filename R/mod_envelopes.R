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
#   envelopes:    the clean table from read_envelopes()
#   transactions: a reactive (the shared reactiveVal in app.R) returning the
#                 current transactions, so entries from the logging form
#                 appear on the cards as soon as they are saved
#   jump_to:      optional reactive returning list(month, count) after each
#                 save; the picker moves to that month (decision 32)
envelopesServer <- function(id, envelopes, transactions, jump_to = NULL) {
  shiny::moduleServer(id, function(input, output, session) {

    # Step 1: the numbers for the chosen month. Each reactive() recalculates
    # when input$month changes or a transaction is added or removed.
    balances <- shiny::reactive({
      shiny::req(input$month)
      envelope_balances(envelopes, transactions(), input$month)
    })
    funds <- shiny::reactive({
      shiny::req(input$month)
      sinking_fund_progress(envelopes, transactions(), input$month)
    })

    # Step 1b: after a save, show the month the entry landed in.
    if (!is.null(jump_to)) {
      shiny::observeEvent(jump_to(), {
        shiny::updateSelectInput(session, "month", selected = jump_to()$month)
      })
    }

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
