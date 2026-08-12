openseamap_settings <- function(settings = load_settings()) {
  setting_value(settings, c("nautical_layers", "openseamap"), list(enabled = FALSE))
}

external_service_result <- function(service, available, status = NA_integer_,
                                    content_type = NA_character_, message = "") {
  tibble::tibble(
    service = as.character(service), available = isTRUE(available),
    http_status = as.integer(status), content_type = as.character(content_type),
    message = as.character(message)
  )
}

probe_openseamap <- function(settings = load_settings(), request_fun) {
  config <- openseamap_settings(settings)
  if (!isTRUE(config$enabled)) {
    return(external_service_result("OpenSeaMap", FALSE, message = "Disabled in configuration."))
  }
  test_url <- gsub("\\{z\\}", "0", config$tile_url)
  test_url <- gsub("\\{x\\}", "0", test_url)
  test_url <- gsub("\\{y\\}", "0", test_url)
  response <- tryCatch(request_fun(test_url), error = function(e) list(status = 0L, content_type = "", body = raw(), error = conditionMessage(e)))
  status <- as.integer(response$status %||% 0L)
  content_type <- as.character(response$content_type %||% "")
  available <- status == 200L && grepl("image/png", content_type, ignore.case = TRUE)
  external_service_result(
    "OpenSeaMap", available, status, content_type,
    response$error %||% if (available) "Tile response validated." else "Tile response unavailable or not PNG."
  )
}

offline_reference_status <- function(settings = load_settings(), offline = FALSE) {
  if (isTRUE(offline)) {
    return(tibble::tibble(
      service = c("OpenStreetMap", "OpenSeaMap", "GEBCO", "GMRT"),
      enabled_for_session = FALSE,
      message = "Offline mode: local Natural Earth land, neutral ocean, route, events, and local tables remain available."
    ))
  }
  tibble::tibble(
    service = c("OpenStreetMap", "OpenSeaMap", "GEBCO", "GMRT"),
    enabled_for_session = c(
      isTRUE(setting_value(settings, c("display", "allow_online_basemaps"), FALSE)),
      isTRUE(setting_value(settings, c("nautical_layers", "openseamap", "enabled"), FALSE)),
      isTRUE(setting_value(settings, c("nautical_layers", "gebco", "enabled"), FALSE)),
      isTRUE(setting_value(settings, c("gmrt", "enabled"), FALSE))
    ),
    message = "Optional modern context; a failure must not remove or reset historical layers."
  )
}

openseamap_warning <- function() {
  paste(
    "OpenSeaMap shows modern seamarks and nautical features.",
    "It does not represent navigation aids, political geography, hydrographic knowledge, or operational conditions during 1943–1946",
    "and is not an official navigation chart."
  )
}
