event_required_columns <- function() c(
  "sequence", "date_start", "date_end", "date_precision", "location_id", "location_name",
  "latitude", "longitude", "position_type", "coordinate_basis", "position_uncertainty_nm",
  "movement_state", "event_category", "event_action", "historical_confidence",
  "include_default_map", "source_id", "source_locator", "source_url", "notes"
)

prepare_events <- function(events_raw) {
  missing <- setdiff(event_required_columns(), names(events_raw))
  if (length(missing)) stop("Event source is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  events_raw |>
    dplyr::mutate(
      sequence = as.integer(.data$sequence),
      date_start = parse_date_safely(.data$date_start),
      date_end = parse_date_safely(.data$date_end),
      date_end = dplyr::coalesce(.data$date_end, .data$date_start),
      latitude = as.numeric(.data$latitude),
      longitude = as.numeric(.data$longitude),
      position_uncertainty_nm = as.numeric(.data$position_uncertainty_nm),
      include_default_map = parse_flag(.data$include_default_map),
      dplyr::across(dplyr::where(is.character), na_if_blank)
    ) |>
    dplyr::arrange(.data$sequence, .data$date_start)
}

prepare_locations <- function(events) {
  events |>
    dplyr::group_by(.data$location_id, .data$location_name) |>
    dplyr::summarise(
      latitude = dplyr::first(stats::na.omit(.data$latitude)),
      longitude = dplyr::first(stats::na.omit(.data$longitude)),
      coordinate_basis = paste(unique(stats::na.omit(.data$coordinate_basis)), collapse = "; "),
      maximum_uncertainty_nm = max(.data$position_uncertainty_nm, na.rm = TRUE),
      event_count = dplyr::n(),
      coordinate_variants = dplyr::n_distinct(paste(.data$latitude, .data$longitude)),
      .groups = "drop"
    ) |>
    dplyr::mutate(maximum_uncertainty_nm = dplyr::if_else(is.infinite(.data$maximum_uncertainty_nm), NA_real_, .data$maximum_uncertainty_nm))
}

events_as_sf <- function(events, crs = 4326) {
  sf::st_as_sf(events, coords = c("longitude", "latitude"), crs = crs, remove = FALSE)
}

locations_as_sf <- function(locations, crs = 4326) {
  sf::st_as_sf(locations, coords = c("longitude", "latitude"), crs = crs, remove = FALSE)
}

build_operating_regions <- function(uncertainty_areas) {
  if (!nrow(uncertainty_areas)) return(uncertainty_areas[0, ])
  uncertainty_areas |>
    dplyr::mutate(
      region_name = dplyr::case_when(
        grepl("Iwo Jima", paste(.data$location_name, .data$event_category), ignore.case = TRUE) ~ "Iwo Jima operating area",
        grepl("Okinawa|Kerama", paste(.data$location_name, .data$event_category), ignore.case = TRUE) ~ "Okinawa–Kerama operating area",
        grepl("Occupation", paste(.data$location_name, .data$event_category), ignore.case = TRUE) ~ "Postwar occupation operating area",
        TRUE ~ NA_character_
      )
    ) |>
    dplyr::filter(!is.na(.data$region_name)) |>
    dplyr::group_by(.data$region_name) |>
    dplyr::summarise(
      date_start = min(.data$date_start, na.rm = TRUE),
      date_end = max(.data$date_end, na.rm = TRUE),
      event_count = dplyr::n(),
      region_method = "Union of source event uncertainty circles; interpretive summary, not an operational boundary",
      .groups = "drop"
    )
}
