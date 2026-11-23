# app.R
# Envelope Budget: a demonstration Shiny app with fictional data.
#
# Run it from RStudio with the "Run App" button, or from the console with
# shiny::runApp(). Shiny automatically sources every file in R/ before this
# one runs, so the logic functions and modules are already loaded here.

library(shiny)
library(bslib)

# Step 1: load the fictional demo data once, when the app starts.
envelopes         <- read_envelopes("data/demo_envelopes.csv")
demo_transactions <- read_transactions("data/demo_transactions.csv", envelopes)

# Step 2: the months the picker offers, oldest first, and the dates the
# logging form allows: the first through the last day of those months
# (decision 30).
months     <- sort(unique(month_key(demo_transactions$date)))
date_range <- month_bounds(months)

# Where the source code lives, for the footer.
REPO_URL <- "https://github.com/lwylie01/envelope-budget"

# Step 3: the page: the logging form, the shared month picker, then two tabs
# (decision 37). bs_theme() with the plain Bootstrap 5 preset uses each
# device's own system font, so nothing extra downloads (decision 24).
ui <- page_fluid(
  theme = bs_theme(version = 5, preset = "bootstrap"),
  lang = "en",
  title = "Envelope Budget",
  tags$head(tags$link(rel = "stylesheet", href = "styles.css")),
  tags$main(
    class = "env-page",
    h1("Envelope Budget"),
    p(class = "env-intro",
      "A demonstration of envelope budgeting. Every name and amount is",
      "fictional."),
    loggingUI("logging", envelopes,
              default_date = max(demo_transactions$date),
              date_range = date_range),
    div(class = "env-picker",
        monthPickerUI("picker", months = months,
                      selected = latest_month(demo_transactions))),
    navset_underline(
      nav_panel("Envelopes", envelopesUI("envelopes")),
      nav_panel("Month View", monthUI("month"))
    ),
    # Step 3b: the footer (decision 56). The links are styled in styles.css
    # with an underline, so they do not rely on color to look like links.
    tags$footer(
      class = "env-footer",
      p("Fictional data. Runs entirely in your browser; nothing is sent anywhere.",
        a("Source code", href = REPO_URL), "and",
        a("design log", href = paste0(REPO_URL, "/blob/main/DECISIONS.md")),
        "on GitHub.")
    )
  )
)

# Step 4: the server. Each visitor gets their own copy of the transactions,
# held only for this visit (decision 34). The logging form changes it; the
# picker follows each save to its month; both tabs redraw from it.
server <- function(input, output, session) {
  transactions <- reactiveVal(demo_transactions)
  saved_month  <- loggingServer("logging", envelopes, transactions,
                                demo_transactions, date_range)
  month        <- monthPickerServer("picker", jump_to = saved_month)
  envelopesServer("envelopes", envelopes, transactions, month)
  monthServer("month", envelopes, transactions, month)
}

shinyApp(ui, server)
