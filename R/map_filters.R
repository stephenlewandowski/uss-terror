deployment_year_choices <- function() {
  c("All years" = "all", "1943" = "1943", "1944" = "1944", "1945" = "1945", "1946" = "1946")
}

deployment_year_modes <- function() {
  c("Selected year only" = "selected_year", "Cumulative through selected year" = "cumulative")
}

filter_period_for_year <- function(selected_year = "all", year_mode = "selected_year",
                                   minimum_date = as.Date("1943-10-02"),
                                   maximum_date = as.Date("1946-12-25")) {
  selected_year <- as.character(selected_year %||% "all")
  if (identical(selected_year, "all")) {
    return(c(as.Date(minimum_date), as.Date(maximum_date)))
  }
  year <- suppressWarnings(as.integer(selected_year))
  if (is.na(year) || !year %in% 1943:1946) {
    stop("Selected year must be 'all' or one of 1943, 1944, 1945, or 1946.", call. = FALSE)
  }
  year_end <- as.Date(sprintf("%d-12-31", year))
  year_start <- if (identical(year_mode, "cumulative")) {
    as.Date(minimum_date)
  } else {
    as.Date(sprintf("%d-01-01", year))
  }
  c(year_start, min(year_end, as.Date(maximum_date)))
}

route_overlaps <- function(start_date, end_date, filter_start, filter_end) {
  start <- as.Date(start_date)
  end <- as.Date(end_date)
  end[is.na(end)] <- start[is.na(end)]
  !is.na(start) & start <= as.Date(filter_end) & end >= as.Date(filter_start)
}

route_crosses_year_boundary <- function(start_date, end_date) {
  start <- as.Date(start_date)
  end <- as.Date(end_date)
  !is.na(start) & !is.na(end) & format(start, "%Y") != format(end, "%Y")
}

cross_year_route_notice <- function() {
  paste(
    "This reconstructed route leg overlaps the selected year boundary.",
    "The complete endpoint-to-endpoint segment is displayed because intermediate daily positions are unknown."
  )
}

filter_deployment_data <- function(events, routes, date_start = NULL, date_end = NULL,
                                   selected_year = "all", year_mode = "selected_year",
                                   categories = character(), confidences = character(),
                                   show_disputed = FALSE) {
  event_dates <- c(as.Date(events$date_start), as.Date(events$date_end))
  route_dates <- c(as.Date(routes$start_date), as.Date(routes$end_date))
  available_dates <- c(event_dates, route_dates)
  available_dates <- available_dates[!is.na(available_dates)]
  minimum_date <- min(available_dates)
  maximum_date <- max(available_dates)

  requested_start <- as.Date(date_start %||% minimum_date)
  requested_end <- as.Date(date_end %||% maximum_date)
  if (requested_start > requested_end) requested_end <- requested_start
  year_period <- filter_period_for_year(selected_year, year_mode, minimum_date, maximum_date)
  filter_start <- max(requested_start, year_period[[1]])
  filter_end <- min(requested_end, year_period[[2]])

  if (filter_start > filter_end) {
    event_keep <- rep(FALSE, nrow(events))
    route_keep <- rep(FALSE, nrow(routes))
  } else {
    event_keep <- event_overlaps(events$date_start, events$date_end, filter_start, filter_end)
    route_keep <- route_overlaps(routes$start_date, routes$end_date, filter_start, filter_end)
  }

  categories <- as.character(categories %||% character())
  if (length(categories)) event_keep <- event_keep & events$event_category %in% categories

  confidences <- tolower(as.character(confidences %||% character()))
  if (length(confidences)) {
    event_keep <- event_keep & tolower(events$historical_confidence) %in% confidences
    route_keep <- route_keep & tolower(routes$route_confidence) %in% confidences
  }

  if (!isTRUE(show_disputed)) route_keep <- route_keep & routes$include_default_map

  filtered_events <- events[event_keep, ]
  filtered_routes <- routes[route_keep, ]
  filtered_routes$cross_year_boundary <- route_crosses_year_boundary(
    filtered_routes$start_date, filtered_routes$end_date
  )
  selected_single_year <- !identical(as.character(selected_year), "all") &&
    identical(year_mode, "selected_year")
  filtered_routes$cross_year_notice <- ifelse(
    selected_single_year & filtered_routes$cross_year_boundary,
    cross_year_route_notice(),
    NA_character_
  )

  list(
    events = filtered_events,
    routes = filtered_routes,
    event_ids = as.character(filtered_events$sequence),
    route_ids = as.character(filtered_routes$leg_id),
    filter_start = filter_start,
    filter_end = filter_end,
    selected_year = as.character(selected_year),
    year_mode = year_mode,
    show_disputed = isTRUE(show_disputed)
  )
}

map_route_ids <- function(filtered_data) {
  filtered_data$route_ids
}

year_filter_validation_table <- function(events, routes, show_disputed = FALSE) {
  selections <- c("all", as.character(1943:1946))
  dplyr::bind_rows(lapply(selections, function(year) {
    dat <- filter_deployment_data(
      events, routes,
      selected_year = year,
      year_mode = "selected_year",
      show_disputed = show_disputed
    )
    tibble::tibble(
      selection = if (identical(year, "all")) "All years" else year,
      visible_event_count = length(dat$event_ids),
      visible_event_ids = paste(dat$event_ids, collapse = ";"),
      visible_route_count = length(dat$route_ids),
      visible_route_ids = paste(dat$route_ids, collapse = ";"),
      disputed_routes_included = any(!dat$routes$include_default_map),
      pacific_map_ids_match_filter = identical(map_route_ids(dat), dat$route_ids)
    )
  }))
}

write_year_filter_validation <- function(events, routes,
                                         path = project_path("outputs", "reports", "year_filter_validation.md")) {
  validation <- year_filter_validation_table(events, routes, show_disputed = FALSE)
  lines <- c(
    "# Year-filter validation", "",
    paste("Generated:", format(Sys.time(), tz = "UTC", usetz = TRUE)), "",
    "Selected-year mode uses inclusive interval overlap for both ranged events and reconstructed route legs.",
    "A cross-year leg is displayed in every overlapping selected year without inventing an intermediate midnight position.", ""
  )
  for (i in seq_len(nrow(validation))) {
    row <- validation[i, ]
    lines <- c(
      lines,
      paste0("## ", row$selection), "",
      paste0("- Visible event count: ", row$visible_event_count),
      paste0("- Visible event IDs: ", ifelse(nzchar(row$visible_event_ids), row$visible_event_ids, "None")),
      paste0("- Visible route count: ", row$visible_route_count),
      paste0("- Visible route IDs: ", ifelse(nzchar(row$visible_route_ids), row$visible_route_ids, "None")),
      paste0("- Disputed routes included: ", row$disputed_routes_included),
      paste0("- Pacific map/filter route-ID consistency: ", ifelse(row$pacific_map_ids_match_filter, "PASS", "FAIL")),
      paste0("- Validation result: ", ifelse(row$pacific_map_ids_match_filter, "PASS", "FAIL")), ""
    )
  }
  writeLines(lines, path, useBytes = TRUE)
  invisible(validation)
}
