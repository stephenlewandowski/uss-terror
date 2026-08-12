# Historical mine-warfare research methods

## Phase 4 scope

Phase 4 creates the database, provenance, review, validation, Shiny, and QGIS structures needed for later research. It contains no accepted historical minefield, laying, sweeping, vessel, unit, or participation records. No external mine-source extraction, archival searching, PDF/image scraping, or bulk retrieval was performed.

## Relational evidence model

`data/processed/pacific_mine_warfare.gpkg` contains eleven empty QGIS-readable layers/tables: minefields, boundaries, laying events, sweeping events, status events, vessels, units, vessel-operation links, sources, source maps, and uncertainty. The many-to-many link table prevents a single `primary_vessel_id` from erasing support, command, escort, or multi-vessel participation. Unknown vessels remain null; identifiers are never invented to make a relationship look complete.

Every accepted fact or relationship requires a source ID and locator. Geometry stores its position basis, boundary precision, uncertainty, source, confidence, and review state. Mine counts preserve planned, emplaced, recovered, destroyed, and remaining-reported concepts separately. Laying, sweeping, and clearance/status events remain distinct.

## Vessel identification rules

A minelaying vessel may be identified only when a cited record directly names it or a source-supported chain uniquely resolves its identifier. Vessel type, proximity, unit membership, or association with an operation is insufficient. The same rule applies to minesweeping vessels. Conflicting names, hull numbers, pennants, roles, or dates are retained and flagged; they are not silently reconciled. The reserved `V-USN-CM5-TERROR` identifier remains absent until source evidence supports the specific mine-warfare relationship.

## Dates and precision

Dates have separate precision fields with controlled values: day, month, year, range, circa, inferred, or unknown. A normalized interval supports temporal filtering without converting an approximate date into a false exact day. Emplacement, activation, sweeping, declared-safe, declared-cleared, and last-verified dates remain separate. A cross-year operation is retained as one interval and appears in each overlapping year.

## Candidate review and acceptance

Future research begins in the empty `data/mine_warfare/review/candidate_*.csv` templates and keeps source files in the appropriate `source_documents`, `raw_maps`, or `raw_tables` area. Derived georeferencing and digitization artifacts remain separate from raw evidence.

A candidate can move to canonical acceptance only after:

1. source title, repository/catalog identifier, page/map locator, and reliability are recorded;
2. dates, precision, counts, vessel/unit identifiers, and foreign keys are checked;
3. geometry is georeferenced or digitized with method, precision, uncertainty, and source map recorded;
4. conflicts and low-confidence/inferred relationships are explicitly retained and labeled;
5. clearance claims have direct supporting evidence beyond the existence of sweeping activity;
6. review status is changed to `accepted` by a manual evidence review; and
7. the canonical build and all tests pass without test fixtures leaking into exports.

## Clearance and modern-navigation caution

Minesweeping demonstrates reported activity, not necessarily complete clearance. A declared-safe or declared-cleared date must be supported and may itself be limited by area, date, source, or later contrary evidence. Historical records and reconstructed boundaries cannot establish the present condition of any waterway.

These interfaces are incomplete historical research reconstructions. They are not current hazard information and must not be used for navigation, route planning, diving, fishing, salvage, ordnance clearance, or safety decisions.

## Shiny, proximity, and offline behavior

The Historical Mine Warfare tab shows the empty state honestly. All mine layers are off by default. The shared deployment year filter applies interval-overlap logic, and proximity options are all records or 25, 50, 100, and 250 nautical miles. Proximity is a research comparison only and does not infer causation, participation, vessel identity, or hazard exposure.

Local schema layers, tables, warnings, and the empty map work offline. OpenSeaMap, GEBCO, and GMRT are optional modern context and remain independent of the evidence database.

## QGIS workflow

Load the mine GeoPackage into **Historical Mine Warfare — Research Reconstruction**, apply the QML styles from `qgis/styles`, and keep the whole group off. Configure laying/sweeping/status temporal fields from their start/end dates. Do not call a generated `.qgz`, theme, or layout validated until it has been opened and visually inspected in QGIS. See `qgis/README_QGIS.md`.
