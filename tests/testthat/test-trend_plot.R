# Tests for R/trend_plot.R. The figure is checked by its layers, not by how
# its pixels look, so the tests do not depend on fonts or the screen.

layer_types <- function(p) {
  unname(vapply(p$layers, function(l) class(l$geom)[1], character(1)))
}

test_that("axis labels read as dollars and short dates", {
  expect_equal(dollar_axis(c(0, 1500, NA)), c("$0", "$1,500", NA))
  expect_equal(short_date_axis(as.Date(c("2026-11-01", "2026-11-15"))),
               c("Nov 1", "Nov 15"))
})

test_that("the figure has a dashed plan, a solid spending line, and labels", {
  pace <- month_pace(fixture_envelopes(), fixture_transactions(), "2026-10")
  p <- trend_plot(pace)
  types <- layer_types(p)
  expect_equal(types[1:2], c("GeomStep", "GeomLine"))
  # The two lines differ by line type, not only color.
  expect_equal(p$layers[[1]]$aes_params$linetype, "dashed")
  expect_null(p$layers[[2]]$aes_params$linetype)
  # Direct labels instead of a legend.
  labels <- unlist(lapply(p$layers, function(l) l$aes_params$label))
  expect_true(all(c("Spent", "Planned", "15th") %in% labels))
  expect_true("GeomVline" %in% types)
})

test_that("the 15th is left off when the drawn days stop before it", {
  pace <- month_pace(fixture_envelopes(), fixture_transactions(), "2026-11")
  p <- trend_plot(pace)
  expect_false("GeomVline" %in% layer_types(p))
})

test_that("the figure draws without errors or warnings", {
  pace <- month_pace(fixture_envelopes(), fixture_transactions(), "2026-10")
  path <- tempfile(fileext = ".png")
  grDevices::png(path)
  expect_silent(print(trend_plot(pace)))
  grDevices::dev.off()
  unlink(path)
})
