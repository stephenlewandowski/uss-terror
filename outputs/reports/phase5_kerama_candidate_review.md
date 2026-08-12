# Phase 5 candidate batch — Kerama Retto

Generated: 2026-08-10 00:35:30 UTC

**Status: REVIEW RESOLVED — CANDIDATE DECISIONS RECORDED**

The bounded Kerama Retto evidence review is complete. Accepted and rejected decisions remain in the candidate-review files only; no row has been copied into any canonical table.

## Batch inventory and decisions

- `candidate_minefields.csv`: 1 record(s)
- `candidate_laying_events.csv`: 0 record(s)
- `candidate_sweeping_events.csv`: 1 record(s)
- `candidate_vessels.csv`: 2 record(s)
- `candidate_vessel_links.csv`: 2 record(s)
- `candidate_sources.csv`: 4 record(s)
- `candidate_uncertainty.csv`: 1 record(s)
- Accepted candidate decisions: 10
- Rejected candidate decisions: 1
- Canonical mine-warfare tables: 11; canonical records: 0

## Evidence added

- Archived *The U.S.S. Halligan (DD-584) in World War II: Documents and Photographs*, which reproduces wartime deck-log and action-report pages.
- Verified archived PDF SHA-256: `F0A0433AD56CA4578F33C67D850CBCC8AFBA301590C6E9A0B80AACE7635C4FE6`.
- USS LSM(R)-194 deck-log transcription, compiled PDF page 105: Halligan hit a mine at 1840 on 26 March near approximately 26°10'N, 127°30'E while patrol craft were firing on mines in Area B-5.
- USS PC-584 Action Report Serial 0063, compiled PDF pages 113-119: PC-584 was assigned to mine destruction; its report places Halligan near 26°09'N, 127°31'E, describes the probable mine line and later nearby mines, and states that Terror had already retired when PC-584 was ordered to join her.

## Candidate decisions

- **Accepted — minefield locality:** `MF-JPN-KERAMA-1945-CAND-01` is now the Area B-5 mine line/locality near the Halligan loss, not a broad Kerama aggregate and not a surveyed boundary.
- **Accepted — operation:** `SWP-ICEBERG-KERAMA-19450326-CAND-01` records directly documented mine-destruction activity on 26 March. No unsupported same-day mine count or clearance claim was added.
- **Accepted — USS Terror:** `V-USN-CM5-TERROR` is accepted for identity and area-level minecraft flagship/tender service.
- **Accepted — USS PC-584:** `V-USN-PC584` is accepted as the directly documented mine-destruction control vessel.
- **Rejected — Terror event link:** `LNK-TERROR-KERAMA-SWEEP-CAND-01` is retained as a rejected audit record because the primary report does not establish Terror's role in this exact event.
- **Accepted — PC-584 event link:** `LNK-PC584-KERAMA-SWEEP-CAND-01` directly links PC-584 to the operation.
- **Accepted — sources:** both NHHC histories and both reproduced primary records have page-level locators; the local PDF is hash-verified.
- **Accepted — uncertainty:** `UNC-KERAMA-1945-CAND-01` uses a 2 NM radius around 26.158333°N, 127.508333°E. The source positions are about 1.34 NM apart; 2 NM conservatively covers their conflict, whole-minute rounding, and Halligan's movement before PC-584 came alongside.

## Review-warning resolutions

- `contextual_participation`: resolved by rejecting Terror's event-level link and adding the direct PC-584 link.
- `geometry_unresolved`: resolved as an approximate event-locality point. No polygonal minefield boundary is claimed.
- `numeric_uncertainty_unresolved`: resolved with the documented 2 NM evidence envelope.

## Validation findings

No validation errors or warnings remain.

## Residual evidence limits

- The accepted point represents a documented mined locality and casualty/mine-destruction evidence, not the complete boundary of a named Japanese minefield.
- Exact laying date, laying unit, mine model, full field count, and field limits remain unknown and are left null.
- The primary reproductions are sufficient for these candidate decisions, but future archival work should retrieve the original National Archives deck-log sheet and complete Mine Squadron Four report before canonical promotion.
- Sweeping and mine destruction do not establish that Area B-5 or Kerama Retto was completely cleared. No safe or cleared status is recorded.

## Sources

- [Halligan (DD-584), DANFS](https://www.history.navy.mil/research/histories/ship-histories/danfs/h/halligan.html)
- [Terror III (CM-5), DANFS](https://www.history.navy.mil/research/histories/ship-histories/danfs/t/terror-iii.html)
- [Wilde, *The U.S.S. Halligan (DD-584) in World War II*](https://destroyerhistory.org/assets/pdf/wilde/584halligan_wilde.pdf)

Historical reconstruction only. Not current hazard information and not for navigation, route planning, diving, fishing, salvage, or ordnance-clearance decisions.
