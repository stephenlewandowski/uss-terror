gmrt_settings <- function(settings = load_settings()) {
  setting_value(settings, c("gmrt"), list(enabled = FALSE))
}

gmrt_regions <- function(settings = load_settings()) {
  regions <- gmrt_settings(settings)$regions %||% list()
  if (!length(regions)) {
    return(tibble::tibble(
      region_id = character(), region_label = character(), west = numeric(), east = numeric(),
      south = numeric(), north = numeric()
    ))
  }
  dplyr::bind_rows(lapply(names(regions), function(id) {
    region <- regions[[id]]
    tibble::tibble(
      region_id = id, region_label = region$label,
      west = as.numeric(region$west), east = as.numeric(region$east),
      south = as.numeric(region$south), north = as.numeric(region$north)
    )
  }))
}

gmrt_region <- function(region_id, settings = load_settings()) {
  regions <- gmrt_regions(settings)
  hit <- regions[regions$region_id == region_id, ]
  if (nrow(hit) != 1L) stop("Unknown GMRT region: ", region_id, call. = FALSE)
  hit
}

build_query_url <- function(base_url, parameters) {
  query <- paste(
    paste0(names(parameters), "=", vapply(parameters, utils::URLencode, character(1), reserved = TRUE)),
    collapse = "&"
  )
  paste0(base_url, ifelse(grepl("\\?$", base_url), "", "?"), query)
}

gmrt_metadata_url <- function(region_id, settings = load_settings(), masked = FALSE,
                              resolution = NULL, format = NULL) {
  config <- gmrt_settings(settings)
  region <- gmrt_region(region_id, settings)
  build_query_url(config$services$metadata_server, list(
    north = as.character(region$north), west = as.character(region$west),
    east = as.character(region$east), south = as.character(region$south),
    format = format %||% config$grid_format %||% "geotiff",
    mformat = "json", resolution = resolution %||% config$default_resolution %||% "default",
    layer = ifelse(isTRUE(masked), "topo-mask", "topo")
  ))
}

gmrt_grid_url <- function(region_id, settings = load_settings(), masked = FALSE,
                          resolution = NULL, format = NULL) {
  config <- gmrt_settings(settings)
  region <- gmrt_region(region_id, settings)
  build_query_url(config$services$grid_server, list(
    north = as.character(region$north), west = as.character(region$west),
    east = as.character(region$east), south = as.character(region$south),
    format = format %||% config$grid_format %||% "geotiff",
    resolution = resolution %||% config$default_resolution %||% "default",
    layer = ifelse(isTRUE(masked), "topo-mask", "topo")
  ))
}

parse_gmrt_metadata <- function(body) {
  metadata <- jsonlite::fromJSON(as.character(body), simplifyVector = TRUE)
  size_bytes <- as.numeric(metadata$file_size_geotiff %||% metadata$file_size_netcdf %||% NA_real_)
  list(
    raw = metadata,
    estimated_bytes = size_bytes,
    estimated_mb = size_bytes / 1024^2,
    meters_per_node = as.numeric(metadata$meters_per_node %||% NA_real_),
    nodes = as.numeric(metadata$nodes %||% NA_real_),
    gmrt_version = as.character(metadata$gmrt_version %||% NA_character_),
    gmrt_release_date = as.character(metadata$gmrt_release_date %||% NA_character_),
    within_service_limit = isTRUE(metadata$lessThanMaxNodes %||% FALSE)
  )
}

probe_gmrt_metadata <- function(region_id, settings = load_settings(), request_fun) {
  url <- gmrt_metadata_url(region_id, settings)
  response <- tryCatch(request_fun(url), error = function(e) list(status = 0L, content_type = "", body = "", error = conditionMessage(e)))
  parsed <- tryCatch(parse_gmrt_metadata(response$body %||% ""), error = function(e) NULL)
  list(
    available = as.integer(response$status %||% 0L) == 200L && !is.null(parsed),
    status = as.integer(response$status %||% 0L), content_type = response$content_type %||% "",
    url = url, metadata = parsed, error = response$error %||% NULL
  )
}

gmrt_cache_inventory <- function(settings = load_settings()) {
  regions <- gmrt_regions(settings)
  raw_dir <- project_path("data", "external", "gmrt", "raw")
  processed_dir <- project_path("data", "external", "gmrt", "processed")
  metadata_dir <- project_path("data", "external", "gmrt", "metadata")
  for (dir in c(raw_dir, processed_dir, metadata_dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  regions |>
    dplyr::mutate(
      raw_path = file.path(raw_dir, paste0(.data$region_id, ".tif")),
      processed_3857_path = file.path(processed_dir, paste0(.data$region_id, "_epsg3857.tif")),
      display_path = file.path(processed_dir, paste0(.data$region_id, "_display.tif")),
      coverage_path = file.path(processed_dir, paste0(.data$region_id, "_coverage.tif")),
      metadata_path = file.path(metadata_dir, paste0(.data$region_id, ".json")),
      raw_cached = file.exists(.data$raw_path),
      processed_cached = file.exists(.data$processed_3857_path),
      display_cached = file.exists(.data$display_path),
      coverage_cached = file.exists(.data$coverage_path),
      service_status = gmrt_settings(settings)$service_check %||% "Not checked",
      gmrt_version = gmrt_settings(settings)$service_version %||% NA_character_,
      notes = "No download occurs during inventory; explicit confirmation and size validation are required."
    )
}

gmrt_regions_for_view <- function(inventory, bounds, zoom, enabled = FALSE,
                                  layer = c("bathymetry", "coverage"), settings = load_settings()) {
  layer <- match.arg(layer)
  if (!isTRUE(enabled) || is.null(bounds) || !nrow(inventory)) return(inventory[0, ])
  minimum_zoom <- as.numeric(setting_value(settings, c("gmrt", "minimum_shiny_zoom"), 6))
  if (!is.finite(as.numeric(zoom)) || as.numeric(zoom) < minimum_zoom) return(inventory[0, ])
  required <- c("west", "east", "south", "north")
  if (!all(required %in% names(bounds)) || any(!is.finite(as.numeric(unlist(bounds[required]))))) return(inventory[0, ])
  cache_field <- if (layer == "bathymetry") "display_cached" else "coverage_cached"
  intersects <- inventory$east >= as.numeric(bounds$west) & inventory$west <= as.numeric(bounds$east) &
    inventory$north >= as.numeric(bounds$south) & inventory$south <= as.numeric(bounds$north)
  inventory[intersects & inventory[[cache_field]], , drop = FALSE]
}

write_gmrt_inventory <- function(settings = load_settings(),
                                 path = project_path("outputs", "reports", "gmrt_inventory.csv")) {
  inventory <- gmrt_cache_inventory(settings)
  readr::write_csv(inventory, path, na = "")
  invisible(inventory)
}

gmrt_warning <- function() {
  paste(
    "GMRT represents modern compiled bathymetry and topography.",
    "It does not reconstruct hydrographic charts, seabed knowledge, navigation aids, or operational conditions available during 1943–1946.",
    "The data are not for navigation."
  )
}
