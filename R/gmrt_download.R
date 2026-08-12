gmrt_download_plan <- function(region_id, metadata, settings = load_settings(), masked = FALSE) {
  config <- gmrt_settings(settings)
  estimate <- metadata$estimated_mb %||% NA_real_
  limit <- as.numeric(config$maximum_download_mb %||% 250)
  allowed <- is.finite(estimate) && estimate <= limit && isTRUE(metadata$within_service_limit)
  list(
    region_id = region_id,
    request_url = gmrt_grid_url(region_id, settings, masked = masked),
    metadata_url = gmrt_metadata_url(region_id, settings, masked = masked),
    estimated_mb = estimate,
    maximum_download_mb = limit,
    allowed = allowed,
    reason = if (allowed) "Within configured size and service limits." else "Refused: missing size metadata, service limit failure, or configured maximum exceeded."
  )
}

process_gmrt_raster <- function(raw_path, processed_path, display_path = NULL) {
  if (!requireNamespace("terra", quietly = TRUE)) {
    stop("Package 'terra' is required to process GMRT rasters; the original raw file remains unchanged.", call. = FALSE)
  }
  raster <- terra::rast(raw_path)
  projected <- terra::project(raster, "EPSG:3857")
  terra::writeRaster(projected, processed_path, overwrite = TRUE)
  if (!is.null(display_path)) {
    factor <- max(1L, ceiling(max(dim(projected)[1:2]) / 2000))
    display <- if (factor > 1L) terra::aggregate(projected, fact = factor, fun = mean, na.rm = TRUE) else projected
    terra::writeRaster(display, display_path, overwrite = TRUE)
  }
  invisible(processed_path)
}

cache_gmrt_region <- function(region_id, confirm = FALSE, settings = load_settings(),
                              metadata_request_fun, download_fun = utils::download.file,
                              masked = FALSE) {
  if (!isTRUE(confirm)) {
    stop("GMRT download not started: pass confirm = TRUE after reviewing metadata and estimated size.", call. = FALSE)
  }
  probe <- probe_gmrt_metadata(region_id, settings, metadata_request_fun)
  if (!isTRUE(probe$available)) stop("GMRT metadata request failed; no download was attempted.", call. = FALSE)
  plan <- gmrt_download_plan(region_id, probe$metadata, settings, masked)
  if (!isTRUE(plan$allowed)) stop(plan$reason, call. = FALSE)

  inventory <- gmrt_cache_inventory(settings)
  row <- inventory[inventory$region_id == region_id, ]
  if (nrow(row) != 1L) stop("Configured GMRT region not found.", call. = FALSE)
  download_fun(plan$request_url, row$raw_path, mode = "wb", quiet = FALSE)
  if (!file.exists(row$raw_path)) stop("GMRT download function returned without creating the raw raster.", call. = FALSE)

  metadata_record <- list(
    requested_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    region_id = region_id, masked = isTRUE(masked), request_url = plan$request_url,
    metadata_url = plan$metadata_url, estimated_mb = plan$estimated_mb,
    gmrt_version = probe$metadata$gmrt_version, gmrt_release_date = probe$metadata$gmrt_release_date,
    raw_path = row$raw_path, sha256 = digest::digest(row$raw_path, algo = "sha256", file = TRUE)
  )
  jsonlite::write_json(metadata_record, row$metadata_path, pretty = TRUE, auto_unbox = TRUE, na = "null")
  process_gmrt_raster(row$raw_path, row$processed_3857_path, row$display_path)
  invisible(metadata_record)
}
