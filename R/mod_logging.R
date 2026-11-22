# mod_logging.R
# The logging form as a Shiny module: add a transaction, see a confirmation,
# and remove entries made during this visit.
#
# The module does not own the transactions. app.R holds them in a single
# reactiveVal() and hands it to both this module and the envelope module, so
# a save here updates the cards there.


# loggingUI() ------------------------------------------------------------------
#   envelopes:    the clean envelope table, for the envelope list
#   default_date: the date the form starts on (decision 30)
#   date_range:   list(min, max) of allowed dates
loggingUI <- function(id, envelopes, default_date, date_range) {
  ns <- shiny::NS(id)

  # Envelope list grouped into Spending and Sinking funds (decision 31).
  # as.list() keeps a group even when it holds a single envelope.
  group <- function(type) {
    rows <- envelopes[envelopes$type == type, ]
    as.list(stats::setNames(rows$envelope_id, rows$name))
  }
  choices <- list(Spending = group("spending"), `Sinking funds` = group("sinking"))

  # The amount box brings up the number keypad on phones (decision 29).
  amount_box <- htmltools::tagAppendAttributes(
    shiny::textInput(ns("amount"), "Amount", placeholder = "12.50"),
    inputmode = "decimal", autocomplete = "off", .cssSelector = "input"
  )
  # The browser stops typing at 100 characters; the server checks again.
  note_box <- htmltools::tagAppendAttributes(
    shiny::textInput(ns("note"), "Note (optional)"),
    maxlength = NOTE_MAX_CHARS, autocomplete = "off", .cssSelector = "input"
  )

  htmltools::tags$section(
    class = "env-form",
    `aria-labelledby` = ns("heading"),
    htmltools::h2(id = ns("heading"), "Log Spending"),

    # Step 1: the fields, laid out in a grid that stacks on a phone.
    htmltools::div(
      class = "env-form-grid",
      shiny::selectInput(ns("envelope"), "Envelope", choices = choices),
      amount_box,
      shiny::radioButtons(ns("kind"), "Type",
                          choices = c(Spending = "spending", Refund = "refund"),
                          inline = TRUE),
      shiny::dateInput(ns("date"), "Date", value = default_date,
                       min = date_range$min, max = date_range$max,
                       format = "yyyy-mm-dd"),
      note_box
    ),

    # Step 2: save, then the message. The message area exists from the start
    # and is aria-live, so screen readers read each new message aloud.
    shiny::actionButton(ns("save"), "Save", class = "btn-primary"),
    htmltools::div(class = "env-message", `aria-live` = "polite",
                   shiny::uiOutput(ns("message"))),
    htmltools::p(class = "env-summary",
                 "Entries stay only until you close or reload this page."),

    # Step 3: what was logged during this visit, with a way to undo.
    htmltools::h3(class = "env-subheading", "Logged This Session"),
    shiny::uiOutput(ns("session_list")),
    shiny::actionButton(ns("reset"), "Reset to demo data",
                        class = "btn-outline-secondary btn-sm")
  )
}


# loggingServer() --------------------------------------------------------------
#   envelopes:         the clean envelope table
#   transactions:      the shared reactiveVal() holding every transaction
#   demo_transactions: the original demo table, restored by Reset
#   date_range:        list(min, max) of allowed dates
# Returns a reactive giving the month of the latest save, so the envelope
# module can jump to it (decision 32).
loggingServer <- function(id, envelopes, transactions, demo_transactions,
                          date_range) {
  shiny::moduleServer(id, function(input, output, session) {

    # Step 1: state for this visit.
    notice   <- shiny::reactiveVal(NULL)   # list(text, kind) or NULL
    jump     <- shiny::reactiveVal(NULL)   # list(month, count) after a save
    used_max <- 0                          # highest session id used so far

    # Step 2: Save. add_transaction() checks everything; any problem comes
    # back as an error whose message is shown instead of saving.
    shiny::observeEvent(input$save, {
      result <- tryCatch(
        add_transaction(transactions(), envelopes,
                        envelope_id = input$envelope,
                        amount_text = input$amount,
                        kind        = input$kind,
                        date        = input$date,
                        note        = input$note,
                        date_range  = date_range,
                        used_max    = used_max),
        error = function(e) e
      )
      if (inherits(result, "error")) {
        notice(list(text = form_message(result), kind = "error"))
        return()
      }

      # Saved: store the table, confirm, and remember the id number used.
      transactions(result)
      entry <- result[nrow(result), ]
      used_max <<- as.integer(sub("^s", "", entry$transaction_id))
      notice(list(text = confirmation_text(entry, envelopes, result),
                   kind = "success"))

      # Ask the envelope view to show the entry's month. The count makes each
      # save a new value, so it jumps even when the month is the same.
      jump(list(month = month_key(entry$date), count = used_max))

      # Clear amount and note; keep envelope and date for the next entry.
      shiny::updateTextInput(session, "amount", value = "")
      shiny::updateTextInput(session, "note", value = "")
    })

    # Step 3: Remove. Each Remove button sends its entry's id as input$remove.
    shiny::observeEvent(input$remove, {
      transactions(remove_transaction(transactions(), input$remove))
      notice(list(text = "Entry removed.", kind = "success"))
    })

    # Step 4: Reset to the demo data.
    shiny::observeEvent(input$reset, {
      transactions(demo_transactions)
      notice(list(text = "Reset to the demo data. Entries from this visit were removed.",
                   kind = "success"))
    })

    # Step 5: the message. An error starts with "Not saved:" so it does not
    # rely on its color.
    output$message <- shiny::renderUI({
      m <- notice()
      if (is.null(m)) return(NULL)
      if (m$kind == "error") {
        htmltools::p(class = "env-message-error",
                     htmltools::strong("Not saved: "), m$text)
      } else {
        htmltools::p(class = "env-message-success", m$text)
      }
    })

    # Step 6: the list of this visit's entries, newest first.
    output$session_list <- shiny::renderUI({
      entries <- session_entries(transactions())
      if (nrow(entries) == 0) {
        return(htmltools::p(class = "env-summary", "Nothing logged yet."))
      }
      entries <- entries[rev(seq_len(nrow(entries))), ]
      names <- envelopes$name[match(entries$envelope_id, envelopes$envelope_id)]
      items <- lapply(seq_len(nrow(entries)), function(i) {
        e <- entries[i, ]
        amount <- if (e$amount_cents < 0) {
          paste("Refund", format_money(-e$amount_cents))
        } else {
          format_money(e$amount_cents)
        }
        label <- paste(c(format_long_date(e$date), names[i], amount,
                         if (nzchar(e$note)) e$note), collapse = " · ")
        htmltools::tags$li(
          class = "env-entry",
          # htmltools escapes this text, so a note is always plain text.
          htmltools::span(label),
          htmltools::tags$button(
            type = "button", class = "btn btn-sm btn-outline-secondary",
            `aria-label` = paste("Remove", label),
            # Ids are generated by the app (s001, s002, ...), never typed in.
            onclick = sprintf(
              "Shiny.setInputValue('%s', '%s', {priority: 'event'})",
              session$ns("remove"), e$transaction_id
            ),
            "Remove"
          )
        )
      })
      htmltools::tags$ul(class = "env-entries", items)
    })

    # Step 7: hand the latest save's month to app.R.
    shiny::reactive(jump())
  })
}
