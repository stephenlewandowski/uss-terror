mine_primary_ids <- function() {
  c(
    minefields = "minefield_id", minefield_boundaries = "boundary_id",
    mine_laying_events = "laying_event_id", mine_sweeping_events = "sweeping_event_id",
    minefield_status_events = "status_event_id", vessels = "vessel_id", units = "unit_id",
    vessel_operation_links = "link_id", minefield_sources = "source_id",
    minefield_source_maps = "source_map_id", minefield_uncertainty = "uncertainty_id"
  )
}

mine_clearance_flags <- function(minefields, sweeping_events) {
  fields <- sf::st_drop_geometry(minefields)
  sweeps <- sf::st_drop_geometry(sweeping_events)
  flags <- tibble::tibble(
    severity = character(), record_type = character(), record_id = character(),
    issue_type = character(), message = character()
  )
  if (nrow(fields)) {
    claimed <- !is.na(fields$date_declared_cleared) | fields$historical_status == "reported_cleared"
    missing_source <- claimed & (is.na(fields$source_id) | fields$source_id == "")
    if (any(missing_source, na.rm = TRUE)) {
      flags <- dplyr::bind_rows(flags, tibble::tibble(
        severity = "warning", record_type = "minefield",
        record_id = fields$minefield_id[missing_source], issue_type = "clearance_claim_missing_source",
        message = "Clearance claim requires supporting source evidence; sweeping alone is not proof of full clearance."
      ))
    }
  }
  if (nrow(sweeps)) {
    unsafe_result <- !is.na(sweeps$date_declared_safe) & !sweeps$result %in% c("clearance_claimed", "verification_only", "completed")
    if (any(unsafe_result, na.rm = TRUE)) {
      flags <- dplyr::bind_rows(flags, tibble::tibble(
        severity = "warning", record_type = "mine_sweeping_event",
        record_id = sweeps$sweeping_event_id[unsafe_result], issue_type = "clearance_date_result_conflict",
        message = "A declared-safe date conflicts with the recorded sweep result and requires review."
      ))
    }
  }
  flags
}

validate_mine_schema <- function(tables, settings = load_settings()) {
  expected <- minefield_schema()
  issues <- tibble::tibble(severity = character(), check = character(), table = character(), message = character())
  add <- function(severity, check, table, message) {
    issues <<- dplyr::bind_rows(issues, tibble::tibble(
      severity = severity, check = check, table = table, message = message
    ))
  }
  compatible_type <- function(column, type) {
    switch(type,
      character = is.character(column), integer = is.integer(column),
      numeric = is.numeric(column), logical = is.logical(column) || is.integer(column),
      date = inherits(column, "Date") || inherits(column, "POSIXt"), FALSE
    )
  }
  valid_fk <- function(table_name, field, target_table, target_field, allow_null = TRUE) {
    if (!all(c(table_name, target_table) %in% names(tables)) || !field %in% names(tables[[table_name]])) return()
    values <- sf::st_drop_geometry(tables[[table_name]])[[field]]
    present <- !is.na(values) & nzchar(as.character(values))
    targets <- sf::st_drop_geometry(tables[[target_table]])[[target_field]]
    if (any(present & !values %in% targets)) {
      add("error", "foreign_key", table_name, paste0(field, " contains a value absent from ", target_table, ".", if (allow_null) " Null remains permitted." else ""))
    }
  }
  for (name in names(expected)) {
    if (!name %in% names(tables)) {
      add("error", "required_table", name, "Required table is missing.")
      next
    }
    missing <- setdiff(names(expected[[name]]), names(tables[[name]]))
    if (length(missing)) add("error", "required_fields", name, paste("Missing:", paste(missing, collapse = ", ")))
    common <- intersect(names(expected[[name]]), names(tables[[name]]))
    bad_types <- common[!vapply(common, function(field) compatible_type(tables[[name]][[field]], expected[[name]][[field]]), logical(1))]
    if (length(bad_types)) add("error", "qgis_compatible_types", name, paste("Incompatible field types:", paste(bad_types, collapse = ", ")))
    id <- mine_primary_ids()[[name]]
    values <- tables[[name]][[id]]
    values <- values[!is.na(values) & nzchar(values)]
    if (anyDuplicated(values)) add("error", "primary_id_unique", name, "Primary IDs are duplicated.")
  }

  for (table_name in c("minefield_boundaries", "mine_laying_events", "mine_sweeping_events",
                       "minefield_status_events", "vessel_operation_links", "minefield_uncertainty")) {
    valid_fk(table_name, "minefield_id", "minefields", "minefield_id")
  }
  for (table_name in c("mine_laying_events", "mine_sweeping_events")) {
    valid_fk(table_name, "primary_vessel_id", "vessels", "vessel_id")
  }
  valid_fk("vessel_operation_links", "vessel_id", "vessels", "vessel_id")
  valid_fk("minefield_status_events", "responsible_vessel_id", "vessels", "vessel_id")
  valid_fk("mine_laying_events", "laying_unit_id", "units", "unit_id")
  valid_fk("mine_sweeping_events", "sweeping_unit_id", "units", "unit_id")
  valid_fk("minefield_status_events", "responsible_unit_id", "units", "unit_id")
  for (table_name in setdiff(names(expected), "minefield_sources")) {
    valid_fk(table_name, "source_id", "minefield_sources", "source_id")
  }
  valid_fk("minefield_source_maps", "source_id", "minefield_sources", "source_id")

  all_fields <- unique(unlist(lapply(expected, names)))
  if (!any(grepl("date.*precision|date_precision", all_fields))) add("error", "date_precision", "schema", "Date precision fields are missing.")
  if (!all(c("source_id", "source_locator", "review_status") %in% all_fields)) add("error", "provenance_review", "schema", "Source or review fields are missing.")
  if (!isFALSE(setting_value(settings, c("mine_warfare", "default_visible"), TRUE))) add("error", "default_hidden", "configuration", "Mine layers must default to hidden.")
  if (!isTRUE(setting_value(settings, c("mine_warfare", "current_navigation_warning"), FALSE))) add("error", "navigation_warning", "configuration", "Current-navigation warning must be enabled.")

  if ("mine_laying_events" %in% names(tables) && nrow(tables$mine_laying_events)) {
    laying <- sf::st_drop_geometry(tables$mine_laying_events)
    if (any(is.na(laying$date_start) & is.na(laying$date_end))) add("warning", "missing_emplacement_date", "mine_laying_events", "At least one record lacks an emplacement date interval.")
    if (any(is.na(laying$primary_vessel_id) | !nzchar(laying$primary_vessel_id), na.rm = TRUE)) add("warning", "missing_vessel_identification", "mine_laying_events", "At least one primary laying vessel remains unknown; retain null until supported.")
  }
  if ("mine_sweeping_events" %in% names(tables) && nrow(tables$mine_sweeping_events)) {
    sweeping <- sf::st_drop_geometry(tables$mine_sweeping_events)
    if (any(is.na(sweeping$date_start) & is.na(sweeping$date_end))) add("warning", "missing_sweeping_date", "mine_sweeping_events", "At least one record lacks a sweeping date interval.")
    if (any(is.na(sweeping$primary_vessel_id) | !nzchar(sweeping$primary_vessel_id), na.rm = TRUE)) add("warning", "missing_vessel_identification", "mine_sweeping_events", "At least one primary sweeping vessel remains unknown; retain null until supported.")
  }
  if ("vessels" %in% names(tables) && nrow(tables$vessels)) {
    vessels <- sf::st_drop_geometry(tables$vessels)
    hull <- vessels$hull_number[!is.na(vessels$hull_number) & nzchar(vessels$hull_number)]
    if (anyDuplicated(hull)) add("warning", "hull_number_conflict", "vessels", "A hull number is assigned to multiple vessel records and requires identity review.")
  }
  if ("minefields" %in% names(tables) && nrow(tables$minefields)) {
    fields <- sf::st_drop_geometry(tables$minefields)
    if (any(fields$mine_count_emplaced > fields$mine_count_planned, na.rm = TRUE)) add("warning", "conflicting_mine_counts", "minefields", "Emplaced count exceeds planned count in at least one record.")
    if (any(fields$date_first_emplaced > fields$date_last_emplaced, na.rm = TRUE) ||
        any(fields$date_first_swept > fields$date_last_swept, na.rm = TRUE)) add("warning", "conflicting_dates", "minefields", "At least one first/last date interval is reversed.")
    if (any(fields$boundary_precision %in% c("disputed", "conflicted") | fields$review_status == "conflicted", na.rm = TRUE)) add("warning", "disputed_geometry", "minefields", "At least one geometry or review state is disputed.")
    if (any(fields$overall_confidence %in% c("low", "very low", "unknown"), na.rm = TRUE)) add("warning", "low_confidence_source", "minefields", "At least one minefield has low or unknown overall confidence.")
  }
  if ("vessel_operation_links" %in% names(tables) && nrow(tables$vessel_operation_links)) {
    links <- sf::st_drop_geometry(tables$vessel_operation_links)
    if (any(links$participation_status %in% c("inferred", "possible", "disputed"), na.rm = TRUE)) add("warning", "inferred_participation", "vessel_operation_links", "At least one vessel-operation relationship is inferred or disputed.")
  }
  clearance <- mine_clearance_flags(tables$minefields, tables$mine_sweeping_events)
  if (nrow(clearance)) {
    for (i in seq_len(nrow(clearance))) add(clearance$severity[[i]], clearance$issue_type[[i]], clearance$record_type[[i]], clearance$message[[i]])
  }
  issues
}

write_mine_validation_report <- function(tables, settings = load_settings(),
                                         path = project_path("outputs", "reports", "mine_schema_validation.md")) {
  issues <- validate_mine_schema(tables, settings)
  status <- if (any(issues$severity == "error")) "FAIL" else "PASS"
  lines <- c(
    "# Empty mine-warfare schema validation", "",
    paste("Generated:", format(Sys.time(), tz = "UTC", usetz = TRUE)), "",
    paste("**Status:**", status), "",
    paste0("- Canonical tables/layers: ", length(tables)),
    paste0("- Canonical minefield records: ", nrow(tables$minefields)),
    paste0("- Canonical vessel records: ", nrow(tables$vessels)),
    paste0("- Canonical vessel-operation links: ", nrow(tables$vessel_operation_links)),
    "- Required columns use character, integer, numeric, logical, and date types compatible with QGIS/GeoPackage.",
    "- Primary-key, foreign-key, source, date-precision, review-state, hidden-layer, and navigation-warning rules are active.",
    "- Candidate-review templates remain outside canonical exports; automated tests verify that fixtures are absent.",
    "- Schema-only mode: no externally researched mine records were added.",
    "- Unknown vessels may remain null; no identity is inferred.",
    "- Sweeping activity and clearance claims remain separate fields and events.", "",
    "## Findings", ""
  )
  if (!nrow(issues)) lines <- c(lines, "No schema validation issues were recorded.")
  if (nrow(issues)) lines <- c(lines, sprintf("- **%s — %s** `%s`: %s", toupper(issues$severity), issues$check, issues$table, issues$message))
  writeLines(lines, path, useBytes = TRUE)
  invisible(issues)
}

empty_candidate_issues <- function() {
  tibble::tibble(
    severity = character(), check = character(), table = character(),
    record_id = character(), message = character()
  )
}

read_mine_candidate_table <- function(path, schema) {
  raw <- readr::read_csv(
    path, col_types = readr::cols(.default = readr::col_character()),
    na = c("", "NA"), show_col_types = FALSE, progress = FALSE,
    trim_ws = TRUE
  )
  parse_issues <- empty_candidate_issues()
  for (field in intersect(names(schema), names(raw))) {
    original <- raw[[field]]
    present <- !is.na(original) & nzchar(original)
    converted <- switch(schema[[field]],
      character = as.character(original),
      integer = suppressWarnings(as.integer(original)),
      numeric = suppressWarnings(as.numeric(original)),
      logical = {
        normalized <- tolower(original)
        value <- rep(NA, length(original))
        value[normalized %in% c("true", "t", "1")] <- TRUE
        value[normalized %in% c("false", "f", "0")] <- FALSE
        as.logical(value)
      },
      date = suppressWarnings(as.Date(original)),
      original
    )
    invalid <- present & is.na(converted)
    if (any(invalid)) {
      parse_issues <- dplyr::bind_rows(parse_issues, tibble::tibble(
        severity = "error", check = "parse_value", table = basename(path),
        record_id = as.character(which(invalid)),
        message = paste0("Invalid ", schema[[field]], " value in ", field, ": ", original[invalid])
      ))
    }
    raw[[field]] <- converted
  }
  attr(raw, "candidate_parse_issues") <- parse_issues
  raw
}

load_mine_candidates <- function(review_dir = project_path("data", "mine_warfare", "review")) {
  mapping <- mine_candidate_files()
  schema <- minefield_schema()
  tables <- list()
  missing_files <- character()
  for (candidate in names(mapping)) {
    table_name <- unname(mapping[[candidate]])
    path <- file.path(review_dir, paste0(candidate, ".csv"))
    if (!file.exists(path)) {
      missing_files <- c(missing_files, path)
      next
    }
    tables[[table_name]] <- read_mine_candidate_table(path, schema[[table_name]])
  }
  attr(tables, "missing_files") <- missing_files
  tables
}

validate_mine_candidates <- function(candidates, require_decisions = FALSE) {
  expected <- minefield_schema()
  issues <- empty_candidate_issues()
  add <- function(severity, check, table, record_id, message) {
    issues <<- dplyr::bind_rows(issues, tibble::tibble(
      severity = severity, check = check, table = table,
      record_id = as.character(record_id), message = message
    ))
  }
  values_present <- function(x) !is.na(x) & nzchar(as.character(x))
  ids <- function(table_name, field) {
    if (!table_name %in% names(candidates) || !field %in% names(candidates[[table_name]])) character()
    else candidates[[table_name]][[field]]
  }
  validate_fk <- function(table_name, field, target_table, target_field) {
    if (!table_name %in% names(candidates) || !field %in% names(candidates[[table_name]])) return()
    values <- candidates[[table_name]][[field]]
    present <- values_present(values)
    target_values <- ids(target_table, target_field)
    bad <- present & !values %in% target_values
    if (any(bad)) {
      record_field <- mine_primary_ids()[[table_name]]
      record_ids <- candidates[[table_name]][[record_field]][bad]
      for (i in seq_along(record_ids)) {
        add("error", "foreign_key", table_name, record_ids[[i]],
            paste0(field, " references a value absent from ", target_table, "."))
      }
    }
  }

  missing_files <- attr(candidates, "missing_files")
  if (length(missing_files)) {
    for (path in missing_files) add("error", "required_candidate_file", "candidate_batch", "", paste("Missing:", basename(path)))
  }

  for (table_name in names(candidates)) {
    table <- candidates[[table_name]]
    parse_issues <- attr(table, "candidate_parse_issues")
    if (!is.null(parse_issues) && nrow(parse_issues)) issues <- dplyr::bind_rows(issues, parse_issues)
    missing <- setdiff(names(expected[[table_name]]), names(table))
    extra <- setdiff(names(table), names(expected[[table_name]]))
    if (length(missing)) add("error", "required_fields", table_name, "", paste("Missing:", paste(missing, collapse = ", ")))
    if (length(extra)) add("warning", "unexpected_fields", table_name, "", paste("Unexpected:", paste(extra, collapse = ", ")))
    id_field <- mine_primary_ids()[[table_name]]
    if (!id_field %in% names(table)) next
    record_ids <- table[[id_field]]
    if (any(!values_present(record_ids))) add("error", "primary_id_required", table_name, "", "Every candidate record requires a primary ID.")
    duplicate <- duplicated(record_ids) & values_present(record_ids)
    if (any(duplicate)) add("error", "primary_id_unique", table_name, paste(record_ids[duplicate], collapse = ", "), "Candidate primary IDs are duplicated.")

    if ("review_status" %in% names(table)) {
      bad_state <- values_present(table$review_status) & !table$review_status %in% mine_review_states()
      if (any(bad_state)) add("error", "review_state", table_name, paste(record_ids[bad_state], collapse = ", "), "Unknown review status.")
      if (any(!values_present(table$review_status))) add("error", "review_state_required", table_name, "", "Every candidate requires a review status.")
      if (isTRUE(require_decisions)) {
        undecided <- !table$review_status %in% c("accepted", "rejected")
        if (any(undecided, na.rm = TRUE)) {
          add("error", "manual_decision_required", table_name,
              paste(record_ids[undecided], collapse = ", "),
              "Resolved review requires an accepted or rejected decision for every candidate record.")
        }
      }
    }

    precision_fields <- grep("(^date_precision$|^date_.*_precision$|^.*_date_precision$)", names(table), value = TRUE)
    for (field in precision_fields) {
      bad <- values_present(table[[field]]) & !table[[field]] %in% mine_date_precisions()
      if (any(bad)) add("error", "date_precision", table_name, paste(record_ids[bad], collapse = ", "), paste("Invalid", field, "value."))
    }

    if ("source_id" %in% names(table) && table_name != "minefield_sources") {
      missing_source <- !values_present(table$source_id)
      if (any(missing_source)) add("error", "source_required", table_name, paste(record_ids[missing_source], collapse = ", "), "Every candidate fact or relationship requires a source ID.")
    }
    if ("source_locator" %in% names(table)) {
      missing_locator <- !values_present(table$source_locator)
      if (any(missing_locator)) add("error", "source_locator_required", table_name, paste(record_ids[missing_locator], collapse = ", "), "Every candidate fact or relationship requires a source locator.")
    }
  }

  for (table_name in setdiff(names(candidates), "minefield_sources")) {
    validate_fk(table_name, "source_id", "minefield_sources", "source_id")
  }
  for (table_name in c("mine_laying_events", "mine_sweeping_events", "vessel_operation_links", "minefield_uncertainty")) {
    validate_fk(table_name, "minefield_id", "minefields", "minefield_id")
  }
  for (table_name in c("mine_laying_events", "mine_sweeping_events")) {
    validate_fk(table_name, "primary_vessel_id", "vessels", "vessel_id")
  }
  validate_fk("vessel_operation_links", "vessel_id", "vessels", "vessel_id")

  if ("vessel_operation_links" %in% names(candidates)) {
    links <- candidates$vessel_operation_links
    for (i in seq_len(nrow(links))) {
      target <- switch(links$operation_type[[i]],
        mine_sweeping_event = ids("mine_sweeping_events", "sweeping_event_id"),
        mine_laying_event = ids("mine_laying_events", "laying_event_id"),
        character()
      )
      if (!length(target) || !links$operation_id[[i]] %in% target) {
        add("error", "operation_foreign_key", "vessel_operation_links", links$link_id[[i]],
            "operation_id does not resolve to the candidate operation table named by operation_type.")
      }
    }
    contextual <- links$participation_status %in% c("inferred", "possible", "disputed") & links$review_status != "rejected"
    if (any(contextual, na.rm = TRUE)) {
      add("warning", "contextual_participation", "vessel_operation_links",
          paste(links$link_id[contextual], collapse = ", "),
          "The vessel-operation relationship is contextual and requires manual source review.")
    }
  }

  for (table_name in intersect(c("mine_sweeping_events", "mine_laying_events", "vessel_operation_links"), names(candidates))) {
    table <- candidates[[table_name]]
    reversed <- !is.na(table$date_start) & !is.na(table$date_end) & table$date_start > table$date_end
    if (any(reversed)) {
      id_field <- mine_primary_ids()[[table_name]]
      add("error", "date_interval", table_name, paste(table[[id_field]][reversed], collapse = ", "), "date_start is later than date_end.")
    }
  }

  if ("minefield_sources" %in% names(candidates)) {
    sources <- candidates$minefield_sources
    required <- c("source_title", "source_type", "author_or_agency", "repository", "catalog_identifier", "source_url", "page_or_map_sheet", "access_date", "primary_or_derivative", "reliability")
    for (field in required) {
      missing <- !values_present(sources[[field]])
      if (any(missing)) add("error", "source_metadata", "minefield_sources", paste(sources$source_id[missing], collapse = ", "), paste("Missing", field, "metadata."))
    }
    bad_type <- values_present(sources$source_type) & !sources$source_type %in% mine_source_types()
    if (any(bad_type)) add("error", "source_type", "minefield_sources", paste(sources$source_id[bad_type], collapse = ", "), "Unknown source type.")
  }

  if ("minefields" %in% names(candidates) && nrow(candidates$minefields)) {
    fields <- candidates$minefields
    if (any(fields$default_visible %in% TRUE, na.rm = TRUE)) add("error", "default_hidden", "minefields", paste(fields$minefield_id[fields$default_visible %in% TRUE], collapse = ", "), "Candidate minefields must remain hidden by default.")
    if (any(!fields$current_navigation_warning %in% TRUE, na.rm = TRUE)) add("error", "navigation_warning", "minefields", paste(fields$minefield_id[!fields$current_navigation_warning %in% TRUE], collapse = ", "), "Candidate minefields must retain the current-navigation warning.")
    unresolved <- fields$boundary_precision %in% c("unknown", "unresolved") | is.na(fields$position_uncertainty_nm)
    if (any(unresolved, na.rm = TRUE)) add("warning", "geometry_unresolved", "minefields", paste(fields$minefield_id[unresolved], collapse = ", "), "Boundary or numeric position uncertainty remains unresolved for manual review.")
  }
  if ("minefield_uncertainty" %in% names(candidates) && nrow(candidates$minefield_uncertainty)) {
    uncertainty <- candidates$minefield_uncertainty
    unresolved <- is.na(uncertainty$position_uncertainty_nm)
    if (any(unresolved)) add("warning", "numeric_uncertainty_unresolved", "minefield_uncertainty", paste(uncertainty$uncertainty_id[unresolved], collapse = ", "), "No defensible nautical-mile uncertainty has yet been derived from a source map.")
  }
  issues
}
