# Validation report

Generated: 2026-07-24 12:30:44 UTC

**Status:** PASS with retained warnings

## Build counts

- Events: 61
- Route legs: 57
- Geodesic route features: 57
- Geodesic line parts: 72
- Disputed or excluded legs: 1
- Uncertainty areas: 61

## Issue summary

- Errors: 0
- Warnings: 5
- Informational notes: 0

Warnings are retained as evidence-review items and are not silently fixed.

## Detailed findings

- **WARNING — disputed_or_excluded_route** `route_leg:L028`: Route is disputed or excluded from the default map.
- **WARNING — implausible_speed** `route_leg:L023`: Implied average speed 33.0 kn exceeds the 23.0 kn review threshold.
- **WARNING — implausible_speed** `route_leg:L034`: Implied average speed 23.4 kn exceeds the 23.0 kn review threshold.
- **WARNING — implausible_speed** `route_leg:L035`: Implied average speed 23.4 kn exceeds the 23.0 kn review threshold.
- **WARNING — low_route_confidence** `route_leg:L028`: Route confidence is low; retain for review and style as uncertain.

## Phase 2–4 integration checks

- Cross-year interval-overlap filter table: **PASS**.
- The Pacific Theater map receives the shared filtered route IDs: **PASS**.
- Disputed routes are preserved outside the default visible layer: **PASS**.
- OpenSeaMap and GEBCO failure paths are nonfatal under mocked offline tests: **PASS**.
- GMRT metadata, empty-cache, size-limit, and explicit-confirmation tests: **PASS**; cached raw grids: 0.
- Empty mine-warfare tables/layers and QGIS-compatible field types: **PASS**.
- Canonical minefield/vessel/link records: 0/0/0.
- Mine layers hidden by default and navigation warning configured: **PASS**.
- QGIS QML style files present: 14; QGIS/GDAL executables detected: 4.
- Offline automated test suite: **PASS**.
- Historical mine-source research and canonical population: **NOT STARTED (out of scope for Phases 1–4)**. 

## Phase 2–4 integration checks

- Cross-year interval-overlap filter table: **PASS**.
- The Pacific Theater map receives the shared filtered route IDs: **PASS**.
- Disputed routes are preserved outside the default visible layer: **PASS**.
- OpenSeaMap and GEBCO failure paths are nonfatal under mocked offline tests: **PASS**.
- GMRT metadata, empty-cache, size-limit, and explicit-confirmation tests: **PASS**; cached raw grids: 0.
- Empty mine-warfare tables/layers and QGIS-compatible field types: **PASS**.
- Canonical minefield/vessel/link records: 0/0/0.
- Mine layers hidden by default and navigation warning configured: **PASS**.
- QGIS QML style files present: 14; QGIS/GDAL executables detected: 4.
- Offline automated test suite: **PASS**.
- Historical mine-source research and canonical population: **NOT STARTED (out of scope for Phases 1–4)**. 
