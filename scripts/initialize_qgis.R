args <- commandArgs(trailingOnly = FALSE)
script_path <- normalizePath(sub("^--file=", "", args[grepl("^--file=", args)][1]), winslash = "/", mustWork = TRUE)
project <- normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE)
setwd(project)
Sys.setenv(USS_TERROR_PROJECT = project)
source("R/helpers.R")
source("R/qgis_exports.R")
tools <- detect_gis_tools()
if (!length(tools)) {
  message("QGIS/GDAL executables were not detected. No software was installed and no untested .qgz was created.")
  quit(status = 0L)
}
cat(paste(tools, collapse = "\n"), "\n")
message("Use qgis/initialize_qgis_project.py inside QGIS, then visually validate the resulting project before treating it as complete.")
