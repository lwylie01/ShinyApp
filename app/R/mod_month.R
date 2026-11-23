# mod_month.R
# The Month View tab as a Shiny module: totals for each half of the month,
# a table by envelope, and the spending-pace figure (decisions 38 to 45).


# monthUI() --------------------------------------------------------------------
monthUI <- function(id) {
  ns <- shiny::NS(id)
  htmltools::tagList(
    # Step 1: the two halves at a glance.
    htmltools::h2("Before and From the 15th"),
    shiny::uiOutput(ns("totals")),

    # Step 2: the same split, envelope by envelope.
    shiny::uiOutput(ns("half_table")),

    # Step 3: the spending pace. The figure gets alt text from the server,
    # and the same sentence is printed below it for everyone (decision 43).
    htmltools::h2("Spending Pace"),
    htmltools::p(class = "env-summary",
                 "Spending so far this month (solid line) against the money",
                 "planned so far (dashed line), which steps up on the 15th."),
    shiny::plotOutput(ns("trend"), height = "340px"),
    htmltools::p(class = "env-figure-text", shiny::textOutput(ns("trend_text"),
                                                              inline = TRUE))
  )
}


# Small HTML helpers -----------------------------------------------------------

# One summary box for a half of the month.
half_tile <- function(row) {
  status_line <- if (row$remaining_cents < 0) {
    htmltools::p(class = "env-tile-over",
                 paste("Over by", format_money(-row$remaining_cents)))
  } else {
    htmltools::p(class = "env-tile-line",
                 paste(format_money(row$remaining_cents), "left"))
  }
  htmltools::div(
    class = "env-tile",
    htmltools::h3(class = "env-tile-title", row$period_label),
    htmltools::p(class = "env-tile-line",
                 paste(format_money(row$budget_cents), "planned")),
    htmltools::p(class = "env-tile-big",
                 paste(format_money(row$spent_cents), "spent")),
    status_line
  )
}

# One table cell: the main text, plus "Over by" on its own line if needed.
half_cell <- function(budget_cents, spent_cents, remaining_cents) {
  over <- over_text(remaining_cents)
  htmltools::tags$td(
    half_cell_text(budget_cents, spent_cents),
    if (!is.na(over)) htmltools::tagList(
      htmltools::tags$br(),
      htmltools::span(class = "env-over-text", over)
    )
  )
}

# The table: one row per spending envelope, a column for each half.
half_table <- function(half_summary, month) {
  ids <- unique(half_summary$envelope_id)
  rows <- lapply(ids, function(id) {
    first  <- half_summary[half_summary$envelope_id == id &
                             half_summary$period == "first", ]
    second <- half_summary[half_summary$envelope_id == id &
                             half_summary$period == "second", ]
    htmltools::tags$tr(
      htmltools::tags$th(scope = "row", first$name),
      half_cell(first$budget_cents, first$spent_cents, first$remaining_cents),
      half_cell(second$budget_cents, second$spent_cents, second$remaining_cents)
    )
  })
  # table-responsive lets the table scroll sideways on a narrow phone.
  htmltools::div(
    class = "table-responsive",
    htmltools::tags$table(
      class = "table env-half-table",
      htmltools::tags$caption(
        sprintf("Spending by half of the month, %s", month_label(month))
      ),
      htmltools::tags$thead(htmltools::tags$tr(
        htmltools::tags$th(scope = "col", "Envelope"),
        htmltools::tags$th(scope = "col", HALF_LABELS[["first"]]),
        htmltools::tags$th(scope = "col", HALF_LABELS[["second"]])
      )),
      htmltools::tags$tbody(rows)
    )
  )
}


# monthServer() ----------------------------------------------------------------
#   envelopes:    the clean envelope table
#   transactions: a reactive returning the current transactions
#   month:        a reactive returning the chosen "YYYY-MM" month
monthServer <- function(id, envelopes, transactions, month) {
  shiny::moduleServer(id, function(input, output, session) {

    # Step 1: the numbers for the chosen month.
    halves <- shiny::reactive(
      half_month_summary(envelopes, transactions(), month())
    )
    pace <- shiny::reactive(
      month_pace(envelopes, transactions(), month())
    )
    pace_text <- shiny::reactive(pace_summary_text(pace()))

    # Step 2: the two summary boxes.
    output$totals <- shiny::renderUI({
      totals <- half_month_totals(halves())
      htmltools::div(class = "env-tiles",
                     half_tile(totals[1, ]), half_tile(totals[2, ]))
    })

    # Step 3: the table.
    output$half_table <- shiny::renderUI(half_table(halves(), month()))

    # Step 4: the figure, with its alt text, and the same text below it.
    output$trend <- shiny::renderPlot(trend_plot(pace()), res = 96,
                                      alt = pace_text)
    output$trend_text <- shiny::renderText(pace_text())
  })
}
