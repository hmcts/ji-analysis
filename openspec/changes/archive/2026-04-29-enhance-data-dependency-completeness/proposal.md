## Why

The `create-data-dependency-architecture` skill misses dependencies between runs against the same source documents — most often the ones where there is no system-to-system integration but a human copies data from another system into the target system. The current spec mentions "gap dependencies" once, but the discovery procedure is prose-shaped (Phase 2a says "walk through these places") rather than a strict, auditable checklist, and the `Status` vocabulary collapses several distinct cases ("Manual" / "NFR-N stated" / "No integration") into a fuzzy enum. The result is that the same documents produce different catalogues on different runs and manual-copy dependencies in particular get dropped because the model treats "no integration" as "no dependency".

This change tightens the discovery, classification and labelling rules so the skill produces the same catalogue every time and never silently drops a dependency that exists only as manual data movement.

## What Changes

- **Formalise the manual-copy dependency case.** Add an explicit `Manual copy` status value and treat any human transcription / re-keying / lookup-and-enter from a named upstream system as a first-class inbound dependency that **must** appear in the catalogue.
- **Replace the fuzzy `Status` enum with a closed, deterministic set.** The new values are: `Implemented (automated)`, `Manual copy`, `Manual entry (no upstream system)`, `Stated NFR; not implemented`, `No integration (by design)`. Every entry must use exactly one of these strings.
- **Make Phase 2a enumeration auditable.** Promote the prose checklist to a strict procedure that produces an intermediate artefact (`output/system-enumeration.md`) listing every named system found in the source text, with classification, citation and alias resolution. Authoring the markdown in Phase 3 is gated on the enumeration existing.
- **Add a manual-copy keyword scan.** Ship a small, deterministic script (`scripts/find-manual-flows.sh`) that scans `output/extracted-text/*.txt` for the canonical phrasings ("copies from", "rekey", "manually enter", "transcribe", "look up in", "is entered by", "obtained from", etc.) and emits `output/manual-flow-candidates.txt`. The model must reconcile every candidate against the enumeration before authoring.
- **Tighten Phase 2d cross-check** into a binary checklist that is itself written to disk (`output/phase-2d-checks.md`) so re-runs produce the same audit trail. Add explicit checks for: every manual-copy candidate accounted for; every reconciliation return leg present; every alias collapsed.
- **Pin the alias map.** Capture canonical-name ↔ aliases as `output/system-aliases.json` so the same alias resolution is applied across re-runs and visible in the audit trail.
- **Update authoring templates and references** (`SKILL.md`, `OUTPUT-STRUCTURE.md`, `STYLE-GUIDE.md`, `LESSONS-LEARNED.md`, `templates/data-dependencies.template.md`) to reflect the new closed Status vocabulary, the manual-copy case, and the gating on the enumeration / checks artefacts.
- **No breaking change to outputs the user sees** — the markdown / PDF still has the same shape (At a Glance table, three Mermaid diagrams, per-dependency Attribute / Detail tables). Only the Status cell vocabulary is constrained, which is a content change, not a structural one.

## Capabilities

### New Capabilities
- `data-dependency-discovery`: The discovery, classification, alias-resolution and audit-trail procedure that the `create-data-dependency-architecture` skill follows when extracting data dependencies from a folder of source documents — covering enumeration, manual-copy detection, the closed `Status` vocabulary, and the deterministic intermediate artefacts that make re-runs reproducible.

### Modified Capabilities
<!-- None — `openspec/specs/` is currently empty so there is no existing spec to modify. -->

## Impact

- **Skill files** under `.claude/lib/create-data-dependency-architecture/` — `SKILL.md` (Phase 2 expanded; gating on intermediate artefacts), `references/OUTPUT-STRUCTURE.md` (Status vocabulary tightened), `references/STYLE-GUIDE.md` (Status row examples updated), `references/LESSONS-LEARNED.md` (new lesson on manual-copy detection), `templates/data-dependencies.template.md` (Status vocabulary in the example rows).
- **New script** `scripts/find-manual-flows.sh` shipped with the skill (top-level-only, deterministic, no Python required — pure shell + ripgrep / grep).
- **New intermediate artefacts** written to `<input-folder>/output/`: `system-enumeration.md`, `system-aliases.json`, `manual-flow-candidates.txt`, `phase-2d-checks.md`. These sit alongside the existing `extracted-text/`, `data-dependencies.md`, `data-dependencies.pdf` and `data-dependencies.assets/`.
- **No code outside the skill is affected.** The repo running the skill (this repo or any other) gets no new files; the build pipeline (`build-pdf.sh`, `md_to_pdf.py`) is unchanged.
- **No external dependencies added.** The keyword scan uses tools already required by the existing pipeline (POSIX shell, `grep`); no new PATH requirements.
