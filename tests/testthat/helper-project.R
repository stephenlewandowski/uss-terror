project <- Sys.getenv("USS_TERROR_PROJECT", unset = normalizePath(file.path(getwd(), "..", ".."), winslash = "/", mustWork = TRUE))
Sys.setenv(USS_TERROR_PROJECT = project)
modules <- c("helpers.R", "load_data.R", "prepare_events.R", "prepare_routes.R", "antimeridian.R",
  "geodesic_routes.R", "validate_data.R", "map_filters.R", "map_layers.R", "event_table.R",
  "timeline_plot.R", "static_maps.R", "qgis_exports.R", "nautical_layers.R", "gebco_layers.R",
  "gmrt_services.R", "gmrt_download.R", "mine_sources.R", "minefield_models.R",
  "minefield_validation.R", "minefield_proximity.R")
invisible(lapply(file.path(project, "R", modules), source, local = globalenv()))
