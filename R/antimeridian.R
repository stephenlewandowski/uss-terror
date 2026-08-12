normalize_longitude <- function(x) ((x + 180) %% 360) - 180

split_antimeridian_coords <- function(coords) {
  coords <- as.matrix(coords[, 1:2, drop = FALSE])
  coords[, 1] <- normalize_longitude(coords[, 1])
  if (nrow(coords) < 2L) return(list(coords))
  segments <- list()
  current <- coords[1, , drop = FALSE]
  for (i in 2:nrow(coords)) {
    p1 <- coords[i - 1L, ]
    p2 <- coords[i, ]
    delta <- p2[1] - p1[1]
    if (abs(delta) <= 180) {
      current <- rbind(current, p2)
      next
    }
    if (p1[1] > 0 && p2[1] < 0) {
      p2_adj <- p2; p2_adj[1] <- p2_adj[1] + 360
      frac <- (180 - p1[1]) / (p2_adj[1] - p1[1])
      cross_lat <- p1[2] + frac * (p2_adj[2] - p1[2])
      current <- rbind(current, c(180, cross_lat))
      segments[[length(segments) + 1L]] <- current
      current <- rbind(c(-180, cross_lat), p2)
    } else {
      p2_adj <- p2; p2_adj[1] <- p2_adj[1] - 360
      frac <- (-180 - p1[1]) / (p2_adj[1] - p1[1])
      cross_lat <- p1[2] + frac * (p2_adj[2] - p1[2])
      current <- rbind(current, c(-180, cross_lat))
      segments[[length(segments) + 1L]] <- current
      current <- rbind(c(180, cross_lat), p2)
    }
  }
  segments[[length(segments) + 1L]] <- current
  Filter(function(x) nrow(x) >= 2L, segments)
}

segments_to_sfg <- function(segments) {
  if (length(segments) == 1L) sf::st_linestring(segments[[1]]) else sf::st_multilinestring(segments)
}

geometry_has_wrap <- function(geometry) {
  coords <- sf::st_coordinates(geometry)
  group_cols <- intersect(colnames(coords), c("L1", "L2", "L3"))
  if (!length(group_cols)) return(any(abs(diff(coords[, "X"])) > 180))
  groups <- interaction(as.data.frame(coords[, group_cols, drop = FALSE]), drop = TRUE)
  any(vapply(split(coords[, "X"], groups), function(x) any(abs(diff(x)) > 180), logical(1)))
}

antimeridian_case_result <- function(route_leg_id, origin, destination,
                                     start_lon, start_lat, end_lon, end_lat,
                                     interval_nm = 75) {
  geometry <- great_circle_path(start_lon, start_lat, end_lon, end_lat, interval_nm)
  coords <- sf::st_coordinates(geometry)
  parts <- if (inherits(geometry, "MULTILINESTRING")) length(geometry) else 1L
  endpoint_delta <- abs(normalize_longitude(end_lon) - normalize_longitude(start_lon))
  crossing <- parts > 1L || endpoint_delta > 180
  valid <- isTRUE(sf::st_is_valid(sf::st_sfc(geometry, crs = 4326)))
  no_wrap <- !geometry_has_wrap(geometry)
  tibble::tibble(
    route_leg_id = route_leg_id,
    origin = origin,
    destination = destination,
    longitude_range = sprintf("%.4f to %.4f degrees", min(coords[, "X"]), max(coords[, "X"])),
    antimeridian_crossing = crossing,
    geometry_splitting_method = if (crossing) {
      "Great-circle interpolation; explicit ±180-degree intersection; MULTILINESTRING split"
    } else {
      "Great-circle interpolation; no split required"
    },
    generated_line_parts = parts,
    validation_result = if (valid && no_wrap) "PASS" else "FAIL",
    remaining_limitation = "Endpoint-to-endpoint reconstruction only; no intermediate daily ship positions are inferred."
  )
}

standard_antimeridian_cases <- function() {
  cases <- tibble::tribble(
    ~route_leg_id, ~origin, ~destination, ~start_lon, ~start_lat, ~end_lon, ~end_lat,
    "L004", "Pearl Harbor", "Funafuti", -157.9750, 21.3440, 179.2000, -8.5167,
    "TEST-FUNAFUTI-TARAWA", "Funafuti", "Tarawa", 179.2000, -8.5167, 172.9300, 1.3500,
    "L020-REFERENCE", "Enewetak (Marshall Islands)", "Pearl Harbor", 162.3500, 11.3500, -157.9750, 21.3440,
    "L012", "Pearl Harbor", "San Francisco Bay", -157.9750, 21.3440, -122.4783, 37.8199,
    "TEST-SF-WESTPAC", "San Francisco Bay", "Saipan", -122.4783, 37.8199, 145.7500, 15.2000,
    "TEST-NEAR-180", "Near 180 east", "Near 180 west", 179.8000, 5.0000, -179.7000, 7.0000
  )
  dplyr::bind_rows(lapply(seq_len(nrow(cases)), function(i) {
    antimeridian_case_result(
      cases$route_leg_id[[i]], cases$origin[[i]], cases$destination[[i]],
      cases$start_lon[[i]], cases$start_lat[[i]], cases$end_lon[[i]], cases$end_lat[[i]]
    )
  }))
}

write_antimeridian_validation <- function(
    path = project_path("outputs", "reports", "antimeridian_validation.md")) {
  cases <- standard_antimeridian_cases()
  lines <- c(
    "# Antimeridian and great-circle validation", "",
    paste("Generated:", format(Sys.time(), tz = "UTC", usetz = TRUE)), "",
    "Canonical WGS84 endpoints are preserved. Display geometry is geodesically interpolated and split only where a part would otherwise jump more than 180 degrees in longitude.", ""
  )
  for (i in seq_len(nrow(cases))) {
    row <- cases[i, ]
    lines <- c(
      lines, paste0("## ", row$route_leg_id, " — ", row$origin, " to ", row$destination), "",
      paste0("- Route-leg ID: ", row$route_leg_id),
      paste0("- Origin: ", row$origin),
      paste0("- Destination: ", row$destination),
      paste0("- Longitude range: ", row$longitude_range),
      paste0("- Antimeridian crossing: ", row$antimeridian_crossing),
      paste0("- Geometry splitting method: ", row$geometry_splitting_method),
      paste0("- Number of generated line parts: ", row$generated_line_parts),
      paste0("- Validation result: ", row$validation_result),
      paste0("- Remaining limitation: ", row$remaining_limitation), ""
    )
  }
  writeLines(lines, path, useBytes = TRUE)
  invisible(cases)
}
