# Antimeridian and great-circle validation

Generated: 2026-07-24 12:30:43 UTC

Canonical WGS84 endpoints are preserved. Display geometry is geodesically interpolated and split only where a part would otherwise jump more than 180 degrees in longitude.

## L004 — Pearl Harbor to Funafuti

- Route-leg ID: L004
- Origin: Pearl Harbor
- Destination: Funafuti
- Longitude range: -180.0000 to 180.0000 degrees
- Antimeridian crossing: TRUE
- Geometry splitting method: Great-circle interpolation; explicit ±180-degree intersection; MULTILINESTRING split
- Number of generated line parts: 2
- Validation result: PASS
- Remaining limitation: Endpoint-to-endpoint reconstruction only; no intermediate daily ship positions are inferred.

## TEST-FUNAFUTI-TARAWA — Funafuti to Tarawa

- Route-leg ID: TEST-FUNAFUTI-TARAWA
- Origin: Funafuti
- Destination: Tarawa
- Longitude range: 172.9300 to 179.2000 degrees
- Antimeridian crossing: FALSE
- Geometry splitting method: Great-circle interpolation; no split required
- Number of generated line parts: 1
- Validation result: PASS
- Remaining limitation: Endpoint-to-endpoint reconstruction only; no intermediate daily ship positions are inferred.

## L020-REFERENCE — Enewetak (Marshall Islands) to Pearl Harbor

- Route-leg ID: L020-REFERENCE
- Origin: Enewetak (Marshall Islands)
- Destination: Pearl Harbor
- Longitude range: -180.0000 to 180.0000 degrees
- Antimeridian crossing: TRUE
- Geometry splitting method: Great-circle interpolation; explicit ±180-degree intersection; MULTILINESTRING split
- Number of generated line parts: 2
- Validation result: PASS
- Remaining limitation: Endpoint-to-endpoint reconstruction only; no intermediate daily ship positions are inferred.

## L012 — Pearl Harbor to San Francisco Bay

- Route-leg ID: L012
- Origin: Pearl Harbor
- Destination: San Francisco Bay
- Longitude range: -157.9750 to -122.4783 degrees
- Antimeridian crossing: FALSE
- Geometry splitting method: Great-circle interpolation; no split required
- Number of generated line parts: 1
- Validation result: PASS
- Remaining limitation: Endpoint-to-endpoint reconstruction only; no intermediate daily ship positions are inferred.

## TEST-SF-WESTPAC — San Francisco Bay to Saipan

- Route-leg ID: TEST-SF-WESTPAC
- Origin: San Francisco Bay
- Destination: Saipan
- Longitude range: -180.0000 to 180.0000 degrees
- Antimeridian crossing: TRUE
- Geometry splitting method: Great-circle interpolation; explicit ±180-degree intersection; MULTILINESTRING split
- Number of generated line parts: 2
- Validation result: PASS
- Remaining limitation: Endpoint-to-endpoint reconstruction only; no intermediate daily ship positions are inferred.

## TEST-NEAR-180 — Near 180 east to Near 180 west

- Route-leg ID: TEST-NEAR-180
- Origin: Near 180 east
- Destination: Near 180 west
- Longitude range: -180.0000 to 180.0000 degrees
- Antimeridian crossing: TRUE
- Geometry splitting method: Great-circle interpolation; explicit ±180-degree intersection; MULTILINESTRING split
- Number of generated line parts: 2
- Validation result: PASS
- Remaining limitation: Endpoint-to-endpoint reconstruction only; no intermediate daily ship positions are inferred.

