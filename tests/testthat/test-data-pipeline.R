test_that("source data load and required columns are retained", {
  src <- load_source_data()
  expect_equal(nrow(src$events_raw), 61)
  expect_equal(nrow(src$routes_raw), 57)
  expect_true(all(event_required_columns() %in% names(src$events_raw)))
  expect_true(all(route_required_columns() %in% names(src$routes_raw)))
})

test_that("source inventory retains paths, hashes, read status, and counts", {
  inventory <- create_source_inventory()
  expect_true(all(c(
    "filename", "original_path", "project_relative_path", "file_type",
    "file_size_bytes", "modified_date", "sha256", "read_status",
    "row_or_feature_count", "notes"
  ) %in% names(inventory)))
  required <- inventory[inventory$filename %in% required_source_files(), ]
  expect_equal(nrow(required), length(required_source_files()))
  expect_true(all(required$read_status == "read"))
  expect_true(all(nchar(required$sha256) == 64L))
})

test_that("dates and WGS84 coordinates normalize correctly", {
  src <- load_source_data()
  events <- prepare_events(src$events_raw)
  routes <- prepare_routes(src$routes_raw)
  expect_s3_class(events$date_start, "Date")
  expect_true(all(events$date_end >= events$date_start))
  expect_true(all(dplyr::between(events$latitude, -90, 90)))
  expect_true(all(dplyr::between(events$longitude, -180, 180)))
  expect_true(all(dplyr::between(routes$start_longitude, -180, 180)))
  expect_true(all(is.finite(routes$great_circle_nm)))
})

test_that("default filtering and disputed records preserve evidence", {
  src <- load_source_data()
  routes <- prepare_routes(src$routes_raw)
  expect_gt(sum(!routes$include_default_map), 0)
  expect_equal(nrow(routes[routes$include_default_map, ]), sum(routes$include_default_map))
  expect_true(all(routes$source_url == src$routes_raw$source_url | (is.na(routes$source_url) & is.na(src$routes_raw$source_url))))
})

test_that("event interval filtering uses overlap rather than daily interpolation", {
  expect_equal(event_overlaps(as.Date("1945-01-01"), as.Date("1945-01-10"), as.Date("1945-01-05"), as.Date("1945-01-06")), TRUE)
  expect_equal(event_overlaps(as.Date("1945-01-01"), as.Date("1945-01-02"), as.Date("1945-01-03"), as.Date("1945-01-04")), FALSE)
})
