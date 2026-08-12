"""Run inside the QGIS 3.44 LTR Python console after reviewing README_QGIS.md.

The initializer uses relative GeoPackage paths, keeps every mine-warfare layer
off, and creates no map themes or layouts that have not been visually checked.
"""
from pathlib import Path

from qgis.core import (
    Qgis,
    QgsCoordinateReferenceSystem,
    QgsProject,
    QgsVectorLayer,
    QgsVectorLayerTemporalProperties,
)

qgis_dir = Path(__file__).resolve().parent if "__file__" in globals() else Path(r"C:\Projects\USSTerrorMap\qgis")
historical_primary = qgis_dir / "uss_terror_layers.gpkg"
historical_staged = qgis_dir / "uss_terror_layers_phase4.gpkg"
historical_gpkg = historical_staged if historical_staged.exists() else historical_primary
mine_gpkg = qgis_dir.parent / "data" / "processed" / "pacific_mine_warfare.gpkg"
project_path = qgis_dir / "USS_Terror_1943_1946.qgz"

project = QgsProject.instance()
project.clear()
project.setFileName(str(project_path))
project.setCrs(QgsCoordinateReferenceSystem("EPSG:4326"))
try:
    project.setFilePathStorage(Qgis.FilePathType.Relative)
except Exception:
    pass

root = project.layerTreeRoot()
historical_group = root.addGroup("USS Terror Historical Reconstruction")
modern_reference_group = root.addGroup("Modern Reference Layers")
modern_bathymetry_group = root.addGroup("Modern Bathymetric Context")
mine_group = root.addGroup("Historical Mine Warfare — Research Reconstruction")
mine_group.setItemVisibilityChecked(False)

historical_subgroups = {
    "Routes": historical_group.addGroup("Routes"),
    "Events and locations": historical_group.addGroup("Events and locations"),
    "Uncertainty and regions": historical_group.addGroup("Uncertainty and regions"),
}

historical_specs = [
    (modern_reference_group, "natural_earth_land", None, True, None, None),
    (historical_subgroups["Routes"], "route_legs_original", None, False, "start_date", "end_date"),
    (historical_subgroups["Routes"], "route_legs_geodesic", "route_default.qml", True, "start_date", "end_date"),
    (historical_subgroups["Routes"], "route_uncertainty", "route_estimated.qml", False, "start_date", "end_date"),
    (historical_subgroups["Routes"], "disputed_routes", "route_disputed.qml", False, "start_date", "end_date"),
    (historical_subgroups["Events and locations"], "events", "events_by_category.qml", True, "date_start", "date_end"),
    (historical_subgroups["Events and locations"], "locations", "locations.qml", True, None, None),
    (historical_subgroups["Uncertainty and regions"], "event_uncertainty", "uncertainty_areas.qml", False, None, None),
    (historical_subgroups["Uncertainty and regions"], "operating_areas", "uncertainty_areas.qml", False, None, None),
]

mine_specs = [
    ("Minefields", "minefields", "minefields_by_status.qml", "date_first_emplaced", "date_declared_cleared"),
    ("Minefield boundaries", "minefield_boundaries", "minefields_by_confidence.qml", None, None),
    ("Mine-laying events", "mine_laying_events", "mine_laying_events.qml", "date_start", "date_end"),
    ("Mine-sweeping events", "mine_sweeping_events", "mine_sweeping_events.qml", "date_start", "date_end"),
    ("Vessel-operation links", "vessel_operation_links", None, "date_start", "date_end"),
    ("Minefield status changes", "minefield_status_events", None, "event_date_start", "event_date_end"),
    ("Position uncertainty", "minefield_uncertainty", "minefield_uncertainty.qml", None, None),
    ("Source maps", "minefield_source_maps", "minefield_uncertainty.qml", "map_date", "map_date"),
]


def add_layer(gpkg, layer_name, display_name, group, style_name=None, visible=False, start_field=None, end_field=None):
    uri = f"{gpkg.as_posix()}|layername={layer_name}"
    layer = QgsVectorLayer(uri, display_name, "ogr")
    if not layer.isValid():
        print(f"WARNING: could not load {layer_name} from {gpkg}")
        return None
    project.addMapLayer(layer, False)
    node = group.addLayer(layer)
    node.setItemVisibilityChecked(visible)
    if style_name:
        style_path = qgis_dir / "styles" / style_name
        if style_path.exists():
            message, ok = layer.loadNamedStyle(str(style_path))
            if not ok:
                print(f"WARNING: style for {layer_name}: {message}")
    if start_field and start_field in layer.fields().names():
        try:
            temporal = layer.temporalProperties()
            temporal.setIsActive(True)
            temporal.setMode(QgsVectorLayerTemporalProperties.ModeFeatureDateTimeStartAndEndFromFields)
            temporal.setStartField(start_field)
            temporal.setEndField(end_field if end_field in layer.fields().names() else start_field)
        except Exception as exc:
            print(f"WARNING: temporal properties for {layer_name}: {exc}")
    return layer


for group, layer_name, style_name, visible, start_field, end_field in historical_specs:
    add_layer(historical_gpkg, layer_name, layer_name, group, style_name, visible, start_field, end_field)

for display_name, layer_name, style_name, start_field, end_field in mine_specs:
    add_layer(mine_gpkg, layer_name, display_name, mine_group, style_name, False, start_field, end_field)

# Online WMS/tiles and cached GMRT rasters are intentionally not inserted here:
# follow README_QGIS.md and validate each service/layer in the installed QGIS version.
modern_bathymetry_group.setItemVisibilityChecked(False)
project.setCustomVariables({
    "historical_notice": "Routes and positions are reconstructed; centroids and modeled areas are not exact ship positions.",
    "mine_notice": "Historical mine reconstruction only. Not for navigation or present-day hazard assessment.",
})
if not project.write(str(project_path)):
    raise RuntimeError(f"QGIS could not write {project_path}")
print(f"Created {project_path}. Visually inspect all groups, temporal fields, styles, antimeridian parts, themes, and layouts before publication.")
