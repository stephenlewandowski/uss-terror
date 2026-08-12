project <- normalizePath(file.path(dirname(commandArgs(trailingOnly = FALSE)[grepl("^--file=", commandArgs(trailingOnly = FALSE))][1] |> sub("^--file=", "", x = _)), ".."), winslash = "/", mustWork = TRUE)
setwd(project)
Sys.setenv(USS_TERROR_PROJECT = project)

cran <- getOption("repos")[["CRAN"]]
if (is.null(cran) || identical(cran, "@CRAN@")) cran <- "https://cloud.r-project.org"
options(repos = c(CRAN = cran))

bootstrap_library <- file.path(project, "renv", "bootstrap-library")
dir.create(bootstrap_library, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(bootstrap_library, .libPaths()))
if (!requireNamespace("renv", quietly = TRUE)) {
  message("Installing renv into a project-local bootstrap library...")
  install.packages("renv", lib = bootstrap_library, repos = cran)
}

renv::consent(provided = TRUE)
if (!file.exists(file.path(project, "renv", "activate.R"))) {
  renv::init(project = project, bare = TRUE, restart = FALSE)
} else {
  renv::activate(project = project)
}

packages <- c(
  "shiny", "sf", "leaflet", "dplyr", "readr", "readxl", "lubridate", "plotly", "DT",
  "geosphere", "ggplot2", "ggrepel", "ggspatial", "rnaturalearth", "rnaturalearthdata",
  "htmltools", "bslib", "jsonlite", "testthat", "renv", "yaml", "digest", "tibble",
  "terra", "units"
)
message("Installing/restoring project packages into renv...")
renv::install(packages = packages, project = project)
renv::snapshot(project = project, type = "explicit", prompt = FALSE)
message("Project environment is ready. Lockfile: ", file.path(project, "renv.lock"))
