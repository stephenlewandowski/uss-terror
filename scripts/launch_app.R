args <- commandArgs(trailingOnly = FALSE)
script_path <- normalizePath(sub("^--file=", "", args[grepl("^--file=", args)][1]), winslash = "/", mustWork = TRUE)
project <- normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE)
setwd(project)
Sys.setenv(USS_TERROR_PROJECT = project)
if (!requireNamespace("shiny", quietly = TRUE)) stop("Shiny is not installed in the project library. Run Rscript scripts/setup.R.", call. = FALSE)
if (!file.exists(file.path(project, "qgis", "uss_terror_layers.gpkg")) &&
    !file.exists(file.path(project, "data", "processed", "uss_terror_map_layers.gpkg"))) {
  stop("Processed data missing. Run Rscript scripts/build_all.R first.", call. = FALSE)
}
legacy_port <- Sys.getenv("USS_TERROR_PORT", unset = "3838")
port <- as.integer(Sys.getenv("USS_TERROR_SHINY_PORT", unset = legacy_port))
if (is.na(port) || port < 1L || port > 65535L) stop("USS_TERROR_SHINY_PORT must be a valid TCP port.", call. = FALSE)
launch_browser <- tolower(Sys.getenv("USS_TERROR_LAUNCH_BROWSER", unset = "true")) %in% c("1", "true", "yes")
message("Launching USS Terror map at http://127.0.0.1:", port)
shiny::runApp(project, host = "127.0.0.1", port = port, launch.browser = launch_browser)
