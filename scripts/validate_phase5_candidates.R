args <- commandArgs(trailingOnly = FALSE)
script_path <- normalizePath(sub("^--file=", "", args[grepl("^--file=", args)][1]), winslash = "/", mustWork = TRUE)
project <- normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE)
setwd(project)
Sys.setenv(USS_TERROR_PROJECT = project)

source(file.path(project, "R", "helpers.R"))
source(file.path(project, "R", "mine_sources.R"))
source(file.path(project, "R", "minefield_models.R"))
source(file.path(project, "R", "minefield_validation.R"))

review_dir <- file.path(project, "data", "mine_warfare", "review")
report_dir <- file.path(project, "outputs", "reports")
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)

candidates <- load_mine_candidates(review_dir)
issues <- validate_mine_candidates(candidates, require_decisions = TRUE)

canonical <- load_mine_database(file.path(project, "data", "processed", "pacific_mine_warfare.gpkg"))
canonical_counts <- vapply(canonical, nrow, integer(1))
if (any(canonical_counts != 0L)) {
  issues <- dplyr::bind_rows(issues, tibble::tibble(
    severity = "error", check = "canonical_isolation", table = names(canonical_counts)[canonical_counts != 0L],
    record_id = "", message = paste0("Canonical table contains ", canonical_counts[canonical_counts != 0L], " row(s).")
  ))
}

expected_hash <- "F0A0433AD56CA4578F33C67D850CBCC8AFBA301590C6E9A0B80AACE7635C4FE6"
archived_sources <- candidates$minefield_sources |>
  dplyr::filter(!is.na(.data$file_path) & nzchar(.data$file_path)) |>
  dplyr::group_by(.data$file_path) |>
  dplyr::summarise(source_ids = paste(.data$source_id, collapse = ";"), .groups = "drop") |>
  dplyr::mutate(
    absolute_path = file.path(project, .data$file_path),
    exists = file.exists(.data$absolute_path),
    byte_size = ifelse(.data$exists, file.info(.data$absolute_path)$size, NA_real_),
    sha256 = ifelse(.data$exists, toupper(vapply(.data$absolute_path, digest::digest, character(1), algo = "sha256", serialize = FALSE, file = TRUE)), NA_character_),
    expected_sha256 = expected_hash,
    integrity_status = ifelse(.data$exists & .data$sha256 == .data$expected_sha256, "verified", "failed")
  )
readr::write_csv(archived_sources, file.path(report_dir, "phase5_source_inventory.csv"), na = "")
if (any(archived_sources$integrity_status != "verified")) {
  failed <- archived_sources$file_path[archived_sources$integrity_status != "verified"]
  issues <- dplyr::bind_rows(issues, tibble::tibble(
    severity = "error", check = "source_file_integrity", table = "minefield_sources",
    record_id = archived_sources$source_ids[archived_sources$integrity_status != "verified"],
    message = paste("Missing or hash-mismatched archived source:", failed)
  ))
}

issue_path <- file.path(report_dir, "phase5_candidate_validation.csv")
readr::write_csv(issues, issue_path, na = "")

mapping <- mine_candidate_files()
counts <- vapply(unname(mapping), function(table_name) nrow(candidates[[table_name]]), integer(1))
names(counts) <- names(mapping)
all_statuses <- unlist(lapply(candidates, function(x) x$review_status), use.names = FALSE)
decision_counts <- table(factor(all_statuses, levels = c("accepted", "rejected")))
has_errors <- any(issues$severity == "error")
has_warnings <- any(issues$severity == "warning")
status <- if (has_errors) {
  "BLOCKED"
} else if (has_warnings) {
  "REVIEW DECISIONS RECORDED WITH WARNINGS"
} else {
  "REVIEW RESOLVED — CANDIDATE DECISIONS RECORDED"
}

lines <- c(
  "# Phase 5 candidate batch — Kerama Retto", "",
  paste("Generated:", format(Sys.time(), tz = "UTC", usetz = TRUE)), "",
  paste0("**Status: ", status, "**"), "",
  "The bounded Kerama Retto evidence review is complete. Accepted and rejected decisions remain in the candidate-review files only; no row has been copied into any canonical table.", "",
  "## Batch inventory and decisions", "",
  sprintf("- `%s`: %d record(s)", paste0(names(counts), ".csv"), counts),
  paste0("- Accepted candidate decisions: ", unname(decision_counts[["accepted"]])),
  paste0("- Rejected candidate decisions: ", unname(decision_counts[["rejected"]])),
  "- Canonical mine-warfare tables: 11; canonical records: 0", "",
  "## Evidence added", "",
  "- Archived *The U.S.S. Halligan (DD-584) in World War II: Documents and Photographs*, which reproduces wartime deck-log and action-report pages.",
  paste0("- Verified archived PDF SHA-256: `", expected_hash, "`."),
  "- USS LSM(R)-194 deck-log transcription, compiled PDF page 105: Halligan hit a mine at 1840 on 26 March near approximately 26°10'N, 127°30'E while patrol craft were firing on mines in Area B-5.",
  "- USS PC-584 Action Report Serial 0063, compiled PDF pages 113-119: PC-584 was assigned to mine destruction; its report places Halligan near 26°09'N, 127°31'E, describes the probable mine line and later nearby mines, and states that Terror had already retired when PC-584 was ordered to join her.", "",
  "## Candidate decisions", "",
  "- **Accepted — minefield locality:** `MF-JPN-KERAMA-1945-CAND-01` is now the Area B-5 mine line/locality near the Halligan loss, not a broad Kerama aggregate and not a surveyed boundary.",
  "- **Accepted — operation:** `SWP-ICEBERG-KERAMA-19450326-CAND-01` records directly documented mine-destruction activity on 26 March. No unsupported same-day mine count or clearance claim was added.",
  "- **Accepted — USS Terror:** `V-USN-CM5-TERROR` is accepted for identity and area-level minecraft flagship/tender service.",
  "- **Accepted — USS PC-584:** `V-USN-PC584` is accepted as the directly documented mine-destruction control vessel.",
  "- **Rejected — Terror event link:** `LNK-TERROR-KERAMA-SWEEP-CAND-01` is retained as a rejected audit record because the primary report does not establish Terror's role in this exact event.",
  "- **Accepted — PC-584 event link:** `LNK-PC584-KERAMA-SWEEP-CAND-01` directly links PC-584 to the operation.",
  "- **Accepted — sources:** both NHHC histories and both reproduced primary records have page-level locators; the local PDF is hash-verified.",
  "- **Accepted — uncertainty:** `UNC-KERAMA-1945-CAND-01` uses a 2 NM radius around 26.158333°N, 127.508333°E. The source positions are about 1.34 NM apart; 2 NM conservatively covers their conflict, whole-minute rounding, and Halligan's movement before PC-584 came alongside.", "",
  "## Review-warning resolutions", "",
  "- `contextual_participation`: resolved by rejecting Terror's event-level link and adding the direct PC-584 link.",
  "- `geometry_unresolved`: resolved as an approximate event-locality point. No polygonal minefield boundary is claimed.",
  "- `numeric_uncertainty_unresolved`: resolved with the documented 2 NM evidence envelope.", "",
  "## Validation findings", ""
)
if (!nrow(issues)) {
  lines <- c(lines, "No validation errors or warnings remain.")
} else {
  lines <- c(lines, sprintf("- **%s — %s** `%s` `%s`: %s", toupper(issues$severity), issues$check, issues$table, issues$record_id, issues$message))
}
lines <- c(
  lines, "", "## Residual evidence limits", "",
  "- The accepted point represents a documented mined locality and casualty/mine-destruction evidence, not the complete boundary of a named Japanese minefield.",
  "- Exact laying date, laying unit, mine model, full field count, and field limits remain unknown and are left null.",
  "- The primary reproductions are sufficient for these candidate decisions, but future archival work should retrieve the original National Archives deck-log sheet and complete Mine Squadron Four report before canonical promotion.",
  "- Sweeping and mine destruction do not establish that Area B-5 or Kerama Retto was completely cleared. No safe or cleared status is recorded.", "",
  "## Sources", "",
  "- [Halligan (DD-584), DANFS](https://www.history.navy.mil/research/histories/ship-histories/danfs/h/halligan.html)",
  "- [Terror III (CM-5), DANFS](https://www.history.navy.mil/research/histories/ship-histories/danfs/t/terror-iii.html)",
  "- [Wilde, *The U.S.S. Halligan (DD-584) in World War II*](https://destroyerhistory.org/assets/pdf/wilde/584halligan_wilde.pdf)", "",
  "Historical reconstruction only. Not current hazard information and not for navigation, route planning, diving, fishing, salvage, or ordnance-clearance decisions."
)

report_path <- file.path(report_dir, "phase5_kerama_candidate_review.md")
writeLines(lines, report_path, useBytes = TRUE)

if (has_errors) stop("Phase 5 candidate validation failed; see ", report_path, call. = FALSE)
message("Phase 5 candidate review decisions are resolved: ", report_path)
