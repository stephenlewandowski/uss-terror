route_required_columns <- function() c(
  "leg_id", "sequence", "start_date", "end_date", "start_location_id", "start_location",
  "start_latitude", "start_longitude", "end_location_id", "end_location", "end_latitude",
  "end_longitude", "source_status", "date_confidence", "route_confidence",
  "include_default_map", "source_id", "source_locator", "source_url", "notes"
)

prepare_routes <- function(routes_raw) {
  missing <- setdiff(route_required_columns(), names(routes_raw))
  if (length(missing)) stop("Route source is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  out <- routes_raw |>
    dplyr::mutate(
      sequence = as.integer(.data$sequence),
      start_date = parse_date_safely(.data$start_date),
      end_date = parse_date_safely(.data$end_date),
      dplyr::across(c("start_latitude", "start_longitude", "end_latitude", "end_longitude"), as.numeric),
      include_default_map = parse_flag(.data$include_default_map),
      source_duration_days = suppressWarnings(as.numeric(.data$duration_days)),
      source_great_circle_nm = suppressWarnings(as.numeric(.data$great_circle_nm)),
      source_implied_avg_speed_kn = suppressWarnings(as.numeric(.data$implied_avg_speed_kn)),
      duration_days = as.numeric(.data$end_date - .data$start_date),
      great_circle_nm = geosphere::distGeo(
        cbind(.data$start_longitude, .data$start_latitude),
        cbind(.data$end_longitude, .data$end_latitude)
      ) / 1852,
      implied_avg_speed_kn = dplyr::if_else(.data$duration_days > 0,
        .data$great_circle_nm / (.data$duration_days * 24), NA_real_),
      dplyr::across(dplyr::where(is.character), na_if_blank)
    ) |>
    dplyr::arrange(.data$sequence)
  out
}
