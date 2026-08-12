# Phase 1–4 implementation change log

Completed 20 July 2026. This log covers only the authorized audit, Shiny/year-filter, geographic validation, external-context framework, and empty mine-warfare framework. Historical mine-source research and canonical population were not started.

## Audit and preservation

- Inventoried and hashed canonical raw sources without modifying them.
- Recorded the resume audit in `project_resume_audit.md`.
- Created `outputs/backups/USSTerrorMap_pre_phases_2_4_20260720_214721.zip` and retained the recoverable pre-edit `app.R` copy in the backup directory.

## Application and filtering

- Initially created separate Pacific and global Pacific-centered maps, then simplified the current UI to one Pacific Theater map supplied by the shared filter reactive.
- Added explicit All years/1943/1944/1945/1946 interval-overlap and cumulative behavior in `R/map_filters.R`.
- Added persistent historical/modern layer controls, shared selection/navigation, modern-data warnings, cached-GMRT hooks, and the empty mine-warfare tab.
- Extended `R/map_layers.R`, `R/timeline_plot.R`, and `R/event_table.R`; added local UI styling under `www/css`.
- Made OpenStreetMap the default online base and added a selectable, generated Natural Earth shapefile boundary-and-label base for local/offline use.

## Geography and cartography

- Extended `R/antimeridian.R`, `R/geodesic_routes.R`, `R/validate_data.R`, and `R/static_maps.R` for six-case wrap validation, coordinate review, geodesic uncertainty, and true Pacific-centered static projection.
- Regenerated the seven requested static map products and validation reports.
- Extended QGIS exports with route/event uncertainty and operating-area layers.

## Modern service framework

- Added `R/nautical_layers.R`, `R/gebco_layers.R`, `R/gmrt_services.R`, and `R/gmrt_download.R`.
- Centralized verified endpoints, attribution, size limits, six bounded GMRT regions, and default/offline behavior in `config/settings.yml`.
- Added `scripts/cache_gmrt_regions.R`; it requires metadata review and explicit `--confirm` and downloads nothing during a normal build.

## Empty mine-warfare framework

- Added `R/mine_sources.R`, `R/minefield_models.R`, `R/minefield_validation.R`, and `R/minefield_proximity.R`.
- Created the eleven-layer empty `data/processed/pacific_mine_warfare.gpkg`, CSV export templates, candidate-review templates, provenance/date/vessel/link validation, and navigation warnings.
- Added seven empty-layer-safe mine QML styles and expanded the QGIS initializer/instructions to the four requested groups and twelve documented themes.

## Reproducibility, scripts, documentation, and tests

- Updated `DESCRIPTION`, `scripts/setup.R`, `scripts/build_all.R`, `scripts/validate_all.R`, and `scripts/launch_app.R`; added mine build, GMRT cache, and QGIS detection entry points.
- Updated `README.md`, `PROJECT_STATUS.md`, methods documentation, minefield methods, QGIS instructions, validation report, build summary, service/cache inventories, and coordinate/antimeridian/year reports.
- Added offline tests for year overlap/map ID parity, external failure behavior, GMRT metadata/cache/limits/view selection, mine schemas/foreign keys/dates/clearance, empty Shiny/QGIS interfaces, and QGIS-compatible types.
- Final build and independent validation passed. The normal local Shiny process was left running at `http://127.0.0.1:3838/`.

## QGIS lock note

An already-open QGIS 3.44.12 LTR session held `qgis/uss_terror_layers.gpkg`. The build did not close QGIS or risk unsaved work; it wrote the complete validated exchange to `qgis/uss_terror_layers_phase4.gpkg`. After QGIS is closed, rerun the build to restore the primary filename.
