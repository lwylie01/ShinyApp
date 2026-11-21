# app.R
# Envelope Budget: a demonstration Shiny app with fictional data.
#
# Run it from RStudio with the "Run App" button, or from the console with
# shiny::runApp(). Shiny automatically sources every file in R/ before this
# one runs, so the logic functions and modules are already loaded here.

library(shiny)
library(bslib)

# Step 1: load the fictional demo data once, when the app starts.
envelopes    <- read_envelopes("data/demo_envelopes.csv")
transactions <- read_transactions("data/demo_transactions.csv", envelopes)

# Step 2: the months the picker offers, oldest first, opening on the latest.
months <- sort(unique(month_key(transactions$date)))

# Step 3: the page. bs_theme() with the plain Bootstrap 5 preset uses each
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
    envelopesUI("envelopes", months = months, selected = latest_month(transactions))
  )
)

# Step 4: the server connects the module to the data.
server <- function(input, output, session) {
  envelopesServer("envelopes", envelopes, transactions)
}

shinyApp(ui, server)
