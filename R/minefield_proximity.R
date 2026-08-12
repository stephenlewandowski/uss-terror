mine_layer_choices <- function() {
  c(
    "Allied minefields" = "allied", "Japanese minefields" = "japanese",
    "Operation Starvation" = "operation_starvation", "Submarine-laid minefields" = "submarine",
    "Ship-laid minefields" = "ship", "Aircraft-laid minefields" = "aircraft",
    "Defensive harbor fields" = "defensive_harbor", "Minesweeping operations" = "sweeping",
    "Postwar clearance activity" = "postwar_clearance", "Minefield uncertainty" = "uncertainty"
  )
}

mine_proximity_choices <- function() {
  c("50 nautical miles" = "50", "100 nautical miles" = "100", "200 nautical miles" = "200", "All records" = "all")
}

mine_review_counts <- function(candidates) {
  decisions <- unlist(lapply(candidates, function(x) {
    if ("review_status" %in% names(x)) as.character(x$review_status) else character()
  }), use.names = FALSE)
  c(
    accepted = sum(decisions == "accepted", na.rm = TRUE),
    rejected = sum(decisions == "rejected", na.rm = TRUE),
    unresolved = sum(!is.na(decisions) & !decisions %in% c("accepted", "rejected"))
  )
}

filter_mine_candidates <- function(candidates, review_status) {
  lapply(candidates, function(x) {
    if (!"review_status" %in% names(x)) return(x[0, , drop = FALSE])
    x[!is.na(x$review_status) & x$review_status == review_status, , drop = FALSE]
  })
}

candidate_review_register <- function(candidates, review_status = NULL) {
  config <- list(
    minefields = c(id = "minefield_id", type = "Mine locality", title = "minefield_name", date = "date_first_swept", confidence = "overall_confidence"),
    mine_laying_events = c(id = "laying_event_id", type = "Mine-laying operation", title = "operation_name", date = "date_start", confidence = "historical_confidence"),
    mine_sweeping_events = c(id = "sweeping_event_id", type = "Mine-destruction operation", title = "operation_name", date = "date_start", confidence = "historical_confidence"),
    vessels = c(id = "vessel_id", type = "Vessel", title = "vessel_name", date = "commission_date", confidence = "historical_confidence"),
    vessel_operation_links = c(id = "link_id", type = "Vessel-operation relationship", title = "vessel_role", date = "date_start", confidence = "historical_confidence"),
    minefield_sources = c(id = "source_id", type = "Source", title = "source_title", date = "publication_date", confidence = "reliability"),
    minefield_uncertainty = c(id = "uncertainty_id", type = "Uncertainty", title = "uncertainty_type", date = NA_character_, confidence = "historical_confidence")
  )
  empty <- tibble::tibble(
    review_key = character(), record_type = character(), record_id = character(),
    title = character(), decision = character(), confidence = character(),
    record_date = character(), source_id = character(), source_locator = character(),
    summary = character()
  )
  rows <- lapply(intersect(names(config), names(candidates)), function(table_name) {
    table <- candidates[[table_name]]
    if (!is.null(review_status) && "review_status" %in% names(table)) {
      table <- table[!is.na(table$review_status) & table$review_status == review_status, , drop = FALSE]
    }
    if (!nrow(table)) return(empty)
    spec <- config[[table_name]]
    value <- function(field, fallback = "") {
      if (is.na(field) || !field %in% names(table)) return(rep(fallback, nrow(table)))
      answer <- as.character(table[[field]])
      answer[is.na(answer)] <- fallback
      answer
    }
    record_id <- value(spec[["id"]])
    source_id <- if (identical(table_name, "minefield_sources")) record_id else value("source_id")
    locator_field <- if (identical(table_name, "minefield_sources")) "page_or_map_sheet" else "source_locator"
    tibble::tibble(
      review_key = paste(table_name, record_id, sep = "::"),
      record_type = unname(spec[["type"]]), record_id = record_id,
      title = value(spec[["title"]]), decision = value("review_status"),
      confidence = value(spec[["confidence"]]), record_date = value(spec[["date"]]),
      source_id = source_id, source_locator = value(locator_field), summary = value("notes")
    )
  })
  dplyr::bind_rows(c(list(empty), rows))
}

candidate_review_record <- function(candidates, review_key) {
  if (!length(review_key) || is.na(review_key) || !nzchar(review_key)) return(NULL)
  parts <- strsplit(review_key, "::", fixed = TRUE)[[1]]
  if (length(parts) != 2L || !parts[[1]] %in% names(candidates)) return(NULL)
  table_name <- parts[[1]]
  id_field <- mine_primary_ids()[[table_name]]
  table <- candidates[[table_name]]
  if (is.null(id_field) || !id_field %in% names(table)) return(NULL)
  hit <- table[as.character(table[[id_field]]) == parts[[2]], , drop = FALSE]
  if (!nrow(hit)) return(NULL)
  list(table = table_name, record = hit[1, , drop = FALSE])
}

extract_candidate_coordinates <- function(position_basis) {
  pattern <- "(-?[0-9]+(?:\\.[0-9]+)?)\\s*([NS])\\s*,\\s*(-?[0-9]+(?:\\.[0-9]+)?)\\s*([EW])"
  matches <- regmatches(as.character(position_basis), regexec(pattern, as.character(position_basis), perl = TRUE))
  latitude <- longitude <- rep(NA_real_, length(matches))
  for (i in seq_along(matches)) {
    match <- matches[[i]]
    if (length(match) != 5L) next
    latitude[[i]] <- as.numeric(match[[2]]) * ifelse(match[[3]] == "S", -1, 1)
    longitude[[i]] <- as.numeric(match[[4]]) * ifelse(match[[5]] == "W", -1, 1)
  }
  tibble::tibble(longitude = longitude, latitude = latitude)
}

candidate_points_sf <- function(table) {
  if (!nrow(table)) return(sf::st_sf(table, geometry = sf::st_sfc(crs = 4326)))
  coordinates <- extract_candidate_coordinates(table$position_basis)
  valid <- is.finite(coordinates$longitude) & is.finite(coordinates$latitude)
  table <- dplyr::bind_cols(table[valid, , drop = FALSE], coordinates[valid, , drop = FALSE])
  sf::st_as_sf(table, coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)
}

candidate_uncertainty_sf <- function(candidates) {
  uncertainty <- candidates$minefield_uncertainty
  points <- candidate_points_sf(candidates$minefields)
  if (!nrow(uncertainty) || !nrow(points)) {
    return(sf::st_sf(uncertainty[0, , drop = FALSE], geometry = sf::st_sfc(crs = 4326)))
  }
  matched <- match(uncertainty$minefield_id, points$minefield_id)
  keep <- !is.na(matched) & is.finite(uncertainty$position_uncertainty_nm)
  uncertainty <- uncertainty[keep, , drop = FALSE]
  matched <- matched[keep]
  if (!nrow(uncertainty)) return(sf::st_sf(uncertainty, geometry = sf::st_sfc(crs = 4326)))
  result <- sf::st_sf(uncertainty, geometry = sf::st_geometry(points)[matched], crs = 4326)
  result <- sf::st_transform(result, 32652)
  result <- sf::st_buffer(result, dist = result$position_uncertainty_nm * 1852)
  sf::st_transform(result, 4326)
}

candidate_layer_choices <- function(candidates) {
  counts <- c(
    minefields = nrow(candidates$minefields),
    sweeping = nrow(candidates$mine_sweeping_events),
    uncertainty = nrow(candidates$minefield_uncertainty)
  )
  labels <- c(
    minefields = "Mine localities", sweeping = "Mine-destruction operations",
    uncertainty = "Uncertainty envelopes"
  )
  available <- counts > 0
  if (!any(available)) return(stats::setNames(character(), character()))
  stats::setNames(names(counts)[available], paste0(labels[available], " (", counts[available], ")"))
}

filter_minefields_by_proximity <- function(minefields, events, proximity = "100") {
  if (!nrow(minefields) || identical(as.character(proximity), "all")) return(minefields)
  if (!nrow(events)) return(minefields[0, ])
  distance_m <- as.numeric(proximity) * 1852
  distances <- sf::st_distance(minefields, events)
  minefields[apply(units::drop_units(distances) <= distance_m, 1, any), ]
}

minefield_popup <- function(minefields, vessels = NULL, links = NULL,
                            laying_events = NULL, sweeping_events = NULL, units = NULL) {
  if (!nrow(minefields)) return(character())
  drop_geometry <- function(x) {
    if (is.null(x)) return(NULL)
    if (inherits(x, "sf")) sf::st_drop_geometry(x) else x
  }
  vessels <- drop_geometry(vessels)
  links <- drop_geometry(links)
  laying_events <- drop_geometry(laying_events)
  sweeping_events <- drop_geometry(sweeping_events)
  units <- drop_geometry(units)
  field <- function(name, missing = "Not recorded") {
    if (!name %in% names(minefields)) return(rep(missing, nrow(minefields)))
    value <- as.character(minefields[[name]])
    value[is.na(value) | value == ""] <- missing
    htmltools::htmlEscape(value)
  }
  related_text <- function(i, operation_pattern = NULL) {
    if (is.null(links) || !nrow(links)) return("Not recorded")
    related <- links[!is.na(links$minefield_id) & links$minefield_id == minefields$minefield_id[[i]], , drop = FALSE]
    if (!is.null(operation_pattern) && nrow(related)) {
      related <- related[grepl(operation_pattern, related$operation_type, ignore.case = TRUE), , drop = FALSE]
    }
    if (!nrow(related)) return("Not recorded")
    labels <- related$vessel_id
    if (!is.null(vessels) && nrow(vessels)) {
      matched <- match(labels, vessels$vessel_id)
      resolved <- vessels$vessel_name[matched]
      labels[!is.na(resolved) & nzchar(resolved)] <- paste0(resolved[!is.na(resolved) & nzchar(resolved)], " (", labels[!is.na(resolved) & nzchar(resolved)], ")")
    }
    labels <- unique(labels[!is.na(labels) & nzchar(labels)])
    if (!length(labels)) "Not recorded" else paste(labels, collapse = "; ")
  }
  event_value <- function(events, i, field_name) {
    if (is.null(events) || !nrow(events) || !field_name %in% names(events)) return(character())
    unique(as.character(events[[field_name]][events$minefield_id == minefields$minefield_id[[i]]]))
  }
  unit_text <- function(i) {
    ids <- unique(c(event_value(laying_events, i, "laying_unit_id"), event_value(sweeping_events, i, "sweeping_unit_id")))
    ids <- ids[!is.na(ids) & nzchar(ids)]
    if (!length(ids)) return("Not recorded")
    if (!is.null(units) && nrow(units)) {
      matched <- match(ids, units$unit_id)
      labels <- units$unit_name[matched]
      labels[is.na(labels) | !nzchar(labels)] <- ids[is.na(labels) | !nzchar(labels)]
      return(paste(unique(labels), collapse = "; "))
    }
    paste(ids, collapse = "; ")
  }
  laying_vessels <- vapply(seq_len(nrow(minefields)), related_text, character(1), operation_pattern = "lay")
  sweeping_vessels <- vapply(seq_len(nrow(minefields)), related_text, character(1), operation_pattern = "sweep|clear")
  associated_units <- vapply(seq_len(nrow(minefields)), unit_text, character(1))
  paste0(
    "<strong>", field("minefield_name"), " (", field("minefield_id"), ")</strong><br/>",
    "Belligerent: ", field("belligerent"), "<br/>",
    "Planned/actual: ", field("planned_or_actual"), "<br/>",
    "Emplacement: ", field("date_first_emplaced"), " to ", field("date_last_emplaced"), "<br/>",
    "Activation: ", field("date_activated"), "<br/>",
    "First/last sweeping: ", field("date_first_swept"), " / ", field("date_last_swept"), "<br/>",
    "Declared-clear date: ", field("date_declared_cleared"), "<br/>",
    "Minelaying vessels: ", htmltools::htmlEscape(laying_vessels), "<br/>",
    "Minesweeping vessels: ", htmltools::htmlEscape(sweeping_vessels), "<br/>",
    "Associated units: ", htmltools::htmlEscape(associated_units), "<br/>",
    "Mine type/count: ", field("mine_type_summary"), " / ", field("mine_count_emplaced"), "<br/>",
    "Geometry precision: ", field("boundary_precision"), "; uncertainty: ", field("position_uncertainty_nm"), " NM<br/>",
    "Confidence: ", field("overall_confidence"), "<br/>",
    "Source: ", field("source_id"), " — ", field("source_locator"), "<hr/>",
    "Historical research reconstruction only — not current hazard or navigation information."
  )
}

mine_vessel_view <- function(tables) {
  vessels <- sf::st_drop_geometry(tables$vessels)
  links <- sf::st_drop_geometry(tables$vessel_operation_links)
  dplyr::left_join(vessels, links, by = "vessel_id", relationship = "many-to-many")
}

initialize_mine_map <- function(boundaries) {
  map <- leaflet::leaflet(options = leaflet::leafletOptions(worldCopyJump = FALSE, minZoom = 1))
  map <- add_simple_boundary_basemap(map, boundaries)
  map |>
    leaflet::setView(lng = 180, lat = 10, zoom = 2) |>
    leaflet::addControl(
      htmltools::HTML("<div class='map-method-note'><strong>Loading accepted candidate evidence.</strong><br/>Historical reconstruction only; not for navigation.</div>"),
      position = "topright", layerId = "mine-review-control"
    )
}
