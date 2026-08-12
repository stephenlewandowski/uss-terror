test_that("Phase 5.2 review helpers preserve decision separation", {
  candidates <- load_mine_candidates()
  counts <- mine_review_counts(candidates)

  expect_equal(unname(counts[c("accepted", "rejected", "unresolved")]), c(10, 1, 0))

  accepted <- filter_mine_candidates(candidates, "accepted")
  rejected <- filter_mine_candidates(candidates, "rejected")
  expect_equal(nrow(candidate_review_register(accepted)), 10L)
  expect_equal(nrow(candidate_review_register(rejected)), 1L)
  expect_equal(rejected$vessel_operation_links$vessel_id, "V-USN-CM5-TERROR")
  expect_equal(nrow(rejected$minefields), 0L)
})

test_that("candidate point and uncertainty geometry are reproducible", {
  candidates <- filter_mine_candidates(load_mine_candidates(), "accepted")
  coordinates <- extract_candidate_coordinates(candidates$minefields$position_basis)
  expect_equal(coordinates$latitude, 26.158333, tolerance = 1e-7)
  expect_equal(coordinates$longitude, 127.508333, tolerance = 1e-7)

  points <- candidate_points_sf(candidates$minefields)
  envelope <- candidate_uncertainty_sf(candidates)
  expect_s3_class(points, "sf")
  expect_s3_class(envelope, "sf")
  expect_equal(nrow(points), 1L)
  expect_equal(nrow(envelope), 1L)
  expect_true(all(sf::st_is_valid(envelope)))
  expect_equal(unname(candidate_layer_choices(candidates)), c("minefields", "sweeping", "uncertainty"))
  empty <- lapply(candidates, function(x) x[0, , drop = FALSE])
  expect_length(candidate_layer_choices(empty), 0L)
})

test_that("Shiny candidate review mode exposes curated views and compact metrics", {
  app_text <- paste(readLines(project_path("app.R"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  expect_match(app_text, '"mine_data_view"')
  expect_match(app_text, '"mine_review_table"')
  expect_match(app_text, '"mine_review_detail"')
  expect_match(app_text, 'downloadHandler')
  expect_match(app_text, 'phase5_sources_table')
  expect_match(app_text, 'nav_menu\\(\n    "Deployment Records"')
  expect_match(app_text, 'nav_menu\\(\n    "Research"')
  expect_match(app_text, 'selected = "accepted", selectize = FALSE', fixed = TRUE)
  expect_match(app_text, 'selected_layers <- if (identical(view, "accepted")) unname(choices)', fixed = TRUE)
  expect_match(app_text, 'Accepted candidate evidence is shown by default', fixed = TRUE)
  expect_match(app_text, '"Candidate review summary"', fixed = TRUE)
  expect_match(app_text, '"Mine-warfare candidate sources"', fixed = TRUE)
  expect_match(app_text, '"Mine-warfare archived-source integrity"', fixed = TRUE)
  expect_false(grepl('"Phase 5.2 candidate review mode"', app_text, fixed = TRUE))
  expect_false(grepl('card_header("Phase ', app_text, fixed = TRUE))

  register_position <- regexpr('card_header("Candidate decision register")', app_text, fixed = TRUE)[[1]]
  vessels_position <- regexpr('card_header("Vessels and participation decisions")', app_text, fixed = TRUE)[[1]]
  map_position <- regexpr('card_header("Historical mine-warfare evidence map")', app_text, fixed = TRUE)[[1]]
  expect_true(register_position < map_position)
  expect_true(vessels_position < map_position)

  expect_false(grepl('title = "Visible review items"', app_text, fixed = TRUE))
  expect_false(grepl('title = "High-confidence events"', app_text, fixed = TRUE))
  expect_false(grepl('title = "Estimated/review events"', app_text, fixed = TRUE))
  expect_equal(lengths(regmatches(app_text, gregexpr("value_box\\(", app_text)))[[1]], 5L)
})
