event_palette <- function(values) {
  leaflet::colorFactor(
    palette = c("#2C7FB8", "#D7301F", "#6A51A3", "#238B45", "#D95F0E", "#636363", "#B8860B", "#1B9E77"),
    domain = sort(unique(values)), na.color = "#555555"
  )
}

event_visual_class <- function(category) {
  dplyr::case_when(
    grepl("combat|attack|kamikaze|damage|iwo jima|okinawa", category, ignore.case = TRUE) ~ "Combat and damage",
    grepl("mine", category, ignore.case = TRUE) ~ "Mine warfare",
    grepl("repair|dry dock|overhaul|alteration", category, ignore.case = TRUE) ~ "Repair and shipyard",
    grepl("typhoon|weather", category, ignore.case = TRUE) ~ "Typhoon and weather",
    grepl("logistic|port|transport|passenger|medical|casualty", category, ignore.case = TRUE) ~ "Logistics and transport",
    grepl("postwar|occupation", category, ignore.case = TRUE) ~ "Postwar and occupation",
    TRUE ~ "Transit and other"
  )
}

event_popup <- function(events) {
  estimated <- ifelse(tolower(events$date_precision) == "day", "", "<strong>Estimated/ranged date</strong><br/>")
  paste0(
    "<div class='terror-popup'><strong>", htmltools::htmlEscape(events$location_name), "</strong><br/>",
    estimated,
    htmltools::htmlEscape(format_event_date(events$date_start, events$date_end, events$date_precision)), "<br/>",
    "<em>", htmltools::htmlEscape(events$event_category), "</em><br/>",
    htmltools::htmlEscape(events$event_action), "<hr/>",
    "Coordinate basis: ", htmltools::htmlEscape(events$coordinate_basis), "<br/>",
    "Uncertainty: ", ifelse(is.na(events$position_uncertainty_nm), "not recorded", paste(events$position_uncertainty_nm, "NM")), "<br/>",
    "Confidence: ", htmltools::htmlEscape(events$historical_confidence), "<br/>",
    "Source: ", htmltools::htmlEscape(events$source_id), " — ", htmltools::htmlEscape(events$source_locator),
    ifelse(is.na(events$source_url), "", paste0("<br/><a href='", htmltools::htmlEscape(events$source_url), "' target='_blank' rel='noopener'>Source link</a>")),
    "</div>"
  )
}

route_popup <- function(routes) {
  boundary_note <- if ("cross_year_notice" %in% names(routes)) {
    ifelse(is.na(routes$cross_year_notice), "", paste0("<br/><strong>", htmltools::htmlEscape(routes$cross_year_notice), "</strong>"))
  } else {
    ""
  }
  paste0(
    "<strong>", htmltools::htmlEscape(routes$leg_id), ": ", htmltools::htmlEscape(routes$start_location),
    " → ", htmltools::htmlEscape(routes$end_location), "</strong><br/>",
    routes$start_date, " to ", routes$end_date, "<br/>",
    sprintf("Great-circle distance: %.1f NM<br/>Implied average speed: %.1f kn<br/>", routes$great_circle_nm, routes$implied_avg_speed_kn),
    "Route confidence: ", htmltools::htmlEscape(routes$route_confidence), "<br/>",
    "Status: ", htmltools::htmlEscape(routes$source_status), "<br/>",
    "Reconstructed endpoint-to-endpoint route; not an exact ship track.",
    boundary_note
  )
}

event_detail_ui <- function(event) {
  if (is.null(event) || !nrow(event)) return(htmltools::p("Select an event on the map, timeline, or table."))
  e <- event[1, ]
  htmltools::div(class = "event-detail",
    htmltools::h4(e$location_name),
    htmltools::p(htmltools::strong("Sequence: "), e$sequence),
    htmltools::p(htmltools::strong("Date: "), format_event_date(e$date_start, e$date_end, e$date_precision)),
    htmltools::p(htmltools::strong("Date precision: "), html_value(e$date_precision)),
    htmltools::p(htmltools::strong("Coordinates: "), sprintf("%.4f, %.4f — %s", e$latitude, e$longitude, e$coordinate_basis)),
    htmltools::p(htmltools::strong("Position uncertainty: "), ifelse(is.na(e$position_uncertainty_nm), "Not recorded", paste(e$position_uncertainty_nm, "nautical miles"))),
    htmltools::p(htmltools::strong("Category: "), html_value(e$event_category)),
    htmltools::p(htmltools::strong("Event: "), html_value(e$event_action)),
    htmltools::p(htmltools::strong("Confidence: "), e$historical_confidence),
    htmltools::p(htmltools::strong("Source: "), paste(e$source_id, e$source_locator, sep = " — ")),
    if (!is.na(e$source_url)) htmltools::a("Open source citation", href = e$source_url, target = "_blank", rel = "noopener"),
    htmltools::p(htmltools::strong("Notes: "), ifelse(is.na(e$notes), "None", e$notes)),
    htmltools::p(htmltools::strong("Default map: "), ifelse(isTRUE(e$include_default_map), "Included", "Excluded"))
  )
}

historical_map_groups <- function() {
  c(
    "Confirmed/default route legs",
    "Estimated route legs",
    "Disputed/excluded route legs",
    "USS Terror events",
    "Position uncertainty",
    "Major operating regions (modeled)",
    "Selected event"
  )
}

modern_map_groups <- function(settings, offline = FALSE) {
  groups <- character()
  if (isTRUE(offline)) return(groups)
  if (isTRUE(setting_value(settings, c("nautical_layers", "openseamap", "enabled"), FALSE))) {
    groups <- c(groups, setting_value(
      settings, c("nautical_layers", "openseamap", "label"),
      "Modern OpenSeaMap seamarks — reference only"
    ))
  }
  groups
}

shift_longitude_360 <- function(x) {
  if (!inherits(x, "sf")) return(x)
  out <- sf::st_shift_longitude(x)
  longitude_fields <- intersect(
    c("longitude", "start_longitude", "end_longitude"),
    names(out)
  )
  for (field in longitude_fields) {
    values <- as.numeric(out[[field]])
    out[[field]] <- ifelse(!is.na(values) & values < 0, values + 360, values)
  }
  out
}

simple_boundary_layers <- function(boundaries) {
  if (!inherits(boundaries, "sf")) {
    stop("Local boundaries must be supplied as an sf object.", call. = FALSE)
  }
  boundaries <- sf::st_transform(boundaries, 4326)
  label_name <- dplyr::coalesce(
    as.character(boundaries$name %||% NA_character_),
    as.character(boundaries$admin %||% NA_character_),
    as.character(boundaries$name_long %||% NA_character_)
  )
  label_x <- suppressWarnings(as.numeric(boundaries$label_x %||% NA_real_))
  label_y <- suppressWarnings(as.numeric(boundaries$label_y %||% NA_real_))

  west <- boundaries[is.finite(label_x) & label_x < 0, ]
  if (nrow(west)) {
    suppressWarnings({
      west_geometry <- sf::st_geometry(west) + c(360, 0)
      sf::st_crs(west_geometry) <- sf::st_crs(boundaries)
      sf::st_geometry(west) <- west_geometry
    })
  }
  polygons <- if (nrow(west)) rbind(boundaries, west) else boundaries

  priority_islands <- c(
    "Fiji", "Kiribati", "Marshall Islands", "Micronesia", "Nauru", "Palau",
    "Samoa", "Solomon Islands", "Tonga", "Tuvalu", "Vanuatu"
  )
  label_rank <- suppressWarnings(as.numeric(boundaries$labelrank %||% NA_real_))
  label_keep <- is.finite(label_x) & is.finite(label_y) & nzchar(label_name) &
    ((!is.na(label_rank) & label_rank <= 3) | label_name %in% priority_islands)
  labels <- data.frame(
    label = label_name[label_keep],
    longitude = ifelse(label_x[label_keep] < 0, label_x[label_keep] + 360, label_x[label_keep]),
    latitude = label_y[label_keep],
    stringsAsFactors = FALSE
  )
  labels <- labels[!duplicated(labels$label), , drop = FALSE]
  labels <- sf::st_as_sf(labels, coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)
  list(polygons = polygons, labels = labels)
}

add_simple_boundary_basemap <- function(
    map, boundaries, group = "Local boundaries & labels") {
  simple <- simple_boundary_layers(boundaries)
  map <- leaflet::addPolygons(
    map, data = simple$polygons, group = group,
    fillColor = "#F2EFE7", fillOpacity = 1, color = "#71808A",
    weight = 0.65, opacity = 0.9, smoothFactor = 0.2
  )
  if (nrow(simple$labels)) {
    map <- leaflet::addLabelOnlyMarkers(
      map, data = simple$labels, lng = ~longitude, lat = ~latitude,
      label = ~label, group = group,
      labelOptions = leaflet::labelOptions(
        noHide = TRUE, textOnly = TRUE, direction = "center",
        className = "simple-boundary-label"
      )
    )
  }
  map
}

add_historical_map_layers <- function(map, events, routes, uncertainty = NULL,
                                      operating_regions = NULL, palette_domain = NULL,
                                      show_disputed = TRUE) {
  events_display <- shift_longitude_360(events)
  routes_display <- shift_longitude_360(routes)
  palette_domain <- palette_domain %||% events_display$event_visual_class
  pal <- event_palette(palette_domain)

  included <- routes_display[
    routes_display$include_default_map & tolower(routes_display$route_confidence) == "high",
  ]
  estimated <- routes_display[
    routes_display$include_default_map & tolower(routes_display$route_confidence) != "high",
  ]
  disputed <- if (isTRUE(show_disputed)) {
    routes_display[
      !routes_display$include_default_map |
        grepl("disput|conflict|exclude|unsupported", routes_display$source_status, ignore.case = TRUE),
    ]
  } else {
    routes_display[0, , drop = FALSE]
  }

  if (nrow(included)) {
    map <- leaflet::addPolylines(
      map, data = included, group = "Confirmed/default route legs",
      layerId = ~paste0("route-", leg_id), color = "#173B57", weight = 3.5,
      opacity = 0.9, popup = route_popup(included)
    )
  }
  if (nrow(estimated)) {
    map <- leaflet::addPolylines(
      map, data = estimated, group = "Estimated route legs",
      layerId = ~paste0("route-", leg_id), color = "#B26A2E", weight = 3.2,
      opacity = 0.85, dashArray = "10,7", popup = route_popup(estimated)
    )
  }
  if (nrow(disputed)) {
    map <- leaflet::addPolylines(
      map, data = disputed, group = "Disputed/excluded route legs",
      layerId = ~paste0("route-", leg_id), color = "#777777", weight = 3,
      opacity = 0.7, dashArray = "2,8", popup = route_popup(disputed)
    )
  }
  if (!is.null(uncertainty) && nrow(uncertainty)) {
    uncertainty_display <- shift_longitude_360(uncertainty)
    map <- leaflet::addPolygons(
      map, data = uncertainty_display, group = "Position uncertainty",
      layerId = ~paste0("uncertainty-", sequence), color = "#6A51A3",
      fillColor = "#807DBA", weight = 1, fillOpacity = 0.16,
      popup = ~paste0("Uncertainty: ", position_uncertainty_nm, " NM; geodesic radius")
    )
  }
  if (!is.null(operating_regions) && nrow(operating_regions)) {
    regions_display <- shift_longitude_360(operating_regions)
    map <- leaflet::addPolygons(
      map, data = regions_display, group = "Major operating regions (modeled)",
      color = "#5A6B48", fillColor = "#A8B58C", weight = 1.2,
      dashArray = "6,5", fillOpacity = 0.14,
      popup = ~paste0("<strong>", region_name, "</strong><br>", date_start,
                      " to ", date_end, "<br>", region_method)
    )
  }
  if (nrow(events_display)) {
    major <- grepl(
      "combat|damage|kamikaze|air attack",
      paste(events_display$event_category, events_display$event_action),
      ignore.case = TRUE
    )
    map <- leaflet::addCircleMarkers(
      map, data = events_display, lng = ~longitude, lat = ~latitude,
      layerId = ~paste0("event-", sequence), group = "USS Terror events",
      radius = ifelse(major, 8, 5.5), color = "#1F1F1F",
      weight = ifelse(major, 2, 1), fillColor = pal(events_display$event_visual_class),
      fillOpacity = 0.88, popup = event_popup(events_display),
      label = ~paste0(format(date_start, "%Y-%m-%d"), " — ", location_name)
    )
  }
  map
}

initialize_deployment_map <- function(events, routes, boundaries, uncertainty, operating_regions,
                                      settings, view_lng, view_lat, view_zoom,
                                      offline = FALSE, initial_basemap = NULL,
                                      show_disputed = TRUE, show_uncertainty = TRUE,
                                      show_regions = TRUE) {
  map <- leaflet::leaflet(options = leaflet::leafletOptions(
    worldCopyJump = FALSE, minZoom = 1, preferCanvas = TRUE
  )) |>
    leaflet::setView(lng = view_lng, lat = view_lat, zoom = view_zoom)

  allow_online <- isTRUE(setting_value(
    settings, c("display", "allow_online_basemaps"),
    settings$allow_online_basemaps %||% FALSE
  )) && !isTRUE(offline)
  initial_basemap <- as.character(initial_basemap %||% if (allow_online) "OpenStreetMap" else "Local boundaries & labels")
  if (allow_online && identical(initial_basemap, "OpenStreetMap")) {
    map <- add_openstreetmap_basemap(map)
  } else {
    map <- add_simple_boundary_basemap(map, boundaries, deployment_local_group)
  }

  map <- add_historical_map_layers(
    map, events, routes, uncertainty, operating_regions,
    palette_domain = events$event_visual_class, show_disputed = show_disputed
  )
  overlays <- historical_map_groups()
  map <- leaflet::addLayersControl(
    map, overlayGroups = overlays,
    options = leaflet::layersControlOptions(collapsed = FALSE)
  )

  hidden <- c(
    if (!isTRUE(show_disputed)) "Disputed/excluded route legs",
    if (!isTRUE(show_uncertainty)) "Position uncertainty",
    if (!isTRUE(show_regions)) "Major operating regions (modeled)"
  )
  if (length(hidden)) map <- leaflet::hideGroup(map, hidden)
  legend_html <- htmltools::HTML(
    "<div class='route-legend'><strong>Historical reconstruction</strong><br><span class='solid-line'>━━</span> included/high confidence<br><span class='dash-line'>┅┅</span> estimated reconstruction<br><span class='dot-line'>•••</span> disputed/excluded<br><small>Endpoint-to-endpoint geodesics are not exact ship tracks.</small></div>"
  )
  map <- leaflet::addControl(map, legend_html, position = "bottomleft")
  map
}

deployment_layer_ids <- c(
  osm = "deployment-openstreetmap",
  gebco = "deployment-gebco",
  openseamap = "deployment-openseamap"
)
deployment_local_group <- "Local boundaries & labels"

deployment_online_basemaps_allowed <- function(settings, offline = FALSE) {
  isTRUE(setting_value(
    settings, c("display", "allow_online_basemaps"),
    settings$allow_online_basemaps %||% FALSE
  )) && !isTRUE(offline)
}

add_openstreetmap_basemap <- function(map) {
  leaflet::addProviderTiles(
    map, leaflet::providers$OpenStreetMap,
    layerId = unname(deployment_layer_ids[["osm"]]),
    group = "OpenStreetMap",
    options = leaflet::providerTileOptions(noWrap = FALSE)
  )
}

add_gebco_context_layer <- function(map, settings) {
  gebco <- setting_value(settings, c("nautical_layers", "gebco"), list())
  if (!isTRUE(gebco$enabled) || !nzchar(gebco$wms_url %||% "") || !nzchar(gebco$layer_name %||% "")) {
    return(map)
  }
  tryCatch(
    leaflet::addWMSTiles(
      map, baseUrl = gebco$wms_url,
      layerId = unname(deployment_layer_ids[["gebco"]]),
      group = gebco$label %||% "GEBCO global bathymetric relief",
      layers = gebco$layer_name, options = leaflet::WMSTileOptions(
        format = "image/png", transparent = FALSE,
        opacity = as.numeric(gebco$opacity %||% 0.65), noWrap = FALSE
      ), attribution = gebco$attribution %||% "GEBCO Compilation Group"
    ),
    error = function(e) map
  )
}

add_openseamap_context_layer <- function(map, settings) {
  openseamap <- setting_value(settings, c("nautical_layers", "openseamap"), list())
  if (!isTRUE(openseamap$enabled) || !nzchar(openseamap$tile_url %||% "")) {
    return(map)
  }
  tryCatch(
    leaflet::addTiles(
      map, urlTemplate = openseamap$tile_url,
      layerId = unname(deployment_layer_ids[["openseamap"]]),
      group = openseamap$label %||% "Modern OpenSeaMap seamarks — reference only",
      options = leaflet::tileOptions(maxZoom = openseamap$max_zoom %||% 18, noWrap = FALSE),
      attribution = openseamap$attribution %||% "OpenSeaMap contributors"
    ),
    error = function(e) map
  )
}

switch_deployment_basemap <- function(proxy, boundaries, selected, settings, offline = FALSE) {
  allow_online <- deployment_online_basemaps_allowed(settings, offline)
  selected <- as.character(selected %||% if (allow_online) "OpenStreetMap" else deployment_local_group)
  proxy <- leaflet::removeTiles(proxy, unname(deployment_layer_ids[["osm"]]))
  proxy <- leaflet::clearGroup(proxy, deployment_local_group)
  if (allow_online && identical(selected, "OpenStreetMap")) {
    add_openstreetmap_basemap(proxy)
  } else {
    add_simple_boundary_basemap(proxy, boundaries, deployment_local_group)
  }
}

toggle_deployment_context_layer <- function(proxy, layer, enabled, settings, offline = FALSE) {
  layer <- match.arg(layer, c("gebco", "openseamap"))
  layer_id <- unname(deployment_layer_ids[[layer]])
  proxy <- leaflet::removeTiles(proxy, layer_id)
  if (!isTRUE(enabled) || isTRUE(offline)) return(proxy)
  if (identical(layer, "gebco")) add_gebco_context_layer(proxy, settings) else add_openseamap_context_layer(proxy, settings)
}

update_deployment_map <- function(proxy, events, routes, uncertainty = NULL,
                                  operating_regions = NULL, palette_domain = NULL,
                                  show_disputed = FALSE, show_uncertainty = FALSE,
                                  show_regions = FALSE) {
  for (group in historical_map_groups()) proxy <- leaflet::clearGroup(proxy, group)
  if (!isTRUE(show_uncertainty)) uncertainty <- NULL
  if (!isTRUE(show_regions)) operating_regions <- NULL
  proxy <- add_historical_map_layers(
    proxy, events, routes, uncertainty, operating_regions, palette_domain,
    show_disputed = show_disputed
  )
  if (isTRUE(show_disputed)) {
    proxy <- leaflet::showGroup(proxy, "Disputed/excluded route legs")
  } else {
    proxy <- leaflet::hideGroup(proxy, "Disputed/excluded route legs")
  }
  if (isTRUE(show_uncertainty)) {
    proxy <- leaflet::showGroup(proxy, "Position uncertainty")
  } else {
    proxy <- leaflet::hideGroup(proxy, "Position uncertainty")
  }
  if (isTRUE(show_regions)) {
    proxy <- leaflet::showGroup(proxy, "Major operating regions (modeled)")
  } else {
    proxy <- leaflet::hideGroup(proxy, "Major operating regions (modeled)")
  }
  proxy
}

highlight_selected_event <- function(proxy, event) {
  proxy <- leaflet::clearGroup(proxy, "Selected event")
  if (is.null(event) || !nrow(event)) return(proxy)
  display <- shift_longitude_360(event)
  leaflet::addCircleMarkers(
    proxy, data = display, lng = ~longitude, lat = ~latitude,
    group = "Selected event", layerId = ~paste0("selected-", sequence),
    radius = 12, fill = FALSE, color = "#FFD34E", weight = 4, opacity = 1
  )
}
