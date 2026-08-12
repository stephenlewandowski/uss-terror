minefield_schema <- function() {
  list(
    minefields = c(
      minefield_id = "character", minefield_name = "character", alternate_names = "character",
      theater = "character", region = "character", country_or_area = "character",
      belligerent = "character", controlling_authority = "character", minefield_type = "character",
      geometry_type = "character", planned_or_actual = "character",
      date_first_emplaced = "date", date_first_emplaced_precision = "character",
      date_last_emplaced = "date", date_last_emplaced_precision = "character",
      date_activated = "date", date_activated_precision = "character",
      date_first_swept = "date", date_first_swept_precision = "character",
      date_last_swept = "date", date_last_swept_precision = "character",
      date_declared_cleared = "date", date_declared_cleared_precision = "character",
      date_status_last_verified = "date", mine_count_planned = "integer",
      mine_count_emplaced = "integer", mine_count_recovered = "integer",
      mine_count_destroyed = "integer", mine_count_remaining_reported = "integer",
      mine_type_summary = "character", historical_status = "character",
      position_basis = "character", position_uncertainty_nm = "numeric",
      boundary_precision = "character", source_confidence = "character",
      overall_confidence = "character", default_visible = "logical",
      current_navigation_warning = "logical", source_id = "character",
      source_locator = "character", source_url = "character", review_status = "character",
      notes = "character"
    ),
    minefield_boundaries = c(
      boundary_id = "character", minefield_id = "character", geometry_type = "character",
      boundary_precision = "character", position_basis = "character",
      position_uncertainty_nm = "numeric", georeferencing_method = "character",
      georeferencing_rmse = "numeric", source_id = "character", source_locator = "character",
      historical_confidence = "character", review_status = "character", notes = "character"
    ),
    mine_laying_events = c(
      laying_event_id = "character", minefield_id = "character", operation_name = "character",
      operation_phase = "character", date_start = "date", date_end = "date",
      date_precision = "character", time_start = "character", time_end = "character",
      belligerent = "character", laying_service = "character", laying_unit_id = "character",
      primary_vessel_id = "character", laying_platform_type = "character",
      departure_location = "character", emplacement_location = "character",
      mine_type = "character", mine_model = "character", mine_count_planned = "integer",
      mine_count_emplaced = "integer", planned_or_actual = "character",
      position_basis = "character", position_uncertainty_nm = "numeric",
      historical_confidence = "character", source_id = "character",
      source_locator = "character", source_url = "character", review_status = "character",
      notes = "character"
    ),
    mine_sweeping_events = c(
      sweeping_event_id = "character", minefield_id = "character", operation_name = "character",
      operation_phase = "character", date_start = "date", date_end = "date",
      date_precision = "character", belligerent = "character", sweeping_service = "character",
      sweeping_unit_id = "character", primary_vessel_id = "character",
      sweeping_method = "character", sweep_type = "character", area_swept_sq_nm = "numeric",
      mines_swept = "integer", mines_destroyed = "integer", mines_recovered = "integer",
      casualties = "character", vessels_damaged = "character", result = "character",
      clearance_status_after_event = "character", date_declared_safe = "date",
      date_declared_safe_precision = "character", position_basis = "character",
      position_uncertainty_nm = "numeric", historical_confidence = "character",
      source_id = "character", source_locator = "character", source_url = "character",
      review_status = "character", notes = "character"
    ),
    minefield_status_events = c(
      status_event_id = "character", minefield_id = "character", event_date_start = "date",
      event_date_end = "date", date_precision = "character", status_before = "character",
      status_after = "character", event_type = "character", responsible_unit_id = "character",
      responsible_vessel_id = "character", source_id = "character", source_locator = "character",
      historical_confidence = "character", review_status = "character", notes = "character"
    ),
    vessels = c(
      vessel_id = "character", vessel_name = "character", alternate_names = "character",
      prefix = "character", navy_or_service = "character", nationality = "character",
      hull_number = "character", pennant_number = "character", ship_type = "character",
      ship_class = "character", mine_warfare_role = "character", commission_date = "date",
      decommission_date = "date", fate = "character", historical_confidence = "character",
      source_id = "character", source_locator = "character", review_status = "character",
      notes = "character"
    ),
    units = c(
      unit_id = "character", unit_name = "character", alternate_names = "character",
      service = "character", nationality = "character", unit_type = "character",
      parent_organization = "character", date_start = "date", date_end = "date",
      source_id = "character", source_locator = "character", review_status = "character",
      notes = "character"
    ),
    vessel_operation_links = c(
      link_id = "character", vessel_id = "character", operation_type = "character",
      operation_id = "character", minefield_id = "character", vessel_role = "character",
      date_start = "date", date_end = "date", date_precision = "character",
      participation_status = "character", historical_confidence = "character",
      source_id = "character", source_locator = "character", review_status = "character",
      notes = "character"
    ),
    minefield_sources = mine_source_schema(),
    minefield_source_maps = c(
      source_map_id = "character", source_id = "character", map_title = "character",
      map_sheet = "character", map_date = "date", map_date_precision = "character",
      file_path = "character", source_url = "character", georeferenced = "logical",
      georeferencing_method = "character", georeferencing_rmse = "numeric",
      review_status = "character", notes = "character"
    ),
    minefield_uncertainty = c(
      uncertainty_id = "character", minefield_id = "character", uncertainty_type = "character",
      position_uncertainty_nm = "numeric", boundary_precision = "character",
      position_basis = "character", source_id = "character", source_locator = "character",
      historical_confidence = "character", review_status = "character", notes = "character"
    )
  )
}

minefield_geometry_types <- function() {
  c(
    minefields = "POINT", minefield_boundaries = "POLYGON", mine_laying_events = "POINT",
    mine_sweeping_events = "POINT", minefield_status_events = "POINT", vessels = "GEOMETRYCOLLECTION",
    units = "GEOMETRYCOLLECTION", vessel_operation_links = "GEOMETRYCOLLECTION",
    minefield_sources = "GEOMETRYCOLLECTION", minefield_source_maps = "POLYGON",
    minefield_uncertainty = "POLYGON"
  )
}

empty_schema_column <- function(type) {
  switch(type,
    character = character(), integer = integer(), numeric = numeric(),
    logical = logical(), date = as.Date(character()),
    stop("Unsupported schema type: ", type, call. = FALSE)
  )
}

empty_schema_table <- function(schema) {
  tibble::as_tibble(stats::setNames(lapply(unname(schema), empty_schema_column), names(schema)))
}

empty_geometry <- function(type, crs = 4326) {
  geometry <- switch(type,
    POINT = sf::st_point(),
    POLYGON = sf::st_polygon(),
    LINESTRING = sf::st_linestring(),
    GEOMETRYCOLLECTION = sf::st_geometrycollection(),
    sf::st_geometrycollection()
  )
  sf::st_sfc(geometry, crs = crs)[0]
}

empty_mine_tables <- function(crs = 4326) {
  schema <- minefield_schema()
  geometry_types <- minefield_geometry_types()
  stats::setNames(lapply(names(schema), function(name) {
    sf::st_sf(empty_schema_table(schema[[name]]), geometry = empty_geometry(geometry_types[[name]], crs))
  }), names(schema))
}

mine_candidate_files <- function() {
  c(
    candidate_minefields = "minefields", candidate_laying_events = "mine_laying_events",
    candidate_sweeping_events = "mine_sweeping_events", candidate_vessels = "vessels",
    candidate_vessel_links = "vessel_operation_links", candidate_sources = "minefield_sources",
    candidate_uncertainty = "minefield_uncertainty"
  )
}

write_empty_mine_database <- function(
    gpkg = project_path("data", "processed", "pacific_mine_warfare.gpkg"),
    export_dir = project_path("outputs", "data_exports", "mine_warfare"),
    review_dir = project_path("data", "mine_warfare", "review"), crs = 4326) {
  tables <- empty_mine_tables(crs)
  dir.create(dirname(gpkg), recursive = TRUE, showWarnings = FALSE)
  dir.create(export_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(review_dir, recursive = TRUE, showWarnings = FALSE)
  if (file.exists(gpkg)) unlink(gpkg)
  first <- TRUE
  for (name in names(tables)) {
    sf::st_write(
      tables[[name]], gpkg, layer = name, delete_dsn = first, delete_layer = TRUE,
      quiet = TRUE, layer_options = "FID=feature_id"
    )
    first <- FALSE
    readr::write_csv(sf::st_drop_geometry(tables[[name]]), file.path(export_dir, paste0(name, ".csv")), na = "")
  }
  mapping <- mine_candidate_files()
  for (candidate in names(mapping)) {
    table_name <- unname(mapping[[candidate]])
    candidate_path <- file.path(review_dir, paste0(candidate, ".csv"))
    if (!file.exists(candidate_path)) {
      readr::write_csv(
        sf::st_drop_geometry(tables[[table_name]]), candidate_path, na = ""
      )
    }
  }
  invisible(tables)
}

load_mine_database <- function(path = project_path("data", "processed", "pacific_mine_warfare.gpkg")) {
  if (!file.exists(path)) return(empty_mine_tables())
  expected <- names(minefield_schema())
  available <- sf::st_layers(path)$name
  stats::setNames(lapply(expected, function(name) {
    if (name %in% available) sf::st_read(path, layer = name, quiet = TRUE) else empty_mine_tables()[[name]]
  }), expected)
}
