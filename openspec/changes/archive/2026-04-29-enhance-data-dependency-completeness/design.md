## Context

`create-data-dependency-architecture` is a Claude skill that turns a folder of source documents about a system (the running example is HMCTS' Judicial Itineraries / JI) into a styled PDF cataloguing the system's inbound and outbound data dependencies. The current pipeline has five phases: distil binaries → extract dependencies → author markdown → render PDF → verify. Phases 1, 3, 4, 5 are already deterministic — they are pure shell / Python scripts that produce identical output from identical input.

The drift lives in **Phase 2**, the model-driven extraction. The current Phase 2 is split into 2a (enumerate), 2b (classify), 2c (per-dependency facts), 2d (cross-check), but these sub-phases live entirely in `SKILL.md` prose. Nothing on disk forces the model to actually do them, and nothing makes the output of one sub-phase visible to the next run for comparison. Two failure modes follow:

1. **Manual-copy dependencies get dropped.** When the source documents say "no integration; user enters by hand", the model often interprets that as "no dependency". But if the user is copying *from a named upstream system* (eLinks → JI, HR system → JI sittings), that named system is genuinely an inbound dependency — a *gap* dependency the user wants surfaced, not hidden.
2. **Run-to-run variance.** The same documents on different days produce catalogues with different counts, different aliasing decisions ("eLinks" vs "Judicial Database" as one entry or two), and different `Status` strings ("Manual" vs "manual" vs "Manual entry" vs "NFR-3 stated"). The downstream PDF therefore drifts even though the source is unchanged.

The fix is to take the model-judgement-only sub-phases and **back each one with a deterministic on-disk artefact** that the next sub-phase consumes, plus a small shell script that does the keyword search no model should be relied on to do exhaustively.

## Goals / Non-Goals

**Goals:**

- A re-run of the skill against the same source documents produces the **same** dependency catalogue (same number of entries, same names, same `Status` values, same alias collapsing, same Direction labels).
- Manual-copy dependencies — i.e. *"user transcribes data from system X into our system"* — are **always** in the catalogue, with `Status` = `Manual copy` and the upstream system named.
- The discovery process leaves an **audit trail** on disk (enumeration, alias map, manual-flow candidates, Phase 2d check results) so a reviewer can see how the catalogue was assembled and so re-runs can diff against earlier runs.
- The closed `Status` vocabulary makes it impossible to invent new fuzzy values; pandoc rendering and reader expectations are stable.
- All new artefacts go under `<input-folder>/output/`, in line with the project's tooling-vs-data separation rule. Nothing accumulates in the repo running the skill.

**Non-Goals:**

- This change does **not** touch the visual style of the PDF (CSS, Mermaid theme, page setup are unchanged).
- This change does **not** add a new external dependency. No new tool on PATH; no new Python package.
- This change does **not** rewrite the build pipeline (`build-pdf.sh`, `md_to_pdf.py`). They keep working as-is.
- This change does **not** auto-generate the dependency catalogue from a script. The model still does the analysis. The script's job is narrow: surface candidate phrases the model **must** then evaluate, so the model is held to a lower-bound discovery floor rather than left to remember every prompt heuristic.
- This change does **not** introduce schemas / JSON Schema validation in this iteration. The artefacts have prescribed shapes documented in `OUTPUT-STRUCTURE.md`, but they are markdown / plain JSON; we don't add a `jsonschema` runtime dependency. (Future change can add validation if drift persists.)

## Decisions

### 1. Replace the fuzzy `Status` enum with a closed set of five strings

**Decision.** The `Status` row of every per-dependency `Attribute / Detail` table uses **exactly one** of:

| Value | Meaning |
|------|---------|
| `Implemented (automated)` | A real system-to-system integration is in production. |
| `Manual copy` | A human regularly transcribes / re-keys / copies data from a named upstream system into the target system. The upstream system is the dependency. |
| `Manual entry (no upstream system)` | A human enters data with no upstream system to point at (genuine first-capture in the target system). Not a dependency on its own — used only to *exclude* the row from the catalogue, in the enumeration artefact. |
| `Stated NFR; not implemented` | The source documents specify an integration as an NFR but it has not been built. |
| `No integration (by design)` | The source documents explicitly state the systems do not exchange data. Used in the enumeration artefact to record a *ruled-out* system. |

**Rationale.** The current enum is a comma-separated suggestion in prose, with examples like "Manual" and "NFR-N stated; not implemented" appearing as if illustrative. That leaves room for wording variance. A closed set with exactly these five strings (matched verbatim) eliminates lexical drift, lets the cross-check step grep for invalid values, and gives the reader a stable mental model.

**Alternatives considered.**

- *Keep the current enum but document each value better.* Rejected — without a syntactic constraint the model still rephrases things ("Manual entry by RSU" instead of "Manual copy"). The cross-check needs a fixed vocabulary to be auditable.
- *Three values (`Implemented` / `Manual` / `Not implemented`).* Rejected — collapses the manual-copy-with-upstream case (which IS a dependency) into the no-upstream case (which is NOT a dependency). That's exactly the discrepancy the user reported.

### 2. Make Phase 2a produce an on-disk enumeration artefact

**Decision.** Before the model authors any markdown, it writes `<input-folder>/output/system-enumeration.md` containing **every** named system found in the source documents — one row per canonical system, with its aliases, classification, and a citation. Phase 3 (authoring) is gated on the file existing and being non-empty.

The artefact's shape is fixed:

```markdown
# System Enumeration — <System Name>

| Canonical name | Aliases | Classification | Status | Citation |
|----|----|----|----|----|
| eLinks | Judicial Database | Inbound | Manual copy | *JI Functional Requirements* §5.3.1 |
| L!BERATA | JFEPS, JFEBS | Outbound; Inbound (return leg) | Implemented (automated); Manual copy (return leg) | *JI Functional Requirements* §5.3.4 |
| Court Staff | — | Internal user (ruled out) | — | (not a system; users) |
```

**Rationale.** Forcing a flat enumeration **before** classification kills the failure mode where the model never names a system and therefore never has the chance to classify it. The artefact is also small and human-readable, so the user can spot a missing system in seconds. Keeping it markdown (not JSON) means no schema, no validator, no PATH dependency — but pandoc / `awk` can still grep it for cross-checks.

**Alternatives considered.**

- *Skip the artefact; just expand the SKILL.md prose.* Rejected — the existing prose already says to enumerate; the discrepancy is that nothing makes the enumeration *visible*. An on-disk artefact is the smallest thing that makes the procedure auditable.
- *JSON enumeration with a JSON Schema validator.* Rejected for now — adds a dependency (`ajv` / `jsonschema`) for marginal benefit. Markdown is enough; we can promote to JSON in a follow-up if needed.

### 3. Ship a deterministic manual-flow keyword scan as a shell script

**Decision.** Add `scripts/find-manual-flows.sh <input-folder>` to the skill. It scans `<input-folder>/output/extracted-text/*.txt` for a fixed list of phrases and writes `<input-folder>/output/manual-flow-candidates.txt`. The phrase list lives at the top of the script and is the **single source of truth** for "what counts as a manual-copy signal":

```
copies from
copy and paste
copy/paste
manually enter
manually entered
manually copied
re-keys
rekey
rekeyed
transcribe
transcribed
look up in
looks up in
look up from
is entered by
data is entered
obtained from
populated from
populated by
sourced from
read from <X> and entered into
no integration
no automated integration
out-of-band
```

The output file lists each match with its source file and line:

```
JI Functional Requirements.txt:142: "RSU users copy judge profile data from eLinks into JI."
JI NFR.txt:88: "Working patterns are manually entered by court staff (NFR-3 not implemented)."
```

The model is required to walk this file before authoring and either (a) account for each match in the enumeration, or (b) record a one-line dismissal in `phase-2d-checks.md`.

**Rationale.** Keyword search is exactly the kind of work a model should not be trusted to do exhaustively across long documents. A 30-line shell script does it perfectly every time. The model's value-add is *interpretation* — deciding whether a match is a real dependency or a false positive — and that's preserved.

**Alternatives considered.**

- *Embed the phrase list in `SKILL.md` and rely on the model.* Rejected — that's the current state, and it's what the user reported breaking. Models forget; a script doesn't.
- *Use a Python script with NLP (spaCy etc.).* Rejected — adds a heavy dependency for a job grep does fine. Pure shell + grep is portable and reviewable.
- *Run the model itself in a sub-task to scan.* Rejected — defeats the determinism goal.

### 4. Make Phase 2d cross-check produce a checklist artefact

**Decision.** The Phase 2d check is upgraded from prose to a fixed checklist written to `<input-folder>/output/phase-2d-checks.md` before authoring. The model marks each item ✅ or ❌ with a one-line justification. Authoring is gated on every item being ✅.

Items (closed list — same on every run):

```markdown
- [ ] Every system in `system-enumeration.md` is either in the catalogue with a per-section entry, or marked "ruled out" with a one-line justification.
- [ ] Every line in `manual-flow-candidates.txt` is accounted for: either the upstream system is an inbound entry with `Status` = `Manual copy`, or the line is dismissed with a one-line justification (e.g. "phrase used metaphorically", "refers to internal screen flow not a system").
- [ ] Every outbound flow has a corresponding inbound entry for its reconciliation / status return leg, or the source documents explicitly state there is no return flow.
- [ ] No catalogue entry is an internal user (court staff, RSU, judges).
- [ ] Aliases from `system-aliases.json` are collapsed: no system appears under two different names in the catalogue.
- [ ] Every catalogue entry's `Status` value is exactly one of: `Implemented (automated)`, `Manual copy`, `Stated NFR; not implemented`, `No integration (by design)`.
- [ ] Every catalogue entry has a `> Sources:` blockquote pointing at a real section / requirement ID in the source documents.
```

**Rationale.** A check that's only written down in `SKILL.md` doesn't get done — there's no artefact to point at. A checklist file has to be filled in, and the act of writing the justification surfaces the cases the model would otherwise gloss.

**Alternatives considered.**

- *Programmatic check (e.g. a script that diffs enumeration against catalogue).* Rejected for v1 — would require parsing the markdown catalogue, which is brittle. A model-completed checklist is sufficient and reviewable. Can be tightened later.

### 5. Pin the alias map in JSON

**Decision.** Add `<input-folder>/output/system-aliases.json` with shape:

```json
{
  "canonical_to_aliases": {
    "eLinks": ["Judicial Database", "JD"],
    "L!BERATA": ["JFEPS", "JFEBS"]
  },
  "aliases_to_canonical": {
    "Judicial Database": "eLinks",
    "JD": "eLinks",
    "JFEPS": "L!BERATA",
    "JFEBS": "L!BERATA"
  }
}
```

The model writes this file in Phase 2a and uses `aliases_to_canonical` to drive the enumeration. On re-runs, the map is regenerated; identical inputs should yield an identical map.

**Rationale.** Aliasing is the second-largest source of variance after manual-copy detection. Capturing the decision in a single file lets the user see exactly how aliases were resolved and lets the model make the *same* decision next run by deriving from the same source phrases. JSON (not markdown) here because the structure is mechanical and a future tool may want to consume it.

**Alternatives considered.**

- *Inline the alias map in `system-enumeration.md`.* Rejected — mixes presentation (the enumeration is for human review) with mechanical data (the alias map is for machine consistency). Two files keep the responsibilities clean.

### 6. Keep all new artefacts under `<input-folder>/output/`

**Decision.** All four new artefacts live alongside the existing `extracted-text/`, `data-dependencies.md`, `data-dependencies.pdf`:

```
<input-folder>/output/
├── extracted-text/                  # existing — Phase 1
├── system-enumeration.md            # NEW — Phase 2a
├── system-aliases.json              # NEW — Phase 2a
├── manual-flow-candidates.txt       # NEW — Phase 2a (script-generated)
├── phase-2d-checks.md               # NEW — Phase 2d
├── data-dependencies.md             # existing — Phase 3
├── data-dependencies.assets/        # existing — Phase 4
└── data-dependencies.pdf            # existing — Phase 4
```

**Rationale.** The project memory is explicit: per-run artefacts live with the input data, never inside the repo running the skill. The new artefacts follow the same rule.

## Risks / Trade-offs

- **Risk:** The closed `Status` vocabulary may not cover a future case. → **Mitigation:** The five values are intentionally broad. If a new case appears, extend the enum in `OUTPUT-STRUCTURE.md` (a small change), don't tolerate ad-hoc strings. The cross-check will surface a non-conforming value before authoring completes.
- **Risk:** The keyword scan produces false positives (e.g. *"the user looks up in the screen"* — internal navigation, not a system dependency). → **Mitigation:** Phase 2d explicitly allows dismissal with a one-line justification. False positives are cheap to dismiss; missed dependencies are expensive. The script is intentionally over-eager.
- **Risk:** The keyword scan misses cases not in the phrase list. → **Mitigation:** The phrase list is in one place at the top of the shell script; adding a phrase is a one-line edit. Phase 2a still asks the model to enumerate systems independently — the script is a *floor*, not the *ceiling*.
- **Risk:** The new artefacts make re-runs slower (more files to write). → **Mitigation:** Each artefact is < 100 lines. The keyword scan runs in milliseconds. Total overhead is sub-second; build pipeline (mermaid + weasyprint) dominates.
- **Trade-off:** The user now sees four extra files in `output/`. → **Acceptable:** The user's project memory says "outputs go alongside input data" — these files are part of the output. A reviewer wanting *only* the deliverable opens `data-dependencies.pdf`; the rest is the audit trail.
- **Trade-off:** Three of the four new artefacts are model-completed (only `manual-flow-candidates.txt` is script-generated), so they still depend on the model writing them faithfully. → **Acceptable for v1:** The artefacts being *named* and *gated* is what changes the determinism floor; perfect mechanical generation is a future improvement (see Open Questions).

## Open Questions

- Should the Phase 2d checklist be **enforced by a script** (e.g. a Python validator that fails the build if a checkbox is unchecked) rather than relying on the model to honour the gate? Probably yes in a follow-up change; out of scope here to avoid widening this PR.
- Should `system-enumeration.md` and `system-aliases.json` be schema-validated? Same answer — defer to a follow-up if drift persists after this change lands.
- Should the keyword phrase list be promoted from the script to a separate `references/manual-flow-keywords.txt` so it's easy to review without reading the script? Possibly — the script is small enough today that inlining is fine, but extracting becomes worthwhile if the list grows past ~30 phrases.
