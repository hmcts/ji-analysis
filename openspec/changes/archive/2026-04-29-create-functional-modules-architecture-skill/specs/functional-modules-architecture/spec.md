## ADDED Requirements

### Requirement: Skill produces a deterministic module-organised PDF from a folder of source binary documents

The skill SHALL accept a single argument — the path to a folder of top-level source documents (`.docx`, `.doc`, `.pdf`, `.md`, `.markdown`, `.txt`) — and produce, deterministically (same inputs + same skill files = byte-equivalent output modulo PNG rasterisation), a styled PDF catalogue at `<input-folder>/output-functional-modules/functional-modules.pdf` together with the source markdown at `<input-folder>/output-functional-modules/functional-modules.md`.

#### Scenario: Standard run against a populated input folder
- **WHEN** the user runs `/create-functional-modules-architecture <input-folder>` against a folder containing at least one supported document type
- **THEN** the skill creates `<input-folder>/output-functional-modules/extracted-text/`, `<input-folder>/output-functional-modules/module-candidates.txt`, `<input-folder>/output-functional-modules/module-enumeration.md`, `<input-folder>/output-functional-modules/module-aliases.json`, `<input-folder>/output-functional-modules/module-phase-2d-checks.md`, `<input-folder>/output-functional-modules/functional-modules.md`, `<input-folder>/output-functional-modules/functional-modules.pdf` and `<input-folder>/output-functional-modules/functional-modules.assets/` — and writes nothing inside the running project

#### Scenario: Re-run is byte-equivalent
- **WHEN** the user runs the skill twice against the same input folder with no document changes between runs
- **THEN** the resulting `functional-modules.md` is byte-identical, the PDF differs only in PNG rasterisation noise, and all four Phase 2 artefacts are byte-identical

#### Scenario: Missing external tool
- **WHEN** any of `python3` (≥ 3.10), `pandoc`, `weasyprint`, `mmdc`, `textutil` (on macOS), or `pdftotext` is not on PATH at the start of the run
- **THEN** the skill SHALL surface the missing tool to the user immediately, before producing any partial output

### Requirement: The pipeline runs in five sequential phases that match the data-dependency skill

The skill SHALL execute Phase 1 (distil binaries), Phase 2 (enumerate modules → classify → cross-check), Phase 3 (author markdown), Phase 4 (render PDF), Phase 5 (verify and report) in strict order. Phase 3 SHALL be gated on the four Phase 2 artefacts existing and `module-phase-2d-checks.md` having every checklist item marked ✅.

#### Scenario: Missing Phase 2 artefact blocks Phase 3
- **WHEN** any of `module-candidates.txt`, `module-enumeration.md`, `module-aliases.json` or `module-phase-2d-checks.md` is missing
- **THEN** the skill SHALL not author `functional-modules.md` and SHALL surface the missing artefact

#### Scenario: Phase 2d cross-check item failed
- **WHEN** `module-phase-2d-checks.md` contains any unchecked or ❌-marked item
- **THEN** the skill SHALL not author `functional-modules.md` and SHALL surface the failed check item

### Requirement: All outputs land alongside the input data, never in the running project, and never collide with the data-dependency skill

The skill SHALL write every per-run artefact under `<input-folder>/output-functional-modules/` and SHALL not write any per-run artefact into the directory containing the skill (`.claude/lib/create-functional-modules-architecture/`) or anywhere else inside the repository running the skill. The skill SHALL NOT write to `<input-folder>/output/` (the data-dependency skill's namespace) — the two skills coexist by partitioning the input folder's output namespace at the top level.

#### Scenario: Output isolation
- **WHEN** the skill is invoked from any working directory
- **THEN** the only files created or modified by the run live under `<input-folder>/output-functional-modules/`, and the data-dependency skill's `<input-folder>/output/` folder is left untouched

### Requirement: Phase 1 distillation uses the existing `distil-binary-data.sh` with an explicit output folder, and treats only top-level files

The skill SHALL invoke the existing `.claude/lib/create-data-dependency-architecture/scripts/distil-binary-data.sh <input-folder> <input-folder>/output-functional-modules/extracted-text` to produce `<input-folder>/output-functional-modules/extracted-text/*.txt`. The explicit second argument overrides the script's default (`<input-folder>/output/extracted-text/`, the data-skill's namespace) so the two skills' outputs never mix. Subfolders of the input folder SHALL NOT be descended into.

#### Scenario: Subfolders ignored on rerun
- **WHEN** the input folder contains previously-created `output/` and/or `output-functional-modules/` subfolders from a prior run
- **THEN** the distiller SHALL skip both subfolders and process only top-level documents

### Requirement: Phase 2a discovery floor — `find-modules.sh` writes `module-candidates.txt`

Phase 2a SHALL begin by running `scripts/find-modules.sh <input-folder>`, which SHALL write `<input-folder>/output-functional-modules/module-candidates.txt` containing every line in the extracted text matching one of the canonical module-introduction patterns (numbered headings, "Ribbon", "Module", "Screen", "Capability", "Domain", functional-requirement table headers).

#### Scenario: Discovery floor populated
- **WHEN** `find-modules.sh` runs against extracted text containing at least one numbered top-level heading
- **THEN** `module-candidates.txt` is created and contains at least one candidate line

#### Scenario: Every candidate line accounted for at the gate
- **WHEN** the Phase 2d cross-check runs
- **THEN** every line in `module-candidates.txt` SHALL either map to an entry in `module-enumeration.md` or be dismissed in `module-phase-2d-checks.md` with a one-line justification

### Requirement: `module-enumeration.md` contains every named module with the canonical name, aliases, classification, status and citation

Phase 2a SHALL produce `module-enumeration.md` with one row per *canonical* module. Aliases SHALL be resolved (via `module-aliases.json`) before enumeration so that the same module never appears twice under different names.

#### Scenario: Alias resolution applied
- **WHEN** the source documents reference the same module by two names (e.g. "Manage Judges" and "Judges Ribbon")
- **THEN** `module-enumeration.md` contains exactly one row for that canonical module, with both names present in the `Aliases` cell, and `module-aliases.json` round-trips the alias both ways

### Requirement: The `Status` cell uses a closed vocabulary

Every `Status` value in `module-enumeration.md` and in the per-module `Attribute / Detail` tables SHALL be exactly one of: `Implemented`, `Partial`, `Discovery required`, `Out of scope`. Paraphrases SHALL be rejected at the Phase 2d gate.

#### Scenario: Non-conforming status rejected
- **WHEN** any `Status` cell in `module-enumeration.md` or `functional-modules.md` contains a value other than the four permitted strings
- **THEN** the Phase 2d cross-check (item that enforces closed vocabulary) SHALL be ❌ and Phase 3 SHALL not proceed

### Requirement: `module-phase-2d-checks.md` is a fixed seven-item checklist

The cross-check file SHALL contain exactly the same seven items, in the same order, on every run. Each item is marked ✅ with a one-line justification or ❌ with the resolution action; authoring is gated on every item being ✅.

#### Scenario: Checklist shape stable across runs
- **WHEN** the skill runs against any input folder
- **THEN** `module-phase-2d-checks.md` contains the same seven numbered items, verbatim, in the same order

### Requirement: `functional-modules.md` follows the deterministic structure defined by `OUTPUT-STRUCTURE.md`

The authored markdown SHALL contain, in this order: YAML front matter (`title:`, `subtitle:`); intent paragraph and bullets; `## At a Glance` module summary table; `## Module overview` Mermaid `flowchart` block (exactly one); `## Modules` H2 with one `### N. <Module>` H3 per module in numerical order; `## Cross-cutting NFRs` (when applicable); `## Summary`; optional `## Appendix`; `## Source Documents`.

#### Scenario: Sections present in order
- **WHEN** Phase 3 completes
- **THEN** `functional-modules.md` contains every required section in the order above and no additional H2 sections

#### Scenario: Exactly one Mermaid diagram
- **WHEN** Phase 3 completes
- **THEN** `functional-modules.md` contains exactly one `flowchart` Mermaid block (the module overview), and no per-module diagrams

### Requirement: Every per-module detail section has a fixed structure

Each `### N. <Module>` H3 SHALL contain, in this order: a 1–2 sentence lead paragraph; a bulleted **Capabilities** list (one capability per line, ≤ 1 line each); an `Attribute | Detail` table with rows `Module ID`, `Primary users`, `Trigger / entry points`, `Inputs`, `Outputs`, `Business rules`, `Cross-module dependencies`, `NFRs`, `Status`; an optional **Key user actions** bulleted list with `WHEN <X> THEN <Y>` items; a `> Sources:` blockquote.

#### Scenario: Mandatory rows present in Attribute / Detail
- **WHEN** any per-module detail section is rendered
- **THEN** all nine `Attribute / Detail` rows are present in the order specified, with `Unknown` used for any value not derivable from the source documents

### Requirement: Cross-references to the data-dependencies output are optional and one-way

When `<input-folder>/output-functional-modules/data-dependencies.md` exists at Phase 3 time, the skill MAY include named links from per-module `Cross-module dependencies` cells into anchors in that document; when it does not exist, the cell SHALL describe dependencies in prose only. The data-dependency skill SHALL NOT be invoked, modified, or required as a precondition by this skill.

#### Scenario: Standalone run with no data-dependencies output
- **WHEN** the skill runs against an input folder with no `data-dependencies.md`
- **THEN** the resulting `functional-modules.pdf` is produced successfully and contains no broken cross-document links

#### Scenario: Co-located run with data-dependencies output
- **WHEN** the skill runs against an input folder where `data-dependencies.md` already exists
- **THEN** the resulting `functional-modules.md` MAY contain named links into `data-dependencies.md` anchors, and the PDF build SHALL NOT fail because of the cross-document references (links are textual)

### Requirement: Phase 4 reuses the existing PDF build pipeline verbatim

Phase 4 SHALL invoke `.claude/lib/create-data-dependency-architecture/scripts/build-pdf.sh <input-folder>/output-functional-modules/functional-modules.md` and SHALL NOT define a parallel build script. The house style (`assets/doc-style.css`) and Mermaid theme (`assets/mermaid-config.json`) used SHALL be the existing files in the data-dependency skill — no per-skill copies.

#### Scenario: Build script reused
- **WHEN** Phase 4 runs
- **THEN** the same `build-pdf.sh` invocation produces `functional-modules.pdf` and a sibling `functional-modules.assets/` next to the markdown

#### Scenario: Style stays in sync
- **WHEN** the data-dependency skill's `doc-style.css` is updated
- **THEN** the next functional-modules build picks up the new style automatically, with no edits to the new skill's files

### Requirement: Phase 5 verifies the PDF and reports concisely

Phase 5 SHALL run `pdfinfo` (or equivalent) against `functional-modules.pdf` to confirm a valid PDF was produced and SHALL report to the user the output path and page count, without dumping the document contents.

#### Scenario: Successful run report
- **WHEN** Phase 5 completes
- **THEN** the user-facing message names the produced PDF, the page count, and the location of the source markdown — and does not summarise the document body unless asked

### Requirement: The skill provides a slash command at `/create-functional-modules-architecture`

A new command file at `.claude/commands/create-functional-modules-architecture.md` SHALL invoke the skill with the user-supplied input folder argument. The command name and behaviour mirror the existing `/create-data-dependency-architecture` command exactly, differing only in the skill name and output filename.

#### Scenario: Command invocation
- **WHEN** the user types `/create-functional-modules-architecture <input-folder>`
- **THEN** the command loads the skill's `SKILL.md`, supplies the input folder, and the skill executes the five-phase pipeline
