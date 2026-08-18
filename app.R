suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(sf)
  library(leaflet)
  library(dplyr)
  library(plotly)
  library(DT)
  library(htmltools)
  library(readr)
  library(yaml)
})

Sys.setenv(USS_TERROR_PROJECT = normalizePath(getwd(), winslash = "/", mustWork = TRUE))
source("R/helpers.R", local = TRUE)
source("R/map_filters.R", local = TRUE)
source("R/map_layers.R", local = TRUE)
source("R/timeline_plot.R", local = TRUE)
source("R/event_table.R", local = TRUE)
source("R/nautical_layers.R", local = TRUE)
source("R/gebco_layers.R", local = TRUE)
source("R/gmrt_services.R", local = TRUE)
source("R/mine_sources.R", local = TRUE)
source("R/minefield_models.R", local = TRUE)
source("R/minefield_validation.R", local = TRUE)
source("R/minefield_proximity.R", local = TRUE)

settings <- load_settings()
gpkg_candidates <- c(
  project_path("data", "processed", "uss_terror_map_layers.gpkg"),
  project_path("qgis", "uss_terror_layers.gpkg")
)
gpkg <- gpkg_candidates[file.exists(gpkg_candidates)][1]
if (!length(gpkg) || is.na(gpkg)) {
  stop("Processed layers are missing. Run: Rscript scripts/build_all.R", call. = FALSE)
}

events <- st_read(gpkg, layer = "events", quiet = TRUE)
routes <- st_read(gpkg, layer = "route_legs_geodesic", quiet = TRUE)
locations <- st_read(gpkg, layer = "locations", quiet = TRUE)
uncertainty <- st_read(gpkg, layer = "uncertainty_areas", quiet = TRUE)
operating_regions <- st_read(gpkg, layer = "major_operating_regions", quiet = TRUE)
land <- st_read(gpkg, layer = "natural_earth_land", quiet = TRUE)
boundary_shapefile_candidates <- c(
  project_path(
    "data", "reference", "simple_boundaries", "natural_earth_boundaries_pacific.shp"
  ),
  project_path(
    "data", "reference", "simple_boundaries", "natural_earth_boundaries.shp"
  )
)
boundary_shapefile <- boundary_shapefile_candidates[
  file.exists(boundary_shapefile_candidates)
][1]
boundaries <- if (file.exists(boundary_shapefile)) {
  st_read(boundary_shapefile, quiet = TRUE)
} else {
  warning("Local boundary shapefile is missing; using the GeoPackage boundary layer.", call. = FALSE)
  land
}
conflicts <- read_csv(project_path("data", "processed", "conflicts.csv"), show_col_types = FALSE)
inventory <- read_csv(project_path("outputs", "reports", "source_inventory.csv"), show_col_types = FALSE)
mine_tables <- load_mine_database()
mine_candidates <- load_mine_candidates()
mine_candidate_issues <- validate_mine_candidates(mine_candidates, require_decisions = TRUE)
mine_candidate_counts <- mine_review_counts(mine_candidates)
phase5_source_inventory_path <- project_path("outputs", "reports", "phase5_source_inventory.csv")
phase5_source_inventory <- if (file.exists(phase5_source_inventory_path)) {
  read_csv(phase5_source_inventory_path, show_col_types = FALSE)
} else {
  tibble::tibble()
}
gmrt_inventory <- gmrt_cache_inventory(settings)
events$event_visual_class <- event_visual_class(events$event_category)

event_categories <- sort(unique(events$event_category))
confidence_choices <- sort(unique(tolower(c(events$historical_confidence, routes$route_confidence))))
offline_override <- tolower(Sys.getenv("USS_TERROR_OFFLINE", unset = "false")) %in% c("1", "true", "yes")
online_basemaps_allowed <- deployment_online_basemaps_allowed(settings, offline_override)
basemap_choices <- if (online_basemaps_allowed) {
  c(
    "OpenStreetMap" = "OpenStreetMap",
    "Local boundaries & labels" = "Local boundaries & labels"
  )
} else {
  c("Local boundaries & labels" = "Local boundaries & labels")
}
default_basemap <- unname(basemap_choices[[1]])
default_start <- as.Date(setting_value(settings, c("display", "default_start_date"), settings$default_start_date %||% min(events$date_start)))
default_end <- as.Date(setting_value(settings, c("display", "default_end_date"), settings$default_end_date %||% max(events$date_end)))
maximum_speed <- as.numeric(setting_value(
  settings, c("display", "maximum_plausible_speed_knots"),
  settings$maximum_plausible_speed_knots %||% 23
))

app_theme <- bs_theme(
  version = 5, bootswatch = "flatly", primary = "#173B57", secondary = "#9B6A3A",
  success = "#2E6B57", bg = "#F4F1EA", fg = "#17232C"
)

header_title <- div(
  class = "brand-lockup",
  div(class = "brand-kicker", "USS Terror (CM-5)"),
  div(class = "brand-title", "Pacific Deployment · 1943–1946")
)

reconstruction_notice <- div(
  class = "reconstruction-notice",
  icon("compass"),
  span(strong("Historical reconstruction."), " Dates, centroids, routes, and modeled positions may be estimated.")
)

map_sidebar <- sidebar(
  width = 340,
  h4("Chronology"),
  dateRangeInput(
    "date_filter", "Start and end dates",
    start = default_start, end = default_end,
    min = min(events$date_start), max = max(events$date_end), format = "yyyy-mm-dd"
  ),
  selectInput("year_filter", "Year", choices = deployment_year_choices(), selected = "all", selectize = FALSE),
  radioButtons("year_mode", "Year behavior", choices = deployment_year_modes(), selected = "selected_year"),
  sliderInput(
    "date_slider", "Animated date range",
    min = min(events$date_start), max = max(events$date_end), value = c(default_start, default_end),
    timeFormat = "%Y-%m-%d", animate = animationOptions(interval = 1200, loop = FALSE)
  ),
  div(
    class = "button-row",
    actionButton("previous_event", "Previous event", icon = icon("chevron-left"), class = "btn-sm"),
    actionButton("next_event", "Next event", icon = icon("chevron-right"), class = "btn-sm")
  ),
  actionButton("locate_selected", "Locate selected event", icon = icon("location-crosshairs"), class = "btn-primary btn-sm w-100"),
  actionButton("reset_filters", "Reset", icon = icon("rotate-left"), class = "btn-outline-secondary btn-sm w-100"),
  uiOutput("cross_year_notice"),
  hr(),
  h4("Evidence filters"),
  selectizeInput(
    "category_filter", "Event categories", choices = event_categories, selected = NULL,
    multiple = TRUE, options = list(plugins = list("remove_button"), placeholder = "All source categories")
  ),
  selectizeInput(
    "confidence_filter", "Historical confidence", choices = confidence_choices, selected = NULL,
    multiple = TRUE, options = list(plugins = list("remove_button"), placeholder = "All confidence levels")
  ),
  checkboxInput(
    "show_disputed", "Show disputed or excluded route legs",
    value = isTRUE(setting_value(settings, c("display", "show_disputed_routes_default"), settings$show_disputed_routes_default %||% FALSE))
  ),
  checkboxInput(
    "show_uncertainty", "Show position-uncertainty areas",
    value = isTRUE(setting_value(settings, c("display", "show_uncertainty_default"), settings$show_uncertainty_default %||% FALSE))
  ),
  div(class = "evidence-note", "Lines connect documented endpoints by great-circle interpolation. They are not daily positions or an exact ship track."),
  hr(),
  h4("Basemap"),
  selectInput(
    "pacific_basemap", NULL, choices = basemap_choices,
    selected = default_basemap, selectize = FALSE
  ),
  h4("Modern geographic context"),
  if (online_basemaps_allowed && isTRUE(setting_value(settings, c("nautical_layers", "gebco", "enabled"), FALSE))) {
    checkboxInput("show_gebco", "GEBCO global bathymetric relief", value = FALSE)
  },
  if (online_basemaps_allowed && isTRUE(setting_value(settings, c("nautical_layers", "openseamap", "enabled"), FALSE))) {
    checkboxInput("show_openseamap", "Modern OpenSeaMap seamarks", value = FALSE)
  },
  checkboxInput("show_operating_regions", "Show modeled operating regions", value = FALSE),
  checkboxInput("show_gmrt_bathymetry", "GMRT regional bathymetry — modern context", value = FALSE),
  checkboxInput("show_gmrt_coverage", "GMRT curated multibeam coverage", value = FALSE),
  uiOutput("gmrt_cache_status"),
  tags$details(
    tags$summary("Modern-layer limitations"),
    p(openseamap_warning()), p(gebco_warning()), p(gmrt_warning())
  )
)

ui <- page_navbar(
  title = header_title, theme = app_theme, id = "main_nav", fillable = FALSE,
  header = tagList(
    tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = "css/terror.css?v=5"),
      tags$meta(name = "description", content = "Interactive historical reconstruction of USS Terror's Pacific deployment, 1943–1946.")
    ),
    reconstruction_notice
  ),
  nav_panel(
    "Pacific Theater",
    layout_sidebar(
      sidebar = map_sidebar,
      div(
        class = "dashboard-grid",
        value_box(title = "Visible events", value = textOutput("stat_events", inline = TRUE), theme = "primary"),
        value_box(title = "Visible route legs", value = textOutput("stat_routes", inline = TRUE), theme = "success"),
        value_box(title = "Visible reconstructed distance", value = textOutput("stat_distance", inline = TRUE), theme = "secondary"),
        value_box(title = "Combat/damage events", value = textOutput("stat_combat", inline = TRUE), theme = "danger"),
        value_box(title = "Unique port/shipyard days", value = textOutput("stat_port_days", inline = TRUE), theme = "primary")
      ),
      layout_columns(
        card(
          full_screen = TRUE,
          card_header("USS Terror deployment interactive view"),
          div(
            class = "pacific-map-shell",
            div(
              id = "pacific_map_loading", class = "map-loading", role = "status",
              span(class = "map-loading-spinner", `aria-hidden` = "true"),
              span("Loading map data and basemap…")
            ),
            leafletOutput("pacific_map", height = "720px"),
            tags$script(HTML(
              "$(document).on('shiny:value', function(event) {\n",
              "  if (event.target.id === 'pacific_map') {\n",
              "    $('#pacific_map_loading').attr('hidden', true);\n",
              "  }\n",
              "});\n",
              "$(document).on('shiny:error', function(event) {\n",
              "  if (event.target.id === 'pacific_map') {\n",
              "    $('#pacific_map_loading').addClass('map-loading-error').text('The map is taking longer than expected. Check the connection and retry.');\n",
              "  }\n",
              "});"
            ))
          )
        ),
        card(card_header("Selected event"), uiOutput("event_detail"), min_height = "340px"),
        col_widths = c(9, 3)
      )
    )
  ),
  nav_menu(
    "Deployment Records",
    nav_panel(
      "Timeline",
      card(full_screen = TRUE, card_header("Linked event timeline"), plotlyOutput("timeline", height = "650px")),
      card(card_header("Selected event"), uiOutput("timeline_detail"))
    ),
    nav_panel(
      "Events",
      card(
        card_header("Visible event records"),
        p(class = "table-note", "The table uses the same year, date, category, and confidence filters as the Pacific map and timeline."),
        DTOutput("events_table")
      )
    ),
    nav_panel(
      "Route Legs",
      card(
        card_header("Visible reconstructed route-leg diagnostics"),
        p(class = "table-note", paste0("Speeds above ", maximum_speed, " knots are highlighted for review; no record is deleted automatically.")),
        DTOutput("routes_table")
      )
    )
  ),
  nav_panel(
    "Historical Mine Warfare",
    layout_sidebar(
      sidebar = sidebar(
        width = 340,
        h4("Review data"),
        selectInput(
          "mine_data_view", "Data view",
          choices = stats::setNames(
            c("canonical", "accepted", "rejected"),
            c(
              "Canonical records",
              paste0("Accepted review candidates (", mine_candidate_counts[["accepted"]], ")"),
              paste0("Rejected audit records (", mine_candidate_counts[["rejected"]], ")")
            )
          ),
          selected = "accepted", selectize = FALSE
        ),
        uiOutput("mine_layer_controls"),
        selectInput(
          "mine_proximity", "Near visible USS Terror events:",
          choices = mine_proximity_choices(), selected = "100", selectize = FALSE
        ),
        p(class = "evidence-note", "Accepted candidate evidence is shown by default with distinct styling. These review records never populate canonical tables."),
        uiOutput("mine_filter_status"),
        downloadButton("download_mine_review", "Download visible review CSV", class = "btn-sm btn-outline-primary w-100")
      ),
      div(
        class = "alert alert-danger",
        "These layers are incomplete historical research reconstructions. They are not current hazard information and must not be used for navigation, route planning, diving, fishing, salvage, ordnance clearance, or safety decisions."
      ),
      uiOutput("mine_schema_status"),
      card(
        card_header("Candidate decision register"),
        p(class = "table-note", "This is a curated review view. Use the download for the complete visible register; canonical storage remains separate."),
        DTOutput("mine_review_table")
      ),
      layout_columns(
        card(card_header("Vessels and participation decisions"), DTOutput("mine_vessels_table")),
        card(card_header("Mine-warfare operations"), DTOutput("mine_operations_table")),
        col_widths = c(6, 6)
      ),
      layout_columns(
        card(full_screen = TRUE, card_header("Historical mine-warfare evidence map"), leafletOutput("mine_map", height = "600px")),
        card(card_header("Selected evidence record"), uiOutput("mine_review_detail"), min_height = "420px"),
        col_widths = c(8, 4)
      )
    )
  ),
  nav_menu(
    "Research",
    nav_panel(
      "Sources and Conflicts",
      layout_columns(
        card(card_header("Deployment source inventory and SHA-256 hashes"), DTOutput("sources_table")),
        card(card_header("Mine-warfare candidate sources"), DTOutput("phase5_sources_table")),
        card(card_header("Mine-warfare archived-source integrity"), DTOutput("phase5_source_integrity_table")),
        card(card_header("Visible deployment conflict register"), DTOutput("conflicts_table")),
        col_widths = c(12, 12, 12, 12)
      )
    ),
    nav_panel("Methods", card(card_header("Method and limitations"), div(class = "methods-text", verbatimTextOutput("methods_text"))))
  ),
  footer = div(class = "app-footer", "Historical reconstruction for interpretive use. Consult the cited records before drawing operational conclusions.")
)

server <- function(input, output, session) {
  selected_sequence <- reactiveVal(events$sequence[[1]])
  selected_review_key <- reactiveVal(NULL)

  filter_window <- reactive({
    req(input$date_filter, input$date_slider)
    start <- max(as.Date(input$date_filter[[1]]), as.Date(input$date_slider[[1]]))
    end <- min(as.Date(input$date_filter[[2]]), as.Date(input$date_slider[[2]]))
    if (start > end) c(start, start) else c(start, end)
  })

  filtered_map_data <- reactive({
    window <- filter_window()
    filter_deployment_data(
      events, routes, date_start = window[[1]], date_end = window[[2]],
      selected_year = input$year_filter %||% "all", year_mode = input$year_mode %||% "selected_year",
      categories = input$category_filter %||% character(), confidences = input$confidence_filter %||% character(),
      show_disputed = isTRUE(input$show_disputed)
    )
  })

  filtered_uncertainty <- reactive({
    dat <- filtered_map_data()
    uncertainty[as.character(uncertainty$sequence) %in% dat$event_ids, ]
  })

  filtered_regions <- reactive({
    dat <- filtered_map_data()
    keep <- event_overlaps(operating_regions$date_start, operating_regions$date_end, dat$filter_start, dat$filter_end)
    operating_regions[keep, ]
  })

  selected_event <- reactive({
    dat <- filtered_map_data()$events
    if (!nrow(dat)) return(dat)
    hit <- dat[dat$sequence == selected_sequence(), ]
    if (nrow(hit)) hit[1, ] else dat[1, ]
  })

  observe({
    dat <- filtered_map_data()$events
    if (nrow(dat) && !selected_sequence() %in% dat$sequence) selected_sequence(dat$sequence[[1]])
  })

  observeEvent(input$reset_filters, {
    updateDateRangeInput(session, "date_filter", start = default_start, end = default_end)
    updateSliderInput(session, "date_slider", value = c(default_start, default_end))
    updateSelectInput(session, "year_filter", selected = "all")
    updateRadioButtons(session, "year_mode", selected = "selected_year")
    updateSelectizeInput(session, "category_filter", selected = character())
    updateSelectizeInput(session, "confidence_filter", selected = character())
    updateCheckboxInput(session, "show_disputed", value = FALSE)
    updateCheckboxInput(session, "show_uncertainty", value = FALSE)
    selected_sequence(events$sequence[[1]])
  })

  move_selection <- function(direction) {
    dat <- filtered_map_data()$events
    if (!nrow(dat)) return()
    pos <- match(selected_sequence(), dat$sequence)
    if (is.na(pos)) pos <- 1L
    pos <- max(1L, min(nrow(dat), pos + direction))
    selected_sequence(dat$sequence[[pos]])
  }
  observeEvent(input$previous_event, move_selection(-1L))
  observeEvent(input$next_event, move_selection(1L))

  timeline_click <- reactive(suppressWarnings(plotly::event_data("plotly_click", source = "terror_timeline")))
  observeEvent(timeline_click(), {
    click <- timeline_click()
    if (!is.null(click$key)) selected_sequence(as.integer(click$key))
  })
  observeEvent(input$pacific_map_marker_click, {
    id <- input$pacific_map_marker_click$id
    if (!is.null(id) && grepl("^event-", id)) selected_sequence(as.integer(sub("^event-", "", id)))
  })
  output$pacific_map <- renderLeaflet({
    dat <- isolate(filtered_map_data())
    show_uncertainty <- isTRUE(isolate(input$show_uncertainty))
    show_regions <- isTRUE(isolate(input$show_operating_regions))
    initialize_deployment_map(
      dat$events, dat$routes, boundaries,
      if (show_uncertainty) isolate(filtered_uncertainty()) else NULL,
      if (show_regions) isolate(filtered_regions()) else NULL,
      settings, view_lng = 175, view_lat = 10, view_zoom = 3,
      offline = offline_override, initial_basemap = isolate(input$pacific_basemap),
      show_disputed = isTRUE(dat$show_disputed),
      show_uncertainty = show_uncertainty,
      show_regions = show_regions
    )
  })

  observeEvent(
    list(filtered_map_data(), input$show_uncertainty, input$show_operating_regions),
    {
    dat <- filtered_map_data()
    u <- filtered_uncertainty()
    regions <- filtered_regions()
    update_deployment_map(
      leafletProxy("pacific_map", session), dat$events, dat$routes, u, regions,
      palette_domain = events$event_visual_class, show_disputed = isTRUE(input$show_disputed),
      show_uncertainty = isTRUE(input$show_uncertainty),
      show_regions = isTRUE(input$show_operating_regions)
    )
    }, ignoreInit = TRUE
  )

  observeEvent(input$pacific_basemap, {
    switch_deployment_basemap(
      leafletProxy("pacific_map", session), boundaries,
      input$pacific_basemap, settings, offline = offline_override
    )
  }, ignoreInit = TRUE)

  observeEvent(input$show_gebco, {
    toggle_deployment_context_layer(
      leafletProxy("pacific_map", session), "gebco", input$show_gebco,
      settings, offline = offline_override
    )
  }, ignoreInit = TRUE)

  observeEvent(input$show_openseamap, {
    toggle_deployment_context_layer(
      leafletProxy("pacific_map", session), "openseamap", input$show_openseamap,
      settings, offline = offline_override
    )
  }, ignoreInit = TRUE)

  observe({
    event <- selected_event()
    highlight_selected_event(leafletProxy("pacific_map", session), event)
  })

  observeEvent(input$locate_selected, {
    event <- selected_event()
    req(nrow(event))
    display_lon <- ifelse(event$longitude[[1]] < 0, event$longitude[[1]] + 360, event$longitude[[1]])
    leafletProxy("pacific_map", session) |> setView(lng = display_lon, lat = event$latitude[[1]], zoom = 6)
  })

  output$cross_year_notice <- renderUI({
    dat <- filtered_map_data()
    if (!any(dat$routes$cross_year_boundary, na.rm = TRUE) || identical(dat$selected_year, "all")) return(NULL)
    div(class = "alert alert-info mt-2 py-2", cross_year_route_notice())
  })

  output$gmrt_cache_status <- renderUI({
    cached <- sum(gmrt_inventory$display_cached, na.rm = TRUE)
    coverage <- sum(gmrt_inventory$coverage_cached, na.rm = TRUE)
    if (!cached && !coverage) {
      return(p(class = "table-note", "GMRT cache is empty; enabling these controls does not start a download. Future cached layers load only at detailed zoom when their region intersects the map."))
    }
    p(class = "table-note", paste(cached, "regional bathymetry raster(s) and", coverage,
                                  "coverage raster(s) are cached; only intersecting regions load at detailed zoom."))
  })

  update_gmrt_layers <- function(map_id, bounds, zoom) {
    proxy <- leafletProxy(map_id, session)
    proxy <- leaflet::clearGroup(proxy, "GMRT regional bathymetry — modern context")
    proxy <- leaflet::clearGroup(proxy, "GMRT curated multibeam coverage")
    if (offline_override || !requireNamespace("terra", quietly = TRUE)) return(invisible(NULL))
    bathymetry <- gmrt_regions_for_view(
      gmrt_inventory, bounds, zoom, enabled = isTRUE(input$show_gmrt_bathymetry),
      layer = "bathymetry", settings = settings
    )
    coverage <- gmrt_regions_for_view(
      gmrt_inventory, bounds, zoom, enabled = isTRUE(input$show_gmrt_coverage),
      layer = "coverage", settings = settings
    )
    for (path in bathymetry$display_path) {
      proxy <- tryCatch(
        leaflet::addRasterImage(
          proxy, x = terra::rast(path), colors = "Spectral", opacity = 0.65,
          group = "GMRT regional bathymetry — modern context", project = FALSE,
          method = "bilinear", maxBytes = 16 * 1024 * 1024,
          attribution = "GMRT modern compiled bathymetry/topography — not for navigation"
        ),
        error = function(e) proxy
      )
    }
    coverage_palette <- leaflet::colorNumeric(c("#002B36", "#00D7FF"), domain = NULL, na.color = "transparent")
    for (path in coverage$coverage_path) {
      proxy <- tryCatch(
        leaflet::addRasterImage(
          proxy, x = terra::rast(path), colors = coverage_palette, opacity = 0.45,
          group = "GMRT curated multibeam coverage", project = FALSE,
          method = "ngb", maxBytes = 16 * 1024 * 1024,
          attribution = "GMRT curated multibeam coverage — modern reference only"
        ),
        error = function(e) proxy
      )
    }
    invisible(NULL)
  }
  observe(update_gmrt_layers("pacific_map", input$pacific_map_bounds, input$pacific_map_zoom))

  mine_view_tables <- reactive({
    view <- input$mine_data_view %||% "accepted"
    if (identical(view, "canonical")) mine_tables else filter_mine_candidates(mine_candidates, view)
  })

  mine_review_register <- reactive({
    view <- input$mine_data_view %||% "accepted"
    if (identical(view, "canonical")) candidate_review_register(mine_candidates, "__canonical__") else candidate_review_register(mine_candidates, view)
  })

  output$mine_layer_controls <- renderUI({
    view <- input$mine_data_view %||% "accepted"
    choices <- candidate_layer_choices(mine_view_tables())
    if (!length(choices)) {
      return(div(class = "empty-layer-note", icon("eye-slash"), " No spatial records in this view."))
    }
    selected_layers <- if (identical(view, "accepted")) unname(choices) else character()
    checkboxGroupInput("mine_layers", "Map layers", choices = choices, selected = selected_layers)
  })

  minefields_filtered <- reactive({
    view <- input$mine_data_view %||% "accepted"
    tables <- mine_view_tables()
    fields <- if (identical(view, "canonical")) tables$minefields else candidate_points_sf(tables$minefields)
    if (!nrow(fields)) return(fields)
    dat <- filtered_map_data()
    end_date <- dplyr::coalesce(
      fields$date_declared_cleared, fields$date_last_swept,
      fields$date_last_emplaced, fields$date_first_swept, fields$date_first_emplaced
    )
    start_date <- dplyr::coalesce(fields$date_first_emplaced, fields$date_first_swept)
    fields <- fields[event_overlaps(start_date, end_date, dat$filter_start, dat$filter_end), ]
    filter_minefields_by_proximity(fields, dat$events, input$mine_proximity %||% "100")
  })

  output$mine_schema_status <- renderUI({
    canonical_rows <- sum(vapply(mine_tables, nrow, integer(1)))
    validation_errors <- sum(mine_candidate_issues$severity == "error")
    class_name <- if (validation_errors) "alert alert-danger mine-review-summary" else "mine-review-summary mine-review-summary-ok"
    div(
      class = class_name,
      div(class = "mine-summary-lead", "Candidate review summary"),
      div(
        class = "mine-summary-counts",
        span(strong(canonical_rows), " canonical records"),
        span(strong(mine_candidate_counts[["accepted"]]), " accepted candidates"),
        span(strong(mine_candidate_counts[["rejected"]]), " rejected audit records"),
        span(strong(mine_candidate_counts[["unresolved"]]), " unresolved decisions")
      ),
      if (validation_errors) span(class = "d-block mt-1", validation_errors, " candidate validation error(s) require attention.")
    )
  })

  output$mine_filter_status <- renderUI({
    dat <- filtered_map_data()
    view_label <- switch(input$mine_data_view %||% "accepted", canonical = "Canonical", accepted = "Accepted candidates", rejected = "Rejected audit")
    p(
      class = "table-note",
      paste0(view_label, " view · ", ifelse(dat$selected_year == "all", "all deployment years", dat$selected_year),
             " · ", input$mine_proximity %||% "100", ifelse(identical(input$mine_proximity, "all"), "", " NM"),
             " · ", nrow(minefields_filtered()), " visible mine localit", ifelse(nrow(minefields_filtered()) == 1, "y", "ies"), ".")
    )
  })

  output$mine_map <- renderLeaflet(initialize_mine_map(boundaries))

  observe({
    view <- input$mine_data_view %||% "accepted"
    layers <- input$mine_layers %||% character()
    tables <- mine_view_tables()
    fields <- minefields_filtered()
    proxy <- leafletProxy("mine_map", session) |>
      clearGroup("Mine localities") |>
      clearGroup("Mine-destruction operations") |>
      clearGroup("Uncertainty envelopes")

    if ("uncertainty" %in% layers && !identical(view, "canonical")) {
      uncertainty_polygons <- candidate_uncertainty_sf(tables)
      if (nrow(fields)) uncertainty_polygons <- uncertainty_polygons[uncertainty_polygons$minefield_id %in% fields$minefield_id, ]
      if (nrow(uncertainty_polygons)) {
        proxy <- addPolygons(
          proxy, data = uncertainty_polygons, group = "Uncertainty envelopes",
          layerId = paste0("minefield_uncertainty::", uncertainty_polygons$uncertainty_id),
          color = "#A85224", weight = 2, dashArray = "6,5", fillColor = "#E9A66F", fillOpacity = 0.18,
          popup = paste0("<strong>2 NM evidence envelope</strong><br/>", htmlEscape(uncertainty_polygons$position_basis), "<br/><em>Candidate reconstruction — not a minefield boundary.</em>")
        )
      }
    }
    if ("minefields" %in% layers && nrow(fields)) {
      popup <- if (identical(view, "canonical")) {
        minefield_popup(fields, tables$vessels, tables$vessel_operation_links, tables$mine_laying_events, tables$mine_sweeping_events, tables$units)
      } else {
        paste0(
          "<strong>", htmlEscape(fields$minefield_name), "</strong><br/>",
          "Decision: ", htmlEscape(fields$review_status), " · confidence: ", htmlEscape(fields$overall_confidence), "<br/>",
          htmlEscape(fields$position_basis), "<br/><em>Candidate locality — not for navigation.</em>"
        )
      }
      proxy <- addCircleMarkers(
        proxy, data = fields, group = "Mine localities", layerId = paste0("minefields::", fields$minefield_id),
        radius = 8, color = "#702B20", weight = 2, fillColor = "#D56A35", fillOpacity = 0.9, popup = popup
      )
    }
    if ("sweeping" %in% layers && !identical(view, "canonical")) {
      operations <- candidate_points_sf(tables$mine_sweeping_events)
      if (nrow(fields)) operations <- operations[operations$minefield_id %in% fields$minefield_id, ] else operations <- operations[0, ]
      if (nrow(operations)) {
        proxy <- addCircleMarkers(
          proxy, data = operations, group = "Mine-destruction operations",
          layerId = paste0("mine_sweeping_events::", operations$sweeping_event_id),
          radius = 6, color = "#123E5A", weight = 2, fillColor = "#63A6C8", fillOpacity = 0.95,
          popup = paste0("<strong>", htmlEscape(operations$operation_name), "</strong><br/>", htmlEscape(operations$result), "<br/><em>No clearance is inferred.</em>")
        )
      }
    }
    proxy <- leaflet::removeControl(proxy, "mine-review-control")
    if (length(layers) && nrow(fields)) {
      coordinates <- sf::st_coordinates(sf::st_centroid(sf::st_geometry(fields)))[1, ]
      proxy <- leaflet::setView(proxy, lng = coordinates[["X"]], lat = coordinates[["Y"]], zoom = 8)
      proxy <- leaflet::addControl(
        proxy,
        htmltools::HTML("<div class='map-method-note'><strong>Historical candidate evidence visible.</strong><br/>Approximate research geometry only; not a surveyed boundary and not for navigation.</div>"),
        position = "topright", layerId = "mine-review-control"
      )
    } else {
      proxy <- leaflet::setView(proxy, lng = 180, lat = 10, zoom = 2)
      proxy <- leaflet::addControl(
        proxy,
        htmltools::HTML("<div class='map-method-note'><strong>Review layers are off.</strong><br/>Choose an evidence view and enable a layer. Historical reconstruction only; not for navigation.</div>"),
        position = "topright", layerId = "mine-review-control"
      )
    }
  })

  observeEvent(input$mine_map_marker_click, {
    id <- input$mine_map_marker_click$id
    if (!is.null(id) && grepl("::", id, fixed = TRUE)) selected_review_key(id)
  })
  observeEvent(input$mine_map_shape_click, {
    id <- input$mine_map_shape_click$id
    if (!is.null(id) && grepl("::", id, fixed = TRUE)) selected_review_key(id)
  })

  observeEvent(input$mine_data_view, {
    register <- mine_review_register()
    selected_review_key(if (nrow(register)) register$review_key[[1]] else NULL)
  }, ignoreInit = FALSE)

  output$mine_review_table <- renderDT({
    register <- mine_review_register()
    display <- register |>
      dplyr::select(-review_key, -summary) |>
      dplyr::rename(
        Type = record_type, ID = record_id, Title = title,
        Decision = decision, Confidence = confidence, Date = record_date,
        Source = source_id, Locator = source_locator
      )
    datatable(
      display, rownames = FALSE, selection = "single", filter = "top", extensions = "Buttons",
      options = list(pageLength = 8, scrollX = TRUE, dom = "Bfrtip", buttons = c("copy", "csv"))
    )
  })

  observeEvent(input$mine_review_table_rows_selected, {
    row <- input$mine_review_table_rows_selected
    register <- mine_review_register()
    if (length(row) && row <= nrow(register)) selected_review_key(register$review_key[[row]])
  })

  output$mine_review_detail <- renderUI({
    key <- selected_review_key()
    if (is.null(key)) {
      return(div(class = "review-detail-empty", icon("arrow-pointer"), h5("Select a review record"), p("Choose a candidate decision in the register or enable and select a map layer.")))
    }
    item <- candidate_review_record(mine_candidates, key)
    if (is.null(item)) return(p("The selected record is unavailable."))
    record <- item$record
    register_row <- candidate_review_register(mine_candidates)
    register_row <- register_row[register_row$review_key == key, , drop = FALSE]
    detail <- function(label, field) {
      if (!field %in% names(record)) return(NULL)
      value <- as.character(record[[field]][[1]])
      if (is.na(value) || !nzchar(value)) return(NULL)
      div(class = "review-detail-row", span(class = "review-detail-label", label), span(value))
    }
    source_url <- if ("source_url" %in% names(record)) as.character(record$source_url[[1]]) else NA_character_
    tagList(
      div(
        class = "review-detail-heading",
        span(class = paste("decision-badge", record$review_status[[1]]), toupper(record$review_status[[1]])),
        h4(register_row$title[[1]]),
        p(class = "text-muted", register_row$record_type[[1]], " · ", register_row$record_id[[1]])
      ),
      detail("Confidence", if ("historical_confidence" %in% names(record)) "historical_confidence" else if ("overall_confidence" %in% names(record)) "overall_confidence" else "reliability"),
      detail("Date", if ("date_start" %in% names(record)) "date_start" else if ("date_first_swept" %in% names(record)) "date_first_swept" else "publication_date"),
      detail("Position basis", "position_basis"),
      detail("Uncertainty", "position_uncertainty_nm"),
      detail("Participation", "participation_status"),
      detail("Role", if ("vessel_role" %in% names(record)) "vessel_role" else "mine_warfare_role"),
      detail("Source", if (identical(item$table, "minefield_sources")) "source_id" else "source_id"),
      detail("Locator", if (identical(item$table, "minefield_sources")) "page_or_map_sheet" else "source_locator"),
      if (!is.na(source_url) && nzchar(source_url)) tags$a(href = source_url, target = "_blank", rel = "noopener noreferrer", icon("arrow-up-right-from-square"), " Open source record"),
      hr(),
      p(class = "review-detail-notes", register_row$summary[[1]])
    )
  })

  output$mine_vessels_table <- renderDT({
    view <- input$mine_data_view %||% "accepted"
    if (identical(view, "canonical")) {
      vessels <- sf::st_drop_geometry(mine_tables$vessels)
      display <- vessels[, intersect(c("vessel_name", "hull_number", "ship_type", "mine_warfare_role", "historical_confidence", "source_id"), names(vessels)), drop = FALSE]
    } else {
      tables <- mine_view_tables()
      vessels <- tables$vessels
      links <- tables$vessel_operation_links
      vessel_rows <- tibble::tibble(
        entry = rep("Vessel", nrow(vessels)), vessel = vessels$vessel_name, hull = vessels$hull_number,
        role = vessels$mine_warfare_role, participation = NA_character_, confidence = vessels$historical_confidence,
        decision = vessels$review_status, source = vessels$source_id
      )
      all_vessels <- mine_candidates$vessels[, c("vessel_id", "vessel_name", "hull_number"), drop = FALSE]
      links <- dplyr::left_join(links, all_vessels, by = "vessel_id")
      link_rows <- tibble::tibble(
        entry = rep("Relationship", nrow(links)), vessel = links$vessel_name, hull = links$hull_number,
        role = links$vessel_role, participation = links$participation_status, confidence = links$historical_confidence,
        decision = links$review_status, source = links$source_id
      )
      display <- dplyr::bind_rows(vessel_rows, link_rows)
    }
    datatable(display, rownames = FALSE, options = list(scrollX = TRUE, pageLength = 6))
  })

  output$mine_operations_table <- renderDT({
    tables <- mine_view_tables()
    drop_geometry <- function(x) if (inherits(x, "sf")) sf::st_drop_geometry(x) else x
    laying <- drop_geometry(tables$mine_laying_events)
    sweeping <- drop_geometry(tables$mine_sweeping_events)
    laying_view <- tibble::tibble(
      type = rep("Mine laying", nrow(laying)), operation = laying$operation_name, date = as.character(laying$date_start),
      primary_vessel = laying$primary_vessel_id, result = NA_character_, clearance_status = NA_character_,
      confidence = laying$historical_confidence, decision = laying$review_status, source = laying$source_id
    )
    sweeping_view <- tibble::tibble(
      type = rep("Mine destruction", nrow(sweeping)), operation = sweeping$operation_name, date = as.character(sweeping$date_start),
      primary_vessel = sweeping$primary_vessel_id, result = sweeping$result, clearance_status = sweeping$clearance_status_after_event,
      confidence = sweeping$historical_confidence, decision = sweeping$review_status, source = sweeping$source_id
    )
    datatable(dplyr::bind_rows(laying_view, sweeping_view), rownames = FALSE, options = list(scrollX = TRUE, pageLength = 6))
  })

  output$download_mine_review <- downloadHandler(
    filename = function() paste0("phase5_", input$mine_data_view %||% "accepted", "_review.csv"),
    content = function(file) readr::write_csv(mine_review_register(), file, na = "")
  )

  output$timeline <- renderPlotly(build_timeline_plot(filtered_map_data()$events, source = "terror_timeline"))
  output$event_detail <- renderUI(event_detail_ui(selected_event()))
  output$timeline_detail <- renderUI(event_detail_ui(selected_event()))

  visible_event_table <- reactive(event_table_data(filtered_map_data()$events))
  output$events_table <- renderDT({
    datatable(
      visible_event_table(), filter = "top", rownames = FALSE, selection = "single", extensions = "Buttons",
      options = list(pageLength = 15, scrollX = TRUE, dom = "Bfrtip", buttons = c("copy", "csv"))
    )
  })
  observeEvent(input$events_table_rows_selected, {
    row <- input$events_table_rows_selected
    dat <- visible_event_table()
    if (length(row) && row <= nrow(dat)) selected_sequence(dat$sequence[[row]])
  })
  output$routes_table <- renderDT({
    datatable(
      route_table_data(filtered_map_data()$routes, maximum_speed), filter = "top", rownames = FALSE,
      extensions = "Buttons", options = list(pageLength = 15, scrollX = TRUE, dom = "Bfrtip", buttons = c("copy", "csv"))
    ) |>
      formatStyle("speed_review", target = "row", backgroundColor = styleEqual(TRUE, "#FFF0D1"))
  })

  output$sources_table <- renderDT(datatable(inventory, filter = "top", rownames = FALSE, options = list(scrollX = TRUE, pageLength = 8)))
  output$phase5_sources_table <- renderDT({
    sources <- mine_candidates$minefield_sources |>
      dplyr::select(
        source_id, source_title, source_type, author_or_agency,
        repository, page_or_map_sheet, primary_or_derivative,
        reliability, review_status, source_url
      )
    datatable(sources, filter = "top", rownames = FALSE, options = list(scrollX = TRUE, pageLength = 6))
  })
  output$phase5_source_integrity_table <- renderDT({
    datatable(phase5_source_inventory, rownames = FALSE, options = list(scrollX = TRUE, pageLength = 5))
  })
  output$conflicts_table <- renderDT({
    ids <- c(filtered_map_data()$event_ids, filtered_map_data()$route_ids)
    visible <- conflicts[as.character(conflicts$record_id) %in% ids, ]
    datatable(visible, filter = "top", rownames = FALSE, options = list(scrollX = TRUE, pageLength = 10))
  })
  output$methods_text <- renderText(paste(readLines(project_path("outputs", "reports", "methods.md"), warn = FALSE, encoding = "UTF-8"), collapse = "\n"))

  output$stat_events <- renderText(nrow(filtered_map_data()$events))
  output$stat_routes <- renderText(nrow(filtered_map_data()$routes))
  output$stat_distance <- renderText(sprintf(
    "%s NM", format(round(sum(filtered_map_data()$routes$great_circle_nm, na.rm = TRUE)), big.mark = ",")
  ))
  output$stat_combat <- renderText({
    dat <- filtered_map_data()$events
    sum(grepl(
      "combat|attack|kamikaze|damage|iwo jima|okinawa", paste(dat$event_category, dat$event_action), ignore.case = TRUE
    ), na.rm = TRUE)
  })
  output$stat_port_days <- renderText({
    dat <- filtered_map_data()$events
    port <- grepl(
      "port|repair|shipyard|dry dock|overhaul", paste(dat$event_category, dat$event_action, dat$movement_state), ignore.case = TRUE
    )
    unique_interval_days(dat$date_start[port], dat$date_end[port])
  })
}

shinyApp(ui, server)
