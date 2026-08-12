mine_review_states <- function() {
  c(
    "unreviewed", "needs_source_check", "needs_date_check", "needs_vessel_check",
    "needs_geometry_check", "conflicted", "accepted", "rejected"
  )
}

mine_date_precisions <- function() {
  c("day", "month", "year", "range", "circa", "inferred", "unknown")
}

mine_source_types <- function() {
  c(
    "war_diary", "deck_log", "action_report", "minefield_summary",
    "mine_warfare_history", "hydrographic_chart", "operational_map",
    "aerial_mining_report", "submarine_patrol_report", "minesweeping_report",
    "postwar_clearance_report", "technical_mission_report", "veteran_history",
    "secondary_history", "catalog_record"
  )
}

mine_source_schema <- function() {
  c(
    source_id = "character", source_title = "character", source_type = "character",
    author_or_agency = "character", publication_date = "date", repository = "character",
    catalog_identifier = "character", file_path = "character", source_url = "character",
    page_or_map_sheet = "character", access_date = "date", primary_or_derivative = "character",
    reliability = "character", review_status = "character", notes = "character"
  )
}

mine_source_warning <- function() {
  paste(
    "Every accepted historical fact, geometry, vessel relationship, and operation date requires a source and locator.",
    "Candidate records remain outside the canonical database until review status is accepted."
  )
}
