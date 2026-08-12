great_circle_path <- function(start_lon, start_lat, end_lon, end_lat, interval_nm = 100) {
  distance_nm <- geosphere::distGeo(c(start_lon, start_lat), c(end_lon, end_lat)) / 1852
  n <- max(2L, min(720L, ceiling(distance_nm / interval_nm)))
  coords <- geosphere::gcIntermediate(
    p1 = c(start_lon, start_lat), p2 = c(end_lon, end_lat),
    n = n, addStartEnd = TRUE, breakAtDateLine = FALSE
  )
  if (is.list(coords)) coords <- do.call(rbind, coords)
  coords <- as.matrix(coords[, 1:2, drop = FALSE])
  segments_to_sfg(split_antimeridian_coords(coords))
}

build_geodesic_routes <- function(routes, crs = 4326, interval_nm = 100) {
  geometry <- lapply(seq_len(nrow(routes)), function(i) {
    great_circle_path(routes$start_longitude[i], routes$start_latitude[i],
                      routes$end_longitude[i], routes$end_latitude[i], interval_nm)
  })
  sf::st_sf(routes, geometry = sf::st_sfc(geometry, crs = crs))
}

build_original_routes <- function(routes, crs = 4326) {
  geometry <- lapply(seq_len(nrow(routes)), function(i) {
    sf::st_linestring(rbind(
      c(routes$start_longitude[i], routes$start_latitude[i]),
      c(routes$end_longitude[i], routes$end_latitude[i])
    ))
  })
  sf::st_sf(routes, geometry = sf::st_sfc(geometry, crs = crs))
}

count_route_parts <- function(routes_sf) {
  sum(vapply(sf::st_geometry(routes_sf), function(g) {
    if (inherits(g, "MULTILINESTRING")) length(g) else 1L
  }, integer(1)))
}
