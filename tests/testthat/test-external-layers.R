test_that("OpenSeaMap configuration is centralized and failures are nonfatal", {
  settings <- load_settings()
  config <- openseamap_settings(settings)
  expect_match(config$tile_url, "tiles\\.openseamap\\.org/seamark")
  expect_false(config$default_visible)
  ok <- probe_openseamap(settings, function(url) list(status = 200L, content_type = "image/png", body = as.raw(1:3)))
  failed <- probe_openseamap(settings, function(url) stop("offline"))
  expect_true(ok$available)
  expect_false(failed$available)
  expect_match(failed$message, "offline")
})

test_that("GEBCO mocked capabilities retain the configured current layer", {
  settings <- load_settings()
  xml <- '<WMS_Capabilities><Capability><Layer><Layer><Name>GEBCO_LATEST</Name><Title>GEBCO shaded relief</Title></Layer></Layer></Capability></WMS_Capabilities>'
  parsed <- validate_gebco_capabilities(xml, "GEBCO_LATEST")
  expect_true(parsed$valid_wms)
  expect_true(parsed$layer_found)
  result <- probe_gebco(settings, function(url) list(status = 200L, content_type = "text/xml", body = xml))
  expect_true(result$available)
  failure <- probe_gebco(settings, function(url) list(status = 503L, content_type = "text/plain", body = "unavailable"))
  expect_false(failure$available)
})

test_that("offline reference status preserves the local fallback", {
  status <- offline_reference_status(load_settings(), offline = TRUE)
  expect_false(any(status$enabled_for_session))
  expect_true(all(grepl("local Natural Earth", status$message)))
})

test_that("GMRT cache can be empty and inventory still lists configured regions", {
  inventory <- write_gmrt_inventory(load_settings())
  expect_equal(nrow(inventory), 6L)
  expect_true(all(c("raw_cached", "processed_cached", "display_cached") %in% names(inventory)))
  expect_false(any(inventory$raw_cached))
})

test_that("GMRT mocked metadata produces a bounded download plan", {
  body <- jsonlite::toJSON(list(
    file_size_netcdf = 5 * 1024^2, meters_per_node = "122.3", nodes = 1000,
    lessThanMaxNodes = TRUE, gmrt_version = "4.5.0", gmrt_release_date = "June 2026"
  ), auto_unbox = TRUE)
  probe <- probe_gmrt_metadata("iwo_jima", load_settings(), function(url) {
    list(status = 200L, content_type = "application/json", body = body)
  })
  expect_true(probe$available)
  plan <- gmrt_download_plan("iwo_jima", probe$metadata, load_settings())
  expect_true(plan$allowed)
  expect_lt(plan$estimated_mb, plan$maximum_download_mb)
  expect_match(plan$request_url, "GridServer")
})

test_that("GMRT size limits and explicit confirmation prevent accidental downloads", {
  metadata <- list(estimated_mb = 251, within_service_limit = TRUE)
  plan <- gmrt_download_plan("iwo_jima", metadata, load_settings())
  expect_false(plan$allowed)
  expect_error(
    cache_gmrt_region("iwo_jima", confirm = FALSE, settings = load_settings(), metadata_request_fun = function(url) stop("must not run")),
    "confirm = TRUE"
  )
})

test_that("future GMRT rasters load only when enabled, intersecting, and sufficiently zoomed", {
  inventory <- gmrt_cache_inventory(load_settings())
  inventory$display_cached <- inventory$region_id == "iwo_jima"
  bounds <- list(west = 140, east = 143, south = 23, north = 27)
  expect_equal(nrow(gmrt_regions_for_view(inventory, bounds, 6, enabled = TRUE)), 1L)
  expect_equal(nrow(gmrt_regions_for_view(inventory, bounds, 5, enabled = TRUE)), 0L)
  expect_equal(nrow(gmrt_regions_for_view(inventory, bounds, 6, enabled = FALSE)), 0L)
  outside <- list(west = 160, east = 165, south = 0, north = 5)
  expect_equal(nrow(gmrt_regions_for_view(inventory, outside, 7, enabled = TRUE)), 0L)
})
