new_issue_table <- function() {
  tibble::tibble(
    severity = character(), check = character(), record_type = character(),
    record_id = character(), message = character()
  )
}

validate_data <- function(events, routes, locations, geojson_raw = NULL,
                          geodesic_routes = NULL, uncertainty_areas = NULL,
                          settings = load_settings()) {
  issues <- new_issue_table()
  add_issue <- function(severity, check, record_type, record_id, message) {
    n <- max(length(record_id), length(message), 1L)
    issues <<- dplyr::bind_rows(issues, tibble::tibble(
      severity = rep(severity, n), check = rep(check, n), record_type = rep(record_type, n),
      record_id = rep(as.character(record_id), length.out = n),
      message = rep(as.character(message), length.out = n)
    ))
  }

  bad_dates <- is.na(events$date_start) | is.na(events$date_end)
  if (any(bad_dates)) add_issue("error", "event_date_parse", "event", events$sequence[bad_dates], "Start or end date did not parse.")
  reversed <- !bad_dates & events$date_end < events$date_start
  if (any(reversed)) add_issue("error", "event_date_order", "event", events$sequence[reversed], "date_end is before date_start.")
  bad_event_coord <- !is.finite(events$latitude) | events$latitude < -90 | events$latitude > 90 |
    !is.finite(events$longitude) | events$longitude < -180 | events$longitude > 180
  if (any(bad_event_coord)) add_issue("error", "event_coordinate_bounds", "event", events$sequence[bad_event_coord], "Event coordinate is missing or outside WGS84 bounds.")
  bad_route_coord <- !is.finite(routes$start_latitude) | routes$start_latitude < -90 | routes$start_latitude > 90 |
    !is.finite(routes$end_latitude) | routes$end_latitude < -90 | routes$end_latitude > 90 |
    !is.finite(routes$start_longitude) | routes$start_longitude < -180 | routes$start_longitude > 180 |
    !is.finite(routes$end_longitude) | routes$end_longitude < -180 | routes$end_longitude > 180
  if (any(bad_route_coord)) add_issue("error", "route_coordinate_bounds", "route_leg", routes$leg_id[bad_route_coord], "Route endpoint is missing or outside WGS84 bounds.")

  valid_locations <- unique(events$location_id)
  invalid_refs <- !(routes$start_location_id %in% valid_locations) | !(routes$end_location_id %in% valid_locations)
  if (any(invalid_refs)) add_issue("error", "route_location_reference", "route_leg", routes$leg_id[invalid_refs], "Route endpoint does not reference an event location_id.")
  dup_seq <- duplicated(routes$sequence) | duplicated(routes$sequence, fromLast = TRUE)
  if (any(dup_seq)) add_issue("error", "route_sequence_unique", "route_leg", routes$leg_id[dup_seq], "Route sequence is duplicated.")
  if (is.unsorted(routes$sequence, strictly = TRUE)) add_issue("warning", "route_sequence_order", "route_leg", "all", "Route records were not supplied in strictly increasing sequence order.")

  missing_source_event <- is.na(events$source_id)
  if (any(missing_source_event)) add_issue("error", "event_source_id", "event", events$sequence[missing_source_event], "Event has no source_id.")
  missing_source_route <- is.na(routes$source_id)
  if (any(missing_source_route)) add_issue("error", "route_source_id", "route_leg", routes$leg_id[missing_source_route], "Route leg has no source_id.")
  missing_locator <- is.na(events$source_locator)
  if (any(missing_locator)) add_issue("warning", "missing_source_locator", "event", events$sequence[missing_locator], "Event has no source locator.")
  route_missing_locator <- is.na(routes$source_locator)
  if (any(route_missing_locator)) add_issue("warning", "missing_source_locator", "route_leg", routes$leg_id[route_missing_locator], "Route leg has no source locator.")

  bad_flag_event <- is.na(events$include_default_map)
  if (any(bad_flag_event)) add_issue("error", "default_map_flag", "event", events$sequence[bad_flag_event], "Event default-map flag did not parse.")
  bad_flag_route <- is.na(routes$include_default_map)
  if (any(bad_flag_route)) add_issue("error", "default_map_flag", "route_leg", routes$leg_id[bad_flag_route], "Route default-map flag did not parse.")

  estimated <- tolower(events$date_precision) != "day" | tolower(events$historical_confidence) %in% c("low", "medium") |
    grepl("model|centroid|estimated|approx", events$coordinate_basis, ignore.case = TRUE)
  unlabeled <- estimated & is.na(events$date_precision) & is.na(events$coordinate_basis) & is.na(events$historical_confidence)
  if (any(unlabeled, na.rm = TRUE)) add_issue("warning", "estimated_event_label", "event", events$sequence[unlabeled], "Estimated event lacks a precision, coordinate-basis, or confidence label.")

  excluded <- !routes$include_default_map
  if (!any(excluded, na.rm = TRUE)) add_issue("info", "excluded_route_preservation", "route_leg", "none", "No excluded route legs were supplied.")
  high_speed <- is.finite(routes$implied_avg_speed_kn) & routes$implied_avg_speed_kn > settings$maximum_plausible_speed_knots
  if (any(high_speed)) add_issue("warning", "implausible_speed", "route_leg", routes$leg_id[high_speed],
                                 sprintf("Implied average speed %.1f kn exceeds the %.1f kn review threshold.", routes$implied_avg_speed_kn[high_speed], settings$maximum_plausible_speed_knots))
  numeric_bad <- !is.finite(routes$great_circle_nm) | routes$great_circle_nm < 0 |
    (routes$duration_days > 0 & !is.finite(routes$implied_avg_speed_kn))
  if (any(numeric_bad)) add_issue("error", "route_numeric", "route_leg", routes$leg_id[numeric_bad], "Distance or speed calculation is not numerically valid.")
  low_conf <- tolower(routes$route_confidence) == "low"
  if (any(low_conf, na.rm = TRUE)) add_issue("warning", "low_route_confidence", "route_leg", routes$leg_id[low_conf], "Route confidence is low; retain for review and style as uncertain.")
  disputed <- grepl("disput|conflict|exclude|unsupported", routes$source_status, ignore.case = TRUE) | !routes$include_default_map
  if (any(disputed, na.rm = TRUE)) add_issue("warning", "disputed_or_excluded_route", "route_leg", routes$leg_id[disputed], "Route is disputed or excluded from the default map.")

  duplicate_event <- duplicated(events[c("date_start", "date_end", "location_id", "event_action")]) |
    duplicated(events[c("date_start", "date_end", "location_id", "event_action")], fromLast = TRUE)
  if (any(duplicate_event)) add_issue("warning", "duplicate_event", "event", events$sequence[duplicate_event], "Potential duplicate event record.")
  coord_variant <- locations$coordinate_variants > 1
  if (any(coord_variant, na.rm = TRUE)) add_issue("warning", "location_coordinate_consistency", "location", locations$location_id[coord_variant], "Location ID is associated with more than one coordinate pair.")

  ordered <- routes[order(routes$start_date, routes$end_date), ]
  overlap <- c(FALSE, ordered$start_date[-1] < ordered$end_date[-nrow(ordered)])
  if (any(overlap, na.rm = TRUE)) add_issue("warning", "route_interval_overlap", "route_leg", ordered$leg_id[overlap], "Route interval overlaps the preceding date-ordered route interval; review rather than sum durations blindly.")
  huge_uncertainty <- is.finite(events$position_uncertainty_nm) & events$position_uncertainty_nm > settings$large_uncertainty_nm
  if (any(huge_uncertainty)) add_issue("warning", "large_position_uncertainty", "event", events$sequence[huge_uncertainty], sprintf("Position uncertainty exceeds %s nautical miles.", settings$large_uncertainty_nm))

  if (!is.null(geojson_raw)) {
    invalid <- !sf::st_is_valid(geojson_raw)
    if (any(invalid)) add_issue("error", "geojson_geometry", "geojson_feature", which(invalid), "GeoJSON geometry is invalid.")
  }
  if (!is.null(geodesic_routes)) {
    invalid <- !sf::st_is_valid(geodesic_routes)
    if (any(invalid)) add_issue("error", "geodesic_geometry", "route_leg", geodesic_routes$leg_id[invalid], "Generated geodesic geometry is invalid.")
    wraps <- vapply(sf::st_geometry(geodesic_routes), geometry_has_wrap, logical(1))
    if (any(wraps)) add_issue("error", "antimeridian_global_wrap", "route_leg", geodesic_routes$leg_id[wraps], "Generated geometry contains a longitude jump greater than 180 degrees within a part.")
  }
  if (!is.null(uncertainty_areas) && nrow(uncertainty_areas)) {
    invalid <- !sf::st_is_valid(uncertainty_areas)
    if (any(invalid)) add_issue("error", "uncertainty_geometry", "event", uncertainty_areas$sequence[invalid], "Uncertainty polygon is invalid.")
  }
  dplyr::arrange(issues, factor(.data$severity, levels = c("error", "warning", "info")), .data$check, .data$record_id)
}

build_conflict_register <- function(issues) {
  issues |>
    dplyr::filter(.data$severity %in% c("error", "warning")) |>
    dplyr::transmute(
      conflict_id = sprintf("C%04d", dplyr::row_number()),
      record_type = .data$record_type,
      record_id = .data$record_id,
      issue_type = .data$check,
      severity = .data$severity,
      details = .data$message,
      resolution = "Retained for archival or modeling review; no silent correction applied."
    )
}

write_validation_report <- function(issues, counts, path = project_path("outputs", "reports", "validation_report.md")) {
  sev <- table(factor(issues$severity, levels = c("error", "warning", "info")))
  status <- if (unname(sev["error"]) == 0) "PASS with retained warnings" else "FAIL — blocking errors found"
  lines <- c(
    "# Validation report", "",
    paste("Generated:", format(Sys.time(), tz = "UTC", usetz = TRUE)), "",
    paste("**Status:**", status), "",
    "## Build counts", "",
    paste0("- Events: ", counts$events),
    paste0("- Route legs: ", counts$routes),
    paste0("- Geodesic route features: ", counts$geodesic_features),
    paste0("- Geodesic line parts: ", counts$geodesic_parts),
    paste0("- Disputed or excluded legs: ", counts$disputed),
    paste0("- Uncertainty areas: ", counts$uncertainty), "",
    "## Issue summary", "",
    paste0("- Errors: ", unname(sev["error"])),
    paste0("- Warnings: ", unname(sev["warning"])),
    paste0("- Informational notes: ", unname(sev["info"])), "",
    "Warnings are retained as evidence-review items and are not silently fixed.", "",
    "## Detailed findings", ""
  )
  if (!nrow(issues)) {
    lines <- c(lines, "No validation issues were recorded.")
  } else {
    detail <- sprintf("- **%s — %s** `%s:%s`: %s", toupper(issues$severity), issues$check,
                      issues$record_type, issues$record_id, issues$message)
    lines <- c(lines, detail)
  }
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

build_coordinate_review <- function(events) {
  events |>
    dplyr::group_by(.data$location_id, .data$location_name) |>
    dplyr::summarise(
      latitude = dplyr::first(.data$latitude),
      longitude = dplyr::first(.data$longitude),
      coordinate_basis = paste(unique(stats::na.omit(.data$coordinate_basis)), collapse = "; "),
      position_uncertainty_nm = max(.data$position_uncertainty_nm, na.rm = TRUE),
      coordinate_variants = dplyr::n_distinct(paste(.data$latitude, .data$longitude)),
      visit_count = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      position_uncertainty_nm = dplyr::if_else(is.infinite(.data$position_uncertainty_nm), NA_real_, .data$position_uncertainty_nm),
      validation_status = dplyr::case_when(
        !dplyr::between(.data$latitude, -90, 90) | !dplyr::between(.data$longitude, -180, 180) ~ "invalid_coordinate_bounds",
        .data$coordinate_variants > 1 ~ "needs_coordinate_variant_review",
        is.na(.data$coordinate_basis) | .data$coordinate_basis == "" ~ "needs_coordinate_basis",
        TRUE ~ "validated_as_supplied"
      ),
      recommended_change = dplyr::case_when(
        .data$validation_status == "invalid_coordinate_bounds" ~ "Investigate source; do not map until resolved.",
        .data$validation_status == "needs_coordinate_variant_review" ~ "Review variants against cited source; retain all evidence until resolved.",
        .data$validation_status == "needs_coordinate_basis" ~ "Add a source-supported coordinate basis before treating the point as precise.",
        TRUE ~ "None. Retain the supplied modeled or centroid reference point and its uncertainty label."
      ),
      change_applied = FALSE,
      review_notes = paste0(
        "Geographic bounds and longitude sign reviewed; ",
        ifelse(.data$visit_count > 1, paste0(.data$visit_count, " event records reuse this location; "), "single recorded visit; "),
        "the coordinate is not interpreted as an exact ship fix."
      )
    ) |>
    dplyr::select(dplyr::all_of(c(
      "location_id", "location_name", "latitude", "longitude", "coordinate_basis",
      "position_uncertainty_nm", "validation_status", "recommended_change",
      "change_applied", "review_notes"
    )))
}

write_coordinate_review <- function(events) {
  review <- build_coordinate_review(events)
  readr::write_csv(review, project_path("outputs", "reports", "coordinate_review.csv"), na = "")
  change_log <- tibble::tibble(
    change_id = character(), location_id = character(), field = character(),
    previous_value = character(), revised_value = character(), reason = character(),
    source_id = character(), review_date = character(), reviewer = character()
  )
  readr::write_csv(change_log, project_path("outputs", "reports", "coordinate_change_log.csv"), na = "")
  invisible(review)
}
