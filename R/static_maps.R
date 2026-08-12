pacific_robinson_crs <- function() {
  sf::st_crs("+proj=robin +lon_0=0 +datum=WGS84 +units=m +no_defs")
}

project_pacific_centered <- function(x) {
  rotated <- sf::st_transform(x, "+proj=longlat +datum=WGS84 +pm=180 +no_defs")
  rotated <- suppressWarnings(sf::st_set_crs(rotated, sf::st_crs(4326)))
  wrapped <- suppressWarnings(sf::st_wrap_dateline(
    rotated, options = c("WRAPDATELINE=YES", "DATELINEOFFSET=10"), quiet = TRUE
  ))
  sf::st_transform(wrapped, pacific_robinson_crs())
}

base_static_map <- function(land, routes, events, title, subtitle, xlim = c(-180, 180), ylim = c(-65, 70),
                            uncertainty = NULL, show_confidence = FALSE, regional = FALSE,
                            pacific_centered = FALSE) {
  routes <- routes |>
    dplyr::mutate(
      route_display = dplyr::case_when(
        !.data$include_default_map ~ "Disputed/excluded",
        tolower(.data$route_confidence) != "high" ~ "Estimated/lower confidence",
        TRUE ~ "Included reconstruction"
      ),
      route_color_key = if (show_confidence) tolower(.data$route_confidence) else .data$route_display
    )
  events_plot <- events |>
    dplyr::filter(.data$longitude >= min(xlim), .data$longitude <= max(xlim),
                  .data$latitude >= min(ylim), .data$latitude <= max(ylim)) |>
    dplyr::mutate(
      event_display = dplyr::case_when(
        grepl("combat|attack|kamikaze|damage|iwo jima|okinawa", .data$event_category, ignore.case = TRUE) ~ "Combat and damage",
        grepl("mine", .data$event_category, ignore.case = TRUE) ~ "Mine warfare",
        grepl("repair|dry dock|overhaul|alteration", .data$event_category, ignore.case = TRUE) ~ "Repair and shipyard",
        grepl("typhoon|weather", .data$event_category, ignore.case = TRUE) ~ "Typhoon and weather",
        grepl("logistic|port|transport|passenger|medical|casualty", .data$event_category, ignore.case = TRUE) ~ "Logistics and transport",
        grepl("postwar|occupation", .data$event_category, ignore.case = TRUE) ~ "Postwar and occupation",
        TRUE ~ "Transit and other"
      )
    )
  plot_xlim <- xlim
  target_crs <- sf::st_crs(4326)
  if (pacific_centered) {
    land <- project_pacific_centered(land)
    routes <- project_pacific_centered(routes)
    events_plot <- project_pacific_centered(events_plot)
    if (!is.null(uncertainty) && nrow(uncertainty)) uncertainty <- project_pacific_centered(uncertainty)
    target_crs <- pacific_robinson_crs()
    plot_xlim <- NULL
  }
  label_events <- events_plot |>
    dplyr::filter(tolower(.data$historical_confidence) == "high" | grepl("Combat|Damage|Weather|Repair", .data$event_category, ignore.case = TRUE)) |>
    dplyr::distinct(.data$location_name, .keep_all = TRUE) |>
    dplyr::slice_head(n = 18)
  labels <- dplyr::bind_cols(
    as.data.frame(sf::st_coordinates(label_events)),
    sf::st_drop_geometry(label_events)["location_name"]
  )
  route_colors <- c(
    "Included reconstruction" = "#173B57", "Estimated/lower confidence" = "#B26A2E",
    "Disputed/excluded" = "#777777", "high" = "#1B7837", "medium-high" = "#5AAE61",
    "medium" = "#D8B365", "low" = "#B2182B"
  )
  event_fills <- c(
    "Combat and damage" = "#D7301F", "Mine warfare" = "#6A51A3",
    "Repair and shipyard" = "#2C7FB8", "Typhoon and weather" = "#D95F0E",
    "Logistics and transport" = "#238B45", "Postwar and occupation" = "#B8860B",
    "Transit and other" = "#737373"
  )
  p <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = land, fill = "#E8E3D8", color = "#A9A59B", linewidth = 0.2) +
    {if (!is.null(uncertainty) && nrow(uncertainty)) ggplot2::geom_sf(data = uncertainty, fill = "#756BB1", color = "#54278F", alpha = 0.12, linewidth = 0.25)} +
    ggplot2::geom_sf(data = routes, ggplot2::aes(linetype = .data$route_display, color = .data$route_color_key), linewidth = 0.75, alpha = 0.85, key_glyph = "path") +
    ggplot2::geom_sf(data = events_plot, ggplot2::aes(shape = .data$historical_confidence, fill = .data$event_display), size = 2.6, color = "#1F1F1F", stroke = 0.4, key_glyph = "point") +
    ggrepel::geom_text_repel(data = labels, ggplot2::aes(x = .data$X, y = .data$Y, label = .data$location_name), size = 2.7, min.segment.length = 0, seed = 5, max.overlaps = 30) +
    ggplot2::scale_linetype_manual(values = c("Included reconstruction" = "solid", "Estimated/lower confidence" = "longdash", "Disputed/excluded" = "dotted")) +
    ggplot2::scale_color_manual(values = route_colors) +
    ggplot2::scale_fill_manual(values = event_fills) +
    ggplot2::scale_shape_manual(values = c("high" = 21, "medium" = 22, "low" = 24), na.value = 4) +
    {if (pacific_centered) ggplot2::coord_sf(crs = target_crs, expand = FALSE) else ggplot2::coord_sf(xlim = plot_xlim, ylim = ylim, expand = FALSE, default_crs = sf::st_crs(4326))} +
    ggplot2::labs(
      title = title, subtitle = subtitle,
      caption = "Routes and positions are reconstructed from historical records. Island, harbor, anchorage, and offshore coordinates may be modeled reference points rather than exact ship positions.",
      linetype = "Route evidence", color = if (show_confidence) "Route confidence" else "Route evidence",
      shape = "Historical confidence", fill = "Event class (visual summary)"
    ) +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::guides(
      fill = ggplot2::guide_legend(override.aes = list(shape = 21, size = 3.2, color = "#1F1F1F", linetype = 0)),
      shape = ggplot2::guide_legend(override.aes = list(fill = "white", color = "#1F1F1F", linetype = 0)),
      linetype = ggplot2::guide_legend(override.aes = list(shape = NA, fill = NA))
    ) +
    ggplot2::theme(
      panel.background = ggplot2::element_rect(fill = "#F4F8FA", color = NA),
      panel.grid.major = ggplot2::element_line(color = "#DCE5E8", linewidth = 0.25),
      legend.position = "bottom", legend.box = "vertical", legend.key.width = grid::unit(1.3, "cm"),
      plot.title = ggplot2::element_text(face = "bold", size = 16),
      plot.caption = ggplot2::element_text(hjust = 0, color = "#4A4A4A")
    )
  if (regional) {
    p <- p + ggspatial::annotation_north_arrow(location = "tr", which_north = "true",
      style = ggspatial::north_arrow_minimal(text_size = 7))
    if (diff(range(xlim)) <= 20 && diff(range(ylim)) <= 15) {
      p <- p + ggspatial::annotation_scale(location = "bl", width_hint = 0.22)
    }
  }
  p
}

generate_static_maps <- function(events_sf, routes_sf, uncertainty_sf, land_sf,
                                 output_dir = project_path("outputs", "static_maps")) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  subset_period <- function(start, end) {
    e <- events_sf[event_overlaps(events_sf$date_start, events_sf$date_end, start, end), ]
    r <- routes_sf[routes_sf$start_date <= as.Date(end) & routes_sf$end_date >= as.Date(start), ]
    u <- uncertainty_sf[event_overlaps(uncertainty_sf$date_start, uncertainty_sf$date_end, start, end), ]
    list(events = e, routes = r, uncertainty = u)
  }
  specs <- list(
    list(file = "01_full_pacific_deployment", start = "1943-10-02", end = "1946-12-25", title = "USS Terror (CM-5): Full Pacific Deployment", sub = "2 October 1943 – 25 December 1946 · Pacific-centered Robinson projection", x = c(-180, 180), y = c(-65, 75), reg = FALSE, pac = TRUE, pdf = TRUE),
    list(file = "02_global_pacific_centered", start = "1943-10-02", end = "1946-12-25", title = "USS Terror (CM-5): Global Context, Pacific Centered", sub = "Asia at left; the Americas at right · Robinson projection centered on 180°", x = c(-180, 180), y = c(-85, 85), reg = FALSE, pac = TRUE, pdf = TRUE),
    list(file = "03_1943_1944_support_operations", start = "1943-10-02", end = "1944-12-31", title = "Support Operations and Pacific Advance", sub = "1943–1944 · Pacific-centered Robinson projection", x = c(-180, 180), y = c(-65, 75), reg = FALSE, pac = TRUE, pdf = FALSE),
    list(file = "04_iwo_jima_okinawa_1945", start = "1945-02-01", end = "1945-06-30", title = "Iwo Jima and Okinawa Operations", sub = "February–June 1945", x = c(120, 150), y = c(10, 35), reg = TRUE, pac = FALSE, pdf = FALSE),
    list(file = "05_kamikaze_withdrawal_repair_1945", start = "1945-05-01", end = "1945-12-31", title = "Kamikaze Damage, Withdrawal, and Repair", sub = "May–December 1945 · Pacific-centered Robinson projection", x = c(-180, 180), y = c(-65, 75), reg = FALSE, pac = TRUE, pdf = FALSE),
    list(file = "06_postwar_occupation_1945_1946", start = "1945-08-15", end = "1946-12-25", title = "Postwar Occupation and Return", sub = "August 1945–December 1946 · Pacific-centered Robinson projection", x = c(-180, 180), y = c(-65, 75), reg = FALSE, pac = TRUE, pdf = FALSE)
  )
  paths <- character()
  for (s in specs) {
    dat <- subset_period(s$start, s$end)
    p <- base_static_map(land_sf, dat$routes, dat$events, s$title, s$sub, s$x, s$y, regional = s$reg, pacific_centered = s$pac)
    png_path <- file.path(output_dir, paste0(s$file, ".png"))
    ggplot2::ggsave(png_path, p, width = 14, height = 8.5, dpi = 300, bg = "white")
    paths <- c(paths, png_path)
    if (isTRUE(s$pdf)) {
      pdf_path <- file.path(output_dir, paste0(s$file, ".pdf"))
      ggplot2::ggsave(pdf_path, p, width = 14, height = 8.5, device = grDevices::cairo_pdf, bg = "white")
      paths <- c(paths, pdf_path)
    }
  }
  p7 <- base_static_map(land_sf, routes_sf, events_sf, "Confidence and Geographic Uncertainty",
                        "USS Terror (CM-5), 1943–1946 · Pacific-centered Robinson projection",
                        c(-180, 180), c(-65, 75), uncertainty_sf, TRUE, FALSE, TRUE)
  path7 <- file.path(output_dir, "07_confidence_and_uncertainty.png")
  ggplot2::ggsave(path7, p7, width = 14, height = 8.5, dpi = 300, bg = "white")
  c(paths, path7)
}
