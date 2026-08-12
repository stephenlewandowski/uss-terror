# Project status — USS Terror map

Updated 9 August 2026. The authorized work is complete through Phase 5.2. Phase 5 resolved one bounded, candidate-only Kerama Retto batch, and Phase 5.2 added a canonical-safe Shiny review mode. Accepted and rejected review decisions are visible for inspection, but no candidate has been copied into a canonical table.

## Completed components

- Phase 1: existing project audited; raw sources hashed and inventoried; pre-edit timestamped backup created; baseline tests retained.
- Phase 2/current UI: one Pacific Theater Leaflet map uses the shared filter pipeline. OpenStreetMap is the default online base; a generated local Natural Earth boundary-and-label shapefile is selectable and becomes the offline default. Year choices are All years and 1943–1946. Events and route legs use interval overlap, so a cross-year leg remains complete and appears in both overlapping years.
- Phase 3: great-circle reconstruction, WGS84 coordinate review, six-case antimeridian regression report, Pacific-centered static projection, and seven publication map products.
- Phase 4: optional OpenSeaMap, GEBCO, and GMRT frameworks; metadata-first/explicit-confirmation GMRT cache; eleven-table empty mine-warfare database; empty candidate-review, Shiny, export, and QGIS interfaces; seven mine-specific QML styles.
- Phase 5.2: Shiny canonical/accepted/rejected data views; accepted candidate locality, mine-destruction, and 2 NM uncertainty layers visible by default; curated decision/evidence/vessel/operation tables; review CSV download; Phase 5 source and file-integrity panels; compact five-card deployment metrics; and grouped top navigation.

## Current record state

- Canonical deployment events: 61.
- Canonical source route legs: 57; 56 are included by default.
- Canonical minefields, vessels, vessel-operation links, and all other mine-warfare tables: zero rows.
- Phase 5 review candidates: one localized mined occurrence, one mine-destruction operation, two vessels, two vessel-operation links, four sources, and one explicit uncertainty record. Ten decisions are `accepted`; the unsupported USS *Terror* event-level link is `rejected`. The laying-event candidate table remains empty.
- USS *Terror* is directly accepted as the area minecraft flagship/tender, but its link to the exact 26 March 1945 Area B-5 event is rejected. USS PC-584 is directly identified and accepted as the mine-destruction control vessel for the event.
- The reproduced PC-584 action report and LSM(R)-194 deck-log transcription are archived at `data/mine_warfare/source_documents/halligan_dd584_wilde_action_reports.pdf` with a verified SHA-256 digest recorded in `outputs/reports/phase5_source_inventory.csv`.
- No GMRT grid has been downloaded by the project build. Cache inventory covers six configured bounded regions and currently expects an empty cache unless the user explicitly approves a later download.

## Geographic and evidence behavior

The master CRS is EPSG:4326. Interactive Pacific centering is a viewport/display transformation, not a new master projection. Static global maps rotate the Robinson central meridian to the Pacific and wrap a single world. Geodesic connectors are split at the antimeridian and are not exact tracks. Coordinates retain their basis and nautical-mile uncertainty.

OpenStreetMap is the default online context. OpenSeaMap is modern seamark reference only. GEBCO is modern global bathymetric context. GMRT is modern regional detail. None reconstructs wartime charts, knowledge, aids to navigation, or operational conditions. External failure is nonfatal; `USS_TERROR_OFFLINE=true` selects the local shapefile boundary-and-label base and preserves all local historical functions.

## Mine-warfare research gate

Candidate records live under `data/mine_warfare/review`. The first batch preserves source IDs/locators, directly supported vessel identity, an accepted PC-584 participation link, a rejected USS *Terror* event link, date precision, a documented approximate position, a 2 NM source-conflict envelope, confidence, and review decisions. Accepted candidates remain outside canonical storage until a separately authorized canonical-population phase. Laying and sweeping vessels must never be identified from ship type, geographic proximity, or operation association alone. Sweeping is activity evidence, not proof of full clearance.

Run `Rscript scripts/validate_phase5_candidates.R` to regenerate `outputs/reports/phase5_candidate_validation.csv`, `outputs/reports/phase5_source_inventory.csv`, and `outputs/reports/phase5_kerama_candidate_review.md`. The current result has no validation errors or warnings; all candidate records have an accepted or rejected decision and the eleven canonical tables remain empty.

The entire mine-warfare interface is an incomplete historical reconstruction. It is not current hazard information and must not be used for navigation, route planning, diving, fishing, salvage, ordnance clearance, or safety decisions.

The Shiny review selector defaults to accepted candidate evidence so the tab opens with meaningful records and plotted geometry. The empty canonical view and rejected audit view remain explicitly selectable. All candidates are loaded directly from review CSVs, remain visually and structurally distinct from canonical data, and are never written to the canonical GeoPackage by the app.

## Tool and service status

R 4.6.1 and the project `renv` environment are used. A user-local OSGeo4W/QGIS LTR installation was detected, including `qgis_process`, `qgis-ltr-bin`, `ogr2ogr`, and `ogrinfo`; nothing was installed and no unvalidated `.qgz` was created. If the primary exchange GeoPackage is open in QGIS, the build safely stages the complete replacement as `qgis/uss_terror_layers_phase4.gpkg`. Official external service endpoints were checked narrowly on 20 July 2026 and are recorded in `config/settings.yml`; automated tests use mocks and require no network.

## Run and validate

From `C:\Projects\USSTerrorMap`:

```powershell
Rscript scripts/build_all.R
Rscript scripts/validate_all.R
Rscript scripts/validate_phase5_candidates.R
Rscript scripts/launch_app.R
```

The local URL is `http://127.0.0.1:3838/` and works only while the local R/Shiny process is running. See `qgis/README_QGIS.md` for the unvalidated manual QGIS workflow and `outputs/reports/minefield_methods.md` for the research acceptance rules.

## Next bounded phase recommendation

Before canonical promotion, retrieve the original National Archives LSM(R)-194 deck-log sheet and complete Mine Squadron Four report to verify the accepted reproductions. Then design a separately authorized canonical-import step that imports accepted candidates only, excludes the rejected USS *Terror* event link, constructs the approximate point and 2 NM uncertainty geometry reproducibly, and reruns all schema, spatial, QGIS, and not-for-navigation checks.
