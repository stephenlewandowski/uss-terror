gebco_settings <- function(settings = load_settings()) {
  setting_value(settings, c("nautical_layers", "gebco"), list(enabled = FALSE))
}

extract_wms_layer_names <- function(capabilities_text) {
  text <- paste(as.character(capabilities_text), collapse = "\n")
  hits <- gregexpr("<Name>[^<]+</Name>", text, perl = TRUE)
  values <- regmatches(text, hits)[[1]]
  if (!length(values) || identical(values, character(0))) return(character())
  unique(gsub("</?Name>", "", values))
}

validate_gebco_capabilities <- function(capabilities_text, configured_layer = "GEBCO_LATEST") {
  layers <- extract_wms_layer_names(capabilities_text)
  list(
    layer_names = layers,
    configured_layer = configured_layer,
    layer_found = configured_layer %in% layers,
    valid_wms = length(layers) > 0L && grepl("WMS_Capabilities|WMT_MS_Capabilities", capabilities_text)
  )
}

probe_gebco <- function(settings = load_settings(), request_fun) {
  config <- gebco_settings(settings)
  if (!isTRUE(config$enabled)) {
    return(external_service_result("GEBCO", FALSE, message = "Disabled in configuration."))
  }
  response <- tryCatch(request_fun(config$capabilities_url), error = function(e) list(status = 0L, content_type = "", body = "", error = conditionMessage(e)))
  check <- validate_gebco_capabilities(response$body %||% "", config$layer_name %||% "")
  available <- as.integer(response$status %||% 0L) == 200L && isTRUE(check$valid_wms) && isTRUE(check$layer_found)
  external_service_result(
    "GEBCO", available, response$status %||% 0L, response$content_type %||% "",
    response$error %||% if (available) paste("Capabilities contain layer", config$layer_name) else "Capabilities unavailable or configured layer absent."
  )
}

gebco_warning <- function() {
  paste(
    "GEBCO bathymetry is modern compiled terrain information provided for geographic context.",
    "It is not a reconstruction of wartime charts, seabed knowledge, navigation aids, or operational conditions."
  )
}
