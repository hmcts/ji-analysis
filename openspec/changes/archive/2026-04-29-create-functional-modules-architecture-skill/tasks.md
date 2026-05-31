## 1. Skill scaffolding

- [x] 1.1 Create the directory tree at `.claude/lib/create-functional-modules-architecture/` with subdirectories `references/`, `templates/`, `scripts/`
- [x] 1.2 Create the slash-command file at `.claude/commands/create-functional-modules-architecture.md`, mirroring the existing `/create-data-dependency-architecture` command (input-folder argument, links to the new SKILL.md and references)

## 2. Authoring references

- [x] 2.1 Write `SKILL.md` describing the five-phase pipeline, inputs, external-tool prerequisites, where outputs land, anti-patterns, and the bootstrapping note for fresh repositories — explicitly referencing the data-skill's shared assets and scripts by path (per design.md decision D1)
- [x] 2.2 Write `references/OUTPUT-STRUCTURE.md` mandating: YAML front matter; intent paragraph + bullets; `## At a Glance` module table (compact, terse cells, lopsided dash-count widths); single `## Module overview` Mermaid `flowchart` block; `## Modules` H2 with one `### N. <Module>` H3 per module; per-module structure (lead → Capabilities bullets → Attribute/Detail table → optional Key user actions → Sources blockquote); optional `## Cross-cutting NFRs`; `## Summary`; optional `## Appendix`; `## Source Documents`
- [x] 2.3 Define the closed-vocabulary `Status` values (`Implemented`, `Partial`, `Discovery required`, `Out of scope`) in `OUTPUT-STRUCTURE.md` and the per-module `Attribute / Detail` table row order (`Module ID`, `Primary users`, `Trigger / entry points`, `Inputs`, `Outputs`, `Business rules`, `Cross-module dependencies`, `NFRs`, `Status`)
- [x] 2.4 Write `references/STYLE-GUIDE.md` carrying the prose-style rules (no skill-internal reasoning in the body; module names not numbers in prose; capability bullets ≤ 1 line; cap on per-module length)
- [x] 2.5 Write `references/LESSONS-LEARNED.md` capturing the non-obvious settings that the new skill inherits from the existing build pipeline (`pandoc --wrap=none`, `<br/>` not `\n`, lopsided dash counts) and the new lessons specific to module enumeration (alias-resolution-before-classification, the discovery floor analogy, the closed-vocabulary `Status`, why one diagram not many)

## 3. Templates and scripts

- [x] 3.1 Write `templates/functional-modules.template.md` — skeleton with placeholders for system name, module list, capability bullets, the Attribute / Detail rows, and the closing sections; copy the load-bearing `---` separator-dash patterns from the data-skill's template
- [x] 3.2 Implement `scripts/find-modules.sh` — pure-shell, top-level-only, writes `<input-folder>/output-functional-modules/module-candidates.txt` with every line in `extracted-text/*.txt` matching the canonical module-introduction patterns (numbered headings, `Ribbon`, `Module`, `Screen`, `Capability`, `Domain`, `Functional Requirement` table headers, `Manage|View|Report|Admin` ribbon names); made it `chmod +x`
- [x] 3.3 Verified `scripts/find-modules.sh` against `ji-input-docs/` extracted text — produces 887 candidate lines that cover Home, Manage Judges, Court Itinerary, Judge Itinerary, Forward Look, Absences, Vacancies, Fee-paid Bookings, Payments, Payment Reconciliation, Sittings, Admin, Reports

## 4. Phase 2 artefact templates and gating

- [x] 4.1 Document the `module-aliases.json` shape in `OUTPUT-STRUCTURE.md` (matching `system-aliases.json`: `canonical_to_aliases` and `aliases_to_canonical` keys, every alias round-trips)
- [x] 4.2 Document the `module-enumeration.md` shape in `OUTPUT-STRUCTURE.md` (header table with columns `Canonical name`, `Aliases`, `Classification`, `Status`, `Citation`)
- [x] 4.3 Document the seven fixed `module-phase-2d-checks.md` items in `SKILL.md` (every module enumerated and either catalogued or ruled out; every candidate-line accounted for; alias collapse verified; closed-vocabulary `Status`; per-module Sources blockquote; mandatory rows in Attribute / Detail; one-and-only-one Mermaid diagram)

## 5. Smoke test against ji-input-docs

- [x] 5.1 Ran the new skill end-to-end against `/Users/ramnishkalsi/Github/scrumconnect/ji-input-docs/` — produced all four Phase 2 artefacts, `functional-modules.md` and `functional-modules.pdf` under `output-functional-modules/`
- [x] 5.2 Confirmed the produced markdown contains exactly one Mermaid `flowchart` block (the module overview) and one detail section per enumerated module (12 modules), each with all nine mandatory Attribute / Detail rows
- [x] 5.3 Confirmed the produced PDF renders with the same house style as `data-dependencies.pdf` — uses the shared `assets/doc-style.css` and `assets/mermaid-config.json` from the data-skill via path indirection
- [x] 5.4 Confirmed cross-references from per-module `Cross-module dependencies` cells to anchors in the same document, and the `## Cross-cutting NFRs` and Appendix references to the sibling `data-dependencies.md` exist as named-link prose (text-only cross-document links remain readable in the PDF)

## 6. Documentation and handoff

- [x] 6.1 Updated `README.md` with a "Slash command — Create Functional Modules Architecture" section that mirrors the data-dependency entry, points at the SKILL.md and notes the dedicated `<input_folder>/output-functional-modules/` location
- [x] 6.2 Verified the new skill files contain no hard-coded per-run data paths (`grep -rE "ji-input-docs|/Users/"` returns no matches in `.claude/lib/create-functional-modules-architecture/`); everything per-run lands under `<input-folder>/output-functional-modules/`
- [x] 6.3 Smoke-tested the slash command's invocation contract — Phase 1 (`distil-binary-data.sh` with explicit second arg), Phase 2a (`find-modules.sh`), Phase 2 artefacts (aliases, enumeration, checks), Phase 3 (markdown), Phase 4 (`build-pdf.sh`) and Phase 5 (`pdfinfo`) all succeed end-to-end against `ji-input-docs/` from this conversation
