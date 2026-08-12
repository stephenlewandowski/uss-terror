args <- commandArgs(trailingOnly = FALSE)
script_path <- normalizePath(sub("^--file=", "", args[grepl("^--file=", args)][1]), winslash = "/", mustWork = TRUE)
project <- normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE)
setwd(project)
Sys.setenv(USS_TERROR_PROJECT = project)
source("R/helpers.R")
source("R/gmrt_services.R")
source("R/gmrt_download.R")

cli <- commandArgs(trailingOnly = TRUE)
region_arg <- grep("^--region=", cli, value = TRUE)
confirmed <- "--confirm" %in% cli
settings <- load_settings()
if (!length(region_arg)) {
  print(gmrt_cache_inventory(settings)[, c("region_id", "region_label", "raw_cached", "processed_cached", "display_cached")])
  message("No download requested. To request one reviewed region, use --region=<id> --confirm.")
  quit(status = 0L)
}
region_id <- sub("^--region=", "", region_arg[[1]])
if (!confirmed) stop("Refusing GMRT download without --confirm. Review region bounds and metadata first.", call. = FALSE)

request_fun <- function(request_url) {
  connection <- base::url(request_url, open = "rb")
  on.exit(close(connection), add = TRUE)
  body <- rawToChar(readBin(connection, what = "raw", n = 1024^2))
  list(status = 200L, content_type = "application/json", body = body)
}
cache_gmrt_region(region_id, confirm = TRUE, settings = settings, metadata_request_fun = request_fun)
message("GMRT region cached and processed: ", region_id)
