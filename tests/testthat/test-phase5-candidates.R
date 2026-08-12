test_that("Phase 5 Kerama review decisions are resolved and internally valid", {
  candidates <- load_mine_candidates()
  issues <- validate_mine_candidates(candidates, require_decisions = TRUE)

  expect_equal(nrow(issues), 0L, info = paste(issues$message, collapse = "\n"))
  expect_equal(nrow(candidates$minefields), 1L)
  expect_equal(nrow(candidates$mine_sweeping_events), 1L)
  expect_equal(nrow(candidates$vessels), 2L)
  expect_equal(nrow(candidates$vessel_operation_links), 2L)
  expect_equal(nrow(candidates$minefield_sources), 4L)
  expect_equal(nrow(candidates$minefield_uncertainty), 1L)
  expect_equal(nrow(candidates$mine_laying_events), 0L)

  decisions <- unlist(lapply(candidates, function(x) x$review_status), use.names = FALSE)
  expect_true(all(decisions %in% c("accepted", "rejected")))
  terror_link <- candidates$vessel_operation_links[candidates$vessel_operation_links$vessel_id == "V-USN-CM5-TERROR", ]
  pc584_link <- candidates$vessel_operation_links[candidates$vessel_operation_links$vessel_id == "V-USN-PC584", ]
  expect_equal(terror_link$review_status, "rejected")
  expect_equal(pc584_link$review_status, "accepted")
  expect_equal(pc584_link$participation_status, "direct")
  expect_equal(candidates$minefield_uncertainty$position_uncertainty_nm, 2)
  expect_equal(candidates$minefields$geometry_type, "POINT")
  expect_match(candidates$minefields$position_basis, "26.158333 N, 127.508333 E", fixed = TRUE)
})

test_that("archived Phase 5 primary-source reproduction is present and hash-stable", {
  path <- project_path("data", "mine_warfare", "source_documents", "halligan_dd584_wilde_action_reports.pdf")
  expect_true(file.exists(path))
  expect_equal(
    toupper(digest::digest(path, algo = "sha256", serialize = FALSE, file = TRUE)),
    "F0A0433AD56CA4578F33C67D850CBCC8AFBA301590C6E9A0B80AACE7635C4FE6"
  )
})

test_that("Phase 5 candidates do not populate canonical mine tables", {
  canonical <- load_mine_database()
  expect_true(all(vapply(canonical, nrow, integer(1)) == 0L))
  expect_false(any(vapply(canonical, function(x) any(grepl("KERAMA-1945-CAND", unlist(sf::st_drop_geometry(x)), fixed = TRUE)), logical(1))))
})

test_that("empty canonical rebuild does not overwrite populated candidate files", {
  review_dir <- tempfile("mine-review-")
  export_dir <- tempfile("mine-export-")
  gpkg <- tempfile(fileext = ".gpkg")
  dir.create(review_dir, recursive = TRUE)
  candidate_path <- file.path(review_dir, "candidate_minefields.csv")
  writeLines(c("minefield_id", "SENTINEL-CANDIDATE"), candidate_path)
  before <- readLines(candidate_path, warn = FALSE)

  write_empty_mine_database(gpkg = gpkg, export_dir = export_dir, review_dir = review_dir)

  expect_identical(readLines(candidate_path, warn = FALSE), before)
  expect_true(all(file.exists(file.path(review_dir, paste0(names(mine_candidate_files()), ".csv")))))
})
