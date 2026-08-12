args <- commandArgs(trailingOnly = FALSE)
script_path <- normalizePath(sub("^--file=", "", args[grepl("^--file=", args)][1]), winslash = "/", mustWork = TRUE)
project <- normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE)
setwd(project)
Sys.setenv(USS_TERROR_PROJECT = project)

required <- c(
  "data/processed/events.gpkg", "data/processed/route_legs.gpkg", "data/processed/locations.gpkg",
  "data/processed/events.csv", "data/processed/route_legs.csv", "data/processed/locations.csv",
  "data/processed/conflicts.csv", "data/processed/uss_terror_map_layers.gpkg",
  "data/processed/pacific_mine_warfare.gpkg",
  "data/reference/simple_boundaries/natural_earth_boundaries.shp",
  "data/reference/simple_boundaries/natural_earth_boundaries.shx",
  "data/reference/simple_boundaries/natural_earth_boundaries.dbf",
  "data/reference/simple_boundaries/natural_earth_boundaries.prj",
  "outputs/reports/source_inventory.csv", "outputs/reports/project_resume_audit.md",
  "outputs/reports/validation_report.md", "outputs/reports/year_filter_validation.md",
  "outputs/reports/antimeridian_validation.md", "outputs/reports/coordinate_review.csv",
  "outputs/reports/gmrt_inventory.csv", "outputs/reports/mine_schema_validation.md",
  "outputs/static_maps/01_full_pacific_deployment.png", "outputs/static_maps/01_full_pacific_deployment.pdf",
  "outputs/static_maps/02_global_pacific_centered.png", "outputs/static_maps/02_global_pacific_centered.pdf",
  "outputs/static_maps/03_1943_1944_support_operations.png", "outputs/static_maps/04_iwo_jima_okinawa_1945.png",
  "outputs/static_maps/05_kamikaze_withdrawal_repair_1945.png",
  "outputs/static_maps/06_postwar_occupation_1945_1946.png",
  "outputs/static_maps/07_confidence_and_uncertainty.png"
)
missing <- required[!file.exists(file.path(project, required))]
if (length(missing)) stop("Required outputs are missing: ", paste(missing, collapse = ", "), call. = FALSE)

boundary_path <- file.path(
  project, "data", "reference", "simple_boundaries", "natural_earth_boundaries.shp"
)
boundaries <- sf::st_read(boundary_path, quiet = TRUE)
required_boundary_fields <- c("name", "admin", "labelrank", "label_x", "label_y")
missing_boundary_fields <- setdiff(required_boundary_fields, names(boundaries))
if (length(missing_boundary_fields)) {
  stop("Simple boundary shapefile fields missing: ", paste(missing_boundary_fields, collapse = ", "), call. = FALSE)
}
if (!nrow(boundaries) || any(!sf::st_is_valid(boundaries))) {
  stop("Simple boundary shapefile is empty or contains invalid geometry.", call. = FALSE)
}

qgis_candidates <- file.path(project, "qgis", c("uss_terror_layers_phase4.gpkg", "uss_terror_layers.gpkg"))
gpkg <- qgis_candidates[file.exists(qgis_candidates)][1]
if (!length(gpkg) || is.na(gpkg)) stop("No QGIS exchange GeoPackage exists.", call. = FALSE)
layers <- sf::st_layers(gpkg)$name
expected_layers <- c("events", "route_legs_geodesic", "route_legs_original", "locations",
  "route_uncertainty", "event_uncertainty", "operating_areas", "uncertainty_areas",
  "major_operating_regions", "disputed_routes", "natural_earth_land")
missing_layers <- setdiff(expected_layers, layers)
if (length(missing_layers)) stop("GeoPackage layers missing: ", paste(missing_layers, collapse = ", "), call. = FALSE)
for (layer in expected_layers) {
  x <- sf::st_read(gpkg, layer = layer, quiet = TRUE)
  if (nrow(x) && any(!sf::st_is_valid(x))) stop("Invalid geometry in layer: ", layer, call. = FALSE)
}
mine_gpkg <- file.path(project, "data", "processed", "pacific_mine_warfare.gpkg")
mine_layers <- sf::st_layers(mine_gpkg)$name
source(file.path(project, "R", "helpers.R"))
source(file.path(project, "R", "mine_sources.R"))
source(file.path(project, "R", "minefield_models.R"))
source(file.path(project, "R", "minefield_validation.R"))
missing_mine_layers <- setdiff(names(minefield_schema()), mine_layers)
if (length(missing_mine_layers)) stop("Mine GeoPackage layers missing: ", paste(missing_mine_layers, collapse = ", "), call. = FALSE)
mine_tables <- load_mine_database(mine_gpkg)
mine_issues <- validate_mine_schema(mine_tables, load_settings())
if (any(mine_issues$severity == "error")) stop("Mine schema validation errors remain.", call. = FALSE)
if (nrow(mine_tables$minefields) || nrow(mine_tables$vessels)) stop("Schema-only canonical mine tables are not empty.", call. = FALSE)
testthat::test_dir(file.path(project, "tests", "testthat"), reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)
message("Validation and tests passed. Detailed historical warnings remain in outputs/reports/validation_report.md.")
