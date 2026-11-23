# mod_month_picker.R
# The month picker as its own small module, shared by both tabs
# (decision 37). It returns the chosen month as a reactive, and moves to a
# new month when the logging form saves an entry (decision 32).


# monthPickerUI() --------------------------------------------------------------
#   months:   the "YYYY-MM" months to offer
#   selected: the month to open on (decision 8: the latest month in the data)
monthPickerUI <- function(id, months, selected) {
  ns <- shiny::NS(id)
  # The label is shown ("October 2026"); the value is used ("2026-10").
  choices <- stats::setNames(months, month_label(months))
  shiny::selectInput(ns("month"), "Month", choices = choices,
                     selected = selected, width = "240px")
}


# monthPickerServer() ----------------------------------------------------------
#   jump_to: optional reactive returning list(month, count) after each save
# Returns a reactive giving the chosen "YYYY-MM" month.
monthPickerServer <- function(id, jump_to = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    if (!is.null(jump_to)) {
      shiny::observeEvent(jump_to(), {
        shiny::updateSelectInput(session, "month", selected = jump_to()$month)
      })
    }
    shiny::reactive({
      shiny::req(input$month)
      input$month
    })
  })
}
