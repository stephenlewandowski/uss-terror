build_timeline_plot <- function(events, source = "terror_timeline") {
  if (!nrow(events)) return(plotly::plot_ly() |> plotly::layout(title = "No events in the selected range"))
  dat <- events |>
    dplyr::mutate(
      y = factor(.data$location_name, levels = rev(unique(.data$location_name))),
      hover = paste0(
        "<b>", .data$location_name, "</b><br>",
        format_event_date(.data$date_start, .data$date_end, .data$date_precision), "<br>",
        .data$event_category, " — confidence: ", .data$historical_confidence, "<br>",
        .data$event_action
      )
    )
  timeline_colors <- grDevices::hcl.colors(max(3L, length(unique(dat$event_category))), palette = "Dynamic")
  plotly::plot_ly(dat, source = source, key = ~sequence, colors = timeline_colors) |>
    plotly::add_segments(x = ~date_start, xend = ~date_end, y = ~y, yend = ~y,
                         color = ~event_category, text = ~hover, hoverinfo = "text",
                         line = list(width = 5), showlegend = FALSE) |>
    plotly::add_markers(x = ~date_start, y = ~y, color = ~event_category,
                        symbol = ~historical_confidence, text = ~hover, hoverinfo = "text",
                        marker = list(size = 9, line = list(width = 1, color = "#222"))) |>
    plotly::layout(
      xaxis = list(title = "Date", rangeslider = list(visible = TRUE)),
      yaxis = list(title = "Location", automargin = TRUE),
      legend = list(orientation = "h", y = -0.28),
      margin = list(l = 150, r = 20, t = 20, b = 100),
      hovermode = "closest"
    ) |>
    plotly::event_register("plotly_click")
}
