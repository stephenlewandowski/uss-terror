# USS Terror (CM-5): Pacific Deployment, 1943–1946

This project reconstructs the wartime and immediate postwar deployment of USS *Terror* (CM-5) as an evidence-aware chronology, interactive Shiny application, reproducible spatial pipeline, QGIS exchange package, and publication map series.

The current authorized implementation is complete through Phase 5.2: the Phase 1–4 deployment and modern-context foundations, one resolved candidate-only Kerama Retto evidence batch, and a canonical-safe Shiny candidate-review mode. Ten candidate decisions are accepted and one unsupported event-level relationship is rejected; all eleven canonical mine-warfare tables remain empty.

The connecting lines are geodesic interpolations between documented or modeled endpoints. They are **not exact ship tracks**, and the application never creates false daily positions between widely spaced records. Island, port, anchorage, and harbor centroids remain labeled through `coordinate_basis` and `position_uncertainty_nm`.

## Inputs and preservation

Canonical inputs are read only from `data/raw`:

- `uss_terror_pacific_timeline_1943_1946.xlsx`
- `uss_terror_timeline_1943_1946.csv`
- `uss_terror_route_legs_1943_1946.csv`
- `uss_terror_timeline_and_route_1943_1946.geojson`

The auxiliary historical PDF in that folder is inventoried but is not parsed as a canonical table. Every raw file's byte size, timestamp, read status, record count where applicable, and SHA-256 digest are written to `outputs/reports/source_inventory.csv`. Build scripts do not edit, rename, move, or delete raw inputs.

## Quick start (PowerShell)

```powershell
Set-Location C:\Projects\USSTerrorMap
& 'C:\Program Files\R\R-4.6.1\bin\Rscript.exe' scripts/setup.R
& 'C:\Program Files\R\R-4.6.1\bin\Rscript.exe' scripts/build_all.R
& 'C:\Program Files\R\R-4.6.1\bin\Rscript.exe' scripts/validate_all.R
& 'C:\Program Files\R\R-4.6.1\bin\Rscript.exe' scripts/launch_app.R
```

If `Rscript` is on `PATH`, the shorter requested commands are equivalent:

```powershell
Set-Location C:\Projects\USSTerrorMap
Rscript scripts/setup.R
Rscript scripts/build_all.R
Rscript scripts/validate_all.R
Rscript scripts/launch_app.R
```

The app opens at `http://127.0.0.1:3838/` only while the local R/Shiny process is running. OpenStreetMap is the normal default base layer. To force fully local operation, set `USS_TERROR_OFFLINE=true` before launching; the generated Natural Earth shapefile boundary-and-label base becomes the default and the Pacific map, timeline, tables, reports, and candidate-review interface continue to work without tiles.

## Reproducible R and RStudio setup

R 4.6.1 was detected during initial development. `scripts/setup.R` bootstraps `renv` into a project-local library, installs the declared packages, and records resolved versions in `renv.lock`; it does not intentionally install packages system-wide. On another computer, open the project folder in RStudio and run `renv::restore()` or rerun `scripts/setup.R`.

RStudio can open `USSTerrorMap.Rproj` directly. Ensure the working directory is `C:/Projects/USSTerrorMap` before sourcing scripts or clicking **Run App** on `app.R`.

## Build products

The build order is inventory, load, normalize, validate, geodesic construction, antimeridian correction, uncertainty geometry, GeoPackage export, QGIS check, static maps, reports, and tests. A blocking missing or malformed required input stops the build and creates a clear report; warnings remain in the conflict register.

Principal normalized and schema outputs are:

```text
data/processed/events.gpkg        data/processed/events.csv
data/processed/route_legs.gpkg    data/processed/route_legs.csv
data/processed/locations.gpkg     data/processed/locations.csv
data/processed/conflicts.csv
data/reference/simple_boundaries/natural_earth_boundaries.shp
qgis/uss_terror_layers.gpkg
data/processed/pacific_mine_warfare.gpkg
outputs/reports/gmrt_inventory.csv
outputs/reports/mine_schema_validation.md
```

All canonical spatial data use EPSG:4326 (WGS84). The consolidated QGIS GeoPackage includes events, source and geodesic routes, route/event uncertainty interfaces, operating areas, disputed routes, locations, and Natural Earth land. The separate mine-warfare GeoPackage contains eleven empty, QGIS-readable schema layers/tables; future test or candidate records are never copied into it automatically.

## Shiny application

The cleaner top navigation provides the primary **Pacific Theater** map, grouped deployment records, **Historical Mine Warfare**, and grouped research pages. Five compact route metrics summarize visible events, route legs, reconstructed distance, combat/damage events, and unique port/shipyard days. One shared reactive filter supplies the map, timeline, tables, counts, selection, and navigation. OpenStreetMap is selected by default when online; the expanded layer control also offers GEBCO and a simple local boundary-and-label base generated as an ESRI Shapefile. The explicit year choices are All years and 1943–1946. Selected-year inclusion uses interval overlap; a cross-year leg appears in each overlapping year as its complete endpoint-to-endpoint connector. Cumulative mode is separate. Pacific centering changes presentation, not the EPSG:4326 master coordinates or Leaflet projection.

Visual evidence conventions use line type and marker symbol in addition to color:

- Solid line: included, high-confidence reconstruction.
- Dashed line: included but estimated/lower-confidence reconstruction.
- Dotted muted line: disputed or excluded route.
- Larger outlined point: major combat or damage event.
- Wrench and burst symbols: repair/shipyard and air attack/kamikaze records.
- Semi-transparent polygons: position uncertainty or modeled operating-region summaries.

## Static cartography

`outputs/static_maps` contains full-deployment, 1943–1944 support, Iwo Jima/Okinawa, kamikaze withdrawal and repair, postwar, and confidence/uncertainty maps. Regenerate them with `scripts/build_all.R`. Labels are selectively reduced to prevent clutter; source and reconstruction caveats appear in every caption.

The full-Pacific and global products use a true Pacific-centered Robinson transformation for static display, with a single wrapped world and no duplicated landmasses. Interactive maps remain Web Mercator viewports and use a 0–360 display shift for Pacific continuity while preserving canonical longitudes.

## Modern maritime and bathymetric context

OpenStreetMap is the default online reference base. OpenSeaMap seamarks are an optional modern overlay, not a wartime chart. GEBCO provides optional modern global bathymetric context. GMRT is reserved for explicitly bounded regional detail; no GMRT grid is downloaded during a normal build. `scripts/cache_gmrt_regions.R` first lists the six configured regions, then requires `--region=<id> --confirm`, checks service metadata and the 250 MB limit, preserves the raw grid, and writes processed display rasters. Modern seamark and bathymetric overlays remain off by default, attributed in configuration, and nonfatal when unavailable.

## Historical mine-warfare research interface

The canonical database remains deliberately empty. Its relational design separates minefields, boundaries, laying/sweeping/status events, vessels, units, many-to-many vessel-operation links, sources/maps, and uncertainty. Unknown vessels remain null. Exact, month, year, range, circa, inferred, and unknown precision values remain explicit. Sweeping activity never proves clearance by itself.

Phase 5 contains one bounded Kerama Retto batch in `data/mine_warfare/review/candidate_*.csv`. Evidence review resolved every candidate decision: the Area B-5 mined locality, mine-destruction operation, USS *Terror* area role, USS PC-584 identity/direct operation link, four sources, and 2 NM uncertainty record are accepted; the unsupported USS *Terror* event-level link is rejected and retained for audit. Reproduced primary records are archived and hash-verified. No clearance is asserted. Run `Rscript scripts/validate_phase5_candidates.R` and review `outputs/reports/phase5_kerama_candidate_review.md`.

Phase 5.2 exposes those records in Shiny through separate **Canonical**, **Accepted review candidates**, and **Rejected audit records** views. The accepted view is the default and immediately plots the Area B-5 candidate locality, mine-destruction operation, and 2 NM uncertainty envelope with distinct styling. A curated decision register, evidence-detail panel, vessel/operation tables, CSV download, source metadata, and archived-file integrity table support manual inspection without copying any candidate into canonical storage. The rejected USS *Terror* event link remains visible as an audit decision while the accepted area-level role remains separately visible.

## QGIS

QGIS was not required for the R build. QGIS/GDAL executables were not detected in the current environment, so no untested `.qgz` was created. Follow `qgis/README_QGIS.md` to load both GeoPackages, apply styles, configure temporal fields/groups/services, and optionally run `qgis/initialize_qgis_project.py` inside QGIS. A generated project is not validated until it has actually been opened and visually reviewed.

## Updating source data

1. Preserve the current raw file and its hash; do not overwrite it without an archival reason.
2. Put the updated file under a distinct archival name outside `data/raw`, then intentionally replace the canonical project copy only after review.
3. Confirm all required columns remain present.
4. Run `scripts/build_all.R` and compare `source_inventory.csv`, `conflicts.csv`, `validation_report.md`, static maps, and test results.
5. Review every new low-confidence, excluded, high-speed, coordinate-variant, or overlapping-interval warning.

## Historical and geographic limitations

Dates can be exact, estimated, or ranges. An event is included when its interval overlaps the selected filter. Coordinates may be a port/anchorage centroid, an island centroid, or a modeled offshore point. Position uncertainty is rendered as a geodesic circle with a radius in nautical miles, never as a planar EPSG:4326 buffer.

Great-circle lines are interpolated locally and split at ±180° so the Pacific route does not wrap across Eurasia or the Atlantic. The original two-endpoint LineString is retained separately for traceability but is not the default display. MGRS is not used as the master representation because open-ocean routes span multiple UTM zones and the antimeridian.

The modeled major operating regions are unions of existing event-level uncertainty circles for explicitly named Iwo Jima, Okinawa–Kerama, and occupation records. They are interpretive summaries, not operational boundaries.

Validation flags rather than silently repairs source conflicts, speeds above the configured 23-knot review threshold, missing locators, duplicates, interval overlaps, large uncertainty, malformed geometry, and low-confidence routes. See `outputs/reports/methods.md` for the formal methodology.

## Project structure

`R/` contains modular transformation and visualization functions; `scripts/` contains reproducible entry points; `tests/testthat/` contains network-independent checks; `config/settings.yml` centralizes operational settings; `data/` separates immutable inputs from generated data; `qgis/` contains exchange data and styles; `www/` contains local UI assets; and `outputs/` contains maps, exports, screenshots, and reports.
