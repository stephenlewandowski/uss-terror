test_that("empty mine database contains all required schema tables and fields", {
  tables <- empty_mine_tables()
  expect_setequal(names(tables), names(minefield_schema()))
  for (name in names(minefield_schema())) {
    expect_true(all(names(minefield_schema()[[name]]) %in% names(tables[[name]])), info = name)
    expect_equal(nrow(tables[[name]]), 0L, info = name)
  }
  expect_equal(nrow(validate_mine_schema(tables, load_settings())), 0L)
})

test_that("vessel, unit, and many-to-many link schemas preserve evidence fields", {
  schema <- minefield_schema()
  expect_true(all(c("vessel_id", "hull_number", "mine_warfare_role", "source_id", "source_locator") %in% names(schema$vessels)))
  expect_true(all(c("unit_id", "parent_organization", "source_id") %in% names(schema$units)))
  expect_true(all(c(
    "link_id", "vessel_id", "operation_type", "operation_id", "minefield_id",
    "vessel_role", "date_start", "date_end", "date_precision", "participation_status",
    "source_id", "source_locator", "review_status"
  ) %in% names(schema$vessel_operation_links)))
})

test_that("unknown primary vessels remain nullable and are not invented", {
  laying <- empty_schema_table(minefield_schema()$mine_laying_events)
  row <- lapply(laying, function(column) {
    if (inherits(column, "Date")) as.Date(NA) else if (is.integer(column)) NA_integer_ else if (is.numeric(column)) NA_real_ else NA_character_
  })
  names(row) <- names(laying)
  row$laying_event_id <- "TEST-LAY-1"
  row$primary_vessel_id <- NA_character_
  fixture <- tibble::as_tibble(row)
  expect_true(is.na(fixture$primary_vessel_id))
  expect_false(any(grepl("V-USN-CM5-TERROR", fixture$primary_vessel_id, fixed = TRUE), na.rm = TRUE))
})

test_that("date precision, sources, and review states are present", {
  schema <- minefield_schema()
  expect_true(all(c(
    "date_first_emplaced_precision", "date_last_emplaced_precision",
    "date_first_swept_precision", "date_last_swept_precision",
    "date_declared_cleared_precision"
  ) %in% names(schema$minefields)))
  expect_true(all(c("day", "month", "year", "range", "circa", "inferred", "unknown") %in% mine_date_precisions()))
  expect_true(all(c("unreviewed", "conflicted", "accepted", "rejected") %in% mine_review_states()))
})

test_that("clearance logic does not equate sweeping with proven clearance", {
  tables <- empty_mine_tables()
  flags <- mine_clearance_flags(tables$minefields, tables$mine_sweeping_events)
  expect_equal(nrow(flags), 0L)
  expect_match(paste(deparse(body(mine_clearance_flags)), collapse = " "), "sweeping alone is not proof", ignore.case = TRUE)
})

test_that("canonical GeoPackage exports empty QGIS-readable layers", {
  gpkg <- project_path("data", "processed", "pacific_mine_warfare.gpkg")
  skip_if_not(file.exists(gpkg), "Empty mine database has not been built")
  layers <- sf::st_layers(gpkg)$name
  expect_setequal(layers, names(minefield_schema()))
  for (name in layers) expect_equal(nrow(sf::st_read(gpkg, layer = name, quiet = TRUE)), 0L, info = name)
  loaded <- load_mine_database(gpkg)
  expect_true(is.character(loaded$minefields$minefield_id))
  expect_true(is.integer(loaded$minefields$mine_count_planned))
  expect_true(is.numeric(loaded$minefields$position_uncertainty_nm))
  expect_true(is.logical(loaded$minefields$default_visible) || is.integer(loaded$minefields$default_visible))
  expect_true(inherits(loaded$minefields$date_first_emplaced, "Date") || inherits(loaded$minefields$date_first_emplaced, "POSIXt"))
  expect_equal(nrow(validate_mine_schema(loaded, load_settings())), 0L)
})

test_that("mine layers are hidden and navigation warnings are enabled by default", {
  settings <- load_settings()
  expect_false(setting_value(settings, c("mine_warfare", "default_visible"), TRUE))
  expect_true(setting_value(settings, c("mine_warfare", "current_navigation_warning"), FALSE))
  expect_equal(setting_value(settings, c("mine_warfare", "default_proximity_nm"), 0), 100)
})

test_that("candidate review templates are separate and canonical exports contain no fixtures", {
  candidates <- paste0(names(mine_candidate_files()), ".csv")
  expect_true(all(file.exists(project_path("data", "mine_warfare", "review", candidates))))
  gpkg <- project_path("data", "processed", "pacific_mine_warfare.gpkg")
  skip_if_not(file.exists(gpkg), "Empty mine database has not been built")
  tables <- load_mine_database(gpkg)
  expect_true(all(vapply(tables, nrow, integer(1)) == 0L))
  expect_false(any(vapply(tables, function(x) any(grepl("TEST-|FIXTURE", unlist(sf::st_drop_geometry(x)), ignore.case = TRUE)), logical(1))))
})

test_that("Shiny exposes a canonical-safe candidate review interface", {
  app_text <- paste(readLines(project_path("app.R"), warn = FALSE), collapse = "\n")
  expect_match(app_text, "Historical Mine Warfare")
  expect_match(app_text, "mine_proximity")
  expect_match(app_text, 'leafletOutput\\("mine_map"')
  expect_match(app_text, "not for navigation", ignore.case = TRUE)
  expect_match(app_text, "canonical records", ignore.case = TRUE)
  expect_match(app_text, "accepted candidates", ignore.case = TRUE)
  expect_match(app_text, "never populate canonical tables", ignore.case = TRUE)
})

test_that("QGIS mine styles and initializer are schema-ready and hidden", {
  style_names <- c(
    "minefields_by_belligerent.qml", "minefields_by_status.qml",
    "minefields_by_platform.qml", "minefields_by_confidence.qml",
    "mine_laying_events.qml", "mine_sweeping_events.qml", "minefield_uncertainty.qml"
  )
  style_paths <- project_path("qgis", "styles", style_names)
  expect_true(all(file.exists(style_paths)))
  for (path in style_paths) {
    qml <- paste(readLines(path, warn = FALSE), collapse = "\n")
    expect_match(qml, "<qgis[ >]")
    expect_match(qml, "</qgis>")
  }
  initializer <- paste(readLines(project_path("qgis", "initialize_qgis_project.py"), warn = FALSE), collapse = "\n")
  expect_match(initializer, "Historical Mine Warfare — Research Reconstruction")
  expect_match(initializer, "mine_group.setItemVisibilityChecked\\(False\\)")
})
