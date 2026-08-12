test_that("selected-year filtering uses interval overlap for events and routes", {
  src <- load_source_data()
  events <- prepare_events(src$events_raw)
  routes <- prepare_routes(src$routes_raw)
  expected <- c(all = 56L, `1943` = 7L, `1944` = 29L, `1945` = 17L, `1946` = 3L)
  for (year in names(expected)) {
    dat <- filter_deployment_data(events, routes, selected_year = year)
    expect_equal(length(dat$route_ids), unname(expected[[year]]), info = year)
  }
})

test_that("the Pacific map receives the shared filtered IDs", {
  src <- load_source_data()
  events <- prepare_events(src$events_raw)
  routes <- prepare_routes(src$routes_raw)
  for (year in c("all", as.character(1943:1946))) {
    dat <- filter_deployment_data(events, routes, selected_year = year)
    expect_identical(map_route_ids(dat), dat$route_ids, info = year)
    expect_identical(as.character(dat$events$sequence), dat$event_ids, info = year)
  }
})

test_that("a cross-year route is retained in both overlapping years without splitting", {
  src <- load_source_data()
  events <- prepare_events(src$events_raw)
  route <- prepare_routes(src$routes_raw[1, ])
  route$leg_id <- "TEST-CROSS-YEAR"
  route$start_date <- as.Date("1944-12-30")
  route$end_date <- as.Date("1945-01-02")
  route$include_default_map <- TRUE
  route_1944 <- filter_deployment_data(events, route, selected_year = "1944")$routes
  route_1945 <- filter_deployment_data(events, route, selected_year = "1945")$routes
  expect_equal(route_1944$leg_id, "TEST-CROSS-YEAR")
  expect_equal(route_1945$leg_id, "TEST-CROSS-YEAR")
  expect_equal(route_1944$start_date, as.Date("1944-12-30"))
  expect_equal(route_1944$end_date, as.Date("1945-01-02"))
  expect_true(route_1944$cross_year_boundary)
  expect_match(route_1944$cross_year_notice, "complete endpoint-to-endpoint", ignore.case = TRUE)
})

test_that("cumulative mode remains distinct from selected-year mode", {
  src <- load_source_data()
  events <- prepare_events(src$events_raw)
  routes <- prepare_routes(src$routes_raw)
  selected <- filter_deployment_data(events, routes, selected_year = "1945", year_mode = "selected_year")
  cumulative <- filter_deployment_data(events, routes, selected_year = "1945", year_mode = "cumulative")
  expect_gt(length(cumulative$event_ids), length(selected$event_ids))
  expect_gt(length(cumulative$route_ids), length(selected$route_ids))
})

test_that("the Shiny entry point defines one Pacific map and one shared filter reactive", {
  app_text <- paste(readLines(project_path("app.R"), warn = FALSE), collapse = "\n")
  expect_match(app_text, 'leafletOutput\\("pacific_map"')
  expect_false(grepl("global_map", app_text, fixed = TRUE))
  expect_false(grepl("deployment_map_tab", app_text, fixed = TRUE))
  expect_match(app_text, "filtered_map_data <- reactive")
  expect_false(grepl('leafletOutput\\("deployment_map"', app_text))
})

test_that("OpenStreetMap is default-capable and the local shapefile base is selectable", {
  layer_text <- paste(readLines(project_path("R", "map_layers.R"), warn = FALSE), collapse = "\n")
  expect_match(layer_text, '"OpenStreetMap"')
  expect_match(layer_text, "Local boundaries & labels")
  expect_match(layer_text, 'selected_base <- if \\(allow_online\\) "OpenStreetMap"')
  expect_false(grepl("Neutral local historical map", layer_text, fixed = TRUE))
})
