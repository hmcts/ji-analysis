## Why

Source documentation often describes a system as a set of *modules* (ribbons / screens / domains) — but readers wanting a structured, module-by-module view of what the application does have to re-derive it each time. The existing `create-data-dependency-architecture` skill solves the equivalent problem for data flows; this change adds a sibling skill for *functional* coverage so analysts can produce a deterministic, module-organised catalogue of capabilities, user stories, business rules and NFRs from the same source binaries with the same workflow.

## What Changes

- Add a new skill at `.claude/lib/create-functional-modules-architecture/` modelled on the existing `create-data-dependency-architecture` skill. Same pipeline shape: distil binaries → discover & enumerate modules → classify & capture per-module facts → cross-check → author markdown → render styled PDF.
- The output is a single module-organised document (`<input-folder>/output-functional-modules/functional-modules.md` and `.pdf`) with:
  - YAML front matter and intent paragraph.
  - "At a Glance" module table (one row per module, terse summary).
  - One Mermaid `Module overview` diagram showing modules grouped into functional domains, with cross-module dependencies as edges.
  - One numbered detail section per module containing: purpose, capability list, user stories / key actions, business rules, data inputs/outputs (cross-references to the data-dependencies skill output where available), NFRs that apply, and a `> Sources:` blockquote.
  - Optional `Appendix` (structural notes), `Summary`, and `Source Documents` list — same conventions as the existing skill.
- Add a new slash command `/create-functional-modules-architecture` invoking the skill against a user-supplied input folder.
- Add a new module-discovery keyword scanner (`scripts/find-modules.sh`) acting as the Phase 2a discovery floor — analogous to `find-manual-flows.sh` in the existing skill, scanning for ribbon / screen / module / section / capability / user-role keywords.
- Reuse the existing `assets/doc-style.css` and `assets/mermaid-config.json` so the two outputs share house style; reuse the existing `scripts/distil-binary-data.sh`, `scripts/build-pdf.sh` and `scripts/python/md_to_pdf.py` either by copy or by shared invocation (decision deferred to design.md).
- Phase 2 produces the same auditable artefact set with module-specific names: `module-candidates.txt`, `module-enumeration.md`, `module-aliases.json`, `phase-2d-checks.md`. Authoring is gated on every cross-check item being ✅, mirroring the existing skill.

## Capabilities

### New Capabilities
- `functional-modules-architecture`: A deterministic skill that ingests a folder of source binary documents, distils them, identifies the application's functional modules, and produces a styled PDF catalogue with one detail section per module covering purpose, capabilities, user actions, business rules, data interactions and NFRs.

### Modified Capabilities
<!-- None — this change is purely additive. The existing data-dependency skill is unchanged. -->

## Impact

- **New files** under `.claude/lib/create-functional-modules-architecture/`: `SKILL.md`; `references/OUTPUT-STRUCTURE.md`, `references/STYLE-GUIDE.md`, `references/LESSONS-LEARNED.md`; `templates/functional-modules.template.md`; `scripts/find-modules.sh`; plus either copies of the shared scripts/assets or a shared-helper indirection (decision in design.md).
- **New slash command**: `.claude/commands/create-functional-modules-architecture.md` (mirrors the existing `create-data-dependency-architecture` command).
- **No breaking changes**: the existing data-dependency skill is untouched. Outputs still land under `<input-folder>/output-functional-modules/`, never inside the running project.
- **Operator workflow**: the same single-command invocation pattern (`/create-functional-modules-architecture <input-folder>`); same external-tool prerequisites (`pandoc`, `weasyprint`, `mmdc`, `textutil`, `pdftotext`, `python3` ≥ 3.10).
- **Composition**: where the data-dependencies output already exists for the same input folder, the functional-modules document cross-references it (e.g. *"the [Payments module](#payments) produces the JFEPS payment schedule — see Data Dependencies §6"*). Cross-referencing is one-way (functional → data); the data-dependency skill is unchanged.
