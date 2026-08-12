event_table_data <- function(events) {
  events |>
    sf::st_drop_geometry() |>
    dplyr::transmute(
      sequence, date_start, date_end, date_precision, location_name,
      event_category, event_action, historical_confidence,
      coordinate_basis, position_uncertainty_nm, source_id, source_locator,
      estimated = .data$date_precision != "day" | grepl("model|centroid|estimated|approx", .data$coordinate_basis, ignore.case = TRUE),
      included = .data$include_default_map
    )
}

route_table_data <- function(routes, maximum_speed = 23) {
  routes |>
    sf::st_drop_geometry() |>
    dplyr::transmute(
      leg_id, start_date, end_date, origin = start_location, destination = end_location,
      duration_days, great_circle_nm = round(.data$great_circle_nm, 1),
      implied_avg_speed_kn = round(.data$implied_avg_speed_kn, 1),
      speed_review = .data$implied_avg_speed_kn > maximum_speed,
      route_confidence, source_status, included = .data$include_default_map,
      source_id, source_locator
    )
}
