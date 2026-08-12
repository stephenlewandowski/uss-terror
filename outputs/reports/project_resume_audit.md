# USS Terror project resume audit

Generated: 2026-07-20 (Asia/Seoul)

## Project and checkpoint

- Project path: `C:/Projects/USSTerrorMap`
- Project version: `0.1.0` from `DESCRIPTION`
- Git status: this directory is not a Git repository; no commit checkpoint was possible.
- Pre-edit checkpoint: `outputs/backups/USSTerrorMap_pre_phases_2_4_20260720_214721.zip`
- Checkpoint size: 7,682,480 bytes
- Checkpoint SHA-256: `9BDF06703E2A120BAA348AF58F3BEBD9E48E4DAD2D83E8892A9C9EF5B4C1A0E9`
- R runtime: R 4.6.1 (2026-06-24 ucrt)
- Package environment: project-local `renv` library; `renv::status()` reported no issues before edits.

## Existing sources and generated data

All four required source datasets were already present under `data/raw`, so no search or copy from another directory was needed:

- `uss_terror_pacific_timeline_1943_1946.xlsx`
- `uss_terror_timeline_1943_1946.csv` (61 event rows)
- `uss_terror_route_legs_1943_1946.csv` (57 route-leg rows)
- `uss_terror_timeline_and_route_1943_1946.geojson` (118 features)

An auxiliary `Ryan-BookUSSTerror-1.pdf` was also present and inventoried. It was not parsed or used for new historical extraction in this run.

Existing processed products included event, route-leg, and location CSV/GeoPackage files plus a consolidated `qgis/uss_terror_layers.gpkg`. The consolidated package contained `events`, `route_legs_geodesic`, `route_legs_original`, `locations`, `uncertainty_areas`, `major_operating_regions`, `disputed_routes`, and `natural_earth_land`.

## Existing R and build code

Existing modules before the Phase 2–4 work were:

- `R/helpers.R`
- `R/load_data.R`
- `R/validate_data.R`
- `R/prepare_events.R`
- `R/prepare_routes.R`
- `R/geodesic_routes.R`
- `R/antimeridian.R`
- `R/map_layers.R`
- `R/timeline_plot.R`
- `R/event_table.R`
- `R/static_maps.R`
- `R/qgis_exports.R`

Existing entry points were `scripts/setup.R`, `scripts/build_all.R`, `scripts/validate_all.R`, and `scripts/launch_app.R`.

## Existing Shiny behavior

The process listening on `127.0.0.1:3838` was `Rscript.exe scripts/launch_app.R`. A baseline browser check found no Shiny output errors and confirmed that the existing `deployment_map` Leaflet widget loaded with 61 events, 56 default-visible route legs, 83,106 reconstructed nautical miles, and five review items.

Existing tabs were:

- Deployment Map
- Timeline
- Events
- Route Legs
- Sources and Conflicts
- Methods

The application had only one Leaflet output (`deployment_map`). It did not have separate Pacific and global map outputs, a Historical Mine Warfare tab, modern seamark/bathymetry controls, or empty mine-warfare interfaces.

## Existing year-filter behavior

The event reactive used interval-overlap filtering for the selected year. The route reactive did not use the year selector at all; it only applied the combined date-range/slider window and the disputed-route flag. Events and route tables used the unfiltered full datasets, and dashboard statistics also used full datasets. Therefore the map, timeline, tables, detail navigation, and statistics were not driven by one authoritative shared filter pipeline.

In the baseline browser session the year widget exposed only `All years`; explicit 1943–1946 choices were not available for selection. The revised implementation must use stable explicit choices and must apply the same selected-year overlap rule to events and routes.

Current expected default-visible route counts from the canonical data are: All years 56, 1943 7, 1944 29, 1945 17, and 1946 3. No supplied canonical route leg crosses a year boundary, so cross-year behavior requires a synthetic noncanonical test fixture.

## Existing geographic processing

The current route pipeline already:

- retains original endpoint-to-endpoint LineStrings;
- creates geodesic routes with `geosphere::gcIntermediate()`;
- splits interpolated coordinates at ±180 degrees;
- validates that no within-part longitude jump exceeds 180 degrees;
- creates geodesic nautical-mile uncertainty circles; and
- exports original and display geometries separately.

The baseline automated suite passed its existing great-circle, antimeridian, and uncertainty checks. The present static-map implementation shifts longitudes for a nominal Pacific display but still uses geographic coordinates rather than a tested true Pacific-centered projected CRS. It also generated only six numbered map products, with names differing from the resumed specification.

## Existing QGIS outputs

The project had a QGIS exchange GeoPackage, seven QML styles, a manual initializer script, and QGIS setup documentation. No `.qgz` project was present. `qgis_process`, `qgis-bin`, `ogr2ogr`, and `ogrinfo` were not found on `PATH` or in the checked `C:/Program Files/QGIS*` and `C:/OSGeo4W*` patterns during the baseline audit. The existing documentation correctly did not claim that a QGIS project had been opened or validated.

## Existing external-layer functionality

The map could use optional CartoDB tiles and had a local Natural Earth fallback controlled by `USS_TERROR_OFFLINE`. It did not yet have OpenSeaMap, GEBCO, or GMRT configuration or failure-safe layer helpers.

## Existing tests and baseline result

The baseline suite comprised source/field/date tests, interval-overlap tests, preservation tests, great-circle and antimeridian tests, uncertainty-radius tests, GeoPackage readability tests, table-field tests, and Plotly click-registration tests. `Rscript scripts/validate_all.R` completed successfully before edits. The existing validation report retained five warnings: one disputed/low-confidence route (`L028`) and three speed-threshold findings (`L023`, `L034`, and `L035`, with `L028` also flagged for low confidence).

## Proposed Phase 2–4 changes

1. Replace the single deployment map with distinct Pacific and global Pacific-centered Leaflet outputs driven by one shared filtered dataset.
2. Centralize selected-year/date/category/confidence/disputed filtering and use it for maps, timeline, tables, statistics, detail selection, and navigation.
3. Add explicit cross-year overlap behavior, both-map consistency tests, antimeridian route cases, coordinate review, and true projected static-map products.
4. Centralize optional OpenSeaMap, GEBCO, and GMRT configuration and add network-independent failure/cache tests.
5. Add the complete empty mine-warfare relational schema, candidate-review templates, validation, GeoPackage/CSV exports, Shiny interface, QGIS-ready layers, styles, and documentation.
6. Preserve all existing evidence and working offline behavior; do not begin historical mine-source extraction or bulk bathymetry downloads.
