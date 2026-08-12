# Methods and Historical Limitations

## Scope

This visualization presents a chronological and geographic reconstruction of USS *Terror* (CM-5) from 2 October 1943 through 1 April 1946. It integrates the supplied event table, route-leg table, workbook, and GeoJSON. The records are complementary evidence products; disagreement is preserved in the validation and conflict reports rather than resolved invisibly.

## Evidence model

Each event retains its date interval, precision, location identifier, WGS84 coordinate, coordinate basis, nautical-mile uncertainty, action, confidence, source identifier, locator, URL, notes, and default-display decision. Each route leg retains its two source endpoints, interval, evidence status, date and route confidence, source citation, and default-display decision. Exact dates, ranges, excluded records, and modeling notes remain distinct.

The ordinary map uses `include_default_map`. Disputed and excluded legs remain queryable and can be shown with a dotted, muted symbol. A filtered ranged event is included whenever its source interval overlaps the selected time window. No daily positions are interpolated.

## Pacific map and year-filter design

The Pacific Theater Leaflet widget is supplied by one filtered data reactive. The same event and route IDs also drive the timeline, tables, counts, detail, and navigation. OpenStreetMap is the default when online. A selectable local Natural Earth boundary-and-label base is generated as a shapefile during the build and becomes the default in offline mode. Explicit choices are All years and 1943–1946. Selected-year inclusion means `record_start <= year_end` and `record_end >= year_start`; consequently a cross-year connector appears intact in both overlapping years. Cumulative mode includes records overlapping the reconstruction start through the selected year's end.

Interactive Pacific centering is a viewport/display convention. It does not change the EPSG:4326 master coordinates or turn Web Mercator into a Pacific-centered projection. Static global products instead use a true Pacific-centered Robinson transformation and a single wrapped world.

## Coordinates and uncertainty

WGS84 longitude and latitude (EPSG:4326) are the master coordinates. Port, anchorage, island, harbor, and operating-area modeling points are not interpreted as exact positions. Their `coordinate_basis` and `position_uncertainty_nm` accompany the map record and popup.

Uncertainty polygons are geodesic circles: bearings around each point are projected on the ellipsoid at a radius of `position_uncertainty_nm × 1,852` metres and converted back to WGS84 coordinates. This avoids treating degrees as distance. The polygons are optional because displaying all of them can obscure the chronology.

Modeled major operating regions are unions of the existing event-level uncertainty circles selected only when supplied location or category text explicitly names Iwo Jima, Okinawa/Kerama, or occupation operations. These shapes summarize the uncertainty already in the data; they are not sourced patrol boundaries, combat zones, or claims about where the vessel traveled between records.

## Route reconstruction and the antimeridian

Route lines follow great-circle interpolation between source endpoints at a configurable interval. They are visual connectors, not logbook tracks. The two-point source geometry is retained in `route_legs_original`, while the default map uses `route_legs_geodesic`.

Interpolated longitude sequences are tested for jumps greater than 180 degrees. A crossing is intersected at +180° or −180°, ended there, and continued as a new line part on the opposite meridian. This prevents central-Pacific legs, including Hawaii–Funafuti/Tarawa relationships, from displaying across Eurasia or the Atlantic. Tests check both the split and the absence of a remaining within-part global wrap.

MGRS is deliberately not the primary coordinate system. The deployment crosses multiple UTM zones and the antimeridian, making MGRS unsuitable as a continuous open-ocean representation.

## Distance, duration, and speed

Great-circle distance is recalculated from endpoint coordinates on WGS84 and reported in nautical miles. Duration is the elapsed difference between route start and end dates. Implied average speed is `distance_nm / (duration_days × 24)` only where duration is positive. It is a diagnostic across an uncertain interval, not a claim about steaming speed. Values above 23 knots are flagged without deleting or altering the leg.

Route distances may be summed for a concise reconstruction statistic because each leg is a distance measure. Route durations and port intervals are not blindly summed where source intervals overlap; overlapping intervals are instead flagged for review.

## Validation and reproducibility

The build checks required fields, ISO date parsing and order, coordinate bounds, location references, unique route sequence, source identifiers and locators, Boolean flags, estimation labeling, excluded-leg preservation, speed arithmetic, duplicate events, coordinate variants, overlapping route intervals, large uncertainty, geometry validity, and antimeridian wrapping. Errors stop the build. Warnings produce conflict-register rows whose resolution explicitly states that the evidence was retained for review.

Raw sources receive SHA-256 hashes in the inventory. Project dependencies are isolated and locked with `renv`. Automated tests require no network connection. The core application exports Natural Earth geometry to a lightweight local shapefile with permanent labels; online tiles may be disabled with `USS_TERROR_OFFLINE=true`.

## Modern maritime and bathymetric layers

OpenSeaMap is optional modern seamark reference, GEBCO is optional modern global bathymetric context, and GMRT is optional modern regional detail. They do not reconstruct wartime charts, seabed knowledge, navigation aids, or operational conditions. Attribution and service configuration live in `config/settings.yml`. Failures are nonfatal and do not clear, refilter, or replace local historical layers.

The normal build downloads no GMRT grids. The cache entry point first obtains metadata for one configured bounded region, refuses requests above the configured 250 MB limit or GMRT node limit, and requires the caller's `--confirm`. A successful request preserves the original grid under `data/external/gmrt/raw`, writes metadata separately, and creates processed/display rasters without overwriting the source.

## Empty mine-warfare structure

Phase 4 provides an empty relational schema and research interfaces only. Vessels, units, operations, minefields, sources, maps, uncertainty, and many-to-many vessel-operation links remain separate. Unknown vessels may be null; roles are not inferred from proximity or vessel class. Date precision remains explicit, and sweeping is not treated as proof of clearance. Candidate records live outside canonical exports until manual source and conflict review assigns `accepted`. See `minefield_methods.md` for the acceptance workflow and navigation warning.

## Interpretive caution

This product supports historical interpretation, not navigation. Sparse records, generalized chart positions, date ranges, source conflicts, and centroid coordinates constrain the conclusions that can be drawn. The visual sequence should be checked against the cited archival locator before publication of a precise operational claim.
