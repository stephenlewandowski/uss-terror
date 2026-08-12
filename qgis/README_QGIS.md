# QGIS setup for USS Terror (CM-5), 1943–1946

The R pipeline creates a relative-path-friendly historical exchange GeoPackage at `qgis/uss_terror_layers.gpkg` and an empty, schema-ready mine-warfare GeoPackage at `data/processed/pacific_mine_warfare.gpkg`. A user-local OSGeo4W/QGIS LTR installation was detected under `C:\Users\slewa\AppData\Local\Programs\OSGeo4W`, including `qgis_process.exe`, `qgis-ltr-bin.exe`, `ogr2ogr.exe`, and `ogrinfo.exe`. Nothing was installed or modified, and no untested `.qgz` is included.

If `uss_terror_layers.gpkg` is open in QGIS during a rebuild, Windows prevents safe replacement. The build preserves that open file and writes the complete new package to `qgis/uss_terror_layers_phase4.gpkg`; the initializer prefers this staged package. After closing QGIS and preserving any unsaved work, rerun the build to restore the primary filename.

## Manual project creation

1. Install or open QGIS 3.x yourself.
2. Create a blank project and set **Project → Properties → CRS** to **EPSG:4326 — WGS 84**.
3. Create top-level groups named **USS Terror Historical Reconstruction**, **Modern Reference Layers**, **Modern Bathymetric Context**, and **Historical Mine Warfare — Research Reconstruction**.
4. Choose **Layer → Add Layer → Add Vector Layer**, select `qgis/uss_terror_layers.gpkg`, and add to the historical or reference groups:
   - `events`
   - `route_legs_geodesic`
   - `route_legs_original`
   - `locations`
   - `event_uncertainty`
   - `operating_areas`
   - `route_uncertainty`
   - `disputed_routes`
   - `natural_earth_land`
5. Add these layers from `data/processed/pacific_mine_warfare.gpkg` to the mine-warfare group: `minefields`, `minefield_boundaries`, `mine_laying_events`, `mine_sweeping_events`, `vessel_operation_links`, `minefield_status_events`, `minefield_uncertainty`, and `minefield_source_maps`. Rename them to readable labels if desired.
6. Keep the complete mine-warfare group and every child layer **off**. It is an empty research interface, not present-day hazard data.
7. Keep `natural_earth_land`, `route_legs_geodesic`, `events`, and `locations` visible. Hide original/disputed routes, uncertainty, operating areas, modern online context, and modern bathymetry by default.
8. Load the matching QML from `qgis/styles`. The seven `mine*.qml`/`minefield*.qml` styles are schema-compatible with empty layers. Alternate styles allow review by belligerent, status, platform, or confidence.

## Modern reference and bathymetry

- OpenSeaMap seamark tiles: `https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png`; modern reference only, with OpenSeaMap/OpenStreetMap attribution.
- GEBCO WMS: `https://wms.gebco.net/mapserv?`, layer `GEBCO_LATEST`; global modern bathymetric context.
- GMRT WMS: `https://www.gmrt.org/services/mapserver/wms_merc?`, layer `topo`; regional detail only. The masked service is `https://www.gmrt.org/services/mapserver/wms_merc_mask?`.
- Approved regional GMRT rasters, if explicitly cached through `scripts/cache_gmrt_regions.R`, belong under `data/external/gmrt/raw` and `processed`. Never use a WMS display as proof that a historical chart or contemporary mariner had the same knowledge.

Test attribution and service behavior in the installed QGIS version before saving a project. A network failure must leave all local historical layers usable.

## Temporal Controller

For `events`, open **Layer Properties → Temporal**, enable **Dynamic Temporal Control**, choose **Start and End Date/Time from Fields**, set start to `date_start` and end to `date_end`, and use a one-day fixed duration only if the installed QGIS version requires it for equal dates.

For route layers, use start `start_date` and end `end_date`. For mine-laying and sweeping events, use `date_start`/`date_end`; for status changes use `event_date_start`/`event_date_end`. Minefield dates are research fields whose precision companion must be consulted. Set the USS *Terror* project range to 1943-10-02 through 1946-12-25. Do not configure daily interpolation; temporal visibility uses interval overlap.

## Labels and forms

- Events: label major records with `location_name`; use rule-based labeling to prioritize Air attack, Kamikaze strike, Iwo Jima, Okinawa, typhoon, damage, and repair records.
- Routes: use `leg_id` as the display expression and expose origin/destination, dates, distance, speed, confidence, source status, and source locator in the form.
- Locations: use `location_name` as the display field.
- Uncertainty: display `position_uncertainty_nm` and `uncertainty_method`.
- Major operating regions: show `region_name` and `region_method`, explicitly retaining the modeled-boundary disclaimer.

## Map themes and layouts

After opening and validating all layers, document or create these themes: **Pacific Theater — Historical**, **Pacific Theater — GEBCO**, **Pacific Theater — GMRT Detail**, **Global Pacific-Centered — Historical**, **Global Pacific-Centered — Bathymetry**, **Iwo Jima and Okinawa**, **May 1945 Withdrawal**, **Marshall Islands**, **Historical Mine Warfare**, **USS Terror Mine-Force Operations**, **GMRT High-Resolution Coverage**, and **Source Confidence**. These themes are documented requirements, not validated deliverables in the current no-QGIS environment.

Create print layouts for:

- Full Pacific route
- Iwo Jima and Okinawa
- May 1945 withdrawal and repair
- Postwar operations

Every layout should include title/date range, legend, source note, reconstruction disclaimer, modern-data attribution where applicable, and a scale bar/north arrow only where the extent makes them meaningful. Mine layouts must include the prominent historical-reconstruction/not-for-navigation warning.

## Optional initializer

Open the QGIS Python Console, then execute the contents of `qgis/initialize_qgis_project.py` (or use `exec(open(r'C:\Projects\USSTerrorMap\qgis\initialize_qgis_project.py', encoding='utf-8').read())`). The script loads both GeoPackages, prepares all four top-level groups, applies available styles, keeps mine layers off, enables temporal fields where supported, stores relative paths, and writes `qgis/USS_Terror_1943_1946.qgz`. It intentionally does not create unvalidated online services, themes, or layouts.

Review warnings printed by the QGIS console. Because QGIS APIs vary by version, visually inspect symbology, empty mine layers, temporal behavior, labels, antimeridian parts, services, themes, and layouts before treating the `.qgz` as validated. Run `Rscript scripts/initialize_qgis.R` first to repeat executable detection; it installs nothing.
