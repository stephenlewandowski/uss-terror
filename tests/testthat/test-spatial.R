test_that("great-circle generation produces valid WGS84 lines", {
  g <- great_circle_path(-76.33, 36.946, -79.5667, 8.95, interval_nm = 100)
  s <- sf::st_sfc(g, crs = 4326)
  expect_true(sf::st_is_valid(s))
  expect_false(geometry_has_wrap(s[[1]]))
  expect_gt(nrow(sf::st_coordinates(s)), 2)
})

test_that("antimeridian crossing is split into wrap-safe parts", {
  g <- great_circle_path(-157.86, 21.31, 179.2, -8.52, interval_nm = 75)
  expect_s3_class(g, "MULTILINESTRING")
  expect_false(geometry_has_wrap(g))
  coords <- sf::st_coordinates(g)
  expect_true(any(abs(coords[, "X"]) == 180))
})

test_that("geodesic uncertainty polygons retain nautical-mile radius", {
  p <- uncertainty_polygon(127, 26, 25, vertices = 180)
  coords <- sf::st_coordinates(sf::st_sfc(p, crs = 4326))
  distance_nm <- geosphere::distGeo(c(127, 26), coords[1, c("X", "Y")]) / 1852
  expect_equal(distance_nm, 25, tolerance = 0.05)
  expect_true(sf::st_is_valid(sf::st_sfc(p, crs = 4326)))
})

test_that("standard Pacific route cases remain wrap-safe", {
  cases <- standard_antimeridian_cases()
  expect_true(all(cases$validation_result == "PASS"))
  expect_true(cases$antimeridian_crossing[cases$route_leg_id == "L004"])
  expect_gt(cases$generated_line_parts[cases$route_leg_id == "L004"], 1L)
  expect_true(cases$antimeridian_crossing[cases$route_leg_id == "TEST-SF-WESTPAC"])
  expect_false(cases$antimeridian_crossing[cases$route_leg_id == "TEST-FUNAFUTI-TARAWA"])
})

test_that("Pacific display shifting preserves one feature copy and canonical data", {
  gpkg <- qgis_exchange_path()
  skip_if_not(file.exists(gpkg), "Build outputs do not exist yet")
  canonical <- sf::st_read(gpkg, layer = "events", quiet = TRUE)
  shifted <- shift_longitude_360(canonical)
  expect_equal(nrow(shifted), nrow(canonical))
  expect_equal(canonical$longitude, sf::st_read(gpkg, layer = "events", quiet = TRUE)$longitude)
  expect_true(all(dplyr::between(shifted$longitude, 0, 360)))
  expect_equal(length(unique(shifted$sequence)), nrow(shifted))
})

test_that("simple local boundaries avoid shifting canonical polygons and include labels", {
  gpkg <- qgis_exchange_path()
  skip_if_not(file.exists(gpkg), "Build outputs do not exist yet")
  canonical <- sf::st_read(gpkg, layer = "natural_earth_land", quiet = TRUE)
  simple <- simple_boundary_layers(canonical)
  expect_gte(nrow(simple$polygons), nrow(canonical))
  expect_gt(nrow(simple$labels), 0)
  expect_true(all(dplyr::between(simple$labels$longitude, 0, 360)))
  expect_equal(sf::st_crs(simple$polygons)$epsg, sf::st_crs(canonical)$epsg)
  expect_true(all(suppressWarnings(sf::st_is_valid(simple$polygons))))
})

test_that("static global geometry uses a true Pacific-centered Robinson projection", {
  gpkg <- qgis_exchange_path()
  skip_if_not(file.exists(gpkg), "Build outputs do not exist yet")
  routes <- sf::st_read(gpkg, layer = "route_legs_geodesic", quiet = TRUE)
  projected <- project_pacific_centered(routes)
  expect_false(sf::st_is_longlat(projected))
  expect_equal(nrow(projected), nrow(routes))
  expect_true(all(sf::st_is_valid(projected)))
  expect_match(sf::st_crs(projected)$input, "robin", ignore.case = TRUE)
  expect_lt(diff(sf::st_bbox(projected)[c("xmin", "xmax")]), 4e7)
})

test_that("coordinate review preserves supplied points without silent edits", {
  src <- load_source_data()
  events <- prepare_events(src$events_raw)
  review <- build_coordinate_review(events)
  expect_true(all(c(
    "location_id", "location_name", "latitude", "longitude", "coordinate_basis",
    "position_uncertainty_nm", "validation_status", "recommended_change",
    "change_applied", "review_notes"
  ) %in% names(review)))
  expect_false(any(review$change_applied))
  expect_true(all(dplyr::between(review$latitude, -90, 90)))
  expect_true(all(dplyr::between(review$longitude, -180, 180)))
})
