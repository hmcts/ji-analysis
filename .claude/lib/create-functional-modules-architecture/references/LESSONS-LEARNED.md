# Lessons learned (read this before "fixing" the pipeline)

This file captures the *non-obvious* settings and gotchas specific to the `create-functional-modules-architecture` skill. The build-pipeline lessons (pandoc flags, Mermaid quirks, anchor stripping) are inherited verbatim from the sibling `create-data-dependency-architecture` skill — see its [`LESSONS-LEARNED.md`](../../create-data-dependency-architecture/references/LESSONS-LEARNED.md) for the full list and treat the rules as load-bearing for both skills.

## Inherited from the data-dependency skill (do not re-derive)

These rules were established in the data-dependency skill and apply to every document this skill produces. Do not "fix" them in the build pipeline.

- **Pandoc must be invoked with `--wrap=none`.** Long lines get wrapped inside SVG `<text>` and HTML attributes otherwise, breaking diagrams and tables.
- **PDF engine is WeasyPrint, not LaTeX.** LaTeX engines can't render inline SVG without significant plumbing.
- **Mermaid blocks are pre-rendered to PNG, not inline SVG.** WeasyPrint silently drops SVG presentation properties otherwise.
- **`<br/>` for line breaks in Mermaid labels — never `\n`.** Literal `\n` renders as the two-character sequence in the PNG.
- **Markdown separator-dash widths control table column widths.** Pandoc's pipe-table reader emits `<colgroup><col style="width:X%">` from the relative width of `---` runs. The patterns specified in [`OUTPUT-STRUCTURE.md`](OUTPUT-STRUCTURE.md) (`4 / 26 / 18 / 36 / 16` for *At a Glance*; `5 / 20` for *Attribute / Detail*) are intentional. Don't normalise the dashes to look symmetrical.
- **Pandoc strips leading numbers and most punctuation from heading IDs.** `### 7. Reports` becomes anchor `#reports`, not `#7-reports`. Cross-references must use the no-number form.
- **Use the Mermaid `default` theme via `--configFile`.** Don't hand-craft a `classDef` palette per document.
- **Use `subgraph` clustering, not flat node lists.**
- **Dashed arrows for non-implemented / out-of-band flows.**
- **All Mermaid nodes are plain rectangles (ArchiMate style).** No cylinders, circles or other shapes.
- **Top-level only — don't descend into subfolders of the input.** `distil-binary-data.sh` enforces this.
- **macOS `.doc` needs `textutil`; `.docx` works with pandoc.**
- **Outputs go alongside the input data, never inside the running project.** Per the user's CLAUDE.md and the project memory.
- **Don't run any git operations from inside Claude.**

## New lessons specific to this skill

### F1. Reuse the data-dependency skill's assets and scripts by path indirection — don't copy

This skill's `SKILL.md` references the data-skill's `assets/doc-style.css`, `assets/mermaid-config.json`, `scripts/distil-binary-data.sh` and `scripts/build-pdf.sh` by absolute path inside the repo (`.claude/lib/create-data-dependency-architecture/...`). They are **not duplicated** into this skill's directory.

> **Why**: duplication invites drift. A fix to `doc-style.css` for the data-dependency PDF would not propagate, and the two PDFs would visually diverge across runs. Path indirection costs nothing and guarantees they stay in sync.

> **Trade-off**: if the data-skill's scripts move or are renamed, this skill stops working until paths are updated. Mitigation: the move would be a single global rename. Acceptable.

> **What to do if you're tempted to copy**: don't. Edit the shared file in the data-dependency skill — both skills benefit. If the change is genuinely module-specific (and not generic style), put it in this skill's `templates/` or `references/` instead, *not* in copied assets.

### F2. The discovery floor is a module-keyword scan — not a clone of `find-manual-flows.sh`

`scripts/find-modules.sh` greps the extracted text for canonical module-introduction patterns (numbered top-level headings, words like `Ribbon` / `Module` / `Screen` / `Capability` / `Domain`, functional-requirement table headers, ribbon-action verbs). The data-skill's `find-manual-flows.sh` is the wrong shape for module discovery — manual-flow phrasings are short and varied; module declarations show up as headings and section markers.

> **Why have a script at all**: models forget. Across runs, the prose-level instruction "look in TOC sections" or "walk the ribbons" is followed unevenly. A 100-line shell script does not forget.

> **The script is intentionally over-eager.** False positives are cheap to dismiss in `module-phase-2d-checks.md`; missed modules are expensive (they're the failure mode this exists to prevent).

### F3. Closed `Status` vocabulary differs from the data skill

The data-skill's `Status` values (`Implemented (automated)` / `Manual copy` / `Stated NFR; not implemented` / `Manual entry (no upstream system)` / `No integration (by design)`) describe *integration* state and don't fit modules. This skill defines its own four-value vocabulary:

- `Implemented` — the module's documented capabilities are live in the application.
- `Partial` — some capabilities live, others stated but not implemented.
- `Discovery required` — the source explicitly marks it as needing discovery.
- `Out of scope` — named in the source but explicitly excluded from the as-is system.

These four are the only legal `Status` values in `module-enumeration.md` and per-module `Attribute / Detail` tables. Phase 2d item 5 enforces this.

### F4. One diagram only — `## Module overview`

The temptation to add a per-module sequence diagram (showing actor → screen → service for that module's primary user actions) is real and wrong. The document has **exactly one** Mermaid block. The per-module *Attribute / Detail* table and optional *Key user actions* bullets carry the equivalent detail in a more scannable form.

> **Why**: multiple diagrams per document is exactly the failure mode the data-skill explicitly protects against (see its `LESSONS-LEARNED.md` LESSON 6). Adding diagram-per-module makes the PDF longer, slower to scan, and harder to keep visually consistent across runs.

> **What if a module's user actions genuinely need a diagram?** Then the source documents probably already describe a separate process flow. Cross-reference that document; don't embed a Mermaid copy.

### F5. Each skill has its own dedicated output folder — no shared state, no filename collisions

The data-skill writes everything (its `extracted-text/`, `phase-2d-checks.md`, the catalogue and PDF) to `<input-folder>/output/`. **This skill writes everything to `<input-folder>/output-functional-modules/`** — including its own `extracted-text/` cache, `module-phase-2d-checks.md`, `module-enumeration.md`, `module-aliases.json`, `module-candidates.txt`, and the catalogue + PDF. The two skills are fully partitioned at the top level of the input folder's output namespace; nothing collides.

> **Why per-skill output folders rather than a shared `output/` with skill-prefixed filenames**: filename prefixes (`module-*.md`, `system-*.md`) almost work, but the build-pipeline writes assets folders alongside the source markdown (`<stem>.assets/`), and those would still need disambiguation; and the user has to mentally partition a flat directory of 14 files instead of two clearly-named subdirectories. Per-skill subdirectories are cleaner, cheaper, and easier to delete (`rm -rf output-functional-modules/` re-cleans this skill's run without touching anything the data-skill produced).

> **The cost — duplicated `extracted-text/`**: yes, both skills produce their own copy of the same plain-text extractions if both are run against the same input folder. Distillation is fast, content-agnostic and idempotent; the duplication is acceptable. If a future user wants to share the cache, the data-skill's `distil-binary-data.sh` already accepts an explicit second argument, so a one-line wrapper could point both skills at a shared `<input-folder>/extracted-text/` — but that's not the current default and not worth doing pre-emptively.

> **The Phase 1 invocation must pass the explicit output folder**: `distil-binary-data.sh <input-folder> <input-folder>/output-functional-modules/extracted-text`. If the second argument is omitted, the script writes to the data-skill's default `<input-folder>/output/extracted-text/` — which would mix the two skills' outputs. SKILL.md spells this out explicitly; the spec enforces it.

### F6. Modules are application surfaces — not external systems and not user roles

External systems (eLinks, JFEPS, OPT) and user roles (RSU, Court Staff, Payment Authoriser) are **not** modules and must not appear in the module catalogue. They belong in the data-dependency catalogue (external systems) or are simply users of one or more modules (roles).

> **Why this is non-obvious**: the source documents often describe a "ribbon" or "screen group" alongside the user roles that consume it; under model variance, runs sometimes promote a user role into a module entry. Phase 2d item 4 catches this.

> **What to do with cross-cutting features** (auth, audit, accessibility): these belong in the closing `## Cross-cutting NFRs` section, not as their own module H3.

### F7. Sub-modules go under their parent's H3, not as separate H3s

The source documents often describe finer-grained screens that share a parent (e.g. *Forward Look* under *Judge Itinerary*; *Payment Reconciliation* under *Payments*). These are **Sub-modules** in `module-enumeration.md` and they appear under the parent's *Capabilities* bullets or *Key user actions*, **not** as their own numbered H3.

> **Why**: a separate H3 per sub-module inflates the document and obscures the parent-child relationship. The *At a Glance* table reads more cleanly when each row is a top-level module the user can navigate to.

> **Edge case — when to promote a sub-module**: when the source documents give it a distinct ribbon entry, distinct user role, distinct NFR set, distinct status. The default is "keep it under the parent"; promotion needs justification and is recorded in `## Appendix` of the catalogue.

### F8. The optional `## Cross-cutting NFRs` section absorbs system-wide NFRs

Module-specific NFRs (e.g. `MJ-NFR-01: Judge search returns within 10 seconds`) go in the `NFRs` row of the per-module *Attribute / Detail* table. **System-wide NFRs that apply to every module** (auth, audit, accessibility, password policy) go in the closing `## Cross-cutting NFRs` section.

> **Why**: repeating the same NFRs in every module's table bloats the document and obscures which NFRs are module-specific. Hoisting system-wide NFRs to a single section keeps each module's table tight and gives a single place to update when the cross-cutting NFRs change.

> **When to omit the section**: when the source documents describe no system-wide NFRs distinct from per-module ones. Don't add an empty section as a placeholder.
