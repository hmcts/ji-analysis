## Context

The existing `create-data-dependency-architecture` skill (`.claude/lib/create-data-dependency-architecture/`) is the reference implementation for the "binaries → distilled text → catalogue markdown → styled PDF" pipeline used in this repo. Its house style (dark headers, zebra rows, A4 with 2cm × 1.25cm margins) is set by `assets/doc-style.css`; its Mermaid theme by `assets/mermaid-config.json`; its Phase 2 gating discipline by `find-manual-flows.sh` plus `system-enumeration.md` / `system-aliases.json` / `phase-2d-checks.md` artefacts; and its build-pipeline lessons (e.g. `pandoc --wrap=none`, `<br/>` not `\n`, lopsided dash counts for column widths) are captured in `references/LESSONS-LEARNED.md`.

The repo also has the auto-memory rule that *outputs go alongside the input data*, never inside the running project — this is non-negotiable and applies to the new skill too. The data-dependency skill writes to `<input-folder>/output/`; the new skill MUST partition its outputs into a sibling `<input-folder>/output-functional-modules/` so the two skills never mix artefacts.

This design adds a sibling skill that reuses the build pipeline and house style verbatim, but produces a different artefact (a module-by-module functionality catalogue) and uses a different Phase 2 discovery scan (module / ribbon / screen / capability keywords instead of manual-flow keywords).

## Goals / Non-Goals

**Goals:**
- Produce a single, deterministic, module-organised PDF catalogue from a folder of source binary docs, with the same one-command operator workflow as the existing data-dependency skill.
- Reuse — not duplicate — the build pipeline (`build-pdf.sh`, `md_to_pdf.py`, `requirements.txt`) and the house style (`doc-style.css`, `mermaid-config.json`).
- Reuse the binary-to-text distiller (`distil-binary-data.sh`) verbatim. Distillation is content-agnostic; both skills can share the same `extracted-text/` cache for the same input folder.
- Provide a Phase 2 discovery floor (`find-modules.sh`) so module discovery is reproducible and runs that miss a module are caught at the cross-check gate, not in review.
- Cross-link with the data-dependencies output when both are produced from the same input folder, but not require it (the functional-modules skill must work standalone).

**Non-Goals:**
- Modifying the existing `create-data-dependency-architecture` skill in any way.
- Generating per-module Mermaid diagrams (one diagram per module would defeat the visual scannability the existing skill protects against — exactly one top-of-document overview diagram, mirroring the existing skill).
- Inferring functionality not present in the source documents (the same "no hallucination" rule applies).
- Producing code, runnable specifications, or test scaffolding from the documents — the deliverable is documentation.
- Building a unified mega-skill that conflates data and functional views — they stay separate skills, with one-way cross-references.

## Decisions

### D1. Reuse shared assets and scripts via path indirection, not duplication

The new skill's `SKILL.md` references the existing skill's `assets/` and `scripts/` paths directly (e.g. `.claude/lib/create-data-dependency-architecture/assets/doc-style.css`). The new skill keeps only the files that are functionally distinct: `SKILL.md`, `references/`, `templates/functional-modules.template.md`, and `scripts/find-modules.sh`.

**Why**: Duplicating `doc-style.css`, `mermaid-config.json`, `build-pdf.sh`, `md_to_pdf.py` and `distil-binary-data.sh` invites drift — a fix to the data-dependency skill would not propagate, and PDFs from the two skills would visually diverge. Path indirection costs nothing and guarantees they stay in sync.

**Alternative considered**: Move the shared assets out to a third location (e.g. `.claude/lib/_shared/`) and have both skills depend on it. Rejected because it changes the existing skill's layout (a non-additive change) and adds a third top-level directory for very little benefit at the current scale of two skills.

### D2. The Phase 2 discovery floor is a module-keyword scan, not a clone of `find-manual-flows.sh`

`find-modules.sh` greps the extracted text for the canonical module-introduction patterns: top-level numbered headings (e.g. `^[0-9]+(\.[0-9]+)?\s+`), the words `Ribbon`, `Module`, `Screen`, `Capability`, `Domain`, table headers like `Functional Requirement` / `Non-Functional Requirement`, and section-anchor words like `Manage`, `View`, `Report`, `Admin`. It writes one candidate line per match into `<input-folder>/output-functional-modules/module-candidates.txt`.

**Why**: The data-skill's `find-manual-flows.sh` works because manual-flow phrasings are short, varied and easy to grep for. Module declarations are different — they show up as headings, table-of-contents entries, and ribbon names. The scan must reflect that. The Phase 2d gate is the same shape (every line accounted for, either as a module entry or with a written dismissal).

**Alternative considered**: Skip the discovery floor and rely on the model to enumerate modules. Rejected for the same reason `find-manual-flows.sh` exists in the data skill — models forget; scripts don't (LESSON 19).

### D3. One overview diagram, no per-module diagrams

The functional-modules document has exactly one Mermaid `flowchart` block (a top-of-document module overview). Each module's detail section uses a structured `Attribute / Detail` table, a capability bullet list, and prose — not a diagram.

**Why**: Multiple diagrams per document is the failure mode the existing skill explicitly protects against (see `LESSONS-LEARNED.md` LESSON 6 and the data-skill's anti-patterns list). The same reasoning applies here — diagram-per-module renders the document harder to read, not easier, and breaks the one-page-per-module budget.

**Alternative considered**: A small inline sequence diagram per module showing actors and screens. Rejected — that level of detail belongs in the per-module table and prose, not in a separate diagram per section.

### D4. Per-module section structure: capability list + Attribute/Detail table + scenarios + sources

Each numbered detail section has a fixed structure (mandated by `OUTPUT-STRUCTURE.md`):

1. 1–2 sentence lead paragraph stating purpose and primary user.
2. **Capabilities** — bulleted list of named capabilities the module provides (each ≤ 1 line).
3. **Attribute / Detail** table with rows: `Module ID`, `Primary users`, `Trigger / entry points`, `Inputs`, `Outputs`, `Business rules`, `Cross-module dependencies`, `NFRs`, `Status`.
4. **Key user actions / scenarios** — short bulleted list of the primary user actions the module supports, each in `WHEN <X> THEN <Y>` form where the source supports it. Optional if the module is purely back-office configuration.
5. `> Sources:` blockquote.

**Why**: This mirrors the existing skill's pattern (load-bearing per-section table; prose for nuance; blockquote for citations). The capability list and scenarios are added here because functional content benefits from explicit named capabilities and user-flow framing in a way data-flow content does not. The structure stays deterministic across runs.

**Alternative considered**: A free-form prose section per module. Rejected — variance between runs is the failure mode the existing skill's structure exists to prevent; the new skill inherits that discipline.

### D5. `Status` vocabulary differs — focused on functional implementation state

The data-skill's `Status` vocabulary (`Implemented (automated)` / `Manual copy` / `Stated NFR; not implemented`) does not map cleanly to functional modules. The new skill defines its own closed vocabulary, enforced at Phase 2d:

- `Implemented` — the module's documented capabilities are live in the application.
- `Partial` — some documented capabilities are live, others are stated but not implemented (e.g. discovery / future-state items).
- `Discovery required` — the source documents explicitly mark the module as "not supported — Discovery required" (the JI docs use this phrasing for Tribunals and Magistrates).
- `Out of scope` — the module is named in the source documents but explicitly excluded from the as-is system.

The same enforcement pattern applies (Phase 2d item 6 rejects any non-conforming string).

### D6. Cross-link to the data-dependencies output when present, but stay standalone

If `<input-folder>/output/data-dependencies.md` exists when this skill runs, the per-module `Cross-module dependencies` cell may include named links into that document — the relative path from inside `output-functional-modules/` is `../output/data-dependencies.md` (e.g. *"Payments produces the [JFEPS payment schedule](../output/data-dependencies.md#jfeps-lberata-finance-fee-paid-payment-schedules)"*). If it does not exist, the cell describes the dependency in prose only.

**Why**: Cheap composition where both outputs exist; no hard dependency. Both PDFs render fine independently.

**Alternative considered**: Embed the data-dependencies catalogue as an appendix in the functional-modules PDF. Rejected — that would mean re-running the data-dependency skill as a sub-step, and would couple the two skills' release cycles.

### D7. Slash command and skill name

The slash command is `/create-functional-modules-architecture <input-folder>`, mirroring the existing `/create-data-dependency-architecture` exactly. The skill directory is `.claude/lib/create-functional-modules-architecture/`. The OpenSpec change name (`create-functional-modules-architecture-skill`) carries the redundant `-skill` suffix purely for change-tracking clarity — it does not propagate into the skill artefacts themselves.

## Risks / Trade-offs

- **Path indirection brittleness** — if the data-skill's `assets/` or `scripts/` paths move, the new skill breaks. Mitigation: a single line in the new skill's `LESSONS-LEARNED.md` documents the dependency; both paths are stable in this repo today, and any future move would be a single global rename.
- **Scope creep at module level** — the docs may describe per-screen, per-ribbon, per-domain and per-function detail; the skill must pick one granularity and stick to it. Mitigation: `OUTPUT-STRUCTURE.md` mandates module-level granularity (typically a top-level ribbon or domain), and explicitly rules out per-screen and per-FR sub-sections in the catalogue body. Per-FR detail can live in an optional appendix only when truly needed.
- **Module enumeration variance** — the same risk as system enumeration in the data skill, in spades, because module names have more variants (Ribbon vs Screen vs Module vs Domain). Mitigation: the alias map (`module-aliases.json`) and Phase 2d gate are mandatory, identical to the data-skill discipline.
- **PDF length** — module-by-module documentation can balloon. Mitigation: the per-module structure caps each entry at roughly 1 page (lead + capabilities list + 9-row table + ≤ 6 scenarios + sources). NFRs that apply system-wide go in a single closing section, not per module.
- **Diagram complexity** — the overview diagram showing all modules grouped into domains can become unreadable for systems with > 12 modules. Mitigation: the diagram caps at 3 domain subgraphs and uses ` <br/>` for multi-line node labels; modules over the cap collapse into a "Reports & MI" or "Admin" cluster following the source documents' own grouping.

## Migration Plan

This change is purely additive — no migration is required. To deploy:

1. Create `.claude/lib/create-functional-modules-architecture/` and its subdirectories (`references/`, `templates/`, `scripts/`).
2. Author `SKILL.md`, `references/OUTPUT-STRUCTURE.md`, `references/STYLE-GUIDE.md`, `references/LESSONS-LEARNED.md`, `templates/functional-modules.template.md`, `scripts/find-modules.sh`.
3. Add the slash-command file at `.claude/commands/create-functional-modules-architecture.md`.
4. Smoke-test against the existing `ji-input-docs/` folder to confirm a 5-phase run produces a styled PDF and that the cross-link to the existing `data-dependencies.md` resolves.
5. No rollback complexity — if the skill misbehaves, deleting `.claude/lib/create-functional-modules-architecture/` and the slash-command file removes it cleanly.

## Open Questions

- Should the module overview diagram embed *cross-module dependency arrows* (e.g. *Vacancies → Fee-paid Bookings → Payments*), or just cluster modules visually with no edges? Provisional: include arrows for explicit cross-module data flows that the source documents call out, dashed for non-implemented; cluster-only otherwise. Final answer at first run.
- Should NFRs be repeated per module or hoisted into a single `## Cross-cutting NFRs` section? Provisional: per-module NFR row in the Attribute / Detail table for module-specific NFRs; a closing `## Cross-cutting NFRs` section for system-wide NFRs that apply to every module (security, accessibility, audit). Final answer to be reviewed after first run.
