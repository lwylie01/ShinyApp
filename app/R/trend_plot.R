# trend_plot.R
# The spending-pace figure (decisions 40 and 43), drawn with ggplot2.
#
# Two lines, told apart without color:
#   - spending so far: a solid dark line
#   - money planned so far: a dashed gray step line that rises on the 15th
# Each line is labeled directly at its right end, so there is no legend to
# decode, and the 15th is marked with a labeled dotted line.
#
# The function takes month_pace() output and returns a ggplot object, so
# tests can inspect its layers without drawing anything.

# Line colors. Both clear 3:1 against white, the WCAG minimum for graphics.
PACE_COLORS <- c(spent = "#212529", planned = "#6c757d")

# Axis labels: whole dollars with commas ("$1,500") and short dates ("Nov 15").
# Built here so the app needs no extra package for formatting.
dollar_axis <- function(x) {
  ifelse(is.na(x), NA, paste0("$", formatC(x, format = "d", big.mark = ",")))
}
short_date_axis <- function(x) {
  ifelse(is.na(x), NA, paste(format(x, "%b"), as.integer(format(x, "%d"))))
}

trend_plot <- function(pace) {
  # Step 1: work in dollars for the axis (the numbers were added in cents).
  pace$spent   <- from_cents(pace$spent_cents)
  pace$planned <- from_cents(pace$planned_cents)
  last <- pace[nrow(pace), ]

  # Step 2: where the 15th falls, if the drawn days reach it.
  fifteenth <- as.Date(paste0(format(pace$date[1], "%Y-%m"), "-15"))
  show_15th <- fifteenth <= last$date

  # Step 3: label positions at the right end. If the two lines end close
  # together, push the labels apart so they do not overlap.
  top <- max(c(pace$spent, pace$planned))
  y_spent <- last$spent
  y_planned <- last$planned
  gap <- top * 0.08
  if (abs(y_spent - y_planned) < gap) {
    if (y_spent >= y_planned) {
      y_spent <- y_planned + gap
    } else {
      y_spent <- y_planned - gap
    }
  }

  # Step 4: build the plot, one layer at a time.
  p <- ggplot2::ggplot(pace, ggplot2::aes(x = date)) +
    # Planned so far: dashed steps.
    ggplot2::geom_step(ggplot2::aes(y = planned), direction = "hv",
                       linetype = "dashed", linewidth = 0.9,
                       color = PACE_COLORS[["planned"]]) +
    # Spending so far: a solid line.
    ggplot2::geom_line(ggplot2::aes(y = spent), linewidth = 1.2,
                       color = PACE_COLORS[["spent"]]) +
    # Direct labels instead of a legend.
    ggplot2::annotate("text", x = last$date + 0.6, y = y_spent,
                      label = "Spent", hjust = 0, size = 4.6,
                      fontface = "bold", color = PACE_COLORS[["spent"]]) +
    ggplot2::annotate("text", x = last$date + 0.6, y = y_planned,
                      label = "Planned", hjust = 0, size = 4.6,
                      color = PACE_COLORS[["planned"]]) +
    ggplot2::scale_y_continuous(labels = dollar_axis, limits = c(0, NA),
                                expand = ggplot2::expansion(mult = c(0, 0.08))) +
    # Three date labels, the ones the split turns on: the 1st, the 15th (when
    # drawn), and the last day drawn. More would crowd together on a phone.
    ggplot2::scale_x_date(breaks = unique(c(pace$date[1],
                                            if (show_15th) fifteenth,
                                            last$date)),
                          labels = short_date_axis,
                          expand = ggplot2::expansion(mult = c(0.02, 0.01))) +
    ggplot2::labs(x = NULL, y = NULL) +
    # The labels sit outside the plotting area, in a fixed right margin, so
    # they fit at a phone's width as well as a laptop's.
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::theme_minimal(base_size = 15) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   axis.text = ggplot2::element_text(color = "#495057"),
                   plot.margin = ggplot2::margin(t = 8, r = 72, b = 4, l = 4))

  # Step 5: the 15th, as a labeled dotted line.
  if (show_15th) {
    p <- p +
      ggplot2::geom_vline(xintercept = fifteenth, linetype = "dotted",
                          color = "#495057") +
      ggplot2::annotate("text", x = fifteenth + 0.4, y = top * 1.05,
                        label = "15th", hjust = 0, size = 4.2,
                        color = "#495057")
  }
  p
}
