library(testthat)
project <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
Sys.setenv(USS_TERROR_PROJECT = project)
test_dir(file.path(project, "tests", "testthat"), reporter = "summary")
