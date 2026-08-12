required_source_files <- function() c(
  "uss_terror_pacific_timeline_1943_1946.xlsx",
  "uss_terror_timeline_1943_1946.csv",
  "uss_terror_route_legs_1943_1946.csv",
  "uss_terror_timeline_and_route_1943_1946.geojson"
)

source_file_count <- function(path) {
  ext <- tolower(tools::file_ext(path))
  tryCatch({
    if (ext == "csv") return(nrow(readr::read_csv(path, show_col_types = FALSE, progress = FALSE)))
    if (ext %in% c("geojson", "json", "gpkg")) return(nrow(sf::st_read(path, quiet = TRUE)))
    if (ext %in% c("xlsx", "xls")) {
      sheets <- readxl::excel_sheets(path)
      return(sum(vapply(sheets, function(s) suppressMessages(nrow(readxl::read_excel(path, sheet = s))), numeric(1))))
    }
    NA_real_
  }, error = function(e) NA_real_)
}

create_source_inventory <- function(raw_dir = project_path("data", "raw")) {
  files <- list.files(raw_dir, full.names = TRUE, recursive = FALSE)
  info <- file.info(files)
  counts <- vapply(files, source_file_count, numeric(1))
  extensions <- tolower(tools::file_ext(files))
  readable <- file.access(files, 4) == 0
  parsed <- is.finite(counts)
  read_status <- dplyr::case_when(
    !readable ~ "unreadable",
    parsed ~ "read",
    extensions == "pdf" ~ "inventoried_not_parsed",
    TRUE ~ "readable_not_parsed"
  )
  notes <- ifelse(
    extensions == "pdf",
    "Auxiliary historical source; inventoried but not parsed as a canonical table. Original upstream location was not established; this is the pre-existing project copy.",
    "Original upstream location was not established; this is the pre-existing project copy."
  )
  tibble::tibble(
    filename = basename(files),
    original_path = normalizePath(files, winslash = "/", mustWork = FALSE),
    project_relative_path = file.path("data", "raw", basename(files)),
    file_type = toupper(tools::file_ext(files)),
    file_size_bytes = as.numeric(info$size),
    modified_date = format(info$mtime, "%Y-%m-%d %H:%M:%S %z"),
    sha256 = vapply(files, digest::digest, character(1), algo = "sha256", file = TRUE),
    read_status = read_status,
    row_or_feature_count = counts,
    notes = notes
  )
}

write_missing_input_report <- function(missing) {
  path <- project_path("outputs", "reports", "missing_inputs.md")
  lines <- c(
    "# Missing input report", "",
    paste("Generated:", format(Sys.time(), tz = "UTC", usetz = TRUE)), "",
    "The build did not invent replacement historical records.", "",
    "Missing required inputs:", "",
    paste0("- `", missing, "`")
  )
  writeLines(lines, path, useBytes = TRUE)
  path
}

check_required_sources <- function(raw_dir = project_path("data", "raw")) {
  required <- required_source_files()
  missing <- required[!file.exists(file.path(raw_dir, required))]
  if (length(missing)) {
    report <- write_missing_input_report(missing)
    stop("Required source data missing. See ", report, ": ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

load_source_data <- function(raw_dir = project_path("data", "raw")) {
  check_required_sources(raw_dir)
  timeline_path <- file.path(raw_dir, "uss_terror_timeline_1943_1946.csv")
  routes_path <- file.path(raw_dir, "uss_terror_route_legs_1943_1946.csv")
  geojson_path <- file.path(raw_dir, "uss_terror_timeline_and_route_1943_1946.geojson")
  xlsx_path <- file.path(raw_dir, "uss_terror_pacific_timeline_1943_1946.xlsx")
  list(
    events_raw = readr::read_csv(timeline_path, show_col_types = FALSE, na = c("", "NA")),
    routes_raw = readr::read_csv(routes_path, show_col_types = FALSE, na = c("", "NA")),
    geojson_raw = sf::st_read(geojson_path, quiet = TRUE, stringsAsFactors = FALSE),
    workbook_sheets = readxl::excel_sheets(xlsx_path),
    paths = list(timeline = timeline_path, routes = routes_path, geojson = geojson_path, workbook = xlsx_path)
  )
}
