# Tests for R/mod_month_picker.R.

test_that("the picker offers the months it is given and opens on the latest", {
  html <- as.character(monthPickerUI("picker", months = c("2026-09", "2026-10"),
                                     selected = "2026-10"))
  expect_match(html, "September 2026", fixed = TRUE)
  expect_match(html, '<option value="2026-10" selected>', fixed = TRUE)
})

test_that("the picker returns the chosen month", {
  shiny::testServer(monthPickerServer, {
    session$setInputs(month = "2026-10")
    expect_equal(session$returned(), "2026-10")
    session$setInputs(month = "2026-09")
    expect_equal(session$returned(), "2026-09")
  })
})
