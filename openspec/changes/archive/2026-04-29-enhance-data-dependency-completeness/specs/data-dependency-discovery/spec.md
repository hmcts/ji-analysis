## ADDED Requirements

### Requirement: Closed Status Vocabulary

The skill SHALL use a closed set of exactly five strings for the `Status` cell of every per-dependency `Attribute / Detail` table and of every row in `system-enumeration.md`. The five permitted values are `Implemented (automated)`, `Manual copy`, `Manual entry (no upstream system)`, `Stated NFR; not implemented`, `No integration (by design)`. No other strings, capitalisations or paraphrases are permitted.

`Manual entry (no upstream system)` and `No integration (by design)` MAY appear in `system-enumeration.md` to record systems that are explicitly *not* dependencies; they MUST NOT appear in the per-section `Attribute / Detail` tables of the rendered catalogue (because those rows describe systems that *are* dependencies).

#### Scenario: A new dependency is added with a permitted status

- **WHEN** the model authors a new inbound entry for a system whose data is regularly transcribed from an upstream system into the target system
- **THEN** the `Status` row of that entry's `Attribute / Detail` table reads exactly `Manual copy`

#### Scenario: A non-conforming status string is rejected by Phase 2d

- **WHEN** the model is about to author the catalogue and the draft contains a `Status` value of `Manual entry by RSU` (a paraphrase, not a permitted value)
- **THEN** the Phase 2d cross-check fails the "every catalogue entry's `Status` value is exactly one of the five permitted strings" check, and authoring does not proceed until the value is corrected to `Manual copy` (or another permitted value)

#### Scenario: Excluded statuses do not appear in the catalogue

- **WHEN** a system is recorded in `system-enumeration.md` with status `Manual entry (no upstream system)` or `No integration (by design)`
- **THEN** that system does NOT appear as a numbered detail entry in `data-dependencies.md`, but DOES appear in `system-enumeration.md` with a one-line justification

### Requirement: Manual-Copy Dependencies Must Be Catalogued

The skill SHALL treat any human-mediated transfer of data from a named upstream system into the target system as a first-class inbound dependency, even when the source documents describe the integration as "no integration", "manual", or "out-of-band". The named upstream system is the dependency; the lack of automation is captured by the `Manual copy` status, not by the absence of an entry.

A "named upstream system" means a specific external system, application, database, register or service identified by name in the source documents — not an internal screen, internal user role, or internal data store of the target system itself.

#### Scenario: Manual transcription from a named upstream system is catalogued as Manual copy

- **WHEN** the source documents state "RSU users copy judge profile data from eLinks into JI"
- **THEN** the catalogue contains an inbound entry for `eLinks` with `Status` = `Manual copy`, `Mechanism` describing the human transcription path, and a citation pointing at the relevant section

#### Scenario: First-capture data entry without an upstream system is excluded

- **WHEN** the source documents state "Working patterns are entered into JI by court staff" and there is no named upstream system the data originates from
- **THEN** the catalogue does NOT contain a "Court Staff" entry, and `system-enumeration.md` records "Court Staff" as `Manual entry (no upstream system)` with the justification that court staff are internal users, not an external system

#### Scenario: An NFR-stated but not built integration is still catalogued

- **WHEN** the source documents state "NFR-3: the system shall integrate with eLinks. (Not implemented in v1.)"
- **THEN** the catalogue contains an inbound entry for `eLinks` with `Status` = `Stated NFR; not implemented`

### Requirement: Phase 2a Produces a System Enumeration Artefact

Before any catalogue markdown is authored, the skill SHALL write `<input-folder>/output/system-enumeration.md` containing one row per canonical external system found in the source documents. Each row records the canonical name, all known aliases, classification (Inbound / Outbound / Platform / Internal user — ruled out / Out of scope — ruled out), the closed-vocabulary `Status` value, and a citation to the source document and section.

The enumeration MUST include every system named in the source documents, including those that are subsequently ruled out — ruling out a system is recorded explicitly with a one-line justification, never by omitting the row.

Authoring the catalogue (Phase 3) SHALL be gated on this file existing and being non-empty.

#### Scenario: Enumeration lists every named system before classification

- **WHEN** the source documents mention five external systems (eLinks, L!BERATA, JFEPS, Outlook, Court Staff Portal) across various sections
- **THEN** `system-enumeration.md` contains five rows, one per canonical name, regardless of how many ultimately appear in the catalogue

#### Scenario: A system is ruled out with an on-record justification

- **WHEN** the source documents mention "Outlook" only as the email client used by users
- **THEN** `system-enumeration.md` contains an "Outlook" row classified as ruled out, with a one-line justification "Outlook is the user mail client; no JI data flows through it as a system integration"

#### Scenario: Authoring is blocked without the enumeration

- **WHEN** Phase 3 begins and `<input-folder>/output/system-enumeration.md` does not exist
- **THEN** the skill halts and reports the missing artefact instead of producing `data-dependencies.md`

### Requirement: Phase 2a Produces a Pinned Alias Map

Before classification, the skill SHALL write `<input-folder>/output/system-aliases.json` with two top-level keys: `canonical_to_aliases` (mapping each canonical name to an array of its aliases) and `aliases_to_canonical` (the inverse map, where every alias resolves back to its canonical name). Aliases identified in the source documents MUST round-trip: every alias listed under `canonical_to_aliases` MUST appear as a key in `aliases_to_canonical` mapping back to the same canonical name.

The catalogue and the system enumeration SHALL use only canonical names (per the alias map) as the primary system identifier; aliases appear only in dedicated "Aliases" cells / columns.

#### Scenario: An alias is collapsed into its canonical name

- **WHEN** the source documents refer to the same system as both "eLinks" and "Judicial Database (JD)"
- **THEN** `system-aliases.json` contains `"canonical_to_aliases": { "eLinks": ["Judicial Database", "JD"] }` and the catalogue has a single `eLinks` entry whose `Source system` cell reads "eLinks (also known as Judicial Database / JD)"

#### Scenario: The alias map round-trips

- **WHEN** `system-aliases.json` lists `"L!BERATA": ["JFEPS", "JFEBS"]` under `canonical_to_aliases`
- **THEN** `aliases_to_canonical` contains both `"JFEPS": "L!BERATA"` and `"JFEBS": "L!BERATA"`

### Requirement: Manual-Flow Keyword Scan

The skill SHALL ship a deterministic shell script `scripts/find-manual-flows.sh` that, when invoked with the input folder, scans every `.txt` file under `<input-folder>/output/extracted-text/` for a fixed list of canonical manual-flow phrases and writes `<input-folder>/output/manual-flow-candidates.txt` listing every match with its source file, line number and the matching line.

The phrase list SHALL include at minimum: "copies from", "copy and paste", "copy/paste", "manually enter", "manually entered", "manually copied", "rekey", "re-keys", "rekeyed", "transcribe", "transcribed", "look up in", "looks up in", "look up from", "is entered by", "data is entered", "obtained from", "populated from", "populated by", "sourced from", "no integration", "no automated integration", "out-of-band". The phrase list lives at the top of the script and is the single source of truth.

The script SHALL run without invoking any model, without network access, and without any tool not already required by the existing pipeline (POSIX shell + grep are sufficient).

#### Scenario: A manual-copy phrase produces a candidate line

- **WHEN** the extracted text contains `JI Functional Requirements.txt` line 142: "RSU users copy judge profile data from eLinks into JI."
- **THEN** `manual-flow-candidates.txt` contains a line of the form `JI Functional Requirements.txt:142: RSU users copy judge profile data from eLinks into JI.`

#### Scenario: Re-running the scan produces identical output

- **WHEN** the script is invoked twice with the same input folder and unchanged extracted text
- **THEN** the two `manual-flow-candidates.txt` outputs are byte-identical

#### Scenario: Phase 2d reconciles every candidate

- **WHEN** `manual-flow-candidates.txt` contains 14 candidate lines
- **THEN** `phase-2d-checks.md` records, for each of the 14 lines, either (a) the inbound catalogue entry that addresses it, or (b) a one-line dismissal justification

### Requirement: Phase 2d Cross-Check Artefact

Before authoring the catalogue, the skill SHALL write `<input-folder>/output/phase-2d-checks.md` containing the closed Phase 2d checklist. Each item MUST be marked with either ✅ (with a one-line justification or pointer) or ❌ (with the action taken to resolve it). The checklist items are fixed across runs:

1. Every system in `system-enumeration.md` is either in the catalogue with a per-section entry, or marked "ruled out" with a one-line justification.
2. Every line in `manual-flow-candidates.txt` is accounted for: either the upstream system is an inbound entry with `Status` = `Manual copy`, or the line is dismissed with a one-line justification.
3. Every outbound flow has a corresponding inbound entry for its reconciliation / status return leg, or the source documents explicitly state there is no return flow.
4. No catalogue entry is an internal user role (court staff, RSU, judges).
5. Aliases from `system-aliases.json` are collapsed: no system appears under two different names in the catalogue.
6. Every catalogue entry's `Status` value is exactly one of the five permitted strings.
7. Every catalogue entry has a `> Sources:` blockquote pointing at a real section / requirement ID in the source documents.

Authoring (Phase 3) SHALL NOT proceed until every item is ✅.

#### Scenario: All checks pass and authoring proceeds

- **WHEN** every item in `phase-2d-checks.md` is marked ✅ with a one-line pointer or justification
- **THEN** Phase 3 proceeds and produces `data-dependencies.md`

#### Scenario: A failed check blocks authoring

- **WHEN** check 2 in `phase-2d-checks.md` is marked ❌ because three lines in `manual-flow-candidates.txt` have not been reconciled
- **THEN** Phase 3 does not proceed until the three lines are either added to the catalogue or dismissed in writing

#### Scenario: The checklist items are stable across runs

- **WHEN** the skill runs against the same source documents on two different occasions
- **THEN** `phase-2d-checks.md` contains the same seven check items in the same order, regardless of how their pass/fail outcomes resolved on either run

### Requirement: Per-Run Artefacts Live Alongside the Input Data

Every artefact produced by the skill — including the four new ones introduced by this change (`system-enumeration.md`, `system-aliases.json`, `manual-flow-candidates.txt`, `phase-2d-checks.md`) — SHALL be written under `<input-folder>/output/`. The skill SHALL NOT write to the repository running the skill, to system temp directories (`/tmp`, `/var/folders/`), or to any path outside `<input-folder>/output/` for per-run data.

#### Scenario: A skill run leaves no trace in the running repository

- **WHEN** the skill is invoked against an input folder outside the running repository
- **THEN** no file inside the running repository is created, modified or deleted as a side effect; every per-run artefact lives under `<input-folder>/output/`

#### Scenario: All four new artefacts land in the output folder

- **WHEN** the skill completes Phase 2d
- **THEN** `<input-folder>/output/` contains `extracted-text/`, `system-enumeration.md`, `system-aliases.json`, `manual-flow-candidates.txt` and `phase-2d-checks.md` (in addition to any catalogue files produced by Phases 3–4)

### Requirement: Same Inputs Produce the Same Catalogue

Given the same set of source documents and the same skill version, the skill SHALL produce a `data-dependencies.md` file with the same number of inbound, outbound and platform entries, the same set of canonical system names, the same `Status` values, and the same alias collapsing across re-runs. Only narrative phrasing within lead paragraphs MAY vary; the structural content (At a Glance table rows; Attribute / Detail rows; the seven Phase 2d checks; the system enumeration rows) MUST be stable.

#### Scenario: A repeat run produces the same dependency count

- **WHEN** the skill runs twice against the same input folder, separated in time, and the source documents are unchanged
- **THEN** the two `data-dependencies.md` outputs have the same number of rows in the At a Glance table, the same canonical system names in those rows, and the same `Status` values per row

#### Scenario: Variance is caught by the Phase 2d cross-check

- **WHEN** a re-run would otherwise drop a manual-copy dependency present in the previous run because the model misclassified "no integration" as "no dependency"
- **THEN** check 2 in `phase-2d-checks.md` flags the unreconciled `manual-flow-candidates.txt` line and the entry is added back, restoring parity with the previous run
