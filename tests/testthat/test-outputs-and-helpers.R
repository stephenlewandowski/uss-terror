test_that("canonical GeoPackages and QGIS exchange layers are readable", {
  gpkg <- qgis_exchange_path()
  skip_if_not(file.exists(gpkg), "Build outputs do not exist yet")
  layers <- sf::st_layers(gpkg)$name
  expect_true(all(c("events", "route_legs_geodesic", "route_legs_original", "locations",
                    "uncertainty_areas", "disputed_routes", "natural_earth_land") %in% layers))
  expect_equal(nrow(sf::st_read(gpkg, layer = "events", quiet = TRUE)), 61)
})

test_that("the local boundary shapefile includes geometry and label fields", {
  path <- project_path(
    "data", "reference", "simple_boundaries", "natural_earth_boundaries.shp"
  )
  skip_if_not(file.exists(path), "Build outputs do not exist yet")
  boundaries <- sf::st_read(path, quiet = TRUE)
  expect_gt(nrow(boundaries), 0)
  expect_true(all(c("name", "admin", "labelrank", "label_x", "label_y") %in% names(boundaries)))
  expect_true(all(sf::st_is_valid(boundaries)))
})

test_that("Shiny-facing table helpers retain source and review fields", {
  gpkg <- qgis_exchange_path()
  skip_if_not(file.exists(gpkg), "Build outputs do not exist yet")
  events <- sf::st_read(gpkg, layer = "events", quiet = TRUE)
  routes <- sf::st_read(gpkg, layer = "route_legs_geodesic", quiet = TRUE)
  et <- event_table_data(events)
  rt <- route_table_data(routes, 23)
  expect_true(all(c("source_id", "source_locator", "estimated", "included") %in% names(et)))
  expect_false(any(vapply(et, inherits, logical(1), what = "sfc")))
  expect_true(all(c("speed_review", "source_status", "included") %in% names(rt)))
  expect_equal(nrow(et), 61)
  expect_equal(nrow(rt), 57)
})

test_that("linked Plotly timeline explicitly registers click events", {
  gpkg <- qgis_exchange_path()
  skip_if_not(file.exists(gpkg), "Build outputs do not exist yet")
  events <- sf::st_read(gpkg, layer = "events", quiet = TRUE)
  timeline <- build_timeline_plot(events[1:3, ], source = "test_timeline")
  expect_contains(timeline$x$shinyEvents, "plotly_click")
})
