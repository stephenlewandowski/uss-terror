write_layer <- function(x, dsn, layer, delete_dsn = FALSE) {
  if (delete_dsn && file.exists(dsn)) unlink(dsn)
  sf::st_write(x, dsn = dsn, layer = layer, delete_layer = TRUE, quiet = TRUE,
               layer_options = "FID=feature_id")
  invisible(dsn)
}

export_simple_boundary_shapefile <- function(
    land_sf,
    path = project_path(
      "data", "reference", "simple_boundaries", "natural_earth_boundaries.shp"
    )) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  keep <- intersect(
    c("name", "name_long", "admin", "labelrank", "label_x", "label_y"),
    names(land_sf)
  )
  boundaries <- land_sf[, keep, drop = FALSE]
  stem <- tools::file_path_sans_ext(basename(path))
  existing <- list.files(
    dirname(path), pattern = paste0("^", stem, "\\."),
    full.names = TRUE, ignore.case = TRUE
  )
  if (length(existing)) unlink(existing)
  sf::st_write(
    boundaries, path, driver = "ESRI Shapefile",
    delete_layer = TRUE, quiet = TRUE
  )
  invisible(path)
}

export_spatial_data <- function(events_sf, routes_geodesic, routes_original, locations_sf,
                                uncertainty_sf, operating_regions_sf, land_sf, conflicts) {
  processed <- project_path("data", "processed")
  dir.create(processed, recursive = TRUE, showWarnings = FALSE)
  write_layer(events_sf, file.path(processed, "events.gpkg"), "events", TRUE)
  write_layer(routes_geodesic, file.path(processed, "route_legs.gpkg"), "route_legs", TRUE)
  write_layer(locations_sf, file.path(processed, "locations.gpkg"), "locations", TRUE)
  readr::write_csv(sf::st_drop_geometry(events_sf), file.path(processed, "events.csv"), na = "")
  readr::write_csv(sf::st_drop_geometry(routes_geodesic), file.path(processed, "route_legs.csv"), na = "")
  readr::write_csv(sf::st_drop_geometry(locations_sf), file.path(processed, "locations.csv"), na = "")
  readr::write_csv(conflicts, file.path(processed, "conflicts.csv"), na = "")
  export_simple_boundary_shapefile(land_sf)

  layers <- list(
    events = events_sf,
    locations = locations_sf,
    route_legs_geodesic = routes_geodesic,
    route_legs_original = routes_original,
    route_uncertainty = routes_geodesic[0, ],
    event_uncertainty = uncertainty_sf,
    operating_areas = operating_regions_sf,
    uncertainty_areas = uncertainty_sf,
    major_operating_regions = operating_regions_sf,
    disputed_routes = routes_geodesic[!routes_geodesic$include_default_map |
      grepl("disput|conflict|exclude|unsupported", routes_geodesic$source_status, ignore.case = TRUE), ],
    natural_earth_land = land_sf
  )

  write_layer_set <- function(path) {
    if (file.exists(path) && !isTRUE(file.remove(path))) {
      stop("Generated GeoPackage is locked and could not be replaced: ", path, call. = FALSE)
    }
    first <- TRUE
    for (nm in names(layers)) {
      sf::st_write(layers[[nm]], path, layer = nm, delete_dsn = first, delete_layer = TRUE, quiet = TRUE,
                   layer_options = "FID=feature_id")
      first <- FALSE
    }
    path
  }
  processed_gpkg <- write_layer_set(file.path(processed, "uss_terror_map_layers.gpkg"))
  qgis_primary <- project_path("qgis", "uss_terror_layers.gpkg")
  qgis_gpkg <- qgis_primary
  if (file.exists(qgis_primary) && !isTRUE(file.remove(qgis_primary))) {
    qgis_gpkg <- project_path("qgis", "uss_terror_layers_phase4.gpkg")
    warning(
      "The primary QGIS GeoPackage is open in another process. Wrote the complete exchange package to ",
      qgis_gpkg, " instead; close QGIS before replacing the primary file.", call. = FALSE
    )
  }
  qgis_gpkg <- write_layer_set(qgis_gpkg)
  invisible(qgis_gpkg)
}

detect_qgis <- function() {
  candidates <- c(
    Sys.which("qgis_process"), Sys.which("qgis_process.exe"),
    Sys.glob("C:/Program Files/QGIS*/bin/qgis_process*.exe"),
    Sys.glob("C:/OSGeo4W*/bin/qgis_process*.exe")
    , Sys.glob(file.path(Sys.getenv("LOCALAPPDATA"), "Programs/OSGeo4W/apps/qgis*/bin/qgis_process*.exe"))
  )
  candidates <- unique(candidates[nzchar(candidates) & file.exists(candidates)])
  if (length(candidates)) candidates[[1]] else NA_character_
}

detect_gis_tools <- function() {
  patterns <- c(
    "C:/Program Files/QGIS*/bin/qgis_process*.exe",
    "C:/Program Files/QGIS*/bin/qgis-bin.exe",
    "C:/Program Files/QGIS*/bin/ogr2ogr.exe",
    "C:/Program Files/QGIS*/bin/ogrinfo.exe",
    "C:/OSGeo4W*/bin/qgis_process*.exe",
    "C:/OSGeo4W*/bin/qgis-bin.exe",
    "C:/OSGeo4W*/bin/ogr2ogr.exe",
    "C:/OSGeo4W*/bin/ogrinfo.exe"
  )
  local_osgeo <- file.path(Sys.getenv("LOCALAPPDATA"), "Programs", "OSGeo4W")
  local_patterns <- c(
    file.path(local_osgeo, "apps/qgis*/bin/qgis_process*.exe"),
    file.path(local_osgeo, "bin/qgis*-bin.exe"),
    file.path(local_osgeo, "bin/ogr2ogr.exe"),
    file.path(local_osgeo, "bin/ogrinfo.exe")
  )
  paths <- unique(c(
    unname(Sys.which(c("qgis_process", "qgis-bin", "ogr2ogr", "ogrinfo"))),
    unlist(lapply(c(patterns, local_patterns), Sys.glob), use.names = FALSE)
  ))
  paths[nzchar(paths) & file.exists(paths)]
}
