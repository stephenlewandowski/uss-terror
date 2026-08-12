args <- commandArgs(trailingOnly = FALSE)
script_arg <- args[grepl("^--file=", args)][1]
script_path <- normalizePath(sub("^--file=", "", script_arg), winslash = "/", mustWork = TRUE)
project <- normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE)
setwd(project)
Sys.setenv(USS_TERROR_PROJECT = project)

required_packages <- c("sf", "dplyr", "readr", "readxl", "geosphere", "ggplot2", "ggrepel",
  "ggspatial", "rnaturalearth", "rnaturalearthdata", "yaml", "digest", "tibble", "testthat", "jsonlite")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages)) stop("Project packages are missing: ", paste(missing_packages, collapse = ", "), ". Run Rscript scripts/setup.R first.", call. = FALSE)

modules <- c("helpers.R", "load_data.R", "validate_data.R", "prepare_events.R", "prepare_routes.R",
  "antimeridian.R", "geodesic_routes.R", "map_layers.R", "timeline_plot.R", "event_table.R",
  "map_filters.R", "static_maps.R", "qgis_exports.R", "nautical_layers.R", "gebco_layers.R",
  "gmrt_services.R", "gmrt_download.R", "mine_sources.R", "minefield_models.R",
  "minefield_validation.R", "minefield_proximity.R")
invisible(lapply(file.path(project, "R", modules), source, local = globalenv()))
settings <- load_settings()

message("[1/18] Verifying resume audit and creating read-only source inventory")
if (!file.exists(project_path("outputs", "reports", "project_resume_audit.md"))) {
  stop("Phase 1 resume audit is missing.", call. = FALSE)
}
check_required_sources()
inventory <- create_source_inventory()
write_csv_project(inventory, "outputs", "reports", "source_inventory.csv")

message("[2/18] Loading source datasets")
source_data <- load_source_data()

message("[3/18] Normalizing tabular data")
events <- prepare_events(source_data$events_raw)
routes <- prepare_routes(source_data$routes_raw)
locations <- prepare_locations(events)

message("[4/18] Constructing geodesic routes")
routes_geodesic <- build_geodesic_routes(routes, crs = settings$crs, interval_nm = settings$geodesic_interval_nm)
routes_original <- build_original_routes(routes, crs = settings$crs)

message("[5/18] Verifying antimeridian correction")
wraps <- vapply(sf::st_geometry(routes_geodesic), geometry_has_wrap, logical(1))
if (any(wraps)) stop("Antimeridian correction failed for: ", paste(routes_geodesic$leg_id[wraps], collapse = ", "), call. = FALSE)
write_antimeridian_validation()

message("[6/18] Creating geodesic uncertainty and modeled operating-region areas")
events_sf <- events_as_sf(events, settings$crs)
locations_sf <- locations_as_sf(locations, settings$crs)
uncertainty_sf <- build_uncertainty_areas(events, settings$crs)
operating_regions_sf <- build_operating_regions(uncertainty_sf)
land_sf <- rnaturalearth::ne_countries(scale = "medium", returnclass = "sf") |>
  sf::st_transform(settings$crs)
write_coordinate_review(events)

message("[7/18] Building conflict register and USS Terror validation report")
issues <- validate_data(events, routes, locations, source_data$geojson_raw, routes_geodesic, uncertainty_sf, settings)
conflicts <- build_conflict_register(issues)
counts <- list(
  events = nrow(events), routes = nrow(routes), geodesic_features = nrow(routes_geodesic),
  geodesic_parts = count_route_parts(routes_geodesic),
  disputed = sum(!routes$include_default_map | grepl("disput|conflict|exclude|unsupported", routes$source_status, ignore.case = TRUE), na.rm = TRUE),
  uncertainty = nrow(uncertainty_sf)
)
write_validation_report(issues, counts)
if (any(issues$severity == "error")) stop("Blocking validation errors found; see outputs/reports/validation_report.md", call. = FALSE)

message("[8/18] Exporting canonical CSV and GeoPackage layers")
gpkg <- export_spatial_data(events_sf, routes_geodesic, routes_original, locations_sf,
  uncertainty_sf, operating_regions_sf, land_sf, conflicts)

message("[9/18] Validating shared year-overlap filtering")
year_validation <- write_year_filter_validation(events_sf, routes_geodesic)
if (!all(year_validation$pacific_map_ids_match_filter)) {
  stop("Pacific map route IDs differ from the shared filter result.", call. = FALSE)
}

message("[10/18] Building external modern-reference inventories without downloading grids")
gmrt_inventory <- write_gmrt_inventory(settings)

message("[11/18] Building empty mine-warfare schema, exports, and candidate-review templates")
mine_tables <- write_empty_mine_database(crs = settings$crs)
mine_issues <- write_mine_validation_report(mine_tables, settings)
if (any(mine_issues$severity == "error")) stop("Empty mine schema validation failed.", call. = FALSE)

message("[12/18] Checking QGIS exchange package and styles")
qml_files <- list.files(project_path("qgis", "styles"), pattern = "\\.qml$", full.names = TRUE)
if (length(qml_files) < 14L) stop("QGIS style set is incomplete; expected at least fourteen QML files.", call. = FALSE)
qgis_process <- detect_qgis()
gis_tools <- detect_gis_tools()

message("[13/18] Generating publication maps")
static_paths <- generate_static_maps(events_sf, routes_geodesic, uncertainty_sf, land_sf)

message("[14/18] Writing machine-readable build summary")
summary <- list(
  generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  project = project, r_version = R.version.string,
  counts = counts,
  validation = list(errors = sum(issues$severity == "error"), warnings = sum(issues$severity == "warning"), info = sum(issues$severity == "info")),
  qgis_process = if (is.na(qgis_process)) NA_character_ else unname(qgis_process),
  gis_tools = as.list(gis_tools),
  qgis_project_created = FALSE,
  qgis_import_package = gpkg,
  static_maps = static_paths,
  year_filter = lapply(seq_len(nrow(year_validation)), function(i) as.list(year_validation[i, ])),
  external_layers = list(
    openseamap = settings$nautical_layers$openseamap$service_check,
    gebco = settings$nautical_layers$gebco$service_check,
    gmrt = settings$gmrt$service_check,
    gmrt_cached_rasters = sum(gmrt_inventory$raw_cached)
  ),
  mine_schema = list(
    tables = names(mine_tables), canonical_minefields = nrow(mine_tables$minefields),
    canonical_vessels = nrow(mine_tables$vessels), vessel_operation_links = nrow(mine_tables$vessel_operation_links),
    validation_errors = sum(mine_issues$severity == "error")
  ),
  raw_sha256 = as.list(stats::setNames(inventory$sha256, inventory$filename))
)
jsonlite::write_json(summary, project_path("outputs", "reports", "build_summary.json"), pretty = TRUE, auto_unbox = TRUE, na = "null")

message("[15/18] Verifying required reports and empty interfaces")
required_reports <- c("project_resume_audit.md", "year_filter_validation.md", "antimeridian_validation.md",
  "coordinate_review.csv", "gmrt_inventory.csv", "mine_schema_validation.md")
missing_reports <- required_reports[!file.exists(file.path(project_path("outputs", "reports"), required_reports))]
if (length(missing_reports)) stop("Build reports missing: ", paste(missing_reports, collapse = ", "), call. = FALSE)

message("[16/18] Confirming no automatic GMRT downloads or canonical mine records")
if (any(gmrt_inventory$raw_cached)) message("Existing user-cached GMRT rasters detected; the build did not download them.")
if (nrow(mine_tables$minefields) || nrow(mine_tables$vessels)) stop("Schema-only build unexpectedly contains canonical mine records.", call. = FALSE)

message("[17/18] Running offline tests")
test_results <- testthat::test_dir(project_path("tests", "testthat"), reporter = "summary", stop_on_failure = TRUE, stop_on_warning = FALSE)

phase_report <- c(
  "", "## Phase 2–4 integration checks", "",
  paste0("- Cross-year interval-overlap filter table: **", ifelse(all(year_validation$pacific_map_ids_match_filter), "PASS", "FAIL"), "**."),
  paste0("- The Pacific Theater map receives the shared filtered route IDs: **", ifelse(all(year_validation$pacific_map_ids_match_filter), "PASS", "FAIL"), "**."),
  "- Disputed routes are preserved outside the default visible layer: **PASS**.",
  "- OpenSeaMap and GEBCO failure paths are nonfatal under mocked offline tests: **PASS**.",
  paste0("- GMRT metadata, empty-cache, size-limit, and explicit-confirmation tests: **PASS**; cached raw grids: ", sum(gmrt_inventory$raw_cached), "."),
  paste0("- Empty mine-warfare tables/layers and QGIS-compatible field types: **", ifelse(any(mine_issues$severity == "error"), "FAIL", "PASS"), "**."),
  paste0("- Canonical minefield/vessel/link records: ", nrow(mine_tables$minefields), "/", nrow(mine_tables$vessels), "/", nrow(mine_tables$vessel_operation_links), "."),
  paste0("- Mine layers hidden by default and navigation warning configured: **", ifelse(
    isFALSE(setting_value(settings, c("mine_warfare", "default_visible"), TRUE)) &&
      isTRUE(setting_value(settings, c("mine_warfare", "current_navigation_warning"), FALSE)), "PASS", "FAIL"), "**."),
  paste0("- QGIS QML style files present: ", length(qml_files), "; QGIS/GDAL executables detected: ", length(gis_tools), "."),
  "- Offline automated test suite: **PASS**.",
  "- Historical mine-source research and canonical population: **NOT STARTED (out of scope for Phases 1–4)**."
)
cat(paste0(phase_report, collapse = "\n"), "\n", file = project_path("outputs", "reports", "validation_report.md"), append = TRUE)

message("[18/18] Build completed successfully. Events: ", counts$events, "; route legs: ", counts$routes,
        "; geodesic parts: ", counts$geodesic_parts, "; warnings retained: ", sum(issues$severity == "warning"))
