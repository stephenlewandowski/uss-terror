`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

project_root <- function() {
  root <- Sys.getenv("USS_TERROR_PROJECT", unset = getwd())
  normalizePath(root, winslash = "/", mustWork = FALSE)
}

project_path <- function(...) {
  path <- normalizePath(file.path(project_root(), ...), winslash = "/", mustWork = FALSE)
  root <- project_root()
  inside <- tolower(path) == tolower(root) |
    startsWith(tolower(path), paste0(tolower(root), "/"))
  if (any(!inside)) stop("Refusing to access a path outside the project: ", paste(path[!inside], collapse = ", "), call. = FALSE)
  path
}

qgis_exchange_path <- function(must_work = FALSE) {
  candidates <- project_path("qgis", c("uss_terror_layers_phase4.gpkg", "uss_terror_layers.gpkg"))
  hit <- candidates[file.exists(candidates)][1]
  if ((!length(hit) || is.na(hit)) && isTRUE(must_work)) stop("No QGIS exchange GeoPackage exists.", call. = FALSE)
  hit
}

load_settings <- function(path = project_path("config", "settings.yml")) {
  settings <- yaml::read_yaml(path)
  if (!is.null(settings$project)) {
    settings$project_title <- settings$project$title %||% settings$project_title
    settings$crs <- settings$project$crs %||% settings$crs
  }
  if (!is.null(settings$display)) {
    for (name in names(settings$display)) settings[[name]] <- settings$display[[name]]
  }
  if (!is.null(settings$processing)) {
    for (name in names(settings$processing)) settings[[name]] <- settings$processing[[name]]
  }
  settings$project_root <- project_root()
  settings
}

setting_value <- function(settings, path, default = NULL) {
  value <- settings
  for (name in path) {
    if (is.null(value) || is.null(value[[name]])) return(default)
    value <- value[[name]]
  }
  value %||% default
}

parse_flag <- function(x) {
  y <- tolower(trimws(as.character(x)))
  out <- rep(NA, length(y))
  out[y %in% c("true", "t", "1", "yes", "y")] <- TRUE
  out[y %in% c("false", "f", "0", "no", "n")] <- FALSE
  out
}

parse_date_safely <- function(x) {
  suppressWarnings(as.Date(trimws(as.character(x)), format = "%Y-%m-%d"))
}

event_overlaps <- function(date_start, date_end, filter_start, filter_end) {
  start <- as.Date(date_start)
  end <- as.Date(date_end)
  end[is.na(end)] <- start[is.na(end)]
  !is.na(start) & start <= as.Date(filter_end) & end >= as.Date(filter_start)
}

na_if_blank <- function(x) {
  y <- trimws(as.character(x))
  y[y == ""] <- NA_character_
  y
}

write_csv_project <- function(x, ...) {
  path <- project_path(...)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(x, path, na = "")
  invisible(path)
}

uncertainty_polygon <- function(lon, lat, radius_nm, crs = 4326, vertices = 120L) {
  if (any(!is.finite(c(lon, lat, radius_nm))) || radius_nm <= 0) return(NULL)
  bearings <- seq(0, 360, length.out = vertices + 1L)
  coords <- geosphere::destPoint(c(lon, lat), b = bearings, d = radius_nm * 1852)
  coords[, 1] <- ((coords[, 1] + 180) %% 360) - 180
  sf::st_polygon(list(coords))
}

build_uncertainty_areas <- function(events, crs = 4326) {
  keep <- is.finite(events$longitude) & is.finite(events$latitude) &
    is.finite(events$position_uncertainty_nm) & events$position_uncertainty_nm > 0
  selected <- events[keep, , drop = FALSE]
  if (!nrow(selected)) {
    return(sf::st_sf(selected, geometry = sf::st_sfc(crs = crs)))
  }
  geom <- lapply(seq_len(nrow(selected)), function(i) {
    uncertainty_polygon(selected$longitude[i], selected$latitude[i],
                        selected$position_uncertainty_nm[i], crs = crs)
  })
  out <- sf::st_sf(selected, geometry = sf::st_sfc(geom, crs = crs))
  out$uncertainty_method <- "geodesic circle (radius in nautical miles)"
  out
}

format_event_date <- function(start, end, precision = NA_character_) {
  start <- as.Date(start)
  end <- as.Date(end)
  label <- ifelse(is.na(end) | start == end, as.character(start), paste(start, end, sep = " to "))
  ifelse(tolower(precision %||% "") %in% c("estimated", "approximate", "range"),
         paste0(label, " (", precision, ")"), label)
}

safe_sum <- function(x) sum(x, na.rm = TRUE)

unique_interval_days <- function(date_start, date_end) {
  start <- as.Date(date_start)
  end <- as.Date(date_end)
  keep <- !is.na(start) & !is.na(end) & end >= start
  if (!any(keep)) return(0L)
  intervals <- data.frame(start = start[keep], end = end[keep])
  intervals <- intervals[order(intervals$start, intervals$end), , drop = FALSE]
  merged <- list()
  current_start <- intervals$start[[1]]
  current_end <- intervals$end[[1]]
  if (nrow(intervals) > 1L) for (i in 2:nrow(intervals)) {
    if (intervals$start[[i]] <= current_end + 1) {
      current_end <- max(current_end, intervals$end[[i]])
    } else {
      merged[[length(merged) + 1L]] <- c(current_start, current_end)
      current_start <- intervals$start[[i]]
      current_end <- intervals$end[[i]]
    }
  }
  merged[[length(merged) + 1L]] <- c(current_start, current_end)
  as.integer(sum(vapply(merged, function(x) as.numeric(x[[2]] - x[[1]]) + 1, numeric(1))))
}

html_value <- function(x, missing = "Not recorded") {
  if (length(x) == 0L || is.na(x) || identical(trimws(as.character(x)), "")) missing else htmltools::htmlEscape(as.character(x))
}
